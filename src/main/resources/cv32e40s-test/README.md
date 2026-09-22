# CV32E40S attacker-only integration

See [the integration document](../../../../docs/CV32E40S_TEST_HARNESS.md)
for implementation details, reset/boot behavior, and recorded validation results.

`CV32E40S_TEST` uses the adapted Spike library for the complete distinguishing
contract atom set and a paired Verilator model for attacker distinguishability.
It supports both `synth_new` and `replay_synthesize_spike`, including their existing
adaptive selection and ILP synthesis. It does not minimize failing prefixes.

## Build

The core submodule is pinned to OpenHW CV32E40S **0.10.0**, commit
`d45d7b4c02a353d093de3efdf0569486d9a506c5`:
<https://github.com/openhwgroup/cv32e40s/tree/0.10.0>.
Upstream licensing is retained in `core/LICENSE` and source headers.

From the repository root:

```sh
nix build .#attacker-cv32e40s
```

The flake fetches the pinned core and supplies Verilator 5.008, a C++17
compiler, and Make. The library is available as
`result/lib/libcontract_cv32e40s_test_attacker.so`.
`CONTRACT_BUILD_JOBS` defaults to 4.
`CONTRACT_BUILD_TIMEOUT_SECONDS` sets the Java build deadline (default 240 seconds).
Compiler output is drained during execution and retained when a build times out.
Optional source overrides are
`CONTRACT_CV32E40S_CORE_ROOT` and `CONTRACT_ATTACKER_COMMON_ROOT`.
The upstream packed performance-counter array needs the narrow BLKANDNBLK
waiver in `verif/upstream.vlt`; the upstream RTL is otherwise unmodified.

## Run

Use the packaged CLI and the same testcase set in separate runs to compare
timing modes:

```sh
nix run . -- synth_new \
  -p CV32E40S_TEST -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
  -n 64 -t 2 -s 1 --output-dir results/cv32e40s-test/off \
  --cv32e40s-data-independent-timing=off --disable-adaptive-skipping

nix run . -- replay_synthesize_spike \
  -p CV32E40S_TEST -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE -t 2 \
  -e results/cv32e40s-test/off/testcases.json \
  -o results/cv32e40s-test/on.json --txt results/cv32e40s-test/on-summary.txt \
  --cv32e40s-data-independent-timing=on --disable-adaptive-skipping
```

Library selection is explicit `--cv32e40s-test-lib`, then
`CONTRACT_CV32E40S_TEST_LIB`, then the packaged library. The existing
`--spike-lib` / `CONTRACT_SPIKE_LIB` options select the adapted Spike library.
Timing defaults to `off`. Both modes use one compiled library; the mode is passed
per native batch and is never shared mutable process state. Summaries record
the mode, fixed security settings, and expected pinned RTL revision. An external
library must be built from these pinned sources for that revision to be accurate.

## Experiment configuration

- RV32I and M; B, debug, interrupts, CLIC, and PMP regions disabled. Compressed
  hardware remains present upstream, but the generator emits 32-bit instructions.
- PMA regions are deconfigured: main, uncached, nonbufferable memory. The CSR
  integrity switch is on; response-data integrity checking is also subject to
  upstream PMA attributes. The harness supplies correct parity and checksums.
- PC hardening, randomized dummy instructions, and randomized hints are off.
  Fixed nonzero LFSR configuration is identical for both cores.
- Boot ROM executes `CSRRWI x0,0xbf0,16|timing` at `0x0`, then jumps to `0x80`.
  This is necessary because upstream reset enables timing protection and PC
  hardening. Setup is excluded from measurement and retirement bounds.
- The unchanged 2048-word program image begins at `0x80`: 31 register setup
  instructions, one NOP, then testcase instructions at `0x100`. Runtime stops at
  `maxInstructionCount + 31` paired image retirements, matching Spike's bound.
- The attacker observes differences in the retirement-synchronized core clocks.
  It sees timing only; RTL does not extract atoms or compare architectural values.
- Data memory matches the adapted Spike's synthetic zero-filled, 32-byte FIFO
  write history, including its raw-address-plus-byte-lane convention. This is
  a research harness model, not ordinary RAM. Byte accesses support every lane;
  halfwords and words must be **word aligned**, as in the generated workload.
  Broader replay accesses return `ERROR` rather than silently supplying evidence.
- Each testcase gets a fresh Verilator context, cores, and memory. Traps, security
  alerts, setup failures, and unsupported alignment return `ERROR`; cycle exhaustion
  returns `TIMEOUT`. Neither is valid positive or negative evidence.

The C ABI `contract_cv32e40s_test_attacker_batch_v1` accepts case count, cycle
limit, timing (0/1), case IDs, retirement bounds, two flattened 2048-word-per-case
images, and status outputs (0 success, 1 distinguishable, 2 timeout, 3 error).
The Java client returns no failure/execution cutoffs, preserving complete Spike
evidence. No waveform or instruction-trace files are emitted.

## Focused validation

```sh
g++ -std=c++17 -I src/main/resources/cv32e40s-test/verif \
  src/main/resources/cv32e40s-test/tests/native_smoke.cpp \
  -L /tmp/cv32e40s-compiled -lcontract_cv32e40s_test_attacker \
  -Wl,-rpath,/tmp/cv32e40s-compiled -o /tmp/cv32e40s-smoke
/tmp/cv32e40s-smoke
mvn -Dcontract.cv32e40s.lib=/tmp/cv32e40s-compiled/libcontract_cv32e40s_test_attacker.so test
```

The native checks cover functional results, memory lanes and history eviction,
JAL/JALR addresses, retirement boundaries, both timing modes, timeouts, illegal
instructions, and injected parity faults. Expected fault cases print diagnostic
flags: bit 0 major alert, 1 minor alert, 2 trap, 3 boot PC mismatch, 4 CSR mismatch,
5 unsupported memory alignment. JUnit additionally checks batches, concurrent
mode isolation, CLI parsing, and image bounds; native tests skip when their library
property is absent.

Full ISA compliance, misaligned-memory experiments, randomized protections, and
new contract atoms are outside this integration.
