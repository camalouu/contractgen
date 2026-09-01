# FWRISC attacker-only harness

`FWRISC_TEST` integrates Featherweight RISC-V directly into the new synthesis
flow. Spike supplies the atom signature and a paired Verilator simulation
supplies the attacker timing label.

## Core and configuration

The upstream core is a submodule at `src/main/resources/fwrisc-test/core`,
pinned by the repository gitlink (integration development used commit
`0e21466336c9d611c2b465dcb0de04572b6ebbcf`). The wrapper instantiates the
non-pipelined `fwrisc` top twice with:

```text
ENABLE_COMPRESSED = 0
ENABLE_MUL_DIV    = 1
ENABLE_DEP        = 0
ENABLE_COUNTERS   = 1
```

This gives the generator's RV32I/RV32IM instruction subset without compressed
instructions. Dependency tracking is disabled because the core is
non-pipelined in this configuration.

## Implementation

Each core receives its own DPI-backed instruction image and deterministic data
memory. Program-image index zero is mapped to FWRISC's reset vector at
`0x8000_0000`. `instr_complete` is used as the retirement pulse. The shared clock
synchronizer advances the lagging core until retirement stays aligned, while
the attacker monitor records any observable clock/timing difference. The run
ends after both images are disabled and the requested retirement count is met.
The native library exposes the same `contract_simple_attacker_batch_v1` ABI as
Sodor and DarkRISCV.

## Important assumptions

- Only 32-bit RV32I/RV32M instructions are generated; compressed instructions
  are intentionally disabled.
- Interrupts are tied low, instruction fetch is always ready, and data memory
  has fixed deterministic latency.
- Hierarchical `instr_complete` is an integration signal, not an architectural
  observation. Contract atoms still come exclusively from Spike.
- Attacker distinguishability is relative execution timing only. Architectural
  result comparison, traps, and external bus contention are out of scope for
  this minimal configuration.

Use `--fwrisc-test-lib` or `CONTRACT_FWRISC_TEST_LIB` to override the default
library at
`/home/yosys/output/fwrisc-test/compiled/libcontract_fwrisc_test_attacker.so`.
