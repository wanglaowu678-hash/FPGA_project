---
name: fpga-vision-pipeline
description: Design, debug, and optimize real-time FPGA/PYNQ vision pipelines (camera -> frame buffer -> color segmentation -> morphology -> centroid -> angle). Use when analyzing Verilog/VHDL/HLS vision designs, binary-mask artifacts, line buffers, centroid tracking, CORDIC, or Vivado timing/resource issues.
---

# FPGA Real-Time Vision Pipeline Skill

This skill packages a reusable workflow for streaming vision pipelines on FPGA/PYNQ:
**camera -> frame buffer -> color space conversion -> segmentation -> morphology ->
weighted centroid -> angle/output**.

## When to use

Use this skill when the user asks to:

- explain or review an FPGA vision pipeline (Verilog/VHDL/HLS/PYNQ);
- debug a noisy binary mask, unstable centroid, wrong angle, or border artifacts;
- optimize timing/resource usage from a Vivado report;
- port an RTL pixel pipeline to a PYNQ overlay;
- bring up a camera + VGA/HDMI + UART board.

Do **not** apply the line-buffer/morphology parts to frame-level CNN accelerators,
multi-camera sync, or MIPI/CSI designs without adapting the capture and boundary sections.
For non-vision topics (signal processing, motor control, communication, AI), only the
generic engineering layer transfers; use `prompts/adapt-to-new-topic.md` to classify and
map the components instead of transplanting the vision algorithms.

## Workflow

1. **Read `README.md` first** for scope, component index, failure conditions, and the
   verified-effect record. Do not claim effects beyond what it says.
2. **Explanation**: use `prompts/explain-pipeline.md` + `templates/pipeline-dataflow.md`.
   Build an ASCII data-flow diagram, a clock/reset table, and per-module responsibilities.
3. **Debugging**: use `prompts/debug-binary-mask.md` + `checklists/rtl-pitfalls.md`.
   Walk the decision tree from raw RGB -> HSV -> reference color -> thresholds ->
   morphology borders -> centroid gating -> output. Cite concrete file/line locations.
4. **Optimization**: use `prompts/optimize-timing-resources.md` +
   `templates/vivado-report-check.md` + `scripts/parse_vivado_report.py`.
   Classify the bottleneck before proposing fixes; produce a before/after table.
5. **PYNQ porting**: use `prompts/port-to-pynq.md`. Keep it at the overlay/block-design
   level unless the user provides board and tool details.
6. **Bring-up**: use `checklists/bringup-checklist.md` in order; do not skip camera I2C
   and frame-buffer readback before debugging color thresholds.
7. **Validate the tooling**: run `python -I tests/selftest.py`. It exercises all three
   scripts with pass/fail fixtures; it should print `9 passed, 0 failed`.
8. **New topic**: classify it with README §1.1, then use
   `prompts/adapt-to-new-topic.md` + `checklists/reuse-checklist.md`. State which
   components are reused, replaced, or newly written; do not claim the vision
   algorithms transfer to non-vision designs.

## Rules

- Ground every claim in the user's actual code or reports. Never invent signal names,
  clock frequencies, pixel formats, or threshold values.
- If information is missing, list what is missing and ask; do not guess.
- Keep beginner explanations beginner-friendly: define terms, use analogies, show a
  small numeric example. For expert requests, skip the analogies.
- State failure conditions explicitly when recommending a component.
- When a pitfall applies, give: trigger condition -> symptom -> root cause -> fix ->
  how to verify. This is the format used in `checklists/rtl-pitfalls.md`.
- Output language follows the user's language (Chinese in, Chinese out).

## Resources

- `README.md` — scope, component table, verified effects, limitations, lesson sources.
- `prompts/` — five prompt workflows (validation status: README §7).
- `templates/` — data-flow, module card, Vivado report check.
- `checklists/` — 16 RTL pitfalls + board bring-up order + reuse self-check.
- `scripts/` — Vivado report parser, UART stream checker, reproducibility checker.
- `tests/selftest.py` — 9 pass/fail cases for the three scripts.
- `prompts/adapt-to-new-topic.md` — classify a new topic and map reusable components.
- `checklists/reuse-checklist.md` — audit whether a stranger can use the package.
- `examples/v1020-case-study.md` — worked example on a Zynq-7020 OV7725 project.
