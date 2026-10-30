# board/ — 上板工程与运行文件

本目录保存可直接用 Vivado 打开的工程与固化文件，设计源码在 [`../src/`](../src/)。

## 文件说明

| 文件 | 说明 |
|---|---|
| `v1020.xpr` | Vivado 2026.1 工程，顶层 `design_1`，目标器件 `xc7a35tcpg236-1` |
| `mcs.mcs` | 用于外部 Flash 固化的 MCS 镜像 |
| `mcs.prm` | MCS 生成时的参数文件 |

工程中的 RTL、约束与 IP 均以相对路径引用 `../src/`，因此移动整个仓库后仍可打开。

## 打开与编译

1. Vivado 打开 `v1020.xpr`；
2. 首次打开时 Vivado 会依据 `../src/ip/*/*.xci` 重新生成 `clk_wiz_0`、`blk_mem_gen_0` 的输出产物；
3. Run Synthesis → Run Implementation → Generate Bitstream；
4. 通过 Hardware Manager 下载，或用 `mcs.mcs` 固化到板载 Flash。

## 运行/实测输出

- 摄像头对准目标颜色，按 BTNL/BTNC/BTNR 采样三路阈值；
- VGA 输出实时画面与质心标注；
- UART 38400 8N1 输出坐标或角度，由 SW2 切换；
- 数码管显示当前数值，LED 指示运行状态。

## 说明

`.runs/`、`.gen/`、`.cache/`、`.ip_user_files/`、`.hw/` 等编译产物不入库，由 Vivado 在本机生成。
工程文件不保存综合与实现报告，需要时可在本机重新生成后归档到 `../build/` 或 `../report/`。
