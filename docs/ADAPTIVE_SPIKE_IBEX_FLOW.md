# Adaptive Spike / IBEX_TEST Flow

This note summarizes the current implementation of the Spike-based atom flow and the simplified IBEX_TEST attacker flow.

## Goal

The updated path decouples:

- atom distinguishability: computed with the adapted Spike shared library
- attacker distinguishability: computed with the simplified IBEX_TEST Verilator shared library

`synth_new -p IBEX_TEST` generates tests and runs this path directly.
`replay_synthesize_spike -p IBEX_TEST` applies the same path to an exported
testcase JSON file. The legacy `synthesize -p IBEX` command does not use Spike
or this attacker-only harness.

Every `synth_new` run also exports its exact generated testcase set in the
same JSON format as `export_tests`. By default, an output `results/run.json`
produces `results/run-testcases.json`; use `--testcases-output` to override the
path. The testcase file is written before Spike or RTL execution begins.

## Spike Atom Extraction

Java entry points:

- `SpikeAtomClient`
- `SpikeAtomParallelRunner`
- hidden CLI worker `spike_atoms_worker`

Spike receives the same testcase structure as the Java project generates: paired RISC-V programs,
register initial values, max instruction count, and testcase index.
The Java side serializes testcases through the existing `RISCVTestCaseIO` JSON format,
and the adapted Spike library returns atom observations for each testcase.

Replay relocates the bounded image without changing PC-relative branch/JAL
displacements. Only absolute JALR addresses in the harness image are translated
to the replay image. Spike follows architectural control flow, including loops
and re-entry through the register-loader prologue; it does not guess a
core-specific fetch-exhaustion policy.

Parallelization is process-based, not thread-based.
Calling the Spike shared library concurrently from multiple Java threads caused native crashes,
so `SpikeAtomParallelRunner` splits the testcase list into chunks and starts separate JVM worker processes.
Each worker loads the Spike shared library independently and runs one chunk.

Current chunk policy:

- max chunk size: 1000 testcases
- min chunk size: 100 testcases
- target chunks: roughly `threads * 4`

With `-t 1`, Spike uses the shared library directly in the main JVM. With more threads, it uses process isolation.

## IBEX_TEST Attacker Execution

Java entry points:

- `IBEXTestAttackerClient`
- `AdaptiveAttackerRunner`

Native entry point:

- `contract_ibex_test_attacker_batch_v4(...)`

The new IBEX_TEST harness is only responsible for attacker distinguishability.
It does not extract RVFI atoms.
The Java side converts each generated testcase directly into fixed-size instruction arrays and calls the native shared-library API through JNA.

Program image format:

- fixed max image size: 2048 words per program
- words `0..30`: register initialization code, encoded as `ADDI xi, x0, value`
- word `31`: unused/padded slot
- words from `32`: actual generated program instructions
- remaining words: NOP padding

This avoids per-test `.dat` file generation for the IBEX_TEST shared-library path. The old RVFI extractor and old IBEX harness path still exist separately.

The native side creates a fresh Verilated `Vtop` for each full or minimized-prefix run. Testcase data is passed through arrays instead of filesystem memory-init files.

The harness retains the established per-core instruction-fetch completion
policy. This is important for liveness after the two cores take different
control-flow paths; paired retirement alone is not a safe completion condition
with the current clock synchronizer.

For an attacker-positive testcase, the native runner reproduces the historical
Ibex prefix minimization without generating a VCD. It records the two fetch
counters and paired retirement counter when `atk_equiv_o` first changes from
true to false, then reruns fresh Verilator models with decreasing instruction-
fetch bounds while the testcase still fails. One final run at the smallest
failing fetch bound supplies the cutoff: its final paired retirement count.
This is the same execution prefix from which the old RVFI path extracted atoms.
Attacker-negative, timeout, and error results return no cutoff.

For every full run, the v4 harness also records the last absolute RVFI
retirement at which either core retires a non-NOP instruction. This is compact
execution-boundary metadata, not an exported instruction trace. Executed
attacker-negative evidence is bounded there, except that Java retains ADDI
RAW/WAW observations for the following four retirements because dependency
atoms can legitimately persist into the terminal NOP suffix. Instruction pairs
and structural/control atoms after the boundary are discarded.

The v4 native symbol makes older shared libraries fail with an explicit rebuild
error instead of silently returning incompatible boundaries.

## Adaptive Filtering

`IBEXTestAdaptiveRunner` groups testcases by exact Spike atom signature.

For each exact signature:

- if one testcase is attacker-distinguishable, remaining testcases with the same signature can be skipped as positive duplicates
- if `negativeSignatureThreshold` attacker-negative cases are seen, remaining cases with the same signature can be skipped as negative duplicates
- optional positive-superset and negative-subset rules can infer labels from
  previously executed signatures

For an executed attacker-positive testcase, Java keeps only Spike atoms and
ordered instruction-type pairs whose earliest absolute retirement is at or
before the native failure cutoff. An executed attacker-negative testcase uses
the native last-non-NOP boundary described above. Missing positive cutoffs and
empty positive filtered evidence sets are errors. The pairs populate the
existing `distinguishingInstructions` result field, allowing the ILP to use the
same type-asymmetry constraints as the RVFI flow.

By default, skipped cases are not added as evidence.
If `--use-skipped-evidence` is enabled, skipped cases are copied into the contract evidence with the inferred attacker label.
Skipped evidence remains signature-level because no individual RTL cutoff was
measured for those cases.

`--disable-adaptive-skipping` bypasses exact-signature duplicate skipping,
threshold skipping, and subset/superset inference. Every testcase is then sent
to RTL, while grouping is retained only as an internal scheduling detail.

## Parallelization Summary

Spike:

- parallelized across JVM worker processes
- each worker loads its own Spike shared library instance
- needed because in-process multi-threaded Spike calls were not stable

IBEX_TEST:

- parallelized across Java threads in `IBEXTestAdaptiveRunner`
- each thread creates its own `IBEXTestAttackerClient`
- work is distributed by exact atom-signature groups
- attacker-positive cases may run several fresh native models internally while
  finding the smallest failing fetch bound; no VCD is written or parsed
- each native batch call currently runs one testcase at a time inside a signature group

## Timing Interpretation

In replay output:

- `Spike Time` is for atom extraction over all testcases
- `Adaptive Attacker Time` is only for RTL executions that survive the signature filter
- `RTL Executed` is the number of testcases actually sent to IBEX_TEST
- `Skipped Positive Signature` and `Skipped Negative Threshold` are not simulated in RTL

So a run can show Spike taking much longer than IBEX_TEST even though RTL is more detailed, because RTL is asked a smaller question for far fewer testcases.

## Assumptions And Limitations

- Spike atoms are treated as the signature source for adaptivity.
- Signature-relation inference is optional and disabled unless requested.
- Inconsistent signatures can exist: the same atom signature may sometimes be attacker-positive and sometimes attacker-negative.
- The current negative threshold is a heuristic, not a proof.
- The IBEX_TEST shared-library path is specialized for attacker distinguishability and should not replace the old RVFI extractor until the new oracle design is finalized.
