#!/usr/bin/env python3
"""Check a project tree for reproducibility: structure, naming, and XDC pins.

Usage:
    python -I repro_check.py /path/to/project
    python -I repro_check.py . --strict
    python -I repro_check.py . --include-build --json

What it checks:
    1. Recommended structure: README.md, src/, sim/, build/, board/, data/,
       skill/, report/ (missing entries are warnings unless --strict).
    2. File/directory names: lowercase letters, digits, dot, underscore, hyphen.
       Conventional names such as README.md and SKILL.md are allowed.
    3. XDC constraints: every PACKAGE_PIN has an IOSTANDARD and vice versa,
       matched by port name inside [get_ports ...].

Exit code:
    0  no errors (warnings allowed)
    1  missing required README/skill README, bad name, or unpaired XDC pin
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

REQUIRED = ["README.md", "src", "sim", "build", "board", "data", "skill", "report"]
NAME_RE = re.compile(r"^[a-z0-9._-]+$")
ALLOW_UPPER = {"README.md", "SKILL.md", "LICENSE", "LICENSE.md"}

# [get_ports {led[0]}] or [get_ports clk]
_PORT = r"\[get_ports\s+(?:\{([^}]*)\}|([^\]\s]+))\s*\]"
DICT_RE = re.compile(r"set_property\s+-dict\s*\{([^}]*)\}\s*" + _PORT, re.S)
PIN_RE = re.compile(r"set_property\s+PACKAGE_PIN\s+([^\s\]]+)\s+" + _PORT, re.S)
IO_RE = re.compile(r"set_property\s+IOSTANDARD\s+([^\s\]]+)\s+" + _PORT, re.S)


def port_of(match: re.Match, first_group: int) -> str:
    """Port name is either the braced group or the bare group."""
    return (match.group(first_group) or match.group(first_group + 1)).strip()


def iter_entries(root: Path, include_build: bool):
    """Yield project-relative paths, skipping hidden entries and build/."""
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = Path(dirpath).relative_to(root)
        dirnames[:] = sorted(name for name in dirnames if not name.startswith("."))

        if not include_build:
            if rel_dir.parts and rel_dir.parts[0] == "build":
                dirnames[:] = []
                continue
            if not rel_dir.parts and "build" in dirnames:
                dirnames.remove("build")

        for name in dirnames:
            yield rel_dir / name
        for name in sorted(filenames):
            if not name.startswith("."):
                yield rel_dir / name


def check_structure(root: Path, strict: bool) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    # Allow running the checker on the skill package itself: when the root is
    # already the skill/ directory, do not require a nested skill/ directory.
    required = list(REQUIRED)
    if root.name == "skill" and (root / "README.md").is_file():
        required.remove("skill")

    for entry in required:
        path = root / entry
        if entry.endswith(".md"):
            if path.is_file():
                continue
            errors.append(f"missing root {entry}")
            continue

        if path.is_dir():
            continue
        message = f"missing recommended directory {entry}/"
        if entry == "skill" or strict:
            errors.append(message)
        else:
            warnings.append(message)

    skill_readme = root / "skill" / "README.md"
    if (root / "skill").is_dir() and not skill_readme.is_file():
        errors.append("missing skill/README.md (skill package description)")

    return errors, warnings


def check_names(root: Path, include_build: bool) -> list[str]:
    errors: list[str] = []
    for rel in iter_entries(root, include_build):
        name = rel.name
        if name in ALLOW_UPPER:
            continue
        if not NAME_RE.match(name):
            errors.append(
                f"{rel.as_posix()}: '{name}' contains uppercase/Chinese/space/"
                f"special character"
            )
    return errors


def find_xdc(root: Path, include_build: bool) -> list[Path]:
    files: list[Path] = []
    for rel in iter_entries(root, include_build):
        if rel.suffix.lower() == ".xdc":
            files.append(root / rel)
    return files


def parse_xdc(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    raw = path.read_text(encoding="utf-8", errors="replace")
    # Drop Tcl comments so example lines in comments do not become false positives.
    text = "\n".join(line.split("#", 1)[0] for line in raw.splitlines())

    pins: dict[str, str] = {}
    ios: dict[str, str] = {}

    for match in DICT_RE.finditer(text):
        body = match.group(1)
        port = port_of(match, 2)
        pin_match = re.search(r"PACKAGE_PIN\s+([^\s\}]+)", body)
        io_match = re.search(r"IOSTANDARD\s+([^\s\}]+)", body)
        if pin_match:
            pins[port] = pin_match.group(1)
        if io_match:
            ios[port] = io_match.group(1)

    for match in PIN_RE.finditer(text):
        pins[port_of(match, 2)] = match.group(1)

    for match in IO_RE.finditer(text):
        ios[port_of(match, 2)] = match.group(1)

    return pins, ios


def check_xdc(
    root: Path, include_build: bool
) -> tuple[list[str], list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    passed: list[str] = []

    xdc_files = find_xdc(root, include_build)
    if not xdc_files:
        warnings.append("no .xdc file found (ignore if using board files)")
        return errors, warnings, passed

    for path in xdc_files:
        rel = path.relative_to(root).as_posix()
        try:
            pins, ios = parse_xdc(path)
        except OSError as exc:
            errors.append(f"{rel}: read failed: {exc}")
            continue

        if not pins and not ios:
            warnings.append(f"{rel}: no PACKAGE_PIN/IOSTANDARD found")
            continue

        bad = 0
        for port in sorted(set(pins) | set(ios)):
            if port in pins and port not in ios:
                errors.append(
                    f"{rel}: port {port} has PACKAGE_PIN={pins[port]} "
                    f"but no IOSTANDARD"
                )
                bad += 1
            elif port not in pins and port in ios:
                errors.append(
                    f"{rel}: port {port} has IOSTANDARD={ios[port]} "
                    f"but no PACKAGE_PIN"
                )
                bad += 1
        if bad == 0:
            passed.append(
                f"{rel}: {len(set(pins) | set(ios))} ports, all pins paired with IO standards"
            )

    return errors, warnings, passed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check project structure, file naming, and XDC pin/IO pairing."
    )
    parser.add_argument("root", nargs="?", default=".", help="project root (default: .)")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="treat missing recommended directories as errors",
    )
    parser.add_argument(
        "--include-build",
        action="store_true",
        help="also scan build/ (generated files often violate naming rules)",
    )
    parser.add_argument("--json", action="store_true", help="print JSON instead of text")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"ERROR: {root} is not a directory", file=sys.stderr)
        return 1

    struct_errors, struct_warnings = check_structure(root, args.strict)
    name_errors = check_names(root, args.include_build)
    xdc_errors, xdc_warnings, xdc_passed = check_xdc(root, args.include_build)

    errors = struct_errors + name_errors + xdc_errors
    warnings = struct_warnings + xdc_warnings
    ok = not errors

    if args.json:
        payload = {
            "root": str(root),
            "ok": ok,
            "errors": errors,
            "warnings": warnings,
            "xdc_passed": xdc_passed,
        }
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print("== Structure ==")
        if struct_errors or struct_warnings:
            for message in struct_errors:
                print(f"[ERROR] {message}")
            for message in struct_warnings:
                print(f"[WARN ] {message}")
        else:
            print("[PASS ] recommended structure complete")

        print("\n== Naming ==")
        if name_errors:
            for message in name_errors:
                print(f"[ERROR] {message}")
        else:
            print("[PASS ] no uppercase/Chinese/space/special characters")

        print("\n== XDC constraints ==")
        for message in xdc_passed:
            print(f"[PASS ] {message}")
        for message in xdc_warnings:
            print(f"[WARN ] {message}")
        for message in xdc_errors:
            print(f"[ERROR] {message}")

        print("\n== Summary ==")
        print(f"errors={len(errors)} warnings={len(warnings)}")
        print(f"Result: {'PASS' if ok else 'FAIL'}")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
