#!/usr/bin/env python3
"""Parse Vivado utilization and timing-summary text reports.

Usage:
    python -I parse_vivado_report.py --util utilization.rpt
    python -I parse_vivado_report.py --timing timing_summary.rpt
    python -I parse_vivado_report.py --util u.rpt --timing t.rpt --json
    python -I parse_vivado_report.py --util u.rpt --timing t.rpt --out summary.md

Exit code:
    0  parsed successfully and WNS/WHS >= 0 (or no timing report given)
    1  parse failure, or WNS/WHS < 0

Only the Python standard library is used, so `python -I` works.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Resource name -> possible rows in a Vivado utilization report (lowercase).
# Order matters: the first matching row wins, so prefer the total rows.
RESOURCE_ALIASES = [
    ("LUT", ("clb luts", "slice luts")),
    ("FF", ("clb registers", "slice registers")),
    ("BRAM", ("block ram tile",)),
    ("DSP", ("dsps", "dsp48e1", "dsp48e2")),
    ("LUTRAM", ("lut as memory",)),
    ("IO", ("bonded iob", "bonded i/o")),
]

NUMBER_RE = re.compile(r"^-?(?:\d+(?:\.\d*)?|\.\d+)$")
INF_RE = re.compile(r"^-?inf$", re.IGNORECASE)


def read_text(path: str | Path) -> str:
    """Read a report as text, tolerating non-UTF-8 bytes from old tools."""
    return Path(path).read_text(encoding="utf-8", errors="replace")


def to_float(text: str) -> float | None:
    """Convert a table cell to float; return None for headers/separators."""
    try:
        return float(text.replace(",", "").strip())
    except (ValueError, AttributeError):
        return None


def parse_utilization(path: str | Path) -> dict[str, dict[str, float]]:
    """Parse `report_utilization` rows into {resource: {used, available, util_pct}}."""
    text = read_text(path)
    rows: dict[str, dict[str, float]] = {}

    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 6:
            continue

        name = cells[0].lower()
        used = to_float(cells[1])
        available = to_float(cells[4])
        if used is None or available is None or available <= 0:
            continue

        for key, aliases in RESOURCE_ALIASES:
            if key in rows:
                continue
            if any(name == alias or name.startswith(alias + " ") for alias in aliases):
                util_pct = to_float(cells[5])
                if util_pct is None:
                    util_pct = used / available * 100.0
                rows[key] = {
                    "used": used,
                    "available": available,
                    "util_pct": util_pct,
                }
                break

    if not rows:
        raise ValueError(
            "no utilization rows found; expected a report_utilization text file"
        )
    return rows


def slack_value(token: str) -> float | None:
    """Parse a timing value; Vivado may print inf/-inf when no paths exist."""
    if INF_RE.match(token):
        return float("-inf") if token.startswith("-") else float("inf")
    if NUMBER_RE.match(token):
        return float(token)
    return None


def parse_timing(path: str | Path) -> dict[str, object]:
    """Parse the Design Timing Summary table (WNS/TNS/WHS/THS)."""
    lines = read_text(path).splitlines()

    header_idx = None
    for index, line in enumerate(lines):
        if "WNS" in line and "WHS" in line and "TNS" in line:
            header_idx = index
            break
    if header_idx is None:
        raise ValueError(
            "timing header with WNS/TNS/WHS/THS not found; "
            "expected a report_timing_summary text file"
        )

    header = lines[header_idx]
    # Columns before WHS: WNS, TNS, plus one column per "Endpoints" header
    # ("TNS Failing Endpoints", "TNS Total Endpoints").
    whs_col = 2 + len(re.findall(r"Endpoints", header[: header.find("WHS")]))

    data: list[str] | None = None
    for line in lines[header_idx + 1 : header_idx + 15]:
        tokens = line.split()
        if len(tokens) < whs_col + 2:
            continue
        if slack_value(tokens[0]) is None:
            continue
        data = tokens
        break

    if data is None:
        raise ValueError("timing numeric row not found below the header")

    wns = slack_value(data[0])
    tns = slack_value(data[1])
    whs = slack_value(data[whs_col])
    ths = slack_value(data[whs_col + 1])
    if None in (wns, tns, whs, ths):
        raise ValueError(f"could not parse timing values from row: {' '.join(data)}")

    text_lower = "\n".join(lines).lower()
    met = "not met" not in text_lower

    return {"wns": wns, "tns": tns, "whs": whs, "ths": ths, "met": met}


def display(value: float) -> str:
    if value == float("inf"):
        return "inf"
    if value == float("-inf"):
        return "-inf"
    return f"{value:.3f}"


def render_markdown(
    utilization: dict[str, dict[str, float]] | None,
    timing: dict[str, object] | None,
) -> str:
    out: list[str] = ["# Vivado Report Summary", ""]

    if utilization:
        out += [
            "## Utilization",
            "",
            "| Resource | Used | Available | Util% |",
            "|---|---:|---:|---:|",
        ]
        for key, _ in RESOURCE_ALIASES:
            if key not in utilization:
                continue
            row = utilization[key]
            out.append(
                f"| {key} | {row['used']:g} | {row['available']:g} "
                f"| {row['util_pct']:.2f} |"
            )
        out.append("")

    if timing:
        out += [
            "## Timing",
            "",
            "| Metric | Value (ns) | Criterion | Result |",
            "|---|---:|---|---|",
        ]
        checks = [
            ("WNS", "wns", ">= 0", timing["wns"] >= 0),
            ("WHS", "whs", ">= 0", timing["whs"] >= 0),
            ("TNS", "tns", "<= 0", timing["tns"] <= 0),
            ("THS", "ths", "<= 0", timing["ths"] <= 0),
        ]
        for label, key, criterion, passed in checks:
            out.append(
                f"| {label} | {display(timing[key])} | {criterion} "
                f"| {'PASS' if passed else 'FAIL'} |"
            )
        out.append("")
        out.append(f"Timing constraints met: {'YES' if timing['met'] else 'NO'}")

    return "\n".join(out) + "\n"


def json_safe(value):
    """Replace inf with a JSON-legal string so the output is portable."""
    if isinstance(value, dict):
        return {key: json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [json_safe(item) for item in value]
    if isinstance(value, float) and value in (float("inf"), float("-inf")):
        return str(value)
    return value


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Parse Vivado utilization/timing reports and check WNS/WHS."
    )
    parser.add_argument("--util", help="report_utilization text report")
    parser.add_argument("--timing", help="report_timing_summary text report")
    parser.add_argument("--json", action="store_true", help="print JSON instead of Markdown")
    parser.add_argument("--out", help="also write the rendered report to this file")
    args = parser.parse_args(argv)

    if not args.util and not args.timing:
        parser.error("provide at least one of --util / --timing")

    utilization = None
    timing = None
    try:
        if args.util:
            utilization = parse_utilization(args.util)
        if args.timing:
            timing = parse_timing(args.timing)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    ok = True
    if timing:
        ok = timing["wns"] >= 0 and timing["whs"] >= 0

    if args.json:
        payload = {
            "ok": ok,
            "utilization": utilization,
            "timing": timing,
        }
        text = json.dumps(json_safe(payload), indent=2, ensure_ascii=False) + "\n"
    else:
        text = render_markdown(utilization, timing)

    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    sys.stdout.write(text)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
