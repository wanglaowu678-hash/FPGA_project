# 模板：Vivado 综合/实现报告检查表

> 每次综合/实现后复制一份，填完再决定“能不能上板”。

## 1. 工程信息

| 项目 | 内容 |
|---|---|
| 器件 | {part} |
| Vivado 版本 | {version} |
| 目标时钟 | {fmax} MHz |
| 综合/实现日期 | {date} |
| 顶层 | {top} |

## 2. 时序

| 指标 | 值 | 门槛 | 通过 | 备注 |
|---|---|---|---|---|
| WNS (setup) | {ns} | ≥ 0 | 是/否 | 最差负 slack |
| WHS (hold) | {ns} | ≥ 0 | 是/否 | |
| TNS | {ns} | ≤ 0 | 是/否 | 总负 slack |
| THS | {ns} | ≤ 0 | 是/否 | |
| 失败端点 | {n} | 0 | 是/否 | |
| 时钟交互 | {list} | 已约束 | 是/否 | CDC 是否被 false_path/async |

## 3. 资源

| 资源 | 已用 | 可用 | 利用率 | 预算 | 备注 |
|---|---|---|---|---|---|
| LUT | {n} | {n} | {%} | {budget} | |
| FF | {n} | {n} | {%} | {budget} | |
| BRAM | {n} | {n} | {%} | {budget} | |
| DSP | {n} | {n} | {%} | {budget} | |
| LUTRAM | {n} | {n} | {%} | {budget} | 行缓存常在此 |
| IO | {n} | {n} | {%} | {budget} | |

## 4. 关键路径

| 路径 | 起点 | 终点 | 逻辑级数 | net delay | logic delay | 模块 |
|---|---|---|---|---|---|---|
| {path1} | {start} | {end} | {n} | {ns} | {ns} | {module} |
| {path2} | ... | ... | ... | ... | ... | ... |

## 5. 时钟域 / CDC

| 源时钟 | 目的时钟 | 路径数 | 约束 | 同步器 | 风险 |
|---|---|---|---|---|---|
| {clkA} | {clkB} | {n} | {set_clock_groups/...} | {2FF/FIFO/无} | 高/中/低 |

## 6. 功耗 / 上板

| 项目 | 值 | 备注 |
|---|---|---|
| 总功耗估算 | {W} | |
| 结温估算 | {C} | |
| bitstream 生成 | 是/否 | |
| 上板实测 | {pass/fail} | |

## 7. 结论

- [ ] 时序满足（WNS/WHS ≥ 0）
- [ ] 资源在预算内
- [ ] CDC 已约束/同步
- [ ] 关键路径已记录
- [ ] 可以上板 / 需要优化：{list}

## 8. 复现命令

```bash
# 综合
vivado -mode batch -source build/synth.tcl

# 实现
vivado -mode batch -source build/impl.tcl

# 解析报告
python -I skill/scripts/parse_vivado_report.py \
  --util build/util.rpt --timing build/timing.rpt
```
