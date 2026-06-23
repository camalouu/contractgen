#!/usr/bin/env python3
"""
Merge testcase and result JSON files by index, keeping only attacker-distinguishable entries.

Usage:
    python extract_distinguishable_program_pairs.py <testcases.json> <results.json> <output.json>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_testcases(path: Path) -> dict[int, list[dict[str, Any]]]:
    data = load_json(path)
    if not isinstance(data, list):
        raise ValueError("Testcase file must be a JSON array.")

    by_index: dict[int, list[dict[str, Any]]] = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        index = item.get("index")
        if not isinstance(index, int):
            continue
        if index not in by_index:
            by_index[index] = []
        by_index[index].append(item)
    return by_index


def load_results(path: Path) -> list[dict[str, Any]]:
    data = load_json(path)
    if isinstance(data, dict):
        results = data.get("testResults")
        if not isinstance(results, list):
            raise ValueError("Result file object must contain a 'testResults' array.")
    elif isinstance(data, list):
        results = data
    else:
        raise ValueError("Result file must be a JSON array or object with 'testResults'.")

    out: list[dict[str, Any]] = []
    for item in results:
        if isinstance(item, dict):
            out.append(item)
    return out


def build_merged(
    testcases_by_index: dict[int, list[dict[str, Any]]],
    results: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[int]]:
    merged: list[dict[str, Any]] = []
    missing: list[int] = []

    for res in results:
        index = res.get("index")
        if not isinstance(index, int):
            continue

        tc_list = testcases_by_index.get(index)
        if not tc_list:
            if bool(res.get("adversaryDistinguishable")):
                missing.append(index)
            continue
            
        tc = tc_list.pop(0)

        if not bool(res.get("adversaryDistinguishable")):
            continue

        merged.append(
            {
                "index": index,
                "adversaryDistinguishable": True,
                "observations": res.get("observations", []),
                "targetedObservation": tc.get("observations", []),
                "distinguishingInstructions": res.get("distinguishingInstructions", []),
                "registers1": tc.get("registers1", {}),
                "program1": tc.get("program1", []),
                "registers2": tc.get("registers2", {}),
                "program2": tc.get("program2", []),
                "maxInstructionCount": tc.get("maxInstructionCount"),
            }
        )

    # We don't sort here because if there are duplicate indices we might want to keep the relative insertion order
    # merged.sort(key=lambda x: x["index"])
    missing.sort()
    return merged, missing


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: python extract_distinguishable_program_pairs.py "
            "<testcases.json> <results.json> <output.json>"
        )
        return 1

    testcases_path = Path(sys.argv[1])
    results_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3])

    if not testcases_path.exists():
        print(f"File not found: {testcases_path}")
        return 1
    if not results_path.exists():
        print(f"File not found: {results_path}")
        return 1

    try:
        testcases_by_index = load_testcases(testcases_path)
        results = load_results(results_path)
        merged, missing = build_merged(testcases_by_index, results)
    except Exception as exc:
        print(f"Error: {exc}")
        return 1

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")

    print(f"Wrote {len(merged)} attacker-distinguishable entries to {output_path}")
    if missing:
        print(f"Missing testcases for {len(missing)} indices: {missing[:20]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
