# Why the fresh Rocket contract selects NEW_PC

> Historical record from the original Rocket branch. Its processor-specific Spike
> profile has been replaced by the shared `rv32-v1` reference. See
> [the current execution model](EXECUTION_MODEL.md) and
> [Rocket instructions](ROCKET_TEST_HARNESS.md). The results below describe the
> original experiment, not a rerun with the current implementation.

Investigation date: 2026-09-15. Input:
`results/rocket_test-50000-seed35/contract.json`, SHA-256
`d07c276308b90db5135a793f2cef75f22b2bf7cc4365d44ca181040bd656cd0e`.
This fresh run has 1,502 positive cases, 48,498 negative cases, nine selected
atoms, and 496 false positives. Every testcase ran in RTL; skipping was disabled.

## The difference is present in the attacker labels

There are 129 positive cases with a conditional branch's NEW_PC evidence but no
BRANCH_TAKEN evidence for that branch. These are taken branches with different
targets. Replacing NEW_PC with BRANCH_TAKEN in the reported contract leaves these
cases uncovered. Branch-taken evidence is present and correctly extracted in the
other positive cases:

| Branch | Positive with both observations | Positive with NEW_PC but no BRANCH_TAKEN |
| --- | --- | --- |
| BEQ | 122 | 19 |
| BNE | 120 | 29 |
| BLT | 193 | 14 |
| BGE | 185 | 22 |
| BLTU | 143 | 16 |
| BGEU | 159 | 29 |

All 129 exact testcase pairs were rerun on the available FWRISC harness library:
**all 129 were indistinguishable**, with skipping disabled. This removes seed,
testcase count, and generated-program differences from that comparison.
FWRISC's stored 10,000-case seed-35 result likewise has zero positive conditional
branch NEW_PC cases without BRANCH_TAKEN evidence.

## Traced cause: instruction-cache refills

An independently clocked Rocket diagnostic run traced instruction TileLink
requests and every retirement for all 129 pairs. The paired scheduler agrees with
these independent timing labels and with Spike retirement PCs in all 129 cases.
The two sides issue different numbers of instruction refills in 123 pairs; the
remaining six issue the same number at different cycles. Different branch targets
change whether and when execution needs another cache line, including whether a
target is in a line already fetched during initialization.

For example, fresh testcase **2884** executes BGEU at `0x100` with the same
registers on both sides (`x18=2019`, `x24=0`), so both branches are taken:

| Event | Left | Right |
| --- | --- | --- |
| Branch target | `0xcfc` | `0xcec` |
| Offset within 64-byte line | 60 | 44 |
| Branch retirement cycle | 82 | 82 |
| First target retirement cycle | 103 | 103 |
| Second target PC | `0xd00` | `0xcf0` |
| Second target retirement cycle | 121 | 104 |
| Final measured retirement cycle | 123 | 106 |

Both sides initially refill the line at `0xcc0`. The left side then needs a refill
at `0xd00`; the right side remains in the previous line through the measured
retirement bound. Both targets are inside the instruction image. This example
does not depend on out-of-image NOPs or RV32 address wraparound.

Controlled changes to this same testcase confirm the boundary effect:

| Left target / right target | Retirement bound | Label |
| --- | --- | --- |
| `0xcfc` / `0xcec` | 37 | Distinguishable |
| `0xcfc` / `0xcec` | 34, ending after the first target instruction | Indistinguishable |
| `0xce8` / `0xcec` | 37 | Indistinguishable |
| `0xcf8` / `0xcec` | 37 | Distinguishable |

Fresh testcase **36** provides the corresponding BNE example: both branches are
taken, to `0xfffffcb8` and `0xfffff54c`. The first two target instructions retire
at cycles 103 and 104 on both sides. The left then crosses into `0xfffffcc0` and
retires the next instruction at cycle 122, versus cycle 105 on the right.
Its complete evidence is BNE:IMM and BNE:NEW_PC, with no BRANCH_TAKEN difference.

These traces demonstrate cache timing effects; they do not justify attributing
the result solely to branch prediction. The cache observes target addresses even
though the branch decision is identical.

## Why the optimizer chooses one atom instead of two

The existing optimizer was rerun on the full exported evidence with atom
constraints. Every contract below covers all 1,502 positive cases:

| Constraint | Size | False-positive cases | Solver primary objective |
| --- | --- | --- | --- |
| Reported contract | 9 | 496 | 28 |
| Require BRANCH_TAKEN for all six conditional branches | 15 | 496 | 28 |
| Forbid NEW_PC for all six conditional branches | 15 | 836 | 34 |

Requiring BRANCH_TAKEN retains all six NEW_PC atoms: taken-outcome differences
were already covered by NEW_PC in this dataset, so the six additional atoms add
no coverage. Forbidding NEW_PC selects BRANCH_TAKEN plus IMM for each conditional
branch, which also covers target changes but causes more false positives.

The solver's primary objective is **not the displayed per-case false-positive
count**. `ILPUpdater` stores negative variables in a map keyed by `TestResult`,
while `RISCVTestResult.equals/hashCode` use only the observation set. Consequently
the objective counts distinct negative observation sets (28 versus 34 here).
The summary counts individual cases (496 versus 836). This shared behavior also
applies to other cores and was not changed in this investigation. The NEW_PC
contract is preferable by both measures in the counterfactual comparison above.

## Scope and artifacts

No production code, RTL, solver weights, or original result files were changed.
Diagnostic scripts, extracted testcase pairs, counterfactual logs, replay results,
and traces are under `/tmp/rocket-branch-*`, `/tmp/rocket-all-target-only-*`, and
`/tmp/fwrisc-all-target-only*`. The Rocket library was the fresh build from the
integration audit; the FWRISC replay used
`/tmp/fwrisc-patched-compile-validation/libcontract_fwrisc_test_attacker.so`.

The final contract contains instruction-level atoms. There is no supplied atom
for “the next few target instructions cross a cold cache-line boundary,” so the
selected NEW_PC atom overapproximates this address-dependent timing behavior.
This explains why some target differences are false positives even though others
are real timing leaks. A finer cache-related contract vocabulary or a different
cache configuration would be a separate experiment.
