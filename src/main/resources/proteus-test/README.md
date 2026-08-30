# Proteus attacker harness

This integration uses Spike to extract contract atoms and a paired Proteus
simulation to determine timing-attacker distinguishability. The normal build
uses the checked-in `generated/ProteusContractCore.v` and therefore needs only
Verilator, a C++ compiler, and Make.

The RTL is generated from the Proteus 25.08 release pinned in `UPSTREAM` with a
minimal static RV32IM configuration: five stages, 32-bit uncached instruction
and data buses, no prefetcher, no branch predictor, and reset vector `0x80`.

To regenerate it, install SBT and run:

```sh
./regenerate-rtl.sh /path/to/proteus
```

The checkout must be at the exact pinned commit. Proteus is distributed under
the MIT license; see `LICENSE.proteus`.
