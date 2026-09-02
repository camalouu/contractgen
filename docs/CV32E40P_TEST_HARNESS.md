# CV32E40P attacker-only harness

`CV32E40P_TEST` connects the `synth_new` and `replay_synthesize_spike` flows to
CV32E40P v1.8.3, pinned as a submodule at commit
`360d272898d81806be3377193870dbf83a3ea79f`. Spike remains the sole source of
contract-atom distinguishability. The RTL pair supplies only attacker timing
distinguishability through the shared `contract_simple_attacker_batch_v1` ABI.

## Configuration

The wrapper instantiates two `cv32e40p_top` cores with `COREV_PULP=0`,
`COREV_CLUSTER=0`, `FPU=0`, and `ZFINX=0`. Interrupt and debug requests are tied
off, boot and trap-vector addresses are zero, and no behavioral tracer or RVFI
logic is compiled. Supported generator ISA sets are `BASE` and `BASE,M`.
Compressed instructions, custom CORE-V instructions, floating point, interrupts,
debug activity, and external memory contention are outside this initial model.

Each core has private deterministic instruction and data memories. OBI requests
are granted combinationally, including back-to-back requests, and their response
is asserted on the following core-clock edge. Instruction words come from the
fixed 2048-word DPI images; addresses beyond them return `addi x0,x0,0`. Each
data memory maintains its own bounded sparse byte history and otherwise uses the
same deterministic address-derived initial value as the other simple harnesses.

The internal `core_i.mhpmevent_minstret` pulse is the upstream retired-instruction
event and is used only by `clk_sync` to align the cores. Completion is based on
the requested number of synchronized retirements, not fetch exhaustion, because
the prefetcher may have outstanding requests. The timing attacker compares the
two gated core clocks on every outer clock transition.

## Build

Initialize the pinned RTL and build the shared object from the repository root:

```sh
git submodule update --init src/main/resources/cv32e40p-test/core
CONTRACT_ATTACKER_COMMON_ROOT="$PWD/src/main/resources/attacker-test-common" \
  src/main/resources/cv32e40p-test/compile-verilator.sh \
  "$PWD/src/main/resources/cv32e40p-test" \
  "$PWD/src/main/resources/cv32e40p-test/compiled"
```

The CLI resolves `--cv32e40p-test-lib` first, then
`CONTRACT_CV32E40P_TEST_LIB`, then
`/home/yosys/output/cv32e40p-test/compiled/libcontract_cv32e40p_test_attacker.so`.

## Examples

```sh
mvn -q exec:java -Dexec.mainClass=contractgen.Main \
  -Dexec.args='synth_new -p CV32E40P_TEST -i BASE,M -c MEM -n 100 -t 2 -s 1 \
  --disable-adaptive-skipping --output-dir results/cv32e40p-smoke \
  --cv32e40p-test-lib src/main/resources/cv32e40p-test/compiled/libcontract_cv32e40p_test_attacker.so'

mvn -q exec:java -Dexec.mainClass=contractgen.Main \
  -Dexec.args='replay_synthesize_spike -p CV32E40P_TEST -i BASE,M -c MEM -t 2 \
  -e results/cv32e40p-smoke/testcases.json -o results/cv32e40p-replay.json \
  --disable-adaptive-skipping \
  --cv32e40p-test-lib src/main/resources/cv32e40p-test/compiled/libcontract_cv32e40p_test_attacker.so'
```

This harness is intentionally a timing-only, deterministic-memory baseline. A
larger experiment should establish recurring false-positive patterns before any
CV32E40P-specific contract atom is introduced.
