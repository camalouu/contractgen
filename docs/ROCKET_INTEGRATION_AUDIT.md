# Rocket integration audit — 2026-09-15

> Historical record from the original Rocket branch. Its processor-specific Spike
> profile has been replaced by the shared `rv32-v1` reference. See
> [the current execution model](EXECUTION_MODEL.md) and
> [Rocket instructions](ROCKET_TEST_HARNESS.md). The results below describe the
> original experiment, not a rerun with the current implementation.

The pinned Rocket configuration, generated RTL, memory endpoint, paired retirement
scheduler, Java integration, and Rocket Spike profile were reviewed and exercised.
One correctness bug was found in the Rocket Spike profile and corrected. No Rocket
pipeline, cache, predictor, generated RTL, or runtime logic changed in this audit.

## Correction

After an out-of-image NOP at `0xfffffffc`, the Rocket Spike profile previously
advanced its internal PC to `0x100000000`. RV32 RTL wraps to zero. This could also
prevent the reference execution from eventually reentering the image at `0x80`.
The synthetic-NOP path now uses 32-bit next-PC arithmetic for the Rocket profile.
Legacy arithmetic is unchanged. The retained patch against adapted Spike revision
`2f3476288f9596906e31a8b5250fef3532e7c7ba` includes the correction.

Regression tests check the boundary, reentry into the image, and agreement with
RTL over 100 retirements. The architectural agreement test no longer truncates
Spike's PC before comparison, which could hide this error. Native tests now also
include a dependent DIVU pair with dividend `0x80000000` and divisors 3 versus
`0xffffffff`, in both pair orders, exercising division timing divergence.

Rebuild the adapted Spike library before subsequent experiments:

```sh
make -C riscv-isa-sim/build -j4 libcontract_spike_atom.so
```

The local library was rebuilt during this audit. No Docker image rebuild is needed.

## Provenance and execution checks

- Re-elaborated the wrapper using the pinned Rocket checkout, recursive submodules,
  Mill 0.11.12, Chisel 6.7.0, and firtool 1.62.0. Every generated RTL file matches
  the checked-in version byte for byte. Upstream source has no tracked edits in
  that generator checkout; the project wrapper is an added source file.
- Built a fresh simulation library from checked-in RTL with Verilator 5.034.
- Ran the standalone TileLink endpoint tests: response backpressure, release
  priority, instruction/data separation, dirty data, masked writes, permission
  upgrades, and early grant acknowledgments passed.
- Ran native architecture, cache, timing, repeated/concurrent isolation, exact
  retirement count, timeout, and exception tests. A later exception overrides an
  earlier timing divergence. Branch, cache, and division divergence checks passed.
- Compared Spike and RTL for 100 directed programs, checking every retirement PC
  and final registers after allowing delayed writeback to complete. These cover
  arithmetic, multiply/divide, control flow, memory lanes, persistent stores,
  dirty conflict eviction/refill, and PC wraparound.
- Java clean test/package passed with 42 tests reported: 35 passed, seven skipped,
  zero failures/errors. Skips are environment-dependent refinement and CV32E40S
  smoke tests. A temporary POM used the repository's Java sources and dependencies
  with output under `/tmp`, avoiding the existing target directory's ownership.
  Native resources were built separately. Both workflow help commands and actual
  direct/replay invocations were exercised. Java tests check profile propagation
  into isolated workers and the actionable error when Rocket uses a pre-v2 library.

## Existing 50,000-case experiment

Input: `results/rocket_test-50000-seed35/testcases.json`.

A streaming selection retained all 1,520 attacker-positive cases plus every
hundredth exported testcase, totaling 2,002 cases. A separate diagnostic driver
clocked each tile independently and compared per-retirement cycle vectors with
the paired scheduler's labels, and retirement PCs with the Spike reference.
Before the correction, PC mismatches occurred in cases 7669, 9579, and 30153,
all from the wraparound bug. After the correction there were zero mismatches.
The fresh RTL labels also match the recorded attacker labels in `contract.json`
for all 2,002 cases. The testcase file's generator-provided distinguishability
field was not used as the measured attacker label.
The independent driver still uses the same RTL and memory responder: this checks
the paired scheduling logic, not an independent implementation of Rocket or memory.

Complete extracted evidence was compared before/after the correction for all
50,000 cases, in bounded batches and separate processes. All evidence is identical,
including first-retirement metadata and instruction-pair evidence. Thus this bug
does not explain the nine-atom contract or its NEW_PC selections in this dataset.
Longer executions that cross the boundary and reenter the image can be affected.

The original legacy ABI was also compared between the adapted Spike base revision
and the current implementation over these 50,000 inputs. Every result matched.
This is evidence of legacy compatibility for these inputs, not a rerun of every
other core's RTL integration.

## Direct synthesis and exact replay

Ran the documented commands with seed 1, BASE,M, observation groups
BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE, two workers, and
`--disable-adaptive-skipping`. Each generated testcase file was replayed exactly.
Per-case labels and complete stored evidence match after normalizing set ordering.

| Cases | RTL executed | Positive | Negative | Contract size | False positives | Positive coverage | Invalid/timeouts |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 64 | 64 | 3 | 61 | 2 | 1 | 3/3 | 0 |
| 512 | 512 | 25 | 487 | 8 | 2 | 25/25 | 0 |

The 64-case contract selects BEQ:BRANCH_TAKEN and JALR:IMM. The 512-case contract
selects BRANCH_TAKEN for BEQ, BGE, and BNE, alongside NEW_PC for other branches.
There is no Rocket-specific forcing of NEW_PC. The shared optimizer minimizes
covered negative observation sets first, then contract size, subject to covering
positive evidence. Its map keys collapse equal observation sets; this differs
from the per-case false-positive count printed in summaries.
These checks do not isolate which predictor/cache mechanism causes a particular
branch-target timing difference; attributing every NEW_PC selection to the branch
predictor alone would go beyond the evidence.

The subsequent [fresh-run branch investigation](ROCKET_BRANCH_OBSERVATIONS.md)
traces target-dependent instruction-cache refills, compares the same 129 cases
on FWRISC, and reruns the optimizer with branch-atom constraints.

Audit outputs are under `/tmp/rocket-audit-*`, including the fresh native build,
direct/replay experiments, and bounded comparison digests. Existing experiment
files and `run.sh` were left untouched. These are integration checks, not formal
verification or a full RISC-V compliance suite. The experiment retains the
documented separate instruction/data memory model and deterministic cold starts.
