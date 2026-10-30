# 模板：流水线数据流 / 时钟域记录表

> 复制到你的设计文档，逐格填写。空着的格子就是还没搞清楚的地方。

## 1. 工程信息

| 项目 | 内容 |
|---|---|
| 工程名 | {name} |
| FPGA/板卡 | {board} |
| 工具/版本 | {tool_version} |
| 输入源 | {camera/sensor/hdmi} |
| 分辨率/帧率 | {resolution} @ {fps} |
| 像素格式 | {RGB565/RGB888/YUV422/灰度/二值} |
| 输出 | {VGA/HDMI/UART/...} |

## 2. 数据流图（ASCII）

```text
{input}
   │
   ▼
[stage 1: {module}] ── {width} bit ──▶ ...
   │
   ▼
[stage 2: {module}]
   │
   ▼
{output}

反馈回路（如有）：
{module A} ──▶ {module B} ──▶ {module A}
```

## 3. 分级表

| 级 | 模块 | 时钟 | 输入 | 输出 | 位宽 | 延迟 | 资源 | 备注 |
|---|---|---|---|---|---|---|---|---|
| 0 | {capture} | {clk} | {in} | {out} | {w} | {cycles} | {IO/BRAM} | {note} |
| 1 | {convert} | {clk} | {in} | {out} | {w} | {cycles} | {LUT} | {note} |
| 2 | {segment} | {clk} | {in} | {out} | {w} | {cycles} | {LUT/DSP} | {note} |
| 3 | {morph} | {clk} | {in} | {out} | {w} | {cycles} | {LUTRAM} | {note} |
| 4 | {centroid} | {clk} | {in} | {out} | {w} | {frames} | {LUT/FF} | {note} |
| 5 | {angle} | {clk} | {in} | {out} | {w} | {cycles} | {LUT/DSP} | {note} |
| 6 | {output} | {clk} | {in} | {out} | {w} | {cycles} | {IO} | {note} |

> 延迟单位写清楚：拍（cycle）、行（line）、帧（frame）、毫秒（ms）。

## 4. 时钟/复位表

| 时钟/复位 | 频率/极性 | 来源 | 驱动模块 | 是否跨域 | 同步方式 |
|---|---|---|---|---|---|
| {pclk} | {MHz} | {camera/PLL} | {modules} | 是/否 | {2FF/FIFO/无} |
| {clk25} | {MHz} | {PLL} | {modules} | 是/否 | {..} |
| {clk100} | {MHz} | {PLL} | {modules} | 是/否 | {..} |
| {rst} | {高/低} | {button/POR} | {modules} | — | — |

## 5. 延迟预算

| 路径 | 级数 | 估算延迟 | 对显示/控制的影响 |
|---|---|---|---|
| 摄像头 → 显示 | {n} | {cycles/ms} | {图像偏移几像素/几行} |
| 摄像头 → 质心 | {n} | {frames} | {跟踪滞后} |
| 质心 → 角度 | {n} | {cycles} | {输出滞后} |
| 角度 → 串口 | {n} | {bits/baud} | {上报周期} |

## 6. 反馈回路

| 回路 | 起点 | 经过 | 回到 | 周期 | 风险 |
|---|---|---|---|---|---|
| {morphology} | {colorDetect} | {erode,dilate} | {colorDetect} | 1 pixel | 边界延迟导致窗口偏移 |
| {display} | {ram_read} | {BRAM,HSV,render} | {ram_read} | 1 frame | 读写时钟不同源 |

## 7. 风险清单

| 风险 | 位置 | 等级 | 触发条件 | 缓解 |
|---|---|---|---|---|
| CDC | {clkA→clkB} | 高/中/低 | 无同步器 | 2FF/FIFO |
| 组合除法 | {module} | 高/中/低 | 每像素 `/` | 流水线/倒数 |
| 行缓存越界 | {module} | 高/中/低 | 边界坐标 | 改 guard |
| 未初始化寄存器 | {module} | 高/中/低 | 上电/复位 | 加复位/初值 |
