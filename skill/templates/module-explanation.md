# 模板：单模块讲解卡

> 一个模块填一张。讲解、评审、交接都用同一张卡，避免“只讲代码不讲边界”。

## 1. 基本信息

| 项目 | 内容 |
|---|---|
| 模块名 | {module} |
| 文件 | {file:line} |
| 时钟 | {clock} |
| 复位 | {reset} |
| 例化次数 | {n} |
| 一句话职责 | {一句话，不超过 20 字} |

## 2. 端口

| 端口 | 方向 | 位宽 | 时钟域 | 含义 | 备注 |
|---|---|---|---|---|---|
| {port} | in/out | {w} | {clk} | {meaning} | {note} |

## 3. 时序 / 握手

- 输入有效条件：{valid/ready/href/vsync/...}
- 输出有效条件：{...}
- 延迟：{n cycles / n lines / n frames}
- 背压：{有/无}
- 复位行为：{同步/异步，复位后输出}

## 4. 算法步骤

1. {step 1}
2. {step 2}
3. {step 3}

> 用“输入 → 中间量 → 输出”的顺序写，不要逐行翻译代码。

## 5. 关键参数

| 参数 | 值 | 含义 | 可调范围 | 影响 |
|---|---|---|---|---|
| {param} | {value} | {meaning} | {range} | {effect} |

## 6. 边界条件

| 条件 | 行为 | 是否正确 | 备注 |
|---|---|---|---|
| 上电/复位 | {behavior} | 是/否 | {note} |
| 行/场消隐 | {behavior} | 是/否 | {note} |
| 坐标越界 | {behavior} | 是/否 | {note} |
| 输入全 0/全 1 | {behavior} | 是/否 | {note} |

## 7. 常见坑

| 坑 | 触发条件 | 现象 | 修复 |
|---|---|---|---|
| {pitfall} | {trigger} | {symptom} | {fix} |

## 8. 如何验证

- 仿真：{testbench / 激励 / 期望}
- ILA：{probe signals}
- 上板：{observable output}
- 通过标准：{pass criteria}
