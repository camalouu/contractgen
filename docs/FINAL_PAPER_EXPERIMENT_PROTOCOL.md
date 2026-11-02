# Recommended final paper experiment protocol

Status: proposed frozen protocol, based on the seminar report, the presentation
`/home/viktor/thesis/presentations/experiment-results.typ`, the completed
September/October campaign reports, and the current implementation. No new
large experiment has been started by writing this document.

## Main workload decision

Use `current` for the main training and in-distribution holdout corpora on every
core. Freeze these settings:

| Setting | Value |
| --- | --- |
| Strategy | `current` |
| Same-program mode | off (`--sp` absent) |
| Repetitions | 1 |
| Random prefix / suffix | both off |
| Bit distribution / reset sequence | both off |
| Template | `BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE` |
| ISA | `BASE,M` where supported; `BASE` for Sodor 2/5 and DarkRISCV 2/3 |
| Alignment | preserve and record the current generator's per-core policy |
| Generation partitioning | fixed one-iterator generation, independent of RTL worker count |

This is a fixed synthetic targeted-test workload, not a claim that `current`
is the best possible generator or covers all real programs. This configuration
matches the generation settings recorded in the completed 100k practical
campaign and the October scheduling protocol. The generators have since evolved;
regenerate and label the final corpora under one frozen revision rather than
pooling old labels and new runs.

The recent Ibex comparison is a reason to include a robustness check if time
permits, not to choose whichever generator produces the smallest contract:
all 15 current-generator atoms were retained by the imported contract, but its
three additions covered nine new positive cases while introducing 197 false
positives on the old corpus. Seed, count, suffix behavior, and register values
also differed in that comparison.

Do not use `coverage_guided` in the main skipping experiment: generation would
introduce another adaptive mechanism. `same_programs` changes the workload to
fixed instruction bodies. `random` changes the targeting distribution. `replay`
is the execution mechanism for the frozen corpora, not a different corpus family.

## Corpus preparation

Per core/configuration:

1. Generate and save an independent 1,000,000-case holdout corpus.
2. Generate and save a separate 100,000-case training corpus.
3. Hash the saved files and record all generator settings. Audit exact pair
   identity overlap using program/register/setup-policy content, excluding
   testcase indices and intended targets. Different seeds alone do not prove
   independence. Preserve within-training repetitions and their ordering.
4. Obtain holdout atom evidence and RTL labels exhaustively. Use `--skipILP`:
   the holdout supplies evaluation evidence, not a contract to train against.
   Process/store/score large artifacts with bounded-memory readers or chunks.
5. Freeze supported, valid cases and their denominators before policy comparisons.
   Report attempted, accepted, unsupported, timeout, error and missing-result
   counts separately. Never turn a failed execution into negative evidence.
   If replacing invalid cases to reach the requested accepted count, use a
   predetermined generation continuation and retain an exclusion ledger.

Suggested fresh seeds, fixed before inspecting their labels: training 2026102801,
2026102802, 2026102803; holdout 2026102899. These are proposals, not already
prepared datasets. Audit actual content overlap even with these seeds.

Minimum initial pass: one training corpus and one independent holdout per core.
Next priority: the other two training seeds against the same frozen holdout.
Repeated timings on one corpus measure runtime variation, not dataset replication.

The same ISA/alignment-compatible raw corpus may be shared by several cores, but
RTL labels and validity decisions remain core-specific. Identical byte-for-byte
inputs across incompatible cores are not required. Identical inputs across
policies for a given core are required.

Do not select thresholds, templates, seeds, corpus families or contracts based
on final holdout results. Use old pilot data or a separate development set for
such choices. Predefine any fallback policy rather than adding it only after
seeing an unfavorable test result.

## Matched execution arms

Replay the same saved 100k training corpus for every arm; never regenerate it
between arms or reuse exhaustive RTL labels inside an adaptive timed run.

| Arm | RTL execution / evidence source | Purpose |
| --- | --- | --- |
| A: legacy exhaustive | comparable legacy execution and extraction; all cases | practical baseline, where available |
| B: native exhaustive | Spike + native attacker; all cases; `--disable-adaptive-skipping` | common reference |
| C: native adaptive N8 | same pipeline and corpus, exact-signature skipping, negative threshold 8 | skipping contribution |

Freeze `grouped` scheduling in B and C, the same RTL worker count, template,
execution model, native library builds and ILP objective. In C leave
`--disable-adaptive-skipping` absent, set `--negative-signature-threshold 8`,
and leave subset/superset inference and `--use-skipped-evidence` off. A positive
result ends that signature; eight observed negatives end a negative signature;
shorter groups can exhaust normally. This is a heuristic, not a safety proof.

N8 is a fixed main policy, not a guarantee of equal quality on every core.
Optional prespecified sensitivity arm: N32, with all its results reported.
Do not tune a separate winning threshold per core against the final holdout.
Breadth scheduling and coverage-guided generation can remain separate studies.

Validate legacy/native label, atom, instruction-pair, boundary and dependency
semantics before an equivalence-based practical speedup claim. Current native
producer-attributed evidence must not be assumed equivalent to historical RVFI
extraction. Disagreements must be reported, not silently removed until a matching
subset remains. If only a compatible subset is benchmarked, disclose the scope,
selection rule, coverage and preparation cost. An unavailable/non-equivalent
legacy arm is N/A, not a fabricated baseline.

A, B and C use the same frozen objective. The current objective counts retained
representative negative observation sets, not testcase-frequency-weighted false
positives. Record that behavior and score holdout quality per testcase. Any ILP
fix must happen before freezing the campaign and apply to all arms.

## Quality evaluation

Score each trained contract against the same independently labelled holdout;
reuse holdout evidence rather than rerunning 1M RTL cases for each contract.
Do not require identical selected atom sets: equally scoring contracts can differ.

Report per core/seed/arm:

- TP, FN, FP and TN, with positive/negative holdout denominators;
- sensitivity/recall TP/(TP+FN), precision TP/(TP+FP), and FPR FP/(FP+TN);
- contract size and paired prediction disagreements;
- adaptive minus exhaustive FN and FP counts/rates.

Undefined precision/recall is N/A, not 100%. Overall accuracy is not a sufficient
quality metric for imbalanced leakage datasets. Zero observed FN on a finite
holdout is empirical sensitivity, not a proof of a sound contract.

The strongest quality-preservation result is identical holdout predictions.
Another useful result is no additional missed leaks and no additional false
alarms. If N8 degrades either metric, publish the measured tradeoff. Do not
redefine "good enough" after seeing the scores; any noninferiority margin must
be justified and fixed in advance.

Optional robustness evaluation, after the main campaign: an additional fresh
`different_programs --register-values full --no-skip-init` holdout (for example
50k cases/core) evaluated by all already-frozen contracts. Report this separately
from the main 1M distribution. Do not use it to revise those contracts or choose
a winner. This probes a broader workload, not all possible out-of-distribution
leakage. The already inspected seed-11 Ibex corpus is development evidence, not
an untouched final holdout.

## Timing and claims

Use one machine (prefer vm1 for the large campaign), fixed worker counts and
resource allocation, with no competing experiments. Realize/build packages first;
report cold build cost separately. Use three balanced/interleaved timing
repetitions per fixed corpus if budget permits, and report median plus range.
Prefer fresh training-seed replication over many timing repetitions of one seed.

Measure outer-process wall time for every timed replay, including input reading,
Spike, selection, RTL, ILP, and required output writes. Record the individual
stages too. The existing summary's `Generation Time` is an internal timer and
is not the entire process lifetime. Keep corpus generation, screening, holdout
labelling and holdout scoring separate and report their preparation cost once.
If measuring prepared-evidence RTL-only execution, label it as a stage speedup;
do not compare it with a whole-process exhaustive time.

Practical speedup = time(A)/time(B).
Adaptive speedup = time(B)/time(C).
Combined speedup = time(A)/time(C), where A is comparable and available.
RTL-call reduction = 1 - calls(C)/calls(B).

Do not combine the costs of a native pipeline run with a cached Spike-only
adaptive run without charging the equivalent preparation to both arms. Holdout
preparation is a common evaluation cost, not work saved by skipping.

Measure each arm with fresh model state; reusable compiled libraries are allowed.
Separate process invocations per core avoid overlapping Verilated symbols.
Report failure rates and exclusions, not only timings of successful cases.

## Core matrix and budget order

The native CLI has 15 distinct configurations: IBEX_SMALL_TEST,
IBEX_MULT_DIV_TEST, IBEX_CACHE_TEST, CVA6_TEST, HAZARD3_TEST, PROTEUS_TEST,
SODOR_2_TEST, SODOR_5_TEST, DARKRISCV_2_TEST, DARKRISCV_3_TEST, FWRISC_TEST,
CV32E40P_TEST, CV32E40S_TEST, PICCOLO_TEST and ROCKET_TEST. IBEX_TEST is an alias
for IBEX_SMALL_TEST and must not be counted as another core. Freeze the CV32E40S
timing-protection setting; if comparing both settings, treat them as two
configurations. All experiments here use the supported RV32 execution model.

First complete a small integration pilot on each configuration, without selecting
on contract quality. Then complete B/C plus one 1M holdout for all configurations.
Add comparable A arms on supported legacy integrations, then independent training
seeds and paired timing repetitions. The packaged legacy benchmark currently
exposes Ibex and CVA6; other legacy integrations need explicit equivalence and
availability checks rather than being assumed present.

Final main table: core/configuration, ISA, valid holdout positive/negative counts,
A/B/C median wall time and ranges, C RTL calls, B/C holdout FN and FP, sensitivity,
precision, contract size, and speedup. Preserve one row per dataset before any
cross-seed aggregation. This supports an efficiency/quality claim even when a
100k exhaustive contract is itself imperfect.
