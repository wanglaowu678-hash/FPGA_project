# build/ — 可复现构建

## 脚本

| 文件 | 说明 |
|---|---|
| `create_project.tcl` | 从 `../src/` 的 RTL、约束和 IP 配置重建 Vivado 工程 |

用法：

```bash
vivado -mode batch -source build/create_project.tcl
```

脚本会在 `../board/` 下重建 `v1020` 工程（顶层 `design_1`，器件 `xc7a35tcpg236-1`），
可替代直接打开 `.xpr` 的方式，便于在干净环境中复现工程结构。

## 报告

综合与实现报告（利用率、时序、DRC）不随仓库提供，构建后由 Vivado 生成：

- `board/v1020.runs/synth_1/*.rpt`
- `board/v1020.runs/impl_1/*.rpt`

如需归档，可将报告复制到本目录或 `../report/` 后再提交。
