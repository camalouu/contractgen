#!/usr/bin/env python3
"""Avoid the pinned Verilator runtime's partial-wide-constant buffer overrun.

VL_CONSTHI_W_nX adjusts its output pointer by lsb/32, but VL_C_END_ then
clears a missing high word using an absolute index relative to that pointer.
Emit that zero explicitly instead: the helper's clearing loop becomes empty.
This changes only generated C++ initialization, not the RTL constant's value.
"""
import pathlib
import re
import sys

INITIALIZER = re.compile(
    r"VL_CONSTHI_W_([1-8])X\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,([^;]+?)\);"
)


def repair(match):
    count, bits, lsb = map(int, match.group(1, 2, 3))
    if lsb % 32:
        raise ValueError("Expected a word-aligned wide constant")
    missing = (bits + 31) // 32 - lsb // 32 - count
    if missing <= 0 or lsb == 0:
        return match.group(0)
    if count + missing > 8:
        raise ValueError("Unexpected high constant chunk wider than eight words")
    values = [value.strip() for value in match.group(5).split(",")]
    if len(values) != count:
        raise ValueError("Unexpected wide constant initializer")
    values = ["0x00000000"] * missing + values
    return (f"VL_CONSTHI_W_{len(values)}X({bits},{lsb},{match.group(4)},"
            + ",".join(values) + ");")


def main():
    changed = 0
    for path in pathlib.Path(sys.argv[1]).glob("*.cpp"):
        source = path.read_text()
        fixed = INITIALIZER.sub(repair, source)
        if fixed != source:
            changed += sum(repair(m) != m.group(0) for m in INITIALIZER.finditer(source))
            path.write_text(fixed)
    print(f"CVA6: made {changed} partial wide constant zero-fill(s) explicit")


if __name__ == "__main__":
    main()
