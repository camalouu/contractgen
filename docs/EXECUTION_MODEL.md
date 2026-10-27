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
retain their established definitions. Spike dependency evidence uses atom schema
`producer-attributed-dependencies-v1`, independently of execution model `rv32-v1`.
A dependency atom names the earlier writer: `LW: RAW_RS1_1` is true when an LW
writes a nonzero destination read through the later instruction's RS1 at distance
1. The later instruction's opcode is not part of the predicate. RAW_RS2 refers
to the later instruction's architectural RS2, and WAW to its destination.

Spike compares these boolean predicates at each later instruction's retirement,
before collecting evidence. For example, LW → MUL and LW → ADD with the same
RAW_RS1_1 link do not distinguish that dependency atom. LW → MUL versus
ADD → MUL distinguishes both LW.RAW_RS1_1 and ADD.RAW_RS1_1. Selecting a
dependency predicate does not expose instruction presence when it is false.
Its first-retirement metadata identifies the later instruction, when the relation
can be observed, rather than the earlier producer.

Distances 1–4 count dynamically executed instructions, not cycles. RAW_RS1/RS2
require an architectural source matching the earlier nonzero destination, with
no intervening write to that register. WAW compares the nonzero destinations of
the earlier and later writers at the stated distance; intervening writes do not
remove this pairwise relation. Writes to x0 are excluded. Shift-immediate bits
are not an architectural RS2 source and cannot produce RAW_RS2 atoms. Structural
RS2 retains its historical five-bit-field convention. These relations describe
architectural context; selecting an atom does not identify an internal RTL hazard.

The `BASE` template also includes four boolean observations extracted by Spike:

- `RD_IS_ZERO`, `RS1_IS_ZERO`, and `RS2_IS_ZERO` test whether the encoded
  architectural register is **x0**, independently of the register's value.
  `RS2_IS_ZERO` excludes shift-immediate instructions: their shamt bits are not
  a register source. The existing `REG_*_ZERO` observations still test values.
- `IMM_IS_NEGATIVE` tests the sign of the decoded immediate: bit 11 for I/S,
  bit 12 for branches, bit 20 for JAL, and bit 31 of the shifted U-type value.
  Zero is nonnegative; shift amounts have no signed-immediate observation.
  This works for both signed Java inputs and unsigned stored bit patterns.

Each predicate is applicable only to instructions that have the corresponding
field. Spike records differences with first-retirement metadata, using the same
instruction-type comparison rules as existing structural observations. A load
to x0 and a load of zero into x5 differ in `RD_IS_ZERO`, while their
`REG_RD_ZERO` values are both true.

Targeted generation compares x0 with a nonzero destination, compares x0 sources
with an ordinary register prefilled with zero, and flips only the immediate's
sign bit for signed-immediate tests. These targets use the existing generation
loops; fixed testcase budgets are redistributed across the expanded template.

New native responses advertise `structural_predicates_version: 1`. Java rejects
an older Spike library when these predicates are requested. Rebuild Spike and
re-extract saved programs to add this evidence to old results; existing RTL
labels can be retained. The legacy RVFI extractor is unchanged, and exporting a
selected new predicate to its Verilog contract monitor is explicitly unsupported.

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

## Paired alignment preparation

For non-dependency targets requiring aligned data accesses, the generator clears
the memory immediate's low two bits and inserts identical ANDI preparation for
the union of both sides' nonzero base registers. JALR uses the controlled
address preparation described below. This avoids one-sided helpers and
immediate-dependent ORI/ANDI sequences. The x0-versus-zero-register
targets already initialize equal zero bases and aligned immediates, so they need
no additional alignment instructions. Shared random prefixes remain shared.

This changes generated programs for existing seeds. Historical testcase files
retain their original programs and labels; regenerate and rerun RTL to evaluate
the corrected generator.

## Observation targeting

Ordinary targets are filtered through `RISCVObservation.isApplicable()` before
setup is generated. Register-number and immediate alternatives must remain
distinct after encoding/alignment. Operand-value targets use nonzero scratch
registers, full-width LUI/ADDI constants when available, and four NOPs between
setup and the target. Both sides use the same setup instruction types. Scratch
registers exclude the target's existing source and destination registers.

Architectural `RS1`/`RS2` targets prepare two nonzero registers with the same
value using identical setup on both sides, then change only which register the
target reads. Neither candidate aliases another target operand or its destination.
Memory alignment is prepared before the four-NOP gap so it does not introduce
different recent dependencies. Dedicated `RS*_IS_ZERO` targets cover x0 versus a
register containing zero. Value targets keep source register numbers fixed.
Structural `RS2` on shift-immediate instructions still varies the encoded shamt
field; it is not an architectural register read and has no equal-value guarantee.
This policy applies across cores and does not use measured leakage or a core's
pipeline behavior to choose cases. It changes generated programs for existing seeds.

Memory templates prepare the target's actual base and accessed locations:

- `MEM_ADDR` changes the target offset from zero to four; loads initialize equal
  data at both locations with identical stores on both sides.
- `MEM_W_DATA` changes the target store's value through the same source register.
- `MEM_R_DATA` initializes different data at the exact location subsequently read.
  Its helper stores use the same base, source register and offset on both sides.
- Alignment targets compare word-aligned addresses against offset two
  (`IS_ALIGNED`) or offset three (`IS_HALF_ALIGNED`), matching Spike's existing
  predicates. They are generated only when the actual access width is naturally
  aligned or misaligned accesses are permitted. Generic alignment preparation
  must not erase these intentional address differences.

Value-zero and log2 observations now have dedicated operand/result targets.
Result templates keep the destination fixed and choose operands with known
zero/nonzero results; load results use controlled memory initialization. JAL/JALR
link values cannot differ at the same instruction slot, so result-value targets
are omitted for them. AUIPC cannot produce zero at these target PCs, so its
result-zero target is omitted. `NEW_PC` targets use a branch outcome difference
or distinct controlled jump destinations. FORMAT/OPCODE/FUNCT and IS_BRANCH
still have no direct template: varying those requires comparing instruction types.

The native targeting regression runs with `CONTRACT_SPIKE_LIB` set. It checks
that every generated target appears in Spike evidence across deterministic seeds,
prefixes, suffixes, repetitions and misalignment modes, and checks retirement
locations for memory targets. This establishes architectural coverage, not
isolation of timing to one instruction: preparation and shared context remain
part of the executed test. These changes redistribute fixed testcase budgets;
retain saved programs when comparing historical runs.

## Controlled branch and jump layouts

The default generator places exactly one target branch/JAL/JALR in each
control-flow testcase. Setup stays below `0x400`; taken destinations are aligned
NOP-only addresses from `0x400` through `0xffffff80`. The upper margin prevents
RV32 wraparound from reaching initialization within the observation window.
Fall-through executes a 16-slot NOP tail. The existing `31 + maxInstructionCount`
bound retires the target once and 15 subsequent NOPs on each side. Random suffix
settings do not change this window. No control-flow target can re-enter setup,
initializers, another target, or a loop. NOP landing space uses the existing
instruction-image/default-NOP behavior; architectural addresses are not relocated.

Registers, values and aligned targets remain randomized. Relative branch/JAL
immediates retain their sign; sign-targeted pairs differ only in the sign bit.
JALR source values and immediates are chosen together to land in the safe space;
index/zero-register tests use equal zero operands, while value tests vary the
prepared source value. Preparation has matching instruction types and length
on both sides. JALR source/destination overlap remains testable because the
updated link value is never consumed after the jump. Dedicated branch-outcome
fixtures prepare taken versus not-taken operands for all six branch types.

RAW/WAW control-flow consumers retain their producer and distances 1–4; JALR
address preparation happens before the producer. `--reps` generates separate
control-flow testcase trials, rather than concatenating transfers that could
skip each other. Compaction likewise keeps control-flow trials separate. The
requested overall CLI testcase count is unchanged. Random prefixes now exclude
control flow for all targets so they cannot bypass or revisit the target.

This isolates architectural continuations, not prediction/fetch microarchitecture:
redirect and instruction-fetch timing remain part of the attacker observation.
Historical saved programs are unchanged; regenerate corpora to use these layouts.

## State-isolated random suffixes

For non-control targets, `--random-suffix` appends the same 5–24 instruction slots
to both programs.
Suffix operands and destinations exclude registers written anywhere in either
preceding program, including prefix/setup and earlier repetitions. ALU/M
instructions remain available. Loads and stores use a single aligned scratch
word at `0x10000000`, initialized by a shared SW before any suffix load. Its LUI
base register is reserved from later writes. An earlier non-x0-based store might
alias that word, so memory operations are omitted for those cases. x0-based
stores have signed 12-bit offsets and cannot alias the scratch word.

Conditional branches and JAL jump only forward to suffix slots. JALR uses a
reserved AUIPC base established at suffix entry and likewise targets only later
suffix slots. No jump can skip the setup, enter the target, or create a loop.
The final suffix slot is NOP. If earlier code contains control flow or the two
layouts differ, entry into the shared setup cannot be guaranteed, so the suffix
remains NOP-only. Insufficient free registers also restrict the available kinds
of instructions. Without the option, the existing five-NOP suffix is unchanged.

These guarantees prevent new architectural differences; they do not promise
identical timing after a target has changed microarchitectural state. Suffix
changes alter seeded corpora, so save generated testcase files for reproduction.

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
only the producer and relation for dependency atoms. There is no producer ×
consumer cross product in the native atom universe. Java's `producerDependency`
marker distinguishes these predicates from historical consumer-attributed atoms;
ordinary observations retain their original instruction scope. Hashing, ordering,
adaptive skipping and ILP variables use this identity. The ILP objectives are unchanged.
Legacy RVFI extraction and its atom universe remain unchanged. The legacy Verilog
monitor exporter rejects producer-attributed contracts instead of dropping their
conditions; these contracts are consumed by the Spike-backed JSON/text workflow.

Old contract JSON without `atomSchema` is read as `legacy-v1`. Evaluation and
contract extension reject mixed schemas, including the earlier pair-based
`producer-dependencies-v1`. Re-run Spike over saved programs to obtain new
evidence; renaming or merging previously extracted pair atoms is insufficient,
because predicates must be compared after dropping the consumer qualification.
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
