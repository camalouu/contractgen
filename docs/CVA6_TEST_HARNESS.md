# CVA6_TEST attacker-only harness

## Purpose

`CVA6_TEST` is the lightweight CVA6 backend for the replay-synthesis path. It
answers one question for a pair of programs: can the attacker distinguish the
two RTL executions? It deliberately does **not** derive contract atoms. Atom
distinguishability remains the responsibility of the Spike shared library.

The resulting split is:

```text
paired testcase JSON
        |
        +-- Spike ------------------> distinguishing contract atoms
        |
        +-- CVA6_TEST / Verilator --> attacker-distinguishable boolean
                                      |
                                      +--> merged RISCVTestResult and ILP update
```

The command is:

```bash
java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main \
  replay_synthesize_spike -p CVA6_TEST \
  -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES -t 8 \
  -e <testcases.json> -o <contract.json> --txt <summary.txt>
```

For newly generated tests, use the corresponding synthesis frontend:

```bash
java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main \
  synth_new -p CVA6_TEST \
  -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES -n 10000 -t 8 -s 51 \
  --output-dir results/cva6_test-10000-seed51
```

The legacy `synthesize` command intentionally remains separate and accepts
only the original `IBEX` and `CVA6` integrations.

The input testcase JSON and output contract JSON are unchanged from the
`IBEX_TEST` replay flow. `--cva6-test-lib` or `CONTRACT_CVA6_TEST_LIB` can
select an already-built attacker shared library. Otherwise the harness is
rebuilt at `/home/yosys/output/cva6-test/compiled/`.

## How the harness is assembled

The source template is `src/main/resources/cva6-test/`.
`compile-verilator.sh` performs the following steps:

1. copies the CVA6 RTL tree, package includes, patches, and the new
   `verif/` files to an isolated compilation directory;
2. applies the CVA6 patches;
3. invokes Verilator once for a command-line executable and once for the
   JNA-loadable `libcontract_cva6_test_attacker.so`;
4. links `cva6_test_runtime.cpp` and `cva6_test_shared.cpp` into the shared
   interface.

At runtime, `CVA6TestAttackerClient` encodes each Java testcase into two fixed
2048-word program images. Register initialisation occupies words `0..30`,
word `31` is padding, and program instructions begin at word `32`. The native
entry point `contract_cva6_test_attacker_batch(...)` creates a fresh Verilated
`Vtop` for each testcase and returns one status: `SUCCESS`, `FAIL`, `TIMEOUT`,
or `ERROR`.

`FAIL` means attacker-distinguishable; `SUCCESS` means indistinguishable.
Timeouts and errors are rejected by replay synthesis rather than converted to
contract evidence.

## What remains of RVFI

RVFI is still used inside `verif/top.sv`, but only as control and alignment
logic:

- `rvfi_instr.valid` provides the per-core retirement signals for `clk_sync`;
- `rvfi_instr.trap` reports an invalid execution to the native runtime;
- paired retirements determine when both executions have completed their
  requested instruction count.

This is intentionally not a full RVFI trace interface. RVFI supplies a stable
retirement boundary, not the observations used to synthesize a contract.

The attacker check (`verif/atk.sv`) compares the two synchronized execution
clocks. Once their timing diverges, `atk_equiv_o` remains low. The runtime
returns `FAIL` when the paired run finishes with that signal low.

## Differences from the original CVA6 harness

| Area | Original `cva6` | `cva6-test` |
| --- | --- | --- |
| Primary result | RTL trace from which Java extracts observations and contract atoms | One attacker label per testcase |
| Atom source | RVFI-derived observation extraction | Spike shared library |
| RVFI use | Full field exposure through `rvfi_unwrap.sv`, instruction decoding, and trace-oriented plumbing | Retirement validity and trap status only |
| Harness modules | Includes `rvfi_unwrap.sv`, `riscv_decoder.sv`, `ctr.sv`, and the related trace/observation logic | Keeps only paired cores, memory, clock synchronization, completion control, and `atk.sv` |
| Testcase transport | Filesystem-oriented `.dat` images and simulation artifacts | Direct fixed-size arrays through a C/JNA shared-library API; legacy `.dat` loading remains only for the command-line fallback |
| Output | Simulator result plus trace data for an extractor | `SUCCESS`/`FAIL`/`TIMEOUT`/`ERROR` status; Java converts only success/fail to an attacker label |
| Replay role | General CVA6 integration | Attacker-only backend selected with `replay_synthesize_spike -p CVA6_TEST` |

The original harness remains the reference used by
`compare_cva6_test_attacker`. That command compares its attacker labels with
the new harness across the same testcase set; it does not run Spike or compare
atoms.

## Maintenance rules

- Keep the native status mapping in `CVA6TestAttackerClient` consistent with
  `cva6_test_shared.cpp`.
- Do not add RVFI observation extraction to `cva6-test`; add it to Spike if it
  is a contract atom.
- If completion or timing semantics change, run
  `compare_cva6_test_attacker` on the CVA6 regression set before relying on
  replay results.
- Keep the JNA function signature, Java program-image layout, and
  `cva6_test_runtime.hpp` in lockstep.
