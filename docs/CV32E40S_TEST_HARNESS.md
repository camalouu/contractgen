# CV32E40S attacker-only harness

`CV32E40S_TEST` connects `synth_new` and `replay_synthesize_spike` to OpenHW
CV32E40S 0.10.0, pinned as a submodule at commit
`d45d7b4c02a353d093de3efdf0569486d9a506c5`.
Spike is the sole source of distinguishing contract atoms and instruction pairs.
The paired Verilator model supplies only attacker timing distinguishability.
The integration uses the complete Spike evidence set, without failing-prefix
minimization or execution-cutoff filtering.

## Core and configuration

The wrapper instantiates two `cv32e40s_core` instances with:

```text
RV32             = RV32I
M_EXT            = M
B_EXT            = B_NONE
DEBUG            = 0
DBG_NUM_TRIGGERS = 0
PMA_NUM_REGIONS  = 0
PMP_NUM_REGIONS  = 0
CLIC             = 0
```

Both cores have the same hart ID, private memories, and inactive interrupt,
debug, and wakeup inputs. The trap and debug vectors point to `0x4000`; a trap
is an invalid experiment result, not a supported execution path.
The generator supports `BASE` and `BASE,M`. Compressed hardware remains present
in the upstream core, but this integration generates only 32-bit instructions.

`--cv32e40s-data-independent-timing=off|on` selects the timing configuration,
defaulting to `off`. Both modes keep PC hardening, randomized dummy insertion,
and randomized hints disabled. The integrity CSR bit stays enabled. All three
LFSRs use coefficients `0x80000057` and seed `1`, identical for both cores.

With PMA regions deconfigured, memory has the upstream default attributes:
main memory, uncached, nonbufferable, and without PMA response-data integrity
checking. The wrapper nevertheless supplies correct OBI parity and response
checksums. Enabling the integrity CSR alone does not enable every PMA-dependent
check.

## Boot, reset, and program layout

CV32E40S resets `cpuctrl` to `0x19`, enabling data-independent timing, PC
hardening, and integrity. The harness explicitly configures both experiment
modes using real instructions before executing register initialization:

| Address | Contents |
| --- | --- |
| `0x0000` | `CSRRWI x0, 0xbf0, 16` for timing off, or immediate `17` for on |
| `0x0004` | `JAL x0, 0x0080` (displacement `0x7c`) |
| `0x0080`–`0x00f8` | Shared image words 0–30: register initialization |
| `0x00fc` | Shared image word 31: NOP spacer |
| `0x0100` onward | Shared image words 32 onward: generated testcase |

The two boot instructions are excluded from attacker measurement and the
test-image retirement count. Their PCs and the resulting CSR values are checked
before measurement starts. The boot ROM is disabled after its jump retires;
the testcase image and Spike input are never modified to insert these instructions.
The image contains 2,048 words, and instruction fetches outside the image return
`ADDI x0,x0,0` after boot.

The native runtime creates an actual falling reset edge before holding reset
for ten clock cycles. Merely starting the reset input at zero was insufficient
in Verilator's two-state simulation: hardened CSR cells behind closed clock
gates did not receive a reset event and raised a major alert. The explicit edge
initializes the upstream cells without modifying the core RTL.

## Attacker and memory model

The core's `debug_pc_valid_o` output is the upstream retired-instruction event.
It feeds the existing shared `clk_sync` module, which holds the faster core while
the other catches up. After boot, any difference between the synchronized core
clocks makes attacker inequivalence sticky. `debug_pc_o` supports boot checks;
it is not a contract observation extracted from RTL.

Completion occurs after `maxInstructionCount + 31` paired image retirements,
matching the bound used by the Spike atom path. It does not depend on prefetch
exhaustion. Each native testcase gets a fresh Verilator context, cores, and memory.

OBI requests are granted combinationally while reset is inactive, and responses
are registered on the following core-clock edge. Each data memory models the
adapted Spike's zero-filled synthetic memory with a FIFO history of 32 written
bytes. Byte keys follow its raw-address-plus-byte-lane convention; this is a
bounded research memory model, not a conventional RAM. In particular, it does
not use CV32E40P_TEST's address-derived initial read values.

Byte accesses support every lane. Halfword and word accesses must be **word
aligned**, matching the generated workload. The wrapper detects unsupported
alignment before accepting it as evidence. This restriction is stronger than
natural halfword alignment and is a harness limitation, not a CV32E40S ISA limit.

Traps, security alerts, setup failures, unsupported alignment, and unexpected
simulator termination return `ERROR`. Cycle exhaustion returns `TIMEOUT`.
The adaptive runner rejects these results rather than treating them as positive
or negative evidence. Expected fault tests print flags: bit 0 major alert,
1 minor alert, 2 trap, 3 boot PC mismatch, 4 CSR mismatch, 5 unsupported alignment.

## Java and native integration

- `Main.java` adds the processor and options to both new-workflow commands and
  forwards direct synthesis into `ReplaySynthesizeSpike`.
- `SimpleTestMARCH` supplies build orchestration and the contract container.
  `CV32E40STestAttackerClient` provides the dedicated JNA adapter.
- `contract_cv32e40s_test_attacker_batch_v1` accepts case count, cycle limit,
  timing mode (0/1), case IDs, retirement bounds, two flattened instruction-image
  arrays, and output statuses. Status codes are 0 success, 1 distinguishable,
  2 timeout, and 3 error.
- Timing is passed per batch, and DPI inputs are thread-local. One compiled
  library supports both modes, including concurrent Java clients.
- `requireFailureCutoff=false` keeps complete Spike evidence. No new contract
  atoms, RTL atom extractor, or legacy `CONFIG.PROCESSOR` entry was introduced.

Library resolution uses `--cv32e40s-test-lib`, then
`CONTRACT_CV32E40S_TEST_LIB`, then
`/home/yosys/output/cv32e40s-test/compiled/libcontract_cv32e40s_test_attacker.so`.
The default container path is rebuilt through the existing setup helper;
explicit or environment-provided libraries are used as supplied. Console output
and text summaries record the timing mode, fixed security settings, and expected
pinned RTL revision. External libraries must match that revision.

## Build and examples

From the repository root:

```sh
git submodule update --init src/main/resources/cv32e40s-test/core
bash src/main/resources/cv32e40s-test/compile-verilator.sh \
  src/main/resources/cv32e40s-test /tmp/cv32e40s-compiled
mvn package

java -cp 'target/classes:target/lib/*' contractgen.Main synth_new \
  -p CV32E40S_TEST -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
  -n 64 -t 2 -s 1 --output-dir results/cv32e40s-test/off \
  --cv32e40s-test-lib /tmp/cv32e40s-compiled/libcontract_cv32e40s_test_attacker.so \
  --cv32e40s-data-independent-timing=off --disable-adaptive-skipping

java -cp 'target/classes:target/lib/*' contractgen.Main replay_synthesize_spike \
  -p CV32E40S_TEST -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE -t 2 \
  -e results/cv32e40s-test/off/testcases.json \
  -o results/cv32e40s-test/on.json --txt results/cv32e40s-test/on-summary.txt \
  --cv32e40s-test-lib /tmp/cv32e40s-compiled/libcontract_cv32e40s_test_attacker.so \
  --cv32e40s-data-independent-timing=on --disable-adaptive-skipping
```

The adapted Spike shared library must be available through the existing default
path, `--spike-lib`, or `CONTRACT_SPIKE_LIB`. Replay the exact exported testcase
file for mode comparisons; separate generation runs can differ in ordering even
with the same seed.

The build needs Verilator, C++17, and Make; integration validation used Verilator
5.034. `CONTRACT_BUILD_JOBS` defaults to 4. Core/common-resource overrides are
`CONTRACT_CV32E40S_CORE_ROOT` and `CONTRACT_ATTACKER_COMMON_ROOT`. The narrow
`verif/upstream.vlt` waiver handles mixed assignment styles in disjoint slices of
the upstream packed performance-counter array. Core RTL is unmodified, and the
build excludes the full RVFI/verification wrappers. No Docker build configuration
was changed; the existing resource mounts expose the new harness.

## Validation results and limits

### Build timeout diagnostics

The shared Java script runner drains compiler stdout/stderr concurrently with
execution. Waiting for exit before reading output can fill the pipe and block a
verbose Verilator build, eventually producing a misleading timeout. Timeouts now
retain captured output and terminate descendant compiler processes as well as
the build shell. Regression tests exercise output larger than a pipe buffer,
timeout diagnostics, and nonzero exit handling.

`SimpleTestMARCH` defaults to a 240-second build timeout. For a genuinely slower
build, set `CONTRACT_BUILD_TIMEOUT_SECONDS` to a positive number of seconds in
the container environment. For example, from `src/main/resources`:

```sh
docker compose run --rm -e CONTRACT_BUILD_TIMEOUT_SECONDS=900 yosys
```

Java is rebuilt by the existing entrypoint; this code fix requires no Docker
image rebuild. The environment override changes the build deadline only.

### Initial integration checks

Initial integration validation passed 36 Java tests, including native batch,
thread isolation, mode selection, image bounds, and missing-library checks.
Native smoke tests checked arithmetic results, memory values and byte lanes,
history eviction, JAL/JALR addresses, retirement boundaries, illegal instructions,
unsupported alignment, timeouts, and injected parity faults. Directed division,
remainder, and branch pairs distinguished with timing off and did not distinguish
with timing on.

A 512-case synthesis run with seed 1 and
`BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE` executed every RTL case, classified 15
as distinguishable, and synthesized a six-atom contract with zero false positives.
On one exact 64-case exported set, timing off produced one distinguishable pair
and `BEQ: BRANCH_TAKEN`; replay with timing on produced no distinguishable pairs
and an empty contract. All 64 complete Spike evidence sets were unchanged.
These are smoke-test results, not exhaustive core contracts.

Direct/replay comparisons matched labels and evidence. ILP may choose different
equally scoring atoms, so validation also compared contract size, false positives,
and coverage instead of requiring identical atom choices in every run.
Build and result artifacts were kept under `/tmp` because the existing repository
`target/` and `results/` directories were not writable; Java tests used a temporary
Maven configuration with isolated build output.

Full ISA compliance, compressed-instruction generation, randomized protections,
misaligned-memory experiments, external contention, and additional contract
atoms remain outside this integration. See the
[harness README](../src/main/resources/cv32e40s-test/README.md#focused-validation)
for native and Java smoke-test commands.
