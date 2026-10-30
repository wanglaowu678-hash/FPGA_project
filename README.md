# FPGA_project

基于 Xilinx Artix-7（Basys3）的**实时摄像头颜色追踪系统**：OV7725 采集 → 帧缓存 → RGB/HSV 颜色分割 → 形态学去噪 → 质心提取 → 三点角度解算 → VGA 显示 / UART 输出 / 数码管显示。

全部逻辑用 Verilog 直接实现，不依赖 HLS，可作为 FPGA 图像处理流水线、DVP 摄像头驱动、VGA 时序与 CORDIC 运算的学习参考。

> Real-time color-tracking vision pipeline on a Xilinx Artix-7 FPGA, written in plain Verilog.

---

## 1. 功能特性

- **DVP 摄像头采集**：OV7725（兼容 OV7670 时序），SCCB 寄存器自动配置，采集数据写入双端口 BRAM 帧缓存。
- **跨时钟域**：摄像头像素时钟写入双端口 BRAM，100 MHz → 25 MHz 时钟域读出，读写地址由两端各自维护。
- **RGB → HSV 转换**：在硬件中完成色彩空间转换，按 HSV 阈值做颜色分割，比直接 RGB 阈值更抗光照变化。
- **按键取色**：按下按键时，取画面中心 32×32 区域的平均 HSV 作为目标颜色阈值，三路按键各自对应一个颜色通道，三路独立做形态学与质心计算。
- **形态学处理**：3×3 腐蚀 + 膨胀，去除二值图噪点、填补空洞。
- **加权质心**：对二值像素按行/列累加，计算 ROI（320×240）内的质心坐标；权重按像素到上一帧质心的距离分档，用于抑制远处噪点。
- **角度解算**：根据三个颜色块的质心坐标，用 CORDIC 计算以第二个点为顶点的三点夹角。
- **多种输出**：
  - VGA 640×480 实时显示，并在原图上渲染质心与连线；
  - UART 38400 8N1 输出坐标/角度；
  - 4 位数码管以 BCD 显示当前数值；
  - 12 个 LED 同步指示。

## 2. 硬件平台

| 项目 | 说明 |
|---|---|
| FPGA | Xilinx Artix-7 **xc7a35tcpg236-1** |
| 开发板 | Basys3（引脚命名与板载按键/开关/数码管/LED 一致，见 XDC） |
| 摄像头 | OV7725（DVP 并口，8-bit），I2C/SCCB 配置 |
| 显示 | VGA 640×480 @ 60 Hz（Pmod VGA） |
| 其他 | 板载 EEPROM（保存颜色阈值）、UART、4 位七段数码管 |

> 引脚以 [ov7725colorbracking.xdc](v_1020/srcs/ov7725colorbracking.xdc) 为准。换板卡时只需改约束文件。

## 3. 仓库结构

```
FPGA_project/
├── README.md
├── LICENSE
├── v_1020/                         # Vivado 工程（可直接打开）
│   ├── v1020.xpr                   # Vivado 2026.1 工程文件
│   ├── srcs/                       # 全部 RTL、约束、说明
│   │   ├── design_1.v              # ★ 顶层
│   │   ├── *.v                     # 各功能模块
│   │   ├── ov7725colorbracking.xdc # 引脚与时序约束
│   │   ├── schematic.pdf           # 设计框图
│   │   └── mcs.mcs / mcs.prm       # Flash 固化文件
│   └── v1020.srcs/sources_1/ip/    # IP 配置（.xci，Vivado 会自动重新生成产物）
│       ├── clk_wiz_0/              # 100 MHz → 25 MHz 时钟
│       └── blk_mem_gen_0/          # 帧缓存 BRAM
├── scripts/
│   └── create_project.tcl          # 从源码重新创建工程（不依赖 .xpr）
└── skill/                          # FPGA 实时视觉流水线经验/提示词/模板包
```

## 4. 快速开始

### 方式一：直接打开工程

1. 安装 Vivado（工程由 **Vivado 2026.1** 创建，建议同版本或更新版本打开）。
2. 打开 `v_1020/v1020.xpr`。
3. Vivado 会根据 `.xci` 自动生成 `clk_wiz_0` 与 `blk_mem_gen_0` 的输出产物。
4. 综合 → 实现 → 生成比特流 → 下载。

> 仓库不包含 `.runs/.gen/.cache/.sim` 等编译产物，首次打开或换机器后需要重新综合，属正常现象。

### 方式二：用 Tcl 重建工程

```tcl
cd /path/to/FPGA_project
vivado -mode batch -source scripts/create_project.tcl
```

脚本会在 `vivado/` 下新建工程、加入全部 RTL/约束/IP，并设置顶层为 `design_1`。

### 上板操作

| 控件 | 功能 |
|---|---|
| BTND (`rst`) | 系统复位（经消抖后复位 IIC 与显示） |
| BTNL (`btn_ColorExtract`) | 采样并设置颜色通道 1 的阈值 |
| BTNC (`btn_ColorExtract1`) | 采样并设置颜色通道 2 的阈值 |
| BTNR (`btn_ColorExtract2`) | 采样并设置颜色通道 3 的阈值 |
| SW0 (`sw_ColorClear`) | 清除当前颜色阈值 |
| SW2 (`SwitchUart`) | 输出选择：0 = 坐标，1 = 角度 |
| 按键 + EEPROM LED | 将当前颜色阈值写入/读出板载 EEPROM |

## 5. 数据流

```
OV7725 ──DVP(8bit)──► cam_ov7670_ov7725 ──► BRAM 帧缓存 ──► rgb565_rgb888 ──► rgb2hsv_top
                                                                                  │
                        ┌─────────────────────────────────────────────────────────┘
                        ▼
              colorDetect（HSV 阈值 → 二值图）
                        │
              erode（3×3 腐蚀）──► dilate（3×3 膨胀）
                        │
              center + weight_cal（加权质心，三通道各一份）
                        │
              angle_calculation + cordic（三点角度）
                        │
        ┌───────────────┼────────────────┬──────────────┐
        ▼               ▼                ▼              ▼
   render → VGA    uart_tx(38400)   bin2bcd → 数码管   LED 指示
```

## 6. 模块说明

| 模块 | 作用 |
|---|---|
| `design_1.v` | 顶层：例化并连接全部模块，定义对外端口 |
| `cam_ov7670_ov7725.v` | DVP 采集：行/场同步解析、像素拼接、BRAM 写地址与写使能 |
| `ov7725_regData.v` | OV7725 寄存器配置表（分辨率、格式等） |
| `IICctrl.v` / `I2C_Controller.v` | SCCB/I2C 主机，把配置表逐条写入摄像头 |
| `clk_div.v` | 由 25 MHz 产生 38400 波特率时钟 |
| `debounce.v` | 复位/按键消抖 |
| `rgb2hsv_top.v` | RGB888 → HSV 色彩空间转换 |
| `colorDetect.v` | 颜色分割核心：HSV 阈值判定、三通道切换、EEPROM 阈值载入、结果渲染 |
| `BW.v` | 按阈值把 HSV 像素判为 0/1，输出二值图 |
| `erode.v` / `dilate.v` | 3×3 腐蚀 / 膨胀（形态学去噪） |
| `weight_cal.v` | 计算像素参与质心的权重 |
| `center.v` | ROI（320×240）内加权质心坐标计算 |
| `cordic.v` | CORDIC 向量模式，计算 atan2 |
| `angle_calculation.v` | 由三个质心点解算目标角度 |
| `region_cut.v` | 从 VGA 时序中裁出 320×240 有效区域坐标 |
| `vga.v` | 640×480 @ 60 Hz VGA 时序产生 |
| `ram_read.v` | 帧缓存读地址与 VGA 像素输出 |
| `render.v` | 在画面上叠加质心、连线等标注 |
| `rgb565_rgb888.v` / `rgb888_rgb565.v` | 像素格式互转 |
| `e2prom_rw.v` / `top_e2prom.v` | 颜色阈值写入 / 读出板载 EEPROM |
| `bin2bcd.v` | 二进制转 BCD（数码管显示） |
| `scan_led_hex_disp.v` | 4 位数码管动态扫描 |
| `rw_result_led.v` | 结果 LED 指示 |
| `uart_tx.v` | UART 发送（38400 8N1） |

## 7. skill/ 目录

`skill/` 是一个可复用的「FPGA 实时视觉流水线」经验包，与具体题目/板卡解耦，包含：

- `SKILL.md` / `README.md`：适用范围与工作流；
- `prompts/`：讲解流水线、调试二值图、优化时序资源、移植到 PYNQ 等提示词；
- `checklists/`：上板调试、RTL 常见坑、代码复用检查表；
- `templates/`：模块说明、数据流、Vivado 报告检查模板；
- `scripts/`：UART 数据流校验、Vivado 报告解析、复现性检查脚本；
- `examples/v1020-case-study.md`：本工程作为案例的拆解。

可以直接作为 AI 编程助手（Claude Code / Codex 等）的技能包使用。

## 8. 已知限制

- 仅在 Basys3 + OV7725 硬件组合上验证；其他板卡需调整 XDC 与时钟。
- ROI、HSV 阈值、形态学窗口等参数目前为常量，针对演示场景调过参。
- `v1020.xpr` 中保存了创建时的绝对路径，跨机器打开时 Vivado 会提示路径变更；也可直接用 `scripts/create_project.tcl` 重建。

## 9. 许可证

[MIT](LICENSE)。欢迎 Issue / PR。
