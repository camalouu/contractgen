# Sodor attacker-only harness

`SODOR_2_TEST` is the new-flow integration for the checked-in two-stage Sodor
core. It is selected with `synth_new -p SODOR_2_TEST`. Spike determines the
contract-atom signature and the RTL pair determines only attacker timing
distinguishability.

## Implementation

The harness reuses the existing `src/main/resources/sodor-2` core and paired
top-level design, but replaces file-based instruction memories with the common
DPI program-image interface. `sodor_test_top.sv` exposes the old pair's
`finished` and timing-equivalence signals to a Verilator shared library. The
library implements `contract_simple_attacker_batch_v1`, the status-only ABI
shared by the new Sodor, DarkRISCV, and FWRISC integrations.

Reset is driven explicitly by the native runner. The completion controller
clears its fetch/retirement counters while reset is asserted; otherwise the
legacy always-requesting instruction interface would consume the instruction
budget before the generated program begins.

The old generated Sodor Verilog was previously accepted after `sv2v`
normalization. `compile-verilator.sh` performs the small equivalent mechanical
normalizations in a generated build copy: ANSI-port redeclarations, unpacked
array initialization/copy, and trailing port commas. The checked-in legacy RTL
is not modified.

## Important assumptions

- This target is the two-stage core (`SODOR_2_TEST`), not Sodor-5.
- The checked-in core is RV32I. The CLI rejects an ISA containing `M`.
- The attacker observes relative execution time through the synchronized clock
  pair, as in the original harness. RVFI signals do not determine the label.
- Instruction and data memory have fixed deterministic latency. Unsupported
  traps and platform effects are outside this minimal configuration.
- Adaptive reuse is safe only at the existing Spike-signature policy level;
  the native result itself is `SUCCESS`, `FAIL`, or `TIMEOUT` and has no Ibex
  failure-cutoff convention.

Use `--sodor-2-test-lib` or `CONTRACT_SODOR_2_TEST_LIB` to select a prebuilt
library. Otherwise it is built at
`/home/yosys/output/sodor-test/compiled/libcontract_sodor_2_test_attacker.so`.
