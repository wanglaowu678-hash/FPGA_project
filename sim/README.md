# sim/ — 仿真与验证

当前工程以**上板实测**为主要验证方式，未附带 testbench，因此本目录暂无仿真脚本与结果。

## 后续补充建议

若需要补充仿真，可在此目录放置：

- `tb_*.v`：针对单模块的 testbench（如 `bw.v`、`erode.v`、`dilate.v`、`bin2bcd.v`、`uart_tx.v`）；
- `run_sim.tcl`：用 Vivado XSim 自动编译并运行仿真；
- `results/`：仿真波形截图或日志（`.log`/`.txt`）。

## 可验证的纯逻辑模块

这些模块不依赖摄像头与板卡时序，适合优先补 testbench：

- `bin2bcd.v`：二进制转 BCD；
- `uart_tx.v`：UART 发送时序（38400 8N1）；
- `erode.v` / `dilate.v`：3×3 形态学窗口；
- `angle_calculation.v`：三点角度解算（可注入固定坐标）。
