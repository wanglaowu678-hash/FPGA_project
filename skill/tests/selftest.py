#!/usr/bin/env python3
"""Self-test for the three verification scripts in this skill package.

Usage:
    python -I tests/selftest.py

It creates temporary fixtures, runs each script as a subprocess, and checks
both the exit code and a few key output strings. Exit code 0 means every
script behaved as documented.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

UTIL_REPORT = """\
| Site Type                     | Used | Fixed | Prohibited | Available | Util% |
| ----------------------------- | ---- | ----- | ---------- | --------- | ----- |
| Slice LUTs                    | 1234 |     0 |          0 |     53200 |  2.32 |
| Slice Registers               | 2345 |     0 |          0 |    106400 |  2.20 |
| Block RAM Tile                | 12.5 |     0 |          0 |       140 |  8.93 |
| DSPs                          |    5 |     0 |          0 |       220 |  2.27 |
| Bonded IOB                    |   33 |     0 |          0 |       125 | 26.40 |
| LUT as Memory                 |  100 |     0 |          0 |     17400 |  0.57 |
"""

TIMING_OK = """\
Design Timing Summary
---------------------
WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints      WHS(ns)  THS(ns)  THS Failing Endpoints  THS Total Endpoints
--------     -------  ---------------------  -------------------      -------  -------  ---------------------  -------------------
   0.123     0.000    0                      10000                    0.045    0.000    0                      10000

All user specified timing constraints are met.
"""

TIMING_BAD = """\
Design Timing Summary
---------------------
WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints      WHS(ns)  THS(ns)  THS Failing Endpoints  THS Total Endpoints
--------     -------  ---------------------  -------------------      -------  -------  ---------------------  -------------------
  -0.500     -12.345   42                     10000                    0.020    0.000    0                      10000

Timing constraints are not met.
"""

UART_OK = "00 0A 14 1E 5A 5A 5A 5A 5A B4 00 0A\n"
UART_BAD = "00 0A 14 1E 5A 5A 5A 5A 5A B4 C8 00\n"

GOOD_XDC = """\
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {sys_clk}]
set_property PACKAGE_PIN U15 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
"""

BAD_XDC = """\
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {sys_clk}]
set_property PACKAGE_PIN V12 [get_ports {led[1]}]
"""


def run(args: list[str], cwd: Path = ROOT) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-I", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def make_project(base: Path, bad: bool = False) -> None:
    for name in ("src", "sim", "build", "board", "data", "skill", "report"):
        (base / name).mkdir(parents=True, exist_ok=True)
    (base / "README.md").write_text("# demo\n", encoding="utf-8")
    source_name = "Top.v" if bad else "top.v"
    (base / "src" / source_name).write_text("module top; endmodule\n", encoding="utf-8")
    (base / "sim" / "tb_top.v").write_text("module tb_top; endmodule\n", encoding="utf-8")
    (base / "build" / "placeholder.txt").write_text("generated\n", encoding="utf-8")
    (base / "board" / "top.xdc").write_text(BAD_XDC if bad else GOOD_XDC, encoding="utf-8")
    (base / "data" / "README.md").write_text("# data\n", encoding="utf-8")
    (base / "skill" / "README.md").write_text("# skill\n", encoding="utf-8")
    (base / "report" / "report.md").write_text("# report\n", encoding="utf-8")


def main() -> int:
    passed = 0
    failed = 0

    with tempfile.TemporaryDirectory(prefix="skill_selftest_") as temp:
        temp_path = Path(temp)
        (temp_path / "util.rpt").write_text(UTIL_REPORT, encoding="utf-8")
        (temp_path / "timing_ok.rpt").write_text(TIMING_OK, encoding="utf-8")
        (temp_path / "timing_bad.rpt").write_text(TIMING_BAD, encoding="utf-8")
        (temp_path / "uart_ok.txt").write_text(UART_OK, encoding="utf-8")
        (temp_path / "uart_bad.txt").write_text(UART_BAD, encoding="utf-8")

        good = temp_path / "project_good"
        bad = temp_path / "project_bad"
        make_project(good)
        make_project(bad, bad=True)

        cases = [
            (
                "parse pass",
                run(
                    [
                        "scripts/parse_vivado_report.py",
                        "--util",
                        str(temp_path / "util.rpt"),
                        "--timing",
                        str(temp_path / "timing_ok.rpt"),
                    ]
                ),
                0,
                ["Timing constraints met: YES", "WNS"],
            ),
            (
                "parse fail",
                run(
                    [
                        "scripts/parse_vivado_report.py",
                        "--timing",
                        str(temp_path / "timing_bad.rpt"),
                    ]
                ),
                1,
                ["Timing constraints met: NO", "FAIL"],
            ),
            (
                "parse missing file",
                run(
                    [
                        "scripts/parse_vivado_report.py",
                        "--util",
                        str(temp_path / "nope.rpt"),
                    ]
                ),
                1,
                ["ERROR"],
            ),
            (
                "uart pass",
                run(
                    [
                        "scripts/check_uart_stream.py",
                        str(temp_path / "uart_ok.txt"),
                        "--format",
                        "hex",
                        "--max",
                        "180",
                    ]
                ),
                0,
                ["Result    : PASS"],
            ),
            (
                "uart range fail",
                run(
                    [
                        "scripts/check_uart_stream.py",
                        str(temp_path / "uart_bad.txt"),
                        "--format",
                        "hex",
                        "--max",
                        "180",
                    ]
                ),
                1,
                ["outside 0..180"],
            ),
            (
                "uart stuck fail",
                run(
                    [
                        "scripts/check_uart_stream.py",
                        str(temp_path / "uart_ok.txt"),
                        "--format",
                        "hex",
                        "--stuck",
                        "3",
                    ]
                ),
                1,
                ["stuck run"],
            ),
            (
                "repro pass",
                run(["scripts/repro_check.py", str(good)]),
                0,
                ["Result: PASS"],
            ),
            (
                "repro naming + xdc fail",
                run(["scripts/repro_check.py", str(bad)]),
                1,
                ["Top.v", "no IOSTANDARD"],
            ),
            (
                "repro skill root",
                run(["scripts/repro_check.py", "."]),
                0,
                ["Result: PASS"],
            ),
        ]

        for name, proc, expected_code, needles in cases:
            output = proc.stdout + proc.stderr
            ok = proc.returncode == expected_code
            missing = [needle for needle in needles if needle not in output]
            if missing:
                ok = False
            if ok:
                passed += 1
                print(f"[PASS] {name}")
            else:
                failed += 1
                print(f"[FAIL] {name}")
                print(f"       exit={proc.returncode}, expected={expected_code}")
                if missing:
                    print(f"       missing text: {missing}")
                for line in output.splitlines():
                    print(f"       | {line}")

    print(f"\n{passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
