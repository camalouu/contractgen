# Z3 ambiguity-guided contract refinement

## Purpose

`refine_z3` improves an existing synthesis result without changing its contract
template. It treats the current result JSON as training evidence, searches for
other contracts that are equally good under the existing ILP objective, and
generates new paired testcases intended to distinguish those alternatives.

The normal synthesis objective remains authoritative:

1. minimize attacker-indistinguishable testcases covered by the contract
   (false positives);
2. subject to that value, minimize contract size.

Consequently, refinement does not assume that an atom is bad merely because it
co-occurs with another atom. It first proves that replacing or removing a
selected atom can produce an **equal-objective** contract. Co-occurrence is only
used to rank such proven ambiguities.

The command is deliberately evidence-driven. Z3 proposes a program pair, but
the candidate is sent to RTL only after the adapted Spike extractor confirms
that its actual atom signature gives different coverage under the baseline and
the specific alternative contract.

## Command

```bash
mvn -q exec:java -Dexec.mainClass=contractgen.Main \
  -Dexec.args='refine_z3 \
    --results 10000-IBEX-full-adaptive-result.json \
    --output 10000-IBEX-full-refined-result.json \
    --threads 4'
```

Important options:

| Option | Default | Meaning |
| --- | --- | --- |
| `-r`, `--results` | required | Existing result JSON, including atoms, test results, and contract. |
| `-o`, `--output` | required | Updated result JSON. |
| `-t`, `--threads` | `1` | Worker count for Spike extraction. |
| `--artifacts` | `<output-base>-refinement` | Directory for all refinement artifacts. |
| `--max-tests` | `50` | Maximum number of Spike-accepted tests executed on RTL. |
| `--models-per-query` | `1` | Maximum Z3 seed models per ambiguity-direction query. |
| `--mutations-per-model` | `8` | Maximum Java variants per Z3 seed, including the identity witness. |
| `--solver-timeout-ms` | `30000` | Timeout of one Z3 solver check. |
| `--max-cycles` | `10000` | Ibex attacker-harness cycle limit per testcase. |
| `--python` | `python3` | Python interpreter with `z3-solver` installed. |
| `--generator-dir` | `abstraction-guided-test-case-generation` | Vendored Z3 project directory. |
| `--spike-lib` | resolved automatically | Adapted Spike atom shared library. |
| `--ibex-test-lib` | resolved automatically | Ibex attacker-only shared library. |
| `--spike-isa` | `RV32IM_Zicclsm` | ISA string passed to Spike. |

`--max-tests 0` is useful as a dry run. It performs result loading, alternative
analysis, query construction, and artifact generation, but skips Z3, Spike, and
RTL execution.

## End-to-end flow

```text
results JSON
    |
    v
equal-optimal ILP alternatives
    |
    v
Z3 batch queries (one atom / direction at a time)
    |
    v
paired RV32IM testcase candidates
    |
    v
Spike atom extraction + baseline XOR alternative coverage check
    |
    v
Ibex attacker-only batch harness labels every accepted testcase
    |
    v
append RTL evidence -> normal ILP update -> updated results JSON
```

### 1. Equal-optimal alternative analysis

`ContractAmbiguityAnalyzer` first solves the ordinary two-stage ILP. It then
forbids each atom selected by that solution and resolves the ILP. A candidate is
an ambiguity only if it is optimal and has exactly the same false-positive count
and contract size as the baseline.

For each retained alternative, the analyzer records:

- the atoms removed from the baseline;
- the atoms added by the alternative;
- the amount of observed co-occurrence; and
- distinguishable results that were exclusively supported by removed atoms.

The solver support is implemented in `ILPUpdater.solve(...)`, which accepts
required and forbidden atom sets and returns explicit solver status and both
objective values. The legacy `update(...)` path still uses the same normal ILP
objective.

### 2. Z3 witness generation

The Java command writes a versioned JSON request and invokes:

```text
abstraction-guided-test-case-generation/refinement_bridge.py
```

The bridge returns standard program words and initial-register maps. Java turns
them into the repository's ordinary `RISCVTestCase` JSON format, so existing
Spike and harness code can consume them directly.

The focused refinement model now uses exactly one symbolic target instruction
at trace step 0. Both sides are constrained to the same RISC-V instruction type.
Z3 also solves a signed 12-bit architectural pre-state for x1 through x31 and
uses full RV32IM target semantics when an atom needs post-state data.

The focused model was chosen after a generic two-program, six-step symbolic
model timed out on practical queries. The supported nonstructural,
nondependency atoms—such as register indices, operand values, immediate, memory
address, alignment, and branch status—can be constrained from a target
instruction and pre-state. Full target transition semantics are enabled for
`REG_RD`, `REG_RD_ZERO`, `REG_RD_LOG2`, `MEM_R_DATA`, and `NEW_PC`.

Structural atoms (`FORMAT`, `OPCODE`, `FUNCT3`, `FUNCT7`, and `IS_BRANCH`) are
not queried. They require an instruction-type divergence and are public or
redundant under the same-type testcase policy. Dependency atoms are also skipped
by the current one-instruction solver path; supporting them correctly requires a
purpose-built producer/gap/consumer template rather than dummy prefix NOPs.

### 2a. Java materialization and mutation

Z3 pre-state differences are no longer passed to the harness as different,
hidden register initialization blocks. Java materializes each seed as follows:

1. Every equal, nonzero Z3 register value is placed in one common initialization
   map, used byte-for-byte by both programs. Equal zero values are omitted and
   therefore retain the ordinary NOP/reset-zero initialization.
2. Every differing register value becomes a paired visible
   `ADDI register, x0, value` instruction. The two ADDIs have the same type and
   register operands; only the required value may differ.
3. The one Z3 target instruction is appended.
4. Five NOPs are appended, matching the ordinary generator's default suffix.

The testcase retirement bound includes the harness padding instruction, so all
five suffix NOPs are actually retired by both Spike and RTL.

Thus both RTL and Spike execute and observe every instruction responsible for a
different target pre-state. There is no hidden input divergence.

One Z3 seed is then amplified cheaply on the Java side. The current simple,
semantics-preserving transformations are:

- bijective renaming of all nonzero registers, preserving x0, aliases, and
  dependencies; and
- swapping the complete left and right programs.

These transformations preserve immediates and concrete values for now. More
aggressive value and immediate mutation can be added later with atom-specific
semantic guards.

For `DIV`, `DIVU`, `REM`, and `REMU`, symbolic division was too expensive even
in the focused model. The bridge therefore uses a small concrete operand basis:

- `0 / {1, 2}` separates `REG_RS2` while keeping the result equal;
- `{1, 2} / 1` separates `REG_RD` while keeping `REG_RS2` equal.

This is a solver constraint, not copied evidence: Spike validates the resulting
programs before RTL.

### 3. Spike validation

For each candidate, Java builds a provisional result from the atoms emitted by
the adapted Spike shared library. Validation rejects a candidate unless all of
the following hold:

- every corresponding instruction has the same type (enforced during Java
  materialization);
- no structural atom is reported;
- the requested target atom is present;
- every mutated clone has exactly the same complete Spike atom signature as its
  unmutated seed; and
- the signature satisfies:

```text
Contract.covers(baseline, result) XOR Contract.covers(alternative, result)
```

The exact-signature check makes Java mutation conservative: a register rename or
pair swap that changes the abstract experiment is discarded. The XOR check is
stronger than checking that a requested atom merely appears in the signature.

No adaptive signature skipping or copied attacker labels are used during
refinement. Every candidate that passes this Spike gate and fits `--max-tests`
is run on RTL.

### 4. Ibex attacker-only labels and update

Accepted tests are passed as one batch to `IBEXTestAttackerClient.runAll(...)`.
The status mapping is:

| Harness status | Added evidence |
| --- | --- |
| `FAIL` | attacker distinguishable |
| `SUCCESS` | attacker indistinguishable |
| `TIMEOUT`, `ERROR`, other | recorded in the report, not added |

The command appends the real labels and Spike atom sets to the input contract,
sorts results by index, and runs `contract.update(true)`. The output JSON uses
the same serialized contract format as the input.

## Artifacts

The artifact directory contains:

| File | Contents |
| --- | --- |
| `ambiguities.json` | Baseline objective and equal-optimal alternatives. |
| `z3-queries.json` | Versioned bridge request. |
| `z3-response.json` | Bridge response. |
| `z3-bridge.log` | Python bridge stdout/stderr, or a skip marker for dry runs. |
| `generated-testcases.json` | All materialized and Java-mutated candidates in normal testcase format. |
| `generated-candidates.json` | Test index to Z3 query/model and Java mutation provenance. |
| `accepted-testcases.json` | Candidates that passed the Spike XOR gate. |
| `refinement-report.json` | Counts, query outcomes, RTL statuses, before/after contracts, and timing. |
| `summary.txt` | Human-readable concise report. |

## Python model corrections made for refinement

The vendored Z3 model was extended and corrected to make its witnesses useful
for the actual RV32IM/Spike/Ibex path:

- Added `NewPcAtom`.
- Changed `MemAddrAtom` to expose the full 32-bit effective address; the model
  still uses a reduced address only internally for bounded memory indexing.
- Matched adapted Spike alignment semantics:
  - `IS_ALIGNED`: `(address & 3) == 0`
  - `IS_HALF_ALIGNED`: `(address & 3) != 3`
- Corrected dependency and destination-register applicability so stores do not
  write `rd`.
- Corrected `MULH`, `MULHSU`, and `MULHU` to use 64-bit products.
- Implemented RISC-V divide/remainder zero-divisor and signed-overflow cases,
  and corrected unsigned remainder to `URem`.
- Corrected control observations for JAL/JALR, including `IS_BRANCH`,
  `BRANCH_TAKEN`, and `NEW_PC`.
- Removed an accidental signed-nonnegative constraint on all modeled register
  states, which was incompatible with full RV32 execution.

## Dependencies

The bridge requires Python 3.12+ and `z3-solver==4.16.0.0`. It does not install
dependencies at runtime. The project Dockerfile now creates a dedicated Python
virtual environment and installs that pinned solver.

For host execution, install the vendored project's environment, for example:

```bash
cd abstraction-guided-test-case-generation
uv sync
```

Then pass the environment interpreter with `--python` if necessary.

The Java side needs the adapted Spike library and an Ibex attacker-only library.
The resolver checks explicit CLI paths first, then `CONTRACT_SPIKE_LIB` /
`CONTRACT_IBEX_TEST_LIB`, then the normal project paths. If the default Ibex
library is absent, it invokes the existing `IBEXTest.compile()` path.

## Validation performed

The current implementation was validated as follows:

- Direct Java compilation of all main and test sources succeeded.
- `mvn test` passed from a clean temporary build copy. A temporary copy was
  necessary because the workspace `target/` directory is owned by another
  container user.
- The Python model and bridge passed `py_compile`.
- A protocol-2 bridge run on the real 10k ambiguity produced four one-word
  same-type `DIVU` seeds (ascending and descending `REG_RS2`/`REG_RD`) in about
  100 ms. Each seed changed exactly one signed-12-bit pre-state register.
- The native adapted-Spike smoke test ran six materialized variants. It confirmed
  that visible setup is reported as `ADDI: IMM` and `ADDI: REG_RD`, the target is
  reported as `DIVU: REG_RS2`, and all register-renamed/pair-swapped variants
  preserve that complete signature.
- A dry run on `10000-IBEX-full-adaptive-result.json` found one equal-optimal
  alternative: `DIVU: REG_RS2` replaced by `DIVU: REG_RD`, with the same
  false-positive objective and size.
- The dry run emitted four one-instruction protocol-2 queries and successfully
  serialized an unchanged result.

An end-to-end local Ibex RTL run was not performed because
`/home/yosys/output/ibex-test/compiled/libcontract_ibex_test_attacker.so` was
not available in this workspace. The Java command is wired to use that library
or compile the current Ibex-test harness when run in the configured simulation
environment.
