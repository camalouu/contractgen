# DarkRISCV attacker-only harness

`DARKRISCV_2_TEST` brings the checked-in two-stage DarkRISCV core into the
`synth_new` pipeline. Spike determines atom distinguishability; the paired RTL
simulation determines attacker timing distinguishability.

## Implementation

The integration wraps the existing `src/main/resources/darkriscv-2` paired
design and feeds both cores through the common DPI program-image interface.
`darkriscv_test_top.sv` exports the legacy pair's completion and timing
equivalence signals. Its Verilator library uses the common
`contract_simple_attacker_batch_v1` status-only ABI.

The native runner explicitly resets both cores, and the completion controller
holds its counters at zero during reset. This prevents the legacy instruction
request interface from consuming the generated program's fetch budget early.

The legacy RTL contains a few constructs that depended on its older conversion
flow. The compile script normalizes only generated copies: trailing port
commas, duplicate declarations, and unpacked register-file array assignments.
The old core and old synthesis command remain unchanged.

## Important assumptions

- This is deliberately the two-stage target (`DARKRISCV_2_TEST`), matching the
  simplest existing integration; DarkRISCV-3 remains legacy-only.
- The checked-in configuration is RV32I, so the CLI rejects `M`.
- The attacker label is the synchronized relative-timing observation, not RVFI
  state or an RTL-derived contract atom.
- Instruction and data memory use deterministic, fixed-latency models.
- The harness reports `SUCCESS`, `FAIL`, or `TIMEOUT`; it does not use the Ibex
  failure-cutoff behavior.

Use `--darkriscv-2-test-lib` or `CONTRACT_DARKRISCV_2_TEST_LIB` to override the
default library at
`/home/yosys/output/darkriscv-test/compiled/libcontract_darkriscv_2_test_attacker.so`.
