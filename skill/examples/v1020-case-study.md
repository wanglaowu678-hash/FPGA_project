# 案例：v_1020 —— Zynq-7020 实时三色跟踪

> 本案例记录如何用本技能包分析一个真实工程。
> **所有结论来自源码静态阅读，不是仿真/上板实测**；修复建议未在原工程中实施。
> 目的是展示“技能包怎么用”，不是宣称“这个工程已经修好了”。

## 1. 项目概况

| 项目 | 内容 |
|---|---|
| 工程 | `D:/fpgacode/v_1020` |
| 板卡/器件 | 正点原子 Zynq-7020，`xc7z020clg400-1` |
| 摄像头 | OV7725，DVP 8 位，RGB565 |
| 分辨率 | 320×240（摄像头） |
| 显示 | VGA 640×480@60，图像窗口 320×240 |
| 处理 | RGB→HSV → 颜色判定 → 4×4 腐蚀/膨胀 → 加权质心 → CORDIC 夹角 |
| 输出 | VGA、UART 38400、数码管、LED、EEPROM |
| 工具 | Vivado（Block Design + 自写 RTL） |

## 2. 数据流

```text
OV7725 DVP
  │  PCLK / HREF / VSYNC，8 bit 双沿拼成 RGB565
  ▼
[camera capture] ──▶ [dual-port BRAM 320×240×16]
                            │  读时钟 25 MHz
                            ▼
                    [RGB565 → RGB888]
                            │
                            ▼
                    [RGB → HSV 3 级流水]
                            │  H(0..179) S(0..255) V(0..255)
              ┌─────────────┴─────────────┐
              ▼                           ▼
    [参考色 ROI 32×32 平均]        [逐像素加权距离判定]
              │  HSV_detect               │  Binary_PreProcess
              └─────────────┬─────────────┘
                            ▼
                 [4×4 腐蚀] → [4×4 膨胀]
                            │  Binary_PostProcess
              ┌─────────────┴─────────────┐
              ▼                           ▼
       [加权质心 center]            [VGA 二值图/渲染]
              │  center_h / center_v
              ▼
       [CORDIC 夹角 ×2] ──▶ [UART / 数码管 / LED]
```

反馈回路有两条：

1. **形态学反馈**：`colorDetect` 内部的二值图先腐蚀再膨胀，结果再参与质心统计；
2. **质心反馈**：`weight_cal` 用上一帧的 `center_h/center_v` 计算本帧权重。

## 3. 时钟 / 复位

| 时钟/复位 | 频率/极性 | 来源 | 主要负载 |
|---|---|---|---|
| `PCLK`（摄像头） | 随 OV7725 配置 | 摄像头 | 捕获、写帧缓存 |
| `clk_wiz_0_clk_out1` | 25 MHz | PLL | 显示、HSV、形态学、质心 |
| `clk100` | 100 MHz | PLL | 角度计算、EEPROM |
| `clk_38400` | 38400 Hz | 分频 | UART |
| `rst` / `vga_rst` | 高有效 | 按键/逻辑 | 显示、VGA |
| `rst_n` | 低有效 | 按键/开关 | 多数处理模块 |

> 观察：25 MHz 域与 100 MHz 域之间没有同步器，角度模块直接读 25 MHz 域的
> `counter_h/counter_v`。这是**待确认风险**，不是本次六个确定问题之一。

## 4. 用了技能包的哪些部分

| 技能包组件 | 在这个工程里的用法 | 产出 |
|---|---|---|
| `prompts/explain-pipeline.md` | 从顶层端口和例化列表还原数据流 | 上面的 ASCII 图、时钟表 |
| `templates/pipeline-dataflow.md` | 记录每级时钟/位宽/延迟 | 发现两条反馈回路 |
| `checklists/rtl-pitfalls.md` | 逐条对照源码 | 6 个确定问题 + 4 个风险 |
| `prompts/debug-binary-mask.md` | 按“参考色→阈值→形态学→质心”排查 | 定位到左边界/顶部伪影 |
| `templates/module-explanation.md` | 给 `erode`/`center`/`cordic` 各填一张卡 | 明确边界条件和位宽 |
| `scripts/check_uart_stream.py` | 检查抓包是否越界/卡死 | 发现“乱码”其实是原始字节 |
| `scripts/repro_check.py` | 检查目录/命名/XDC | 发现工程目录不在竞赛推荐结构内 |

## 5. 六个确定问题

### 5.1 行缓存读下标越界

- **证据**：`src/erode.v:53-55`、`src/dilate.v:52-54`
  - guard：`VtcHCnt>=2`
  - 读：`LineBuffer2[VtcHCnt-3]`
- **现象**：`VtcHCnt=2` 时读下标为负；仿真得到 X，上板左边界 1~3 列异常。
- **根因**：`VtcHCnt` 是 12 位无符号；`2-3` 在表达式中回绕成一个巨大的无符号数，
  超出 `LineBuffer[0..319]` 的范围。
- **修复**：guard 改为 `VtcHCnt>=3`（`dilate.v` 同样改）。
- **验证**：仿真 h=0..5 无 X；左边界无固定条带。

```verilog
// 修改前
if (VtcHCnt>=2 && VtcVCnt>=2 && VtcHCnt<318 && VtcVCnt<238) begin
    ... LineBuffer2[VtcHCnt-3] ...

// 修改后
if (VtcHCnt>=3 && VtcVCnt>=3 && VtcHCnt<318 && VtcVCnt<238) begin
```

> 注意：`reg LineBuffer0[319:0]` 是 **320 个 1 bit 的数组**，不是 320 位向量。
> 变量下标读会综合成大的多路选择器；这是后续资源优化的重点。

### 5.2 帧首行缓存未清，`v>=2` 不够

- **证据**：`src/erode.v:22-34`，`state` 每帧在 `VtcVCnt==0` 归零；
  `LineBuffer0..3` 没有清零逻辑。
- **现象**：每帧最上面一行（v=2）出现上一帧的残留白块/黑块。
- **根因**：4×4 窗口需要前 3 行。v=2 时只有 v=0、v=1 两行属于当前帧，
  第三行来自上一帧的陈旧数据。
- **修复**：帧首清零 4 个行缓存；或 guard 改为 `VtcVCnt>=3`。
- **验证**：连续多帧，顶部边界稳定；换帧无闪烁。

```verilog
// 方案 A：帧首清零（在 VtcVCnt==0 的 Line_CLK 周期）
if (VtcVCnt == 0) begin
    for (i = 0; i < 320; i = i + 1) begin
        LineBuffer0[i] <= 0; LineBuffer1[i] <= 0;
        LineBuffer2[i] <= 0; LineBuffer3[i] <= 0;
    end
end
```

### 5.3 消隐期仍写行缓存第 0 列

- **证据**：`src/erode.v:44-47` 等，`LineBuffer0[VtcHCnt] <= pix_i;` 没有写使能；
  `region_cut` 在窗口外把 `VtcHCnt` 钳到 0。
- **现象**：左边界 3 列参与形态学运算时，用的是被消隐期覆盖过的第 0 列。
- **根因**：消隐期每个 25 MHz 周期都写 `LineBuffer[0]`，把上一行第 0 列覆盖掉；
  等这个缓存转成“前一行”时，第 0 列已经不是原来的像素。
- **修复**：只在有效像素区写，例如 `if (VtcHCnt < 320 && VtcVCnt < 240)`。
- **验证**：ILA 看写使能，消隐期应为 0；左边界无固定伪影。

### 5.4 组合逻辑里用非阻塞赋值

- **证据**：`src/bw.v:12-38`，`always@(*)` 内使用 `H_diff <= ...`、`diff_sum <= ...`、
  `Binary_out <= ...`。
- **现象**：仿真依赖 delta cycle 收敛；可读性差，容易在后续修改中引入竞争。
- **根因**：组合逻辑应使用阻塞赋值 `=`，非阻塞赋值表达的是“时钟沿后更新”。
- **修复**：`always@(*)` 内全部改为 `=`。
- **验证**：lint 无警告；仿真结果与手算阈值一致。

```verilog
// 修改前
always @(*) begin
    H_diff <= ...;
    diff_sum <= H_diff/2 + S_diff/4 + V_diff/4;
    Binary_out <= 0;
end

// 修改后
always @(*) begin
    H_diff = ...;
    diff_sum = H_diff/2 + S_diff/4 + V_diff/4;
    Binary_out = 0;
end
```

### 5.5 HSV 色相环绕：红色可能被平均成青色

- **证据**：`src/color_detect.v:139-152`，ROI 内直接累加 `HUE`，帧末 `H_Sum/1024`；
  `HUE` 范围 0..179，红色同时出现在 0 和 179 附近。
- **现象**：目标红色跨 0/179 时，参考色 H 可能落在 90 附近（青色），红色检测不到。
- **根因**：H 是环形量，线性平均不满足环绕语义；`(0+179)/2≈90`。
- **修复**：距离用环形距离 `min(|ΔH|, 180-|ΔH|)`；平均用 sin/cos 或向量平均；
  或者规定参考色只取 ROI 主色（直方图峰值）。
- **验证**：红目标跨 0/179 时，参考色仍接近 0 或 179。

```verilog
// 环形距离
wire [7:0] dh = (HUE > ref_h) ? (HUE - ref_h) : (ref_h - HUE);
wire [7:0] dh_wrap = (dh > 90) ? (180 - dh) : dh;
```

### 5.6 UART 发的是原始字节，不是 ASCII

- **证据**：`src/design_1.v:111`，`assign uarttemp = SwitchUart ? angle : counter_v1;`；
  `src/design_1.v:389`，`.data_o(uarttemp)`；`src/uart_tx.v` 直接按位发送。
- **现象**：串口助手默认 ASCII 模式显示乱码；用户误以为波特率不对。
- **根因**：发送的是 0..255 的二进制值，不是 `'0'..'9'`/`'A'..'F'` 字符。
- **修复**：FPGA 内先做 bin→ASCII（十进制字符串），或上位机切 HEX 模式/按二进制解析。
- **验证**：HEX 模式字节值等于角度；ASCII 模式显示可读数字。

## 6. 额外观察（未列为确定问题）

| 观察 | 位置 | 风险 | 建议 |
|---|---|---|---|
| 25 MHz ↔ 100 MHz 无同步器 | `design_1.v` 角度模块输入 | 中 | 单比特 2FF；多比特握手/异步 FIFO |
| `angle` 只有 8 位 | `angle_calculation.v:14` | 中 | 最大约 358°，会回绕；改 9 位或限幅 |
| 加权质心用上一帧中心 | `weight_cal.v` + `center.v` | 中 | 中心偏了会正反馈锁死；首帧用普通质心 |
| 行缓存用变量下标数组 | `erode.v:40-43` | 中 | 可能综合成大量 LUT/FF；考虑向量+移位或 BRAM |
| EEPROM 读入标志粘滞 | `src/color_detect.v:133` | 低 | 读完后清标志，避免覆盖按钮/清空 |

## 7. 复现步骤

陌生队伍拿到这个案例后，可以按下面顺序复现：

1. 打开工程，列出顶层端口与所有例化模块（`design_1.v`）；
2. 用 `templates/pipeline-dataflow.md` 填时钟、位宽、延迟；
3. 用 `checklists/rtl-pitfalls.md` 的「触发条件」逐条 grep：
   - `grep -n "\-3\]" src/erode.v src/dilate.v`
   - `grep -n "always@(\*)" src/bw.v`
   - `grep -n "H_Sum / 1024" src/color_detect.v`
   - `grep -n "uarttemp" src/design_1.v`
4. 对每个命中项，按「现象 → 根因 → 修复 → 验证」记录；
5. 用 `scripts/check_uart_stream.py capture.bin --max 180` 检查串口抓包；
6. 用 `scripts/repro_check.py .` 检查目录/命名/XDC。

## 8. 这个案例验证了什么

| 验证点 | 结果 |
|---|---|
| 能从源码还原数据流和时钟域 | 是，20+ 模块、2 条反馈回路 |
| 能定位到具体文件/行 | 是，6 个问题都有行号 |
| 能给出可执行的修复 | 是，附代码片段 |
| 修复后上板验证 | **否**，未在原始工程实施 |
| 在第二个无关工程复现 | **否**，尚未做 |

## 9. 教训

1. **边界条件比算法更容易出错**：6 个问题里有 3 个是边界/消隐/帧首。
2. **“看起来能跑”不等于正确**：左边界 3 列、顶部 1 行的问题很容易被忽略。
3. **输出格式要写进接口约定**：UART 发原始字节还是 ASCII，必须在文档里写清楚。
4. **环量不能线性平均**：色相、角度都要用环形距离。
5. **反馈回路要单独验证**：加权质心的正反馈会放大初始误差。
