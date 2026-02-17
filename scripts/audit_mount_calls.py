#!/usr/bin/env python3
"""
Audit MountManager callsites for explicit operationID forwarding.

Checks every Swift call to:
  - mountManager.connect(...)
  - mountManager.disconnect(...)
  - mountManager.refreshStatus(...)
  - mountManager.forceStopProcesses(...)
  - mountManager.testConnection(...)

and verifies the call argument list contains `operationID:`.

Usage (run from repo root):
  scripts/audit_mount_calls.py
  scripts/audit_mount_calls.py --root macfuseGui
  scripts/audit_mount_calls.py --root macfuseGuiTests
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


CALL_PATTERN = re.compile(
    r"mountManager\.(connect|disconnect|refreshStatus|forceStopProcesses|testConnection)\s*\(",
    re.MULTILINE,
)


@dataclass
class Callsite:
    file: Path
    method: str
    line: int
    call_text: str
    has_operation_id: bool


def parse_call(text: str, start_idx: int) -> tuple[str, int]:
    """
    Return (call_text, end_idx) for a function call starting at the opening '('.
    This parser is intentionally lightweight; it assumes balanced call parentheses.
    """
    depth = 0
    i = start_idx
    while i < len(text):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[start_idx : i + 1], i + 1
        i += 1
    return text[start_idx:], len(text)


def collect_calls(file_path: Path) -> list[Callsite]:
    text = file_path.read_text(encoding="utf-8")
    calls: list[Callsite] = []
    for match in CALL_PATTERN.finditer(text):
        method = match.group(1)
        open_paren_index = text.find("(", match.start())
        call_text, _ = parse_call(text, open_paren_index)
        line = text.count("\n", 0, match.start()) + 1
        calls.append(
            Callsite(
                file=file_path,
                method=method,
                line=line,
                call_text=call_text,
                has_operation_id=("operationID:" in call_text),
            )
        )
    return calls


def iter_swift_files(root: Path) -> list[Path]:
    return sorted(root.rglob("*.swift"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("macfuseGui"),
        help="Root directory to scan for Swift files (default: macfuseGui).",
    )
    args = parser.parse_args()

    root: Path = args.root
    if not root.exists():
        print(f"error: root path does not exist: {root}", file=sys.stderr)
        return 2

    all_calls: list[Callsite] = []
    for swift_file in iter_swift_files(root):
        all_calls.extend(collect_calls(swift_file))

    if not all_calls:
        print("No mountManager callsites found.")
        return 0

    missing = [call for call in all_calls if not call.has_operation_id]

    for call in all_calls:
        status = "OK" if call.has_operation_id else "MISSING operationID"
        first_line = call.call_text.splitlines()[0].strip()
        print(f"{status}: {call.file}:{call.line} {call.method} {first_line}")

    if missing:
        print(
            f"\nFAIL: {len(missing)} callsite(s) missing explicit operationID forwarding.",
            file=sys.stderr,
        )
        return 1

    print(f"\nPASS: {len(all_calls)} callsite(s) include explicit operationID.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
