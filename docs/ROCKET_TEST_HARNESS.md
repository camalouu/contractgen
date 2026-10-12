# Cached RV32 Rocket attacker harness

`ROCKET_TEST` connects `synth_new` and `replay_synthesize_spike` to a cached
Rocket tile. The processor-independent `rv32-v1` Spike reference supplies contract
atoms; paired Verilator simulations supply attacker timing labels. Complete
bounded evidence is retained without Ibex-specific execution-cutoff filtering.

Read [the shared execution specification](EXECUTION_MODEL.md) for architectural
semantics, compatibility, provenance, and the requirements for adding another core.
There is no processor-specific Spike profile or separate Rocket Spike patch.

## Configuration and provenance

Rocket Chip is pinned to `55bcad0f59436de98ea510334121de8546b9e9d7`.
The wrapper is `src/main/resources/rocket-test/generator/ContractRocket.scala`.
It instantiates one RocketTile; the paired runtime instantiates it twice with
independent backing stores and clocks.

- RV32IM, machine mode; no VM, compressed instructions, atomics, FPU, vector,
  debug, CEASE, or simulation-timeout CSR hook.
- I/D L1 caches: 64 sets, four ways, 64-byte lines, 64-bit rows, random replacement.
  D-cache is blocking (`nMSHRs=0`); no scratchpads, ECC, or cache clock gating.
- BTB and BHT enabled with pinned defaults. Multiply unroll 8, divide unroll 1,
  multiply/divide early-out enabled.
- Complete parameters and negotiated client source IDs are in
  `generator/parameters.lock`; recursive revisions are in `generator/submodules.lock`.
  `generated.sha256` checks the generated RTL; licenses are in `licenses/`.

The RTL is imported unchanged from the Rocket branch. Its elaboration used
Mill 0.11.12, Scala 2.13.12, Chisel 6.7.0, firtool 1.62.0 and Java 21.
Routine Nix builds use the checked-in RTL and the existing Verilator 5.008 pin.
Scala tooling and network-dependent elaboration are not needed for those builds.

## Execution and attacker model

The image starts at 0x80, with testcase instructions at 0x100. Instruction fetches
outside the fixed 2048-word image return NOP. Sparse data memory is private,
zero-initialized and persistent. Stores cannot modify instructions. Naturally
aligned byte/halfword/word accesses are supported. The shared Spike reference also
executes misaligned data accesses; Rocket's capability check excludes testcases
which execute them, records the reason in `<contract>.unsupported.json`, and never
turns exclusions into negative evidence. A direct native call that bypasses the
check still returns invalid on an exception. Unreachable misaligned instructions
do not exclude a testcase.

The TileLink endpoint distinguishes instruction requests by negotiated client
identity, not address. It handles refills, acquisitions, permission upgrades,
dirty releases, grant acknowledgments, masked writes and backpressure. It accepts
one transaction at a time, giving pending releases priority. Its timing is part
of this experimental platform; there is no inter-tile contention or coherence.

The scheduler follows the established half-edge clock-hold rule: the faster tile
pauses at retirement until the other catches up. Its caches, interconnect and
memory endpoint pause together. Any clock divergence is sticky. Completion
requires exactly `31 + maxInstructionCount` paired retirements. A later exception
invalidates an execution even if timing diverged earlier.

Each testcase creates fresh models and backing memory. Reset lasts ten cycles;
uninitialized simulator storage starts at deterministic zero. Diagnostic register
writes include delayed multiply/divide writes and are not attacker observations.
Native statuses remain 0=indistinguishable, 1=distinguishable, 2=timeout, 3=invalid.

This models a cached tile with the project's explicit separate-memory environment.
It does not certify full ISA compliance, multicore behavior or a unified-memory SoC.

## Build and run

```sh
nix build .#attacker-rocket .#spike
nix run . -- synth_new \
  -p ROCKET_TEST -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
  -n 64 -t 2 -s 1 --output-dir results/rocket-test/64 \
  --disable-adaptive-skipping

nix run . -- replay_synthesize_spike \
  -p ROCKET_TEST -i BASE,M -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
  -t 2 \
  -e results/rocket-test/64/testcases.json \
  -o results/rocket-test/64/replayed.json \
  --txt results/rocket-test/64/replayed-summary.txt --disable-adaptive-skipping
```

All Spike-backed workflows use the same shared architectural reference by default.
No execution-model flag is required. Historical experiments require their archived environment.
The packaged launcher supplies both libraries. Library selection is
`--rocket-test-lib`, then `CONTRACT_ROCKET_TEST_LIB`, then compilation beneath
`CONTRACTGEN_WORK_ROOT` (default `results/.work`). External libraries must implement
the documented configuration. Use `-i BASE` for integer-only generation.

Keep the testcase and contract `.execution.json` sidecars with their artifacts.
Replay the exact testcase export; a seed alone does not guarantee identical
ordering. Compare per-case labels and evidence, allowing tied ILP solutions to
choose different atoms.

## Validation and regeneration

```sh
nix build .#checks.x86_64-linux.rocket-conformance
nix build .#checks.x86_64-linux.rocket-workflow
nix flake check
```

The conformance check tests the TileLink endpoint, native architecture/timing/
isolation behavior, and every retirement PC plus final registers for 1,123 programs
against the shared Spike reference. The Rocket package additionally compares the
paired scheduler with independently clocked tiles on 209 pairs. The workflow check runs 64 cases and
exact replay with adaptive skipping disabled. Shared-reference tests separately
cover memory lanes, persistence, isolation, alignment, ISA restrictions and wraparound.

For optional regeneration, install the pinned Mill/firtool tools and run:

```sh
MILL=/path/to/mill FIRTOOL=/path/to/firtool \
  bash src/main/resources/rocket-test/regenerate.sh
```

This network-dependent script clones pinned source/submodules into `/tmp` and
publishes generated RTL and hashes after successful elaboration. It is not yet a
Nix-packaged regeneration pipeline. Review output and manifests together.

The [September audit](ROCKET_INTEGRATION_AUDIT.md) and
[branch-observation investigation](ROCKET_BRANCH_OBSERVATIONS.md) are historical
records of the original branch and its former Spike profile. They are useful
context, not validation records for the new shared-reference implementation.
