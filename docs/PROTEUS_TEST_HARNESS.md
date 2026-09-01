# PROTEUS_TEST harness

`PROTEUS_TEST` follows the same split used by the current `IBEX_TEST` flow:

1. Spike executes both ISA programs and reports contract atoms with one-based
   first-retirement metadata.
2. Two Proteus RTL instances execute the same fixed images under Verilator.
3. Retirement-synchronized local clocks form the timing-attacker observation.
4. Positive RTL results are prefix-minimized and Spike evidence after the
   returned cutoff is discarded.
5. The surviving labeled evidence is passed to the existing contract updater.

## Core configuration

The checked-in `ProteusContractCore.v` is generated from Proteus release 25.08,
commit `0f489fc5cfddabca93ae01880374385fcb649660`. It is a static five-stage RV32IM
core with 32-bit uncached instruction and data buses, no prefetcher, no branch
prediction, and reset vector `0x80`. The generator exports a direct retirement
pulse and the RVFI retirement metadata needed by this harness: valid, order,
instruction, and trap.

Normal compilation uses the checked-in Verilog and does not require Scala or
SBT. See `src/main/resources/proteus-test/README.md` for regeneration details.

## Commands

Direct generation and synthesis:

```sh
mvn -q exec:java -Dexec.mainClass=contractgen.Main \
  -Dexec.args='synth_new -p PROTEUS_TEST -i BASE,M -c BASE -n 100 -t 4 -s 1 \
  --output-dir results/proteus_test-100-seed1 \
  --proteus-test-lib /path/to/libcontract_proteus_test_attacker.so'
```

Replay an exported testcase set:

```sh
mvn -q exec:java -Dexec.mainClass=contractgen.Main \
  -Dexec.args='replay_synthesize_spike -p PROTEUS_TEST -i BASE,M -c BASE -t 4 \
  -e testcases.json -o results/proteus.json \
  --proteus-test-lib /path/to/libcontract_proteus_test_attacker.so'
```

The library can instead be provided through `CONTRACT_PROTEUS_TEST_LIB`.
Direct synthesis currently requires `--reps=1` and rejects
`--reset-sequence`. Proteus always uses Verilator on this path.

## Native result contract

The shared library exports `contract_proteus_test_attacker_batch_v1`. Each case
returns a status plus either a minimized positive failure cutoff or the final
non-NOP execution cutoff. Cutoffs are absolute, one-based retirement numbers
and therefore align with Spike's `first_retire` values. Traps and cycle-budget
exhaustion are errors/timeouts and never become attacker labels.
