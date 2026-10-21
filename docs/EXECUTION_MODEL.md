# Shared architectural reference and compatibility

The Spike atom reference accepts a testcase, an ISA, and a versioned execution
model. It never accepts a processor identity, timing configuration, cache state,
or attacker cutoff. Identical inputs under the same execution model produce the
same raw contract evidence, independently of which RTL attacker will consume it.

The sole active reference executes Spike's own instruction handlers, including
loads and stores. The historical manual evaluator has been removed from the active
native source. The original and versioned C ABI use the same reference. The fixed
`rv32-v1` identifier records provenance; users do not select semantics per core.
The compatibility option `--execution-model rv32-v1` is accepted but hidden from
normal CLI help. `legacy-v1` is rejected.

## Execution specification

The shared reference uses the following environment:

- RV32I or RV32IM, machine mode, 32-bit architectural addresses. ISA spelling is
  case-insensitive. Plain RV32I/RV32IM and their `_Zicclsm` spellings use the same
  byte-addressed environment, with Spike's Zicclsm paths enabled for misaligned
  scalar data accesses. Compressed, atomic, privileged/CSR, floating-point and vector
  instructions are outside this version's supported contract vocabulary.
- Exactly 2048 instruction words beginning at architectural address 0x80.
  The first 31 slots contain the existing ADDI register initialization or NOP for
  an unspecified register; initial registers are zero. Slot 31 is a NOP and the
  program begins at 0x100. Register initializer immediates retain the existing
  12-bit instruction encoding. Programs may contain at most 2016 instructions.
- Fetches outside the image return NOP, including across RV32 address wraparound.
  All architectural PC-relative values and absolute jump targets use the actual
  addresses; no semantic relocation occurs.
- Separate, little-endian instruction and data storage. Untouched data bytes are
  zero, and writes persist until the testcase ends. Data addresses can overlap
  instruction addresses without modifying code. This is an experimental memory
  environment, not a unified-memory platform model.
- Byte, halfword and word accesses, including misaligned data accesses, page splits
  and RV32 address wraparound. Misaligned instruction targets, unsupported executed instructions and architectural traps
  invalidate the case rather than contributing contract evidence.
- Exactly `31 + maxInstructionCount` retirements per side. Each run resets
  registers, memory and instruction-cache state in the reference. The two sides
  can follow different architectural paths.

The reference uses separate lazily allocated instruction/data pages behind
Spike's simulator interface. Fetch obtains the decoded instruction from Spike;
execution calls that instruction's handler at the architectural PC. Data accesses
use Spike's load/store implementation against the persistent data pages.

## Contract observations and attacker boundaries

Structural fields, register values, branches and instruction-pair observations
retain their established definitions. Spike dependency evidence now uses atom
schema `producer-dependencies-v1`, independently of execution model `rv32-v1`.
A dependency atom includes the exact earlier writer and later instruction:
`LW -> MUL: RAW_RS1_1`. It is a boolean which is false outside that instruction
pair, and true when its register relation holds. Evidence records predicates
whose values differ across executions, including changes of producer or consumer
type when both executions have a register link. Selecting a pair predicate does
not expose instruction presence when that predicate is false.

Distances 1–4 count dynamically executed instructions, not cycles. RAW_RS1/RS2
require an architectural source matching the earlier nonzero destination, with
no intervening write to that register. WAW compares the nonzero destinations of
the earlier and later writers at the stated distance; intervening writes do not
remove this pairwise relation. Writes to x0 are excluded. Shift-immediate bits
are not an architectural RS2 source and cannot produce RAW_RS2 atoms. Structural
RS2 retains its historical five-bit-field convention. These relations describe
architectural context; selecting an atom does not identify an internal RTL hazard.

For `rv32-v1`, MEM_ADDR is the RV32 effective address, MEM_W_DATA is the source
register value, and MEM_R_DATA contains the accessed bytes in their RV32 word
lanes `(address + byte_offset) mod 4`, with other lanes zero. Misaligned accesses
crossing a word boundary wrap those observation lanes. This is a defined observation encoding, independent
of a core's physical memory-bus width. A future trace extractor must normalize to
this encoding before claiming atom equivalence.

Spike emits the full bounded evidence with first-retirement metadata. Existing
Java attacker cutoff/filtering policies remain separate and unchanged. Thus
raw Spike evidence is reusable across conforming cores; the final evidence
retained for synthesis can differ where an attacker uses a different execution
boundary policy. Invalid results and timeouts are never negative evidence.

Canonical cases also report `requires_misaligned_data_access`, based on accesses
actually executed by either side through the requested bound. It is metadata,
not a contract atom, and does not depend on a core name. Java checks that this
metadata is present rather than trusting an older library's implicit default.
Target-core capability checks exclude unsupported cases before signature grouping
and RTL execution. Their results remain absent from synthesis, never inferred negatives;
original testcase indices are preserved. Summaries count `Unsupported For Core`,
and `<contract>.unsupported.json` lists excluded ordinals, case indices and reasons.
A wholly unsupported nonempty set produces an explicit error instead of an empty
contract. Unexpected reference failures or RTL errors still fail synthesis.

## Controlled dependency generation

RAW and WAW targets at distances 1–4 select enabled integer ALU producers:
ADD/SUB, bitwise operations, comparisons and shifts (including immediate forms),
plus MUL/MULH/MULHSU/MULHU and DIV/DIVU/REM/REMU when M is enabled. LB/LBU/LH/LHU/LW
producers are included when SW is available to initialize their data. Loads read
the controlled word at data address zero; byte/halfword results use the appropriate
sign or zero extension. Control-flow producers are excluded. Immediates fit signed 12-bit encoding;
shift immediates are 0–31. Operands mix
random RV32 values with zero, one, minus one and signed extrema. Both sides
prefill the dependent and independent destinations with the producer result, preserving
architectural values while changing the destination register. Setup uses LUI/ADDI
for full-width constants, or small operands if LUI is unavailable (left shifts
are then limited so the prefill also fits ADDI). Targeting is
skipped if ADDI is unavailable for setup. These generator changes alter seeded
corpora, so retain saved testcase files for exact reproduction.
Targets whose overlapping consumer operands/destination would toggle additional
RAW/WAW relations are skipped, so the controlled pair isolates the selected link.

Naturally aligned memory consumers and JALR targets are aligned through setup
and immediate selection, without inserting an instruction between the intended
producer and consumer. Saved target metadata retains the selected producer type.

Native contracts include `atomSchema`; text contracts and signature reports print
the producer as well as the consumer. Hashing, ordering, adaptive skipping and
ILP variables use the complete identity. The ILP objectives are unchanged.
Legacy RVFI extraction and its atom universe remain unchanged. The legacy Verilog
monitor exporter rejects producer-specific contracts instead of dropping their
conditions; these contracts are consumed by the Spike-backed JSON/text workflow.

Old contract JSON without `atomSchema` is read as `legacy-v1`. Evaluation and
contract extension reject mixed schemas. Re-run Spike over saved programs to
obtain new evidence; adding a producer label to old signatures is insufficient.
Existing RTL labels may be reused only for the same programs, architectural
environment and attacker harness. Old native libraries are rejected explicitly;
rebuild with `nix build .#spike`. `print_atoms` uses the new vocabulary by default;
`--legacy-dependencies` prints the historical universe.

## Harness migration and historical reproduction

All Spike-backed attacker paths use this reference. Harnesses must provide the
same image, persistent zero-filled byte memory, architectural addresses, and
retirement bound. Hardware timing remains an attacker observation, separate from
reference execution. Capability filtering excludes programs whose executed
accesses a core cannot support. These exclusions are absent from synthesis,
never negative evidence.

All ten native adapters pass 10,779 directed and fixed control-flow program runs.
The broad conformance suite checks every retirement PC and final register value
against Spike, plus fetched instructions where a probe is exposed. The new sole
reference also matches its pre-removal canonical predecessor on 7,135,706 pairs.
The full Nix matrix passes, including direct synthesis, exact replay, eligibility,
independent Rocket timing, and the preserved classic simulation flows. See the
[migration evidence](../results/spike-reference-migration-20261012/RETIREMENT.md).
Classic RVFI/Icarus flows remain separate from the Spike-backed native adapters.

Historical experiments require their archived source and environment. The broad
comparison in `results/spike-reference-migration-20261012/REPORT.md` found 295
atom disagreements among 7,135,706 pairs. Consequently, old contracts must not be
assumed identical under the new reference. The pre-removal native source and Nix
patch are preserved under that report directory's `archive/`; its provenance
records the immutable historical native library. Existing testcase artifacts are
left unchanged. Timing results also require the historical harness revision.

## Native adapter details

The pinned core revisions and simulator tool versions are unchanged. Native
verification adapters use the shared instruction address and persistent byte
memory instead of their historical synthetic memory models. Retirement completion
uses architectural commit signals, including both CVA6 commit ports. Protocol
adapters retain the cores' actual request/response and write-data phases.

Sodor and FWRISC diagnostics collect actual register-file writes separately from
retirement metadata. Rocket's raw RF probe includes a provisional mul/div write;
its diagnostic completion probe observes the core's late-write arbiter instead.
This changes only a probe assignment in the disposable build copy. The imported
38 generated RTL files and their hashes remain unchanged. Ordinary Rocket attacker
runs keep their existing timing behavior and independent timing regression.

DarkRISCV's native build corrects imported RTL defects: `SLTIU` uses a
sign-extended immediate for the unsigned comparison, the two-stage fetch PC
holds its target address during the flush bubble, and `JALR` clears target bit 0.
Without that hold, the imported
fork skips the first instruction after reset and every taken control transfer.
These corrections are asserted against the pinned source layout; the classic
DarkRISCV experiment resources remain unchanged. The reset address is 0x80.
These are RTL correctness fixes, not Spike specializations.

CV32E40P uses its upstream RVFI monitor. The disposable monitor copy contains
compatibility transformations for pinned Verilator 5.008's class code emitter
(explicit captured inputs, package placement, and equivalent field assignments).
The processor RTL is unchanged. The runtime services the monitor's scheduled
sampling events before testing completion.

Locally compiled default attacker libraries are rebuilt from the current harness
sources. Packaged Nix libraries and explicit external libraries keep their
existing selection precedence. External libraries must implement the documented
shared environment; a historical attacker library is not a reproducible pairing
with the new reference. RV32I-only adapters reject imported programs containing
M-extension instructions before simulation, even if the CLI selects `BASE`.

Generation retains its established seed behavior: Ibex generation permits
misalignment, and other presets generate naturally aligned memory tests. Replay
eligibility independently permits imported misaligned accesses on the validated
Ibex, CV32E40P, and CV32E40S configurations.

## Performance expectations

The migration checks establish correctness, not relative throughput: they run
multiple references and include JSON processing, comparison, and concurrent
build activity. They are not an isolated Spike benchmark.

Removing the legacy implementation does not change the existing `rv32-v1`
execution loop, so comparable canonical workloads should have similar runtime.
Relative to the legacy implementation, actual Spike instruction handlers and
MMU accesses can cost more than manual evaluation, especially for misaligned
memory operations. Conversely, the shared reference constructs a processor
without the legacy full simulator environment and allocates memory in pages
only when accessed. The processor is reused within each native batch; memory,
registers, and translations are reset for each program side. These differences
can reduce setup and memory costs, but do not establish a net speedup.

JSON transport and Java worker startup also contribute to end-to-end runtime.
Capability filtering still requires reference execution, but avoids RTL runs
for unsupported cases. Install-time debug stripping reduces build disk usage;
it is not a simulation runtime optimization. A controlled benchmark with identical
inputs, batch sizes, and worker counts is required to quantify performance.
