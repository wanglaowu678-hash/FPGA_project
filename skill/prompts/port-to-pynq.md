# 提示词：把 RTL 视觉流水线迁到 PYNQ

## 适用场景

- 已有一条纯 RTL 的像素流水线（摄像头 → 处理 → 显示/输出），想搬到 PYNQ-Z2 或其它 Zynq 板；
- 想用 Python 动态调阈值、ROI、颜色参考，而不是每次重新综合；
- 想把处理结果送到 PS/DDR，做上位机显示、记录或二次处理；
- 需要一套“先跑通、再优化”的上板顺序。

## 使用方法

1. 先确认数据通路的归属：**PL 内闭环** 还是 **经 PS/DDR**；
2. 让模型先给 block design 框图，再给寄存器映射，最后给 Python 骨架；
3. 不要一上来就上 VDMA；先用 AXI-Stream + ILA 验证像素流；
4. 每一步都要有“通过标准”，不通过不要往下走。

## 三种典型架构

### 架构 A：PL 内闭环（最低延迟）

```text
Camera → PL pipeline → frame buffer → HDMI/VGA out
                 ↑
          PS 只写配置寄存器（阈值/ROI）
```

- 优点：延迟最低，PS 不参与像素搬运；
- 缺点：PS 拿不到图像，调试靠 ILA；
- 适用：实时跟踪、角度输出、低延迟控制。

### 架构 B：经 VDMA 到 DDR（最灵活）

```text
Camera → PL pipeline → AXI-Stream → VDMA → DDR → PS/Python
                                      ↓
                               frame buffer / 显示
```

- 优点：Python 能读图、存图、做后处理；
- 缺点：DDR 带宽、缓存一致性、DMA 对齐要处理；
- 适用：需要记录、可视化、算法迭代。

### 架构 C：混合

- 低延迟通路走 A（PL 内），调试/记录通路走 B（VDMA 旁路）；
- 用 AXI-Stream 的 `tuser`（SOF）和 `tlast`（EOL）分帧。

## PYNQ overlay 要点

| 组件 | 作用 | 注意 |
|---|---|---|
| AXI-Stream video in | 摄像头/PL 输出进 PS | `tlast` 每行拉高；`tuser` 帧首 |
| AXI-Stream video out | PS 输出到 HDMI | 背压 `tready` 必须处理 |
| VDMA | DDR ↔ Stream | 至少 3 个帧缓冲；地址 64 字节对齐 |
| AXI-Lite | 寄存器控制 | 阈值/ROI/使能；加影子寄存器避免撕裂 |
| Clock Wizard | 像素时钟/总线时钟 | 像素时钟与 AXI 时钟分离 |
| Reset | 软复位 | 先复位 pipeline，再使能 DMA |

## Python 骨架（概念版）

```python
from pynq import Overlay, allocate
from pynq.lib.video import VideoMode

ol = Overlay("vision.bit")
ol.download()

# 1) 配置寄存器（AXI-Lite）
ip = ol.vision_pipeline_0
ip.register_map.threshold_h = 19
ip.register_map.threshold_s = 63
ip.register_map.threshold_v = 63
ip.register_map.enable = 1

# 2) 帧缓冲（如走 VDMA）
fb = allocate(shape=(240, 320, 3), dtype="uint8")
# ... 配置 VDMA，启动，等待帧完成 ...

# 3) 读结果
angle = ip.register_map.angle
print("angle =", angle)
```

> 具体 API 随 PYNQ 版本变化；先 `help(ol)` 和 `help(ip.register_map)` 确认字段名。

## 上板顺序（不要跳步）

1. **PS 启动**：PYNQ 镜像启动，`overlay` 能下载；
2. **AXI-Lite 回环**：写寄存器 → 读回，确认总线通；
3. **时钟/复位**：ILA 看像素时钟、`tvalid/tready/tlast`；
4. **Stream 直通**：摄像头 → AXI-Stream → HDMI，不做处理；
5. **单级处理**：只开颜色判定，看二值图；
6. **全流水线**：形态学 + 质心 + 角度；
7. **DMA/VDMA**：小分辨率、单帧，确认地址/对齐；
8. **长时间运行**：看丢帧、温度、DDR 带宽。

## 提示词模板

```text
你是一名 PYNQ/Zynq 视频流水线工程师。请把下面的 RTL 流水线迁到 PYNQ overlay。

【现有设计】
- 顶层端口：{ports}
- 像素格式/位宽：{pixel_format}
- 分辨率/帧率：{resolution_fps}
- 时钟：{clocks}
- 处理模块：{modules}
- 输出：{outputs}

【目标】
- 板卡：{board}
- PYNQ 版本：{pynq_version}
- 数据通路：{A | B | C}
- 需要 Python 控制的参数：{params}

请输出：
1. block design 框图（ASCII），标出 AXI-Stream/AXI-Lite/VDMA/时钟/复位；
2. 寄存器映射表（偏移、位宽、读写、默认值、影子寄存器策略）；
3. AXI-Stream 接口约定（tdata 位宽、tlast/tuser、背压）；
4. VDMA 配置（帧数、stride、像素格式、对齐）；
5. Python 初始化/读结果骨架；
6. 上板顺序与每步通过标准；
7. 3 个最可能踩的坑及规避方法。
```

## 常见坑

| 坑 | 现象 | 规避 |
|---|---|---|
| DMA 地址未对齐 | 传输失败/花屏 | 64 字节对齐；用 `pynq.allocate` |
| 缓存一致性 | PS 读到旧帧 | `buffer.flush()` / `invalidate()` |
| 帧缓冲太少 | 撕裂/丢帧 | 至少 3 个缓冲，乒乓+1 |
| `tlast` 缺失 | VDMA 不认帧边界 | 每行末尾拉高 `tlast` |
| 背压未处理 | 丢像素 | 全通路检查 `tready` |
| 像素格式不匹配 | 颜色错 | RGB888/BGR/ARGB 对齐 |
| 跨时钟域 | 偶发花屏 | 异步 FIFO；不要直接连 |
| 复位顺序 | DMA 卡死 | 先复位 pipeline，再启 DMA |

## 已验证效果

- 在 v_1020 的 RTL 结构上，按架构 A/B 拆分后，能明确哪些模块留在 PL、哪些数据需要过 DDR；
- 寄存器映射表可直接对应到 `colorDetect` 的阈值/ROI 参数；
- 上板顺序与 `checklists/bringup-checklist.md` 一致，可复用。

## 失效条件

- 板卡不是 Zynq（没有 PS）：PYNQ 章节不适用；
- 摄像头是 MIPI/CSI：需要先加 CSI-2 RX，不能直接套 DVP；
- PYNQ 版本过旧/过新：API 名称可能变化，需以 `help()` 为准。
