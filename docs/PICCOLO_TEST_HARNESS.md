# Cached RV32 Piccolo attacker harness

`PICCOLO_TEST` connects `synth_new` and `replay_synthesize_spike` to the
pre-generated Piccolo RTL. The shared Spike reference supplies contract atoms;
paired Verilator simulations supply attacker timing labels. Read the
[shared execution model](EXECUTION_MODEL.md) for the `rv32-v1` specification.

## Configuration and provenance

`PICCOLO_TEST` uses the supplied `RV32ACIMU_Piccolo_verilator/Verilog_RTL`
configuration at bluespec/Piccolo commit
`8a80b63af7e0036833836c91fc95f18f74c5fafa` (Apache-2.0).
The Nix input records the source NAR hash; [`source-hashes.sha256`](../src/main/resources/piccolo-test/source-hashes.sha256) records the
individual supplied Verilog and library hashes and the license hash. No Bluespec
compiler is required. Existing simulator/core pins are preserved.

The top instantiates `mkCore`, including its three-stage CPU, separate instruction
and data caches, and supplied multiply/divide units. It excludes the surrounding
`mkSoC`/testbench peripherals. The internal near-memory IO/interrupt block is
reset but never receives experimental memory requests; external interrupt inputs
are inactive. The asserted disposable build copy changes the reset PC to `0x80`,
maps all experimental addresses to ordinary memory, disables IO interception,
and silences simulation diagnostic printing while retaining failure assertions.
A specialized copy of the GPR `RegFile` changes its simulation-only initializer
from `0xaaaaaaaa` to zero to match `rv32-v1`; it preserves the register write
ports and datapath. No pipeline, cache or arithmetic rules are changed.

## Execution, memory and attacker model

Each testcase creates fresh models and Verilator contexts, clears both memory
adapters and pending transactions, and completes the upstream reset handshake
(which invalidates both caches) before measuring execution. Instruction memory
has 2,048 words starting at `0x80`, the shared register initialization prefix,
and user code at `0x100`; unmapped fetches return NOPs. Data memory is sparse,
zero-filled and persistent within a testcase. Overlapping instruction/data
addresses remain separate. Architectural addresses and Spike semantics are
preserved.

The two AXI adapters support fixed, incrementing and wrapping bursts, response
IDs, byte strobes, separate AW/W arrival and backpressure. A response first becomes
available on the next enabled core cycle after acceptance. Each adapter advances
only with its own core. Invalid bursts/strobes/WLAST are errors.

Retirement is `WILL_FIRE_RL_rl_pipe && stage3_rg_full`, the actual stage-three
dequeue, with PC, instruction and destination/value from `stage3_rg_stage3`.
Trap-rule firing is an error. The native runtime applies the established
`clk_sync` paired-retirement hold rule and sticky timing observation: a side
ready to retire waits for its peer; any unequal retirement readiness makes the
pair attacker-distinguishable. It stops at the shared `31 + maxInstructionCount`
bound. The shared Java runner owns testcase scheduling and skipping policies.
Traps, protocol errors, reset failures, malformed inputs, premature termination
and cycle exhaustion cannot become negative evidence.

## Native interfaces and supported instructions

The public ABIs are `contract_simple_attacker_batch_v1` and
`contract_architectural_trace_v1`. A diagnostic-only
`contract_piccolo_retirement_cycles_v1(words, count, max_cycles, cycles_out)`
returns enabled retirement cycles for an identical pair, for timing fixtures.
All diagnostic capture state is thread-local. Every worker/case owns its models,
contexts and memory.

Supported test vocabulary is `BASE` and `BASE,M`. A/C and privilege instructions
present in upstream RTL are not added to the generator. Reached misaligned data
accesses are excluded through Spike capability metadata and the existing
unsupported-case report. Unreachable misaligned instructions remain eligible.
Contract atoms and ILP objectives are unchanged.

## Build and run

Build the native package and run the project checks:

```sh
nix build .#attacker-piccolo
nix flake check
```

The optimized compiler binary in pinned Verilator 5.008 fails internally when
linking this hierarchy. This build uses `verilator_bin_dbg` shipped in the same
package, without debug output or tree dumps. The generated model uses the normal
C++ optimization flags. No simulator derivation or revision is changed.

Library precedence is `--piccolo-test-lib`, then `CONTRACT_PICCOLO_TEST_LIB`,
then the locally compiled default. Nix supplies the packaged default.

## Reproduction

Reproducible training and independent holdout corpora (retain the saved JSON;
seeds alone do not guarantee ordering across JVMs):

```sh
for seed in 35 36; do
  nix run . -- synth_new -p PICCOLO_TEST -i BASE,M \
    -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE -n 500 -t 1 -s "$seed" \
    --output-dir "results/piccolo/seed-$seed" --disable-adaptive-skipping
  for workers in 1 8; do
    nix run . -- replay_synthesize_spike -p PICCOLO_TEST -i BASE,M \
      -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE -t "$workers" \
      -e "results/piccolo/seed-$seed/testcases.json" \
      -o "results/piccolo/seed-$seed/replay-$workers.json" \
      --txt "results/piccolo/seed-$seed/replay-$workers-summary.txt" \
      --disable-adaptive-skipping
  done
done
```

Use `min(8, available CPUs)` instead of 8 on smaller machines. Compare labels
with `python3 nix/tests/compare-replay.py ORIGINAL REPLAY`. The generated
training corpus and holdout corpus are separate; replay reuses their exact saved
cases. The commands above describe reproduction; they are not a record of
completed validation. The package check runs the AXI adapter and native runtime
regressions; the shared native smoke and workflow checks also include Piccolo.


## Implementation files

- [`prepare.py`](../src/main/resources/piccolo-test/prepare.py) verifies the source
  hashes and prepares the disposable RTL copy and architectural probes.
- [`compile-verilator.sh`](../src/main/resources/piccolo-test/compile-verilator.sh)
  builds `libcontract_piccolo_test_attacker.so`.
- [`axi_memory.hpp`](../src/main/resources/piccolo-test/verif/axi_memory.hpp)
  implements the separate instruction/data AXI endpoints.
- [`piccolo_runtime.cpp`](../src/main/resources/piccolo-test/verif/piccolo_runtime.cpp)
  implements reset, retirement synchronization and diagnostic traces.
- [`axi_memory_test.cpp`](../src/main/resources/piccolo-test/tests/axi_memory_test.cpp)
  and [`runtime.py`](../src/main/resources/piccolo-test/tests/runtime.py) contain
  the package regression checks.
