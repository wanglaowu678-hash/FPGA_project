#!/usr/bin/env python3
"""Check a captured UART byte stream for range, stuck runs, and jumps.

Usage:
    python -I check_uart_stream.py capture.bin
    python -I check_uart_stream.py capture.bin --format bin --min 0 --max 180
    python -I check_uart_stream.py capture.txt --format hex --max 180 --stuck 200
    python -I check_uart_stream.py capture.txt --json

Input formats:
    bin   raw bytes
    hex   whitespace/comma separated hex bytes, e.g. "0A 1F 80" or "0x0A,0x1F"
    dec   whitespace/comma separated decimal bytes, e.g. "10 31 128"
    auto  detect from content (default)

Exit code:
    0  all checks passed
    1  empty input (unless --allow-empty), out-of-range value, stuck run
       over --stuck, or a jump over --jump
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

DEC_RE = re.compile(r"^\d{1,4}$")
HEX_RE = re.compile(r"^(?:0[xX])?[0-9a-fA-F]{1,2}$")


def split_tokens(text: str) -> list[str]:
    return [token for token in re.split(r"[\s,;]+", text.strip()) if token]


def load_values(path: str | Path, fmt: str) -> tuple[list[int], str]:
    """Return (byte values, detected/used format)."""
    raw = Path(path).read_bytes()
    if fmt == "bin" or not raw:
        return list(raw), "bin"

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        if fmt == "auto":
            return list(raw), "bin"
        raise ValueError("file is not valid UTF-8 text; use --format bin")

    tokens = split_tokens(text)
    if not tokens:
        return [], "empty"

    chosen = fmt
    if fmt == "auto":
        if all(DEC_RE.match(token) for token in tokens):
            chosen = "dec"
        elif all(HEX_RE.match(token) for token in tokens):
            chosen = "hex"
        else:
            return list(raw), "bin"

    base = 16 if chosen == "hex" else 10
    values: list[int] = []
    for index, token in enumerate(tokens):
        try:
            value = int(token, base)
        except ValueError:
            raise ValueError(f"token #{index} '{token}' is not valid {chosen}")
        if not 0 <= value <= 255:
            raise ValueError(
                f"token #{index} '{token}' = {value} is outside the byte range 0..255"
            )
        values.append(value)
    return values, chosen


def analyse(
    values: list[int],
    low: int,
    high: int,
    jump_limit: int,
) -> dict[str, object]:
    count = len(values)
    ordered = sorted(values)
    mean = sum(values) / count
    if count % 2:
        median = float(ordered[count // 2])
    else:
        median = (ordered[count // 2 - 1] + ordered[count // 2]) / 2.0
    variance = sum((value - mean) ** 2 for value in values) / count

    longest = 0
    longest_value = None
    run = 0
    previous = None
    for value in values:
        if value == previous:
            run += 1
        else:
            run = 1
            previous = value
        if run > longest:
            longest = run
            longest_value = value

    out_of_range = [
        (index, value) for index, value in enumerate(values) if not low <= value <= high
    ]
    jumps = []
    if jump_limit > 0:
        jumps = [
            index
            for index in range(1, count)
            if abs(values[index] - values[index - 1]) > jump_limit
        ]

    return {
        "count": count,
        "min": min(values),
        "max": max(values),
        "mean": mean,
        "median": median,
        "std": math.sqrt(variance),
        "unique": len(set(values)),
        "longest_run": longest,
        "longest_run_value": longest_value,
        "out_of_range_count": len(out_of_range),
        "out_of_range_first": out_of_range[:10],
        "jump_count": len(jumps),
        "jump_first": jumps[:10],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check a UART byte stream for range/stuck/jump problems."
    )
    parser.add_argument("file", help="capture file (.bin, .txt, .csv, ...)")
    parser.add_argument(
        "--format",
        choices=("auto", "bin", "hex", "dec"),
        default="auto",
        help="input format (default: auto)",
    )
    parser.add_argument("--min", dest="low", type=int, default=0, help="minimum valid value")
    parser.add_argument("--max", dest="high", type=int, default=255, help="maximum valid value")
    parser.add_argument(
        "--stuck",
        type=int,
        default=0,
        metavar="N",
        help="fail when the same value repeats > N times; 0 disables (default)",
    )
    parser.add_argument(
        "--jump",
        type=int,
        default=0,
        metavar="N",
        help="fail when adjacent values differ by > N; 0 disables (default)",
    )
    parser.add_argument("--json", action="store_true", help="print JSON instead of text")
    parser.add_argument(
        "--allow-empty", action="store_true", help="do not fail on an empty capture"
    )
    args = parser.parse_args(argv)

    if args.low > args.high:
        parser.error("--min must be <= --max")
    if args.stuck < 0 or args.jump < 0:
        parser.error("--stuck and --jump must be >= 0")

    try:
        values, used_format = load_values(args.file, args.format)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if not values:
        if args.allow_empty:
            print("EMPTY: no samples (allowed)")
            return 0
        print("ERROR: no samples found", file=sys.stderr)
        return 1

    stats = analyse(values, args.low, args.high, args.jump)

    failures: list[str] = []
    if stats["out_of_range_count"]:
        failures.append(
            f"{stats['out_of_range_count']} value(s) outside {args.low}..{args.high}"
        )
    if args.stuck > 0 and stats["longest_run"] > args.stuck:
        failures.append(
            f"stuck run {stats['longest_run']} > {args.stuck} "
            f"(value {stats['longest_run_value']})"
        )
    if args.jump > 0 and stats["jump_count"]:
        failures.append(
            f"{stats['jump_count']} jump(s) > {args.jump} between adjacent samples"
        )

    ok = not failures

    if args.json:
        payload = {
            "file": str(args.file),
            "format": used_format,
            "range": [args.low, args.high],
            "stats": stats,
            "ok": ok,
            "failures": failures,
        }
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"File      : {args.file}")
        print(f"Format    : {used_format}")
        print(f"Samples   : {stats['count']}")
        print(
            f"Min/Max   : {stats['min']} / {stats['max']} "
            f"(allowed {args.low}..{args.high})"
        )
        print(
            f"Mean/Med  : {stats['mean']:.2f} / {stats['median']:.1f} "
            f"(std {stats['std']:.2f})"
        )
        print(f"Unique    : {stats['unique']}")
        print(
            f"Longest   : {stats['longest_run']} sample(s), "
            f"value {stats['longest_run_value']}"
        )
        if stats["out_of_range_count"]:
            first = ", ".join(
                f"#{index}={value}" for index, value in stats["out_of_range_first"]
            )
            print(f"Out-range : {stats['out_of_range_count']} (first: {first})")
        else:
            print("Out-range : 0")
        if args.jump > 0:
            print(f"Jumps     : {stats['jump_count']} (threshold {args.jump})")
        print(f"Result    : {'PASS' if ok else 'FAIL'}")
        for reason in failures:
            print(f"  - {reason}")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
