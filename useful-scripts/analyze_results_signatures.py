#!/usr/bin/env python3
"""
Compact streaming signature analysis for ContractGen result JSON files.

The parser is intentionally line-oriented so large result files can be scanned
without loading the full JSON document into memory.

Usage:
    python useful-scripts/analyze_results_signatures.py <result.json>
"""

from __future__ import annotations

import argparse
import time
from pathlib import Path
from typing import Dict, FrozenSet, Iterator, List, Sequence, Set, Tuple

Atom = Tuple[str, str]
Signature = Tuple[Atom, ...]
SignatureSet = FrozenSet[Atom]


def as_pct(n: int, d: int) -> str:
    return "0.0%" if d == 0 else f"{100.0 * n / d:.1f}%"


def signature_text(sig: Signature) -> str:
    return ", ".join(f"{t}:{o}" for t, o in sig) if sig else "<empty>"


class SubsetIndex:
    """Tracks minimal attacker-distinguishable signatures seen so far."""

    def __init__(self) -> None:
        self.roots: List[SignatureSet] = []
        self.root_ids_by_atom: Dict[Atom, List[int]] = {}

    def has_known_subset(self, sig_set: SignatureSet) -> bool:
        candidate_ids: Set[int] = set()
        for atom in sig_set:
            candidate_ids.update(self.root_ids_by_atom.get(atom, []))
        return any(self.roots[rid].issubset(sig_set) for rid in candidate_ids)

    def add_if_minimal(self, sig_set: SignatureSet) -> bool:
        if self.has_known_subset(sig_set):
            return False

        # A newly observed smaller signature can make older larger roots redundant.
        kept_roots: List[SignatureSet] = []
        for root in self.roots:
            if not sig_set.issubset(root):
                kept_roots.append(root)

        kept_roots.append(sig_set)
        self.roots = kept_roots
        self.root_ids_by_atom = {}
        for rid, root in enumerate(self.roots):
            for atom in root:
                self.root_ids_by_atom.setdefault(atom, []).append(rid)
        return True


def bucket_for(pos: int, total: int, buckets: int) -> int:
    if total <= 0:
        return 0
    return min((pos * buckets) // total, buckets - 1)


def count_results(path: Path) -> int:
    total = 0
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith('"adversaryDistinguishable":'):
                total += 1
    return total


def iter_results(path: Path) -> Iterator[Tuple[int, Signature, bool]]:
    total_tests = 0

    current_atoms: List[Atom] = []
    current_atom_type: str | None = None
    current_atom_obs: str | None = None
    in_observations = False

    with path.open("r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()

            if stripped == '"observations": [':
                in_observations = True
                current_atoms = []
                current_atom_type = None
                current_atom_obs = None
                continue

            if in_observations:
                if stripped in ("]", "],"):
                    in_observations = False
                elif stripped.startswith('"type":'):
                    current_atom_type = stripped.split('"')[3]
                elif stripped.startswith('"observation":'):
                    current_atom_obs = stripped.split('"')[3]
                    if current_atom_type is not None:
                        current_atoms.append((current_atom_type, current_atom_obs))
                    current_atom_type = None
                    current_atom_obs = None
                continue

            if stripped.startswith('"adversaryDistinguishable":'):
                is_ad = "true" in stripped
                sig = tuple(sorted(set(current_atoms)))
                yield total_tests, sig, is_ad
                total_tests += 1

def analyze(path: Path, buckets: int, total_tests: int | None) -> None:
    t0 = time.time()
    if total_tests is None:
        total_tests = count_results(path)

    all_seen: Set[Signature] = set()
    ad_seen_exact: Set[Signature] = set()
    subset_index = SubsetIndex()

    bucket_ranges: List[Tuple[int, int]] = []
    ad_counts = [0] * buckets
    new_all_sig_counts = [0] * buckets
    new_ad_exact_counts = [0] * buckets
    new_ad_subset_root_counts = [0] * buckets
    subset_redundant_ad_counts = [0] * buckets

    for i in range(buckets):
        start = (total_tests * i) // buckets
        end = (total_tests * (i + 1)) // buckets
        bucket_ranges.append((start, end))

    parsed_tests = 0
    for pos, sig, is_ad in iter_results(path):
        parsed_tests += 1
        b = bucket_for(pos, total_tests, buckets)
        sig_set = frozenset(sig)

        if sig not in all_seen:
            all_seen.add(sig)
            new_all_sig_counts[b] += 1

        if not is_ad:
            continue

        ad_counts[b] += 1

        if sig not in ad_seen_exact:
            ad_seen_exact.add(sig)
            new_ad_exact_counts[b] += 1

        if subset_index.has_known_subset(sig_set):
            subset_redundant_ad_counts[b] += 1
        elif subset_index.add_if_minimal(sig_set):
            new_ad_subset_root_counts[b] += 1

    cumulative_all = 0
    cumulative_ad_exact = 0
    cumulative_ad_roots = 0

    print(f"File: {path}")
    print(f"Parsed tests: {parsed_tests:,}")
    print(f"Elapsed: {time.time() - t0:.2f}s")
    print()
    print(
        "part;test_range;attacker_d;new_all_signatures;all_signatures;"
        "new_ad_signatures;ad_signatures;new_ad_subset_roots;"
        "ad_subset_roots;subset_redundant_ad;subset_redundant_ad_share"
    )

    for i in range(buckets):
        cumulative_all += new_all_sig_counts[i]
        cumulative_ad_exact += new_ad_exact_counts[i]
        cumulative_ad_roots += new_ad_subset_root_counts[i]
        start, end = bucket_ranges[i]
        print(
            f"{(i + 1) * 10}%;"
            f"{start:,}-{end:,};"
            f"{ad_counts[i]:,};"
            f"{new_all_sig_counts[i]:,};"
            f"{cumulative_all:,};"
            f"{new_ad_exact_counts[i]:,};"
            f"{cumulative_ad_exact:,};"
            f"{new_ad_subset_root_counts[i]:,};"
            f"{cumulative_ad_roots:,};"
            f"{subset_redundant_ad_counts[i]:,};"
            f"{as_pct(subset_redundant_ad_counts[i], ad_counts[i])}"
        )


def main(argv: Sequence[str] | None = None) -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("result_json", type=Path)
    parser.add_argument("--buckets", type=int, default=10)
    parser.add_argument(
        "--total",
        type=int,
        default=None,
        help="Known number of test results. Avoids a counting pre-pass on large files.",
    )
    args = parser.parse_args(argv)

    if args.buckets <= 0:
        raise SystemExit("--buckets must be positive")
    if not args.result_json.exists():
        raise SystemExit(f"File not found: {args.result_json}")

    analyze(args.result_json, args.buckets, args.total)


if __name__ == "__main__":
    main()
