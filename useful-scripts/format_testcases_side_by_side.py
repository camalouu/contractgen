#!/usr/bin/env python3
"""
Render testcase program pairs side-by-side in a readable text/markdown view.

Usage:
    python format_testcases_side_by_side.py <testcases.json> <output.md>
    python format_testcases_side_by_side.py <testcases.json> <output.md> --index 65
    python format_testcases_side_by_side.py <testcases.json> <output.txt> --index 10,11,65-70
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


LOADS = {"LB", "LH", "LW", "LBU", "LHU"}
STORES = {"SB", "SH", "SW"}
BRANCHES = {"BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU"}
UTYPES = {"LUI", "AUIPC"}


def x(reg: Any) -> str:
    return f"x{reg}" if reg is not None else "?"


def normalize_imm(imm: Any) -> str:
    if imm is None:
        return "?"
    return str(int(imm))


def fmt_instr(instr: dict[str, Any]) -> str:
    typ = str(instr.get("type", "UNKNOWN")).upper()
    m = typ.lower()
    rd = instr.get("rd")
    rs1 = instr.get("rs1")
    rs2 = instr.get("rs2")
    imm = normalize_imm(instr.get("imm"))

    if typ in UTYPES:
        return f"{m} {x(rd)}, <<{imm}>>"
    if typ in LOADS:
        return f"{m} {x(rd)}, {imm}({x(rs1)})"
    if typ in STORES:
        return f"{m} {x(rs2)}, {imm}({x(rs1)})"
    if typ in BRANCHES:
        return f"{m} {x(rs1)}, {x(rs2)}, {imm}"
    if typ == "JAL":
        return f"{m} {x(rd)}, {imm}"
    if typ == "JALR":
        return f"{m} {x(rd)}, {x(rs1)}, {imm}"

    if rs2 is not None:
        return f"{m} {x(rd)}, {x(rs1)}, {x(rs2)}"
    if rs1 is not None:
        return f"{m} {x(rd)}, {x(rs1)}, {imm}"
    if rd is not None:
        return f"{m} {x(rd)}, {imm}"
    return m


def targeted_atoms(obs: Any) -> str:
    if not isinstance(obs, list) or not obs:
        return "(none)"
    parts: list[str] = []
    for item in obs:
        if not isinstance(item, dict):
            continue
        t = item.get("type")
        o = item.get("observation")
        if t is None and o is None:
            continue
        parts.append(f"{t}:{o}")
    return ", ".join(parts) if parts else "(none)"


def parse_index_filter(raw: str | None) -> set[int] | None:
    if not raw:
        return None
    out: set[int] = set()
    for part in raw.split(","):
        token = part.strip()
        if not token:
            continue
        if "-" in token:
            left, right = token.split("-", 1)
            a = int(left)
            b = int(right)
            if a <= b:
                out.update(range(a, b + 1))
            else:
                out.update(range(b, a + 1))
        else:
            out.add(int(token))
    return out


def fmt_init_lines(registers: Any) -> list[str]:
    reg_values: dict[int, int] = {}
    if isinstance(registers, dict):
        for reg, val in registers.items():
            try:
                r = int(reg)
                v = int(val)
            except (TypeError, ValueError):
                continue
            reg_values[r] = v

    lines: list[str] = []
    # Matches RISCVProgram.printInit(): 31 executed setup instructions for x1..x31.
    for r in range(1, 32):
        if r in reg_values:
            lines.append(f"addi x{r}, x0, {reg_values[r]}")
        else:
            lines.append("addi x0, x0, 0")
    return lines


def build_pair_table(
    registers1: Any,
    registers2: Any,
    program1: list[dict[str, Any]],
    program2: list[dict[str, Any]],
) -> str:
    left_prog = [fmt_instr(i) for i in program1]
    right_prog = [fmt_instr(i) for i in program2]
    left_lines = left_prog
    right_lines = right_prog
    max_rows = max(len(left_lines), len(right_lines))

    left_width = max([len("P1")] + [len(s) for s in left_lines]) if max_rows else len("P1")
    right_width = max([len("P2")] + [len(s) for s in right_lines]) if max_rows else len("P2")

    header = f"{'P1'.ljust(left_width)} | {'P2'.ljust(right_width)}"
    sep = f"{'-' * left_width}-+-{'-' * right_width}"
    rows = [header, sep]

    for i in range(max_rows):
        p1 = left_lines[i] if i < len(left_lines) else ""
        p2 = right_lines[i] if i < len(right_lines) else ""
        rows.append(f"{i:02d} {p1.ljust(left_width - 3)} | {p2.ljust(right_width)}")
    return "\n".join(rows)


def load_testcases(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("Input testcase file must be a JSON array.")
    out = [item for item in data if isinstance(item, dict)]
    out.sort(key=lambda x: int(x.get("index", 0)))
    return out


def render_markdown(cases: list[dict[str, Any]]) -> str:
    lines: list[str] = []
    lines.append("# Side-by-side testcase view")
    lines.append("")
    for tc in cases:
        idx = tc.get("index", "?")
        atoms = targeted_atoms(tc.get("observations"))
        r1 = tc.get("registers1")
        r2 = tc.get("registers2")
        p1 = tc.get("program1") if isinstance(tc.get("program1"), list) else []
        p2 = tc.get("program2") if isinstance(tc.get("program2"), list) else []

        lines.append(f"## Testcase {idx}")
        lines.append(f"- **Targeted atom(s):** {atoms}")
        lines.append("")
        lines.append("```text")
        lines.append(build_pair_table(r1, r2, p1, p2))
        lines.append("```")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_text(cases: list[dict[str, Any]]) -> str:
    chunks: list[str] = []
    for tc in cases:
        idx = tc.get("index", "?")
        atoms = targeted_atoms(tc.get("observations"))
        r1 = tc.get("registers1")
        r2 = tc.get("registers2")
        p1 = tc.get("program1") if isinstance(tc.get("program1"), list) else []
        p2 = tc.get("program2") if isinstance(tc.get("program2"), list) else []
        chunks.append(
            f"Testcase {idx}\n"
            f"Targeted atom(s): {atoms}\n"
            f"{build_pair_table(r1, r2, p1, p2)}"
        )
    return "\n\n".join(chunks).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Format testcase programs side by side.")
    parser.add_argument("input", type=Path, help="Path to testcase JSON (array format).")
    parser.add_argument("output", type=Path, help="Output path (.md or .txt recommended).")
    parser.add_argument(
        "--index",
        type=str,
        default=None,
        help="Only include selected indices (e.g., 65 or 1,2,10-20).",
    )
    args = parser.parse_args()

    if not args.input.exists():
        print(f"File not found: {args.input}")
        return 1

    try:
        cases = load_testcases(args.input)
        selected = parse_index_filter(args.index)
        if selected is not None:
            cases = [tc for tc in cases if int(tc.get("index", -1)) in selected]
    except Exception as exc:
        print(f"Error: {exc}")
        return 1

    if args.output.suffix.lower() == ".txt":
        content = render_text(cases)
    else:
        content = render_markdown(cases)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(content, encoding="utf-8")
    print(f"Wrote {len(cases)} testcase(s) to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
