# FPGA Real-Time Vision Pipeline Skill

> 把「摄像头 → 帧缓存 → 颜色分割 → 形态学 → 质心 → 角度」这条实时视觉流水线的
> **设计、调试、优化经验**，打包成陌生队伍可以直接复用的提示词、模板、脚本和踩坑清单。

本技能包面向 **Zynq-7000 / PYNQ / 纯 RTL** 的像素流设计，不绑定某一个题目、某一块板卡。
换题目、换板卡后，核心工作流和检查表仍然可用。

---

## 0. 一句话说明

做 FPGA 视觉项目时，真正耗时间的往往不是写代码，而是：

1. 看不懂别人（或自己上周）的流水线；
2. 二值图有噪点、质心乱跳，不知道问题出在颜色判定、形态学还是边界；
3. 时序不收敛、资源超了，不知道先动哪里；
4. 上板后串口/数码管/VGA 有一个不对，只能从头查。

这个技能包把上述四类问题拆成**可执行的提示词、模板、脚本和清单**，
让一个没参与过原项目的队伍，也能按步骤复现分析和调试过程。

---

## 1. 适用场景

| 场景 | 说明 |
|---|---|
| 实时像素流 | 摄像头/DVP/HDMI 输入，逐像素处理，行/场同步 |
| 帧缓存 | 双端口 BRAM、乒乓缓冲、读写时钟不同源 |
| 颜色分割 | RGB→HSV/YCbCr，阈值判定，参考色采样 |
| 形态学 | 腐蚀/膨胀/开闭运算，行缓存 + 移位寄存器 |
| 质心/角度 | 加权质心、CORDIC atan2、定点数换算 |
| 输出 | VGA/HDMI、UART、数码管、LED、EEPROM |
| 平台 | Zynq-7000（含 PYNQ-Z2）、Artix/Kintex、纯 RTL 或 HLS |
| 工具 | Vivado（综合/实现/时序报告） |

### 1.1 能不能复用到其他题目？

**能，但要分清“通用工程层”和“视觉专用层”。**

- 视觉/视频类新题目：约 **70~90%** 可直接复用，主要换摄像头接口、颜色空间、阈值；
- 信号/控制/通信/AI 类题目：约 **30~60%** 可复用，保留数据流模板、模块卡、时序/资源优化、
  报告/复现脚本、上板基础检查；算法层要自己补；
- 本技能包**不声称**覆盖模拟前端、射频、高压安全、纯软件/批处理等场景。

| 题目类型 | 可直接复用 | 需要替换/补充 | 基本不适用 |
|---|---|---|---|
| 视觉/视频（摄像头、显示、跟踪） | 几乎全部 | 摄像头接口、颜色空间、阈值 | — |
| 工业视觉/检测 | 数据流、形态学、质心、时序/资源、报告/复现脚本 | ROI、标定、分类器 | 角度（不测角时） |
| 信号处理/测量（ADC/FFT/滤波） | 数据流模板、模块卡、时序/资源、报告/复现脚本、上板 0-2/10-12 | 采样/FFT/峰值流水线、测试激励 | 颜色/形态学/质心/CORDIC |
| 电机/运动控制（PWM/编码器/PID） | 时序/资源、CDC、复位、上板 0-2/12、报告/复现脚本 | 控制环路、保护、编码器解码 | 视觉链路 |
| 通信/接口（UART/SPI/I2C/以太网） | CDC、位宽、UART 检查、时序/资源、上板 0-2/10/12 | 协议层、误码率测试 | 视觉链路 |
| AI 推理/加速（PYNQ/DPU/HLS） | PYNQ 提示词、时序/资源、报告/复现脚本、上板 0-2 | DMA、量化、模型部署 | 像素级形态学/质心 |
| 仪器/人机交互 | 上板清单、UART、显示时序、模块卡 | 传感器驱动、菜单状态机 | 视觉算法 |

**复用等级**（详细迁移步骤见 `prompts/adapt-to-new-topic.md`）：

- **A 级，改参数即可**：`parse_vivado_report.py`、`repro_check.py`、
  `module-explanation.md`、`optimize-timing-resources.md`；
- **B 级，换输入/输出层**：`pipeline-dataflow.md`、`bringup-checklist.md`、
  `check_uart_stream.py`、`port-to-pynq.md`、`rtl-pitfalls.md` 的通用条；
- **C 级，仅作参考或需重写**：HSV/形态学/质心/CORDIC/行缓存的专用条、
  `debug-binary-mask.md`。

> 提交前用 `checklists/reuse-checklist.md` 自查一遍，避免把“纸面推演”写成“上板实测”。

---

## 2. 不适用场景（失效条件）

遇到以下情况，本技能包的部分内容会失效，请先判断：

| 失效条件 | 影响 | 替代做法 |
|---|---|---|
| 非像素流架构（CNN 加速器、帧级批处理） | 行缓存、逐像素流水线模板不适用 | 改用张量/帧级流水线模板 |
| 多摄像头同步、多路视频拼接 | 单路时钟域分析不够 | 增加多时钟域/同步章节 |
| 1080p/4K 高带宽 | 行缓存位宽、BRAM 带宽估算需重算 | 先做带宽预算，再套模板 |
| MIPI/CSI 摄像头 | DVP 捕获章节不适用 | 替换为 MIPI CSI-2 RX 章节 |
| Quartus/Gowin/ISE | `parse_vivado_report.py` 不能直接解析 | 用对应工具的报表解析器 |
| 纯软件 OpenCV | 硬件流水线模板不适用 | 只用「算法描述→软硬划分」提示词 |
| 没有行/场同步的连续流 | 行缓存边界处理不适用 | 改用 AXI-Stream 帧边界方案 |

> **判断方法**：如果你的设计里存在「当前像素 + 上一行/前几行」的窗口运算，
> 本技能包的行缓存与边界清单就适用；如果只做逐帧独立处理，可跳过形态学部分。

---

## 3. 目录结构

```
skill/
├── README.md                         # 本文件：总说明
├── SKILL.md                          # Claude Code 技能入口（可被自动加载）
├── prompts/
│   ├── explain-pipeline.md           # 提示词：讲清一条陌生流水线
│   ├── debug-binary-mask.md          # 提示词：二值图/质心调试决策树
│   ├── optimize-timing-resources.md  # 提示词：按时序/资源报告优化
│   ├── port-to-pynq.md               # 提示词：把 RTL 流水线迁到 PYNQ
│   └── adapt-to-new-topic.md         # 提示词：迁移到非视觉题目
├── templates/
│   ├── pipeline-dataflow.md          # 模板：流水线数据流/时钟域表
│   ├── module-explanation.md         # 模板：单模块讲解卡
│   └── vivado-report-check.md        # 模板：综合/实现报告检查表
├── checklists/
│   ├── rtl-pitfalls.md               # 清单：RTL 视觉流水线常见坑
│   ├── bringup-checklist.md          # 清单：上板 bring-up 顺序
│   └── reuse-checklist.md            # 清单：技能包复用性自检
├── scripts/
│   ├── parse_vivado_report.py        # 脚本：解析 Vivado 利用率/时序报告
│   ├── check_uart_stream.py          # 脚本：检查串口字节流是否合理
│   └── repro_check.py                # 脚本：检查目录/命名/XDC 可复现性
├── tests/
│   └── selftest.py                   # 自测：9 个用例，验证三个脚本
└── examples/
    └── v1020-case-study.md           # 案例：v_1020 项目的应用记录
```

所有目录和文件名均为**小写英文 + 数字 + 下划线/连字符**，无中文、无空格，满足跨平台复现要求
（`README.md`、`SKILL.md` 为约定名，保留大写）。中文只出现在文件正文中。

---

## 4. 快速开始（10 分钟）

### 第一步：讲清流水线

把 `prompts/explain-pipeline.md` 的模板复制给大模型，替换 `{}` 里的信息。
如果你只有源码、没有文档，把顶层端口和模块例化列表贴进去，让模型先画数据流图。

**产出**：一张 ASCII 数据流图 + 时钟/复位表 + 每个模块的一句话职责。

### 第二步：对照踩坑清单

打开 `checklists/rtl-pitfalls.md`，按编号逐条对照你的代码。
每条都给出「触发条件 → 现象 → 根因 → 修复 → 验证」，可以先只看「触发条件」快速筛选。

**产出**：一张 `问题 | 位置 | 风险等级 | 修复` 的表。

### 第三步：跑校验脚本

```bash
# 解析 Vivado 报告（利用率 + 时序）
python -I scripts/parse_vivado_report.py --util util.rpt --timing timing.rpt

# 检查串口抓包
python -I scripts/check_uart_stream.py capture.bin --min 0 --max 180

# 检查目录/命名/XDC 是否可复现
python -I scripts/repro_check.py /path/to/project

# 运行技能包自测（9 个用例，约 1 秒）
python -I tests/selftest.py
```

**产出**：Markdown 表格 + 非零退出码（可直接接 CI）。

### 第四步（可选）：迁到 PYNQ

如果板卡是 PYNQ-Z2 或其它 Zynq 板，用 `prompts/port-to-pynq.md` 生成
overlay 方案（AXI-Stream + VDMA + Python 控制）和上板顺序。

### 第五步（可选）：换到其他题目

先用 §1.1 的矩阵分类，再用 `prompts/adapt-to-new-topic.md` 填新旧阶段映射表；
迁移前用 `checklists/reuse-checklist.md` 自查。视觉类题目可直接复用 70% 以上；
非视觉题目只复用通用工程层，算法层需自己补。

---

## 5. 组件详解

### 5.1 提示词工作流（prompts/）

| 文件 | 用途 | 输入 | 输出 |
|---|---|---|---|
| `explain-pipeline.md` | 讲清陌生工程 | 顶层端口、模块列表、时钟 | 数据流图、时钟域表、模块职责 |
| `debug-binary-mask.md` | 二值图/质心异常 | 现象、关键波形、阈值 | 按决策树定位到具体阶段 |
| `optimize-timing-resources.md` | 时序/资源优化 | Vivado 报告、目标频率 | 瓶颈分类、优化方案、前后对比表 |
| `port-to-pynq.md` | RTL 迁 PYNQ | 接口、数据宽度、帧率 | overlay 框图、DMA/缓冲方案、bring-up 顺序 |
| `adapt-to-new-topic.md` | 换到非视觉题目 | 新题目输入/输出/指标 | 复用等级、阶段映射表、最小闭环 |

**使用方法**：复制文件内容 → 替换 `{}` → 发给大模型 → 按输出里的「还缺什么」补信息。
**失效条件**：输入信息严重不足（例如只有一句“帮我优化”）时，模型会先追问；
不要让它猜时钟频率、像素格式、位宽，否则输出不可信。

### 5.2 案例模板（templates/）

| 文件 | 用途 |
|---|---|
| `pipeline-dataflow.md` | 记录每一级的时钟、位宽、延迟、资源、备注 |
| `module-explanation.md` | 单模块讲解卡：职责、端口、时序、算法、边界、验证 |
| `vivado-report-check.md` | 综合/实现报告检查表：WNS/WHS、LUT/FF/BRAM/DSP、CDC |

**使用方法**：复制模板到你的设计文档，逐格填写；空着的格子就是还没搞清楚的地方。
**失效条件**：模板是“提问清单”，不是“自动填表”；需要你提供真实报告和代码。

### 5.3 校验脚本（scripts/）

| 脚本 | 检查什么 | 退出码 |
|---|---|---|
| `parse_vivado_report.py` | LUT/FF/BRAM/DSP、WNS/WHS/TNS/THS | 0=时序满足，1=不满足/解析失败 |
| `check_uart_stream.py` | 字节范围、卡死（可选）、跳变（可选）、统计 | 0=通过，1=越界/卡死 |
| `repro_check.py` | 目录结构、文件命名、XDC 引脚/电平配对 | 0=通过，1=有问题 |

**使用方法**：见每个脚本头部的 `--help` 和示例。
**失效条件**：报告格式随 Vivado 版本变化；脚本用宽松正则，解析不到时会明确报错并返回 1，
不会静默给出错误结果。

### 5.4 踩坑清单（checklists/）

`rtl-pitfalls.md` 收录 16 条真实踩过的坑，覆盖：

- 行缓存下标越界、帧首陈旧数据、消隐期写坏第 0 列；
- 派生时钟导致状态切换慢一拍；
- 组合逻辑里用非阻塞赋值；
- RGB565→RGB888 零填充导致最大值只有 0xF8；
- HSV 色相环绕、线性平均把红色平均成青色；
- 参考色无复位、EEPROM 标志粘滞、清空开关被当复位；
- 质心门限、加权质心反馈锁死；
- CORDIC 输入缩放溢出、输出位宽不够；
- 25/100 MHz 跨时钟域没有同步器；
- UART 发原始字节而不是 ASCII。

每条都有「来源」，说明是从哪个项目的哪次失败/观察中总结的。

`reuse-checklist.md` 用于提交/交接前自查：范围、每项四要素、脚本可执行性、
迁移能力、评审前 10 分钟检查。它不替代 `rtl-pitfalls.md`，而是检查“别人能不能用”。

### 5.5 组件证据表（对应 3.3.5.2 的“每一项”）

> 验证效果分三档，不要混用：
> **已执行** = 脚本/自测实际跑过；**静态分析** = 对照源码逐行检查；
> **纸面推演** = 只做了方案推演，没有建工程/上板。

| 组件 | 适用场景 | 使用方法 | 验证效果 | 来源/失败观察 |
|---|---|---|---|---|
| `prompts/explain-pipeline.md` | 陌生 RTL 流水线 | 填顶层/端口/例化，先要结构 | 静态分析：v_1020 产出 20+ 模块、4 时钟域、2 反馈回路、4~6 拍延迟 | 显示比摄像头晚几拍、两条反馈回路 |
| `prompts/debug-binary-mask.md` | 二值图/质心异常 | 按 0~7 级决策树逐级排查 | 静态分析：定位左边界、顶部、红色丢失、上电误检 4 类 | 坑 #1/#2/#7/#8 |
| `prompts/optimize-timing-resources.md` | Vivado 时序/资源 | 先跑脚本提数，再贴关键路径 | 静态分析：识别组合除法、16 项 AND/OR、派生时钟、CDC 4 个热点；未做优化前后对比 | HSV 除法、形态学长路径 |
| `prompts/port-to-pynq.md` | Zynq/PYNQ overlay | 选 A/B/C 架构，按 8 步上板 | 纸面推演：完成架构/寄存器/上板顺序模板；未在真实 PYNQ 跑通 | PL 内闭环 vs VDMA 的取舍 |
| `prompts/adapt-to-new-topic.md` | 换到非视觉题目 | 先分类，再填新旧阶段映射表 | 纸面推演：覆盖信号/控制/通信 3 类；未实际建工程 | 非视觉题目只能复用通用层 |
| `templates/pipeline-dataflow.md` | 任何多级流水线 | 逐级填时钟/位宽/延迟/资源 | 静态分析：v_1020 填出 6 级流水和 2 条反馈 | 模块间时钟/位宽不一致 |
| `templates/module-explanation.md` | 任何 RTL 模块 | 一模块一卡 | 静态分析：用于 `erode`/`center`/`cordic`，暴露边界/位宽问题 | 坑 #1/#13/#14 |
| `templates/vivado-report-check.md` | Vivado 报告 | 对照 WNS/WHS/资源/CDC 打勾 | 示例报告可填；未在完整工程报告上逐项打勾 | 只看 WNS 不看 WHS/CDC 会误判 |
| `scripts/parse_vivado_report.py` | Vivado 文本报告 | `--util` / `--timing` | **已执行**：自测 3/3；WNS<0 返回 1 | 报告数字散落在长文本里 |
| `scripts/check_uart_stream.py` | 定长字节流 | `.bin`/hex/dec + 阈值 | **已执行**：自测 3/3；识别越界/卡死/跳变 | 坑 #16，串口“乱码”其实是二进制 |
| `scripts/repro_check.py` | 工程目录 | 传根目录 | **已执行**：自测 3/3；好/坏工程 + 技能包自身 | 目录/命名/XDC 是复现第一道坎 |
| `checklists/rtl-pitfalls.md` | 行缓存/形态学/定点/CDC | 按触发条件筛选 | 静态分析：v_1020 定位 6 个确定问题；16 条均有来源 | 失败观察 #1~#16 |
| `checklists/bringup-checklist.md` | 上板调试 | 0~12 步顺序执行 | 条目来自 v_1020 接口与常见故障；未逐项上板执行 | 全链路一起查会浪费时间 |
| `checklists/reuse-checklist.md` | 提交/交接前 | 逐项打勾 | 纸面推演 + 技能包自查 | 评审标准是“陌生人能否直接用” |
| `examples/v1020-case-study.md` | 案例参考 | 按复现步骤 grep/填表 | 静态分析：6 个问题有文件/行号；修复未实施 | v_1020 源码 |
| `tests/selftest.py` | 脚本回归 | `python -I tests/selftest.py` | **已执行**：9/9 通过（2026-10-25） | 脚本开发中的好/坏样例 |

---

## 6. 总表：适用范围 / 使用方法 / 失效条件

| 组件 | 适用范围 | 使用方法 | 失效条件 |
|---|---|---|---|
| `prompts/explain-pipeline.md` | 任何逐像素流水线 | 填顶层信息，让模型画图 | 只有零散代码、没有模块边界 |
| `prompts/debug-binary-mask.md` | 颜色分割 + 形态学 + 质心 | 按决策树从图像到质心逐级排查 | 问题不在视觉链路（如电源/时钟） |
| `prompts/optimize-timing-resources.md` | Vivado 综合/实现后 | 贴报告，按瓶颈分类优化 | 没有报告，或目标频率未定 |
| `prompts/port-to-pynq.md` | Zynq + PYNQ overlay | 按框图接 AXI-Stream/VDMA | 板卡不是 Zynq，或不用 PYNQ |
| `prompts/adapt-to-new-topic.md` | 换到非视觉题目 | 先分类，再填新旧阶段映射表 | 题目需要模拟前端/射频/安全隔离 |
| `templates/pipeline-dataflow.md` | 任何多级流水线 | 逐级填表 | 单模块、无流水线 |
| `templates/module-explanation.md` | 任何 RTL 模块 | 逐项填写讲解卡 | 纯 IP 黑盒、无源码 |
| `templates/vivado-report-check.md` | Vivado 工程 | 对照报告打勾 | Quartus/Gowin 工程 |
| `checklists/rtl-pitfalls.md` | 行缓存/形态学/定点/CDC | 按触发条件筛选 | 非像素流架构 |
| `checklists/bringup-checklist.md` | 上板调试 | 按顺序逐项验证 | 仿真阶段（可先用前 3 项） |
| `checklists/reuse-checklist.md` | 提交/交接前 | 逐项打勾 | 技能包尚未抽象成组件 |
| `scripts/parse_vivado_report.py` | Vivado 文本报告 | `--util` / `--timing` | 报告格式不兼容 |
| `scripts/check_uart_stream.py` | 串口字节流 | 传 `.bin` 或十六进制文本 | 数据不是定长字节 |
| `scripts/repro_check.py` | 工程目录 | 传项目根目录 | 目录结构与约定不同 |

---

## 7. 已验证的效果

> 说明：以下记录来自本技能包形成过程中对 **v_1020（Zynq-7020 + OV7725 + VGA + 三色跟踪）**
> 项目的实际分析，不是凭空声称的通用 benchmark。

| 验证项 | 做法 | 结果 |
|---|---|---|
| 流水线讲解 | 用 `explain-pipeline` 工作流分析 20+ 模块的工程 | 产出统一的数据流图、时钟域表，能解释“显示图为什么比摄像头晚几拍” |
| 踩坑清单 | 用 `rtl-pitfalls` 对照 v_1020 源码 | 定位到 6 个具体问题：行缓存 `h-3` 越界、帧首陈旧行、消隐期写第 0 列、组合逻辑非阻塞赋值、HSV 红色环绕、UART 发原始字节 |
| 报告脚本 | 用 `parse_vivado_report.py` 解析示例利用率/时序报告 | 能输出 Markdown 表，并在 WNS<0 时返回非零退出码 |
| 串口脚本 | 用 `check_uart_stream.py` 检查示例字节流 | 能统计 min/max/mean，识别越界和长时间卡死 |
| 复现脚本 | 用 `repro_check.py` 检查技能包自身目录 | 能发现中文文件名、缺失目录、XDC 引脚/电平不配对 |
| 脚本自测 | 运行 `tests/selftest.py`（2026-10-25） | 9/9 通过：3 个解析场景、3 个串口场景、3 个复现场景 |
| 跨题目复用 | 对 7 类题目做纸面推演（2026-10-25） | 视觉类 70~90% 复用；信号/控制/通信/AI 类 30~60%；未实际建工程 |

**还没有验证的**：

- 尚未在第二个完全无关的项目上做端到端验证；
- 非视觉题目只做了纸面推演，没有实际新建工程验证；
- 尚未在真实 PYNQ-Z2 上跑通 `port-to-pynq` 的完整 overlay；
- Vivado 报告解析只覆盖常见文本格式，未覆盖所有版本。

这些限制写在 README 里，避免使用者误以为“万能”。

---

## 8. 经验来源：从哪些失败/观察中总结

| 编号 | 失败/观察 | 沉淀到 |
|---|---|---|
| 1 | 腐蚀模块在 `h=2` 读 `LineBuffer[h-3]`，仿真出现 X | `rtl-pitfalls` #1 |
| 2 | 每帧最上面几行出现异常白块，发现行缓存未清、`v>=2` 不够 | `rtl-pitfalls` #2 |
| 3 | 消隐期 `h=0` 仍在写行缓存，左边界第 0 列被覆盖 | `rtl-pitfalls` #3 |
| 4 | `always@(posedge Line_CLK)` 派生时钟导致换行慢一拍 | `rtl-pitfalls` #4 |
| 5 | `BW.v` 在 `always@(*)` 里用 `<=`，仿真/综合语义有差异风险 | `rtl-pitfalls` #5 |
| 6 | RGB565→888 用零填充，白色最大只有 0xF8，阈值需按 0..248 设计 | `rtl-pitfalls` #6 |
| 7 | 红色目标 H 在 0/179 两端，线性平均可能得到 90（青色） | `rtl-pitfalls` #7 |
| 8 | `HSV_detect` 无复位，上电默认 0，会先匹配黑色 | `rtl-pitfalls` #8 |
| 9 | EEPROM 读入后 `data_on*Switch_changed` 粘滞，按键/清空失效 | `rtl-pitfalls` #9 |
| 10 | `sw_ColorClear` 同时当异步复位，按住时 ROI 不累加 | `rtl-pitfalls` #10 |
| 11 | 质心 `Binary_Sum<=30` 时直接归零，目标小时十字光标跳到原点 | `rtl-pitfalls` #11 |
| 12 | 加权质心用上一帧中心算权重，中心错了会锁死在错误区域 | `rtl-pitfalls` #12 |
| 13 | CORDIC 输入 `<<14` 溢出 16 位，改为 `*50` | `rtl-pitfalls` #13 |
| 14 | `angle` 8 位，最大约 358°，会回绕 | `rtl-pitfalls` #14 |
| 15 | 25 MHz 视觉域与 100 MHz 角度/EEPROM 域直接相连，无同步器 | `rtl-pitfalls` #15 |
| 16 | UART 发原始字节，串口助手显示“乱码”，其实是二进制 | `rtl-pitfalls` #16 |

---

## 9. 迁移到自己的题目

### 9.1 三步迁移法

1. **分类**：用 §1.1 的矩阵判断新题目属于哪一类，得到 A/B/C 复用等级；
2. **映射**：把新题目拆成“输入 → 缓存 → 核心算法 → 后处理 → 输出”五级，
   逐级填 `prompts/adapt-to-new-topic.md` 里的映射表（复用/新写/验证/风险）；
3. **闭环**：先做一个“输入能进、结果能出、有已知答案”的最小系统，再替换算法。

### 9.2 同领域迁移（视觉 → 视觉）

- **换摄像头**：只改捕获层（DVP→MIPI/CSI），行缓存/形态学/质心模板不变；
- **换颜色空间**：RGB→HSV 换成 RGB→YCbCr，阈值清单里的“色相环绕”改成“Cb/Cr 范围”；
- **换输出**：VGA→HDMI 只改时序生成和像素打包；UART→以太网只改输出适配层；
- **换板卡**：Zynq→Artix 时，PYNQ 章节跳过，RTL/行缓存/CDC 章节保留。

### 9.3 跨领域迁移（视觉 → 非视觉）

- **信号/测量**：保留数据流模板、模块卡、时序/资源、报告/复现脚本；
  把 HSV/形态学/质心换成“采样/FFT/峰值检测”，用已知正弦/双音做验证；
- **电机/控制**：保留 CDC、复位、位宽、时序/资源、上板基础检查；
  把视觉链路换成“采样/PID/PWM”，先开环再闭环；
- **通信/接口**：保留 CDC、UART 检查、时序/资源；补协议层和误码率测试；
- **AI/PYNQ**：保留 PYNQ 提示词、报告/复现脚本；补 DMA、量化、模型部署。

### 9.4 不要做的事

- 不要把“通用工程层”说成“算法层也能直接用”；
- 不要把 v_1020 的阈值、权重、ROI 坐标照抄到新题目；
- 不要在非视觉题目里硬套“行缓存/形态学/质心”；
- 不要在没跑通最小闭环前就做全链路优化。

> 迁移前用 `checklists/reuse-checklist.md` 自查；迁移方案用
> `prompts/adapt-to-new-topic.md` 生成，避免“凭感觉复用”。

---

## 10. 已知限制

- 报告解析脚本按 Vivado 常见文本格式编写，版本差异可能导致解析失败（会报错，不会静默）。
- 踩坑清单来自 Zynq-7020 + OV7725 + VGA 的实现，其他平台需自行验证。
- PYNQ 章节是方案级指导，不是可直接上板的完整 overlay。
- 阈值/权重是示例值，不能照抄；技能包教的是“怎么调”，不是“调成多少”。
- 技能包以视觉流水线为主案例；非视觉题目只迁移通用工程层，算法层（FFT/PID/协议等）需自行补充。
- §1.1 的复用矩阵是纸面推演，不是已建工程的实测结论；引用时请保留这一限定。

---

## 11. 许可与引用

本技能包可自由用于学习、竞赛和工程实践。
引用时请注明：`FPGA Real-Time Vision Pipeline Skill`。
