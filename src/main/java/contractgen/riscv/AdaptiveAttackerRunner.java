package contractgen.riscv;

import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import contractgen.util.Pair;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.OptionalInt;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Function;

public final class AdaptiveAttackerRunner {
    private static final int MAX_FAILURES = 10;

    private final Path attackerLibrary;
    private final String harnessName;
    private final Function<Path, AttackerHarnessClient> attackerFactory;
    private final int threads;
    private final int negativeSignatureThreshold;
    private final boolean useSkippedEvidence;
    private final boolean skipPositiveSupersets;
    private final boolean skipNegativeSubsets;
    private final boolean disableAdaptiveSkipping;
    private final boolean requireFailureCutoff;

    /**
     * Reuses the Spike-signature adaptive strategy with any attacker-only RTL harness.
     */
    public AdaptiveAttackerRunner(
            Path attackerLibrary,
            String harnessName,
            Function<Path, AttackerHarnessClient> attackerFactory,
            boolean requireFailureCutoff,
            int threads,
            int negativeSignatureThreshold,
            boolean useSkippedEvidence,
            boolean skipPositiveSupersets,
            boolean skipNegativeSubsets,
            boolean disableAdaptiveSkipping
    ) {
        if (negativeSignatureThreshold < 0) {
            throw new IllegalArgumentException("negativeSignatureThreshold must be >= 0.");
        }
        this.attackerLibrary = attackerLibrary;
        this.harnessName = harnessName;
        this.attackerFactory = attackerFactory;
        this.threads = Math.max(1, threads);
        this.negativeSignatureThreshold = negativeSignatureThreshold;
        this.useSkippedEvidence = useSkippedEvidence;
        this.skipPositiveSupersets = skipPositiveSupersets;
        this.skipNegativeSubsets = skipNegativeSubsets;
        this.disableAdaptiveSkipping = disableAdaptiveSkipping;
        this.requireFailureCutoff = requireFailureCutoff;
    }

    public Result run(
            List<TestCase> tests,
            List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal
    ) {
        List<SignatureGroup> signatureGroups = groupBySignature(tests.size(), spikeByOrdinal);
        System.out.printf("Running %s adaptive attacker labels for %d cases across %d exact signatures.%n", harnessName, tests.size(), signatureGroups.size());
        if (!disableAdaptiveSkipping && (skipPositiveSupersets || skipNegativeSubsets)) {
            return runWithSignatureRelations(tests, ordinalTests, spikeByOrdinal, signatureGroups);
        }
        RISCVTestResult[] mergedResults = new RISCVTestResult[tests.size()];
        Stats stats = new Stats();
        List<String> failures = Collections.synchronizedList(new ArrayList<>());
        AtomicInteger groupCursor = new AtomicInteger();
        AtomicReference<Throwable> runnerFailure = new AtomicReference<>();
        List<Thread> runners = new ArrayList<>();
        for (int id = 1; id <= threads; id++) {
            runners.add(new Thread(() -> {
                try {
                    AttackerHarnessClient attacker = attackerFactory.apply(attackerLibrary);
                    int groupIndex;
                    while (runnerFailure.get() == null
                            && (groupIndex = groupCursor.getAndIncrement()) < signatureGroups.size()) {
                        executeSignatureGroup(attacker, tests, ordinalTests, spikeByOrdinal, signatureGroups.get(groupIndex), mergedResults, stats, failures);
                        int doneGroups = stats.completedGroups.incrementAndGet();
                        if (shouldReportProgress(doneGroups, signatureGroups.size())) {
                            System.out.printf("%s adaptive progress: %d of %d signatures, %d RTL executions.%n", harnessName, doneGroups, signatureGroups.size(), stats.executed.get());
                        }
                    }
                } catch (Throwable failure) {
                    runnerFailure.compareAndSet(null, failure);
                }
            }, harnessName + "_Adaptive_Replay_Runner_" + id));
        }
        runners.forEach(Thread::start);
        runners.forEach(t -> {
            try {
                t.join();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException(e);
            }
        });
        if (runnerFailure.get() != null) {
            throw new IllegalStateException(harnessName + " adaptive attacker execution failed", runnerFailure.get());
        }
        System.out.println();
        return new Result(signatureGroups.size(), mergedResults, stats, List.copyOf(failures));
    }

    private Result runWithSignatureRelations(
            List<TestCase> tests,
            List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal,
            List<SignatureGroup> signatureGroups
    ) {
        RISCVTestResult[] mergedResults = new RISCVTestResult[tests.size()];
        Stats stats = new Stats();
        List<String> failures = new ArrayList<>();
        List<AtomSignature> knownPositive = new ArrayList<>();
        List<AtomSignature> knownNegative = new ArrayList<>();
        AttackerHarnessClient attacker = attackerFactory.apply(attackerLibrary);

        for (SignatureGroup group : signatureGroups) {
            boolean positiveBySuperset = skipPositiveSupersets && hasKnownPositiveSubset(group.signature(), knownPositive);
            boolean negativeBySubset = skipNegativeSubsets && hasKnownNegativeSuperset(group.signature(), knownNegative);
            if (positiveBySuperset && negativeBySubset) {
                stats.relationConflicts.incrementAndGet();
            } else if (positiveBySuperset) {
                skipRelationGroup(tests, spikeByOrdinal, group, mergedResults, stats, true);
                reportSequentialProgress(stats, signatureGroups.size());
                continue;
            } else if (negativeBySubset) {
                skipRelationGroup(tests, spikeByOrdinal, group, mergedResults, stats, false);
            reportSequentialProgress(stats, signatureGroups.size());
                continue;
            }

            executeSignatureGroup(attacker, tests, ordinalTests, spikeByOrdinal, group, mergedResults, stats, failures);
            GroupLabels labels = labelsForGroup(group, mergedResults);
            if (labels.hasPositive()) {
                knownPositive.add(group.signature());
            } else if (labels.hasNegative()) {
                knownNegative.add(group.signature());
            }
                reportSequentialProgress(stats, signatureGroups.size());
        }

        System.out.println();
        return new Result(signatureGroups.size(), mergedResults, stats, List.copyOf(failures));
    }

    private void skipRelationGroup(
            List<TestCase> tests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal,
            SignatureGroup group,
            RISCVTestResult[] mergedResults,
            Stats stats,
            boolean attackerLabel
    ) {
        for (int ordinal : group.ordinals()) {
            TestCase original = tests.get(ordinal);
            SpikeAtomClient.SpikeCaseAtoms spikeCase = spikeByOrdinal.get(ordinal);
            if (attackerLabel) {
                stats.skippedPositiveSuperset.incrementAndGet();
            } else {
                stats.skippedNegativeSubset.incrementAndGet();
            }
            if (useSkippedEvidence) {
                mergedResults[ordinal] = new RISCVTestResult(
                        spikeCase.atoms(), spikeCase.instructionPairs(), attackerLabel, original.getIndex());
            }
        }
    }

    private void reportSequentialProgress(Stats stats, int total) {
        int doneGroups = stats.completedGroups.incrementAndGet();
        if (shouldReportProgress(doneGroups, total)) {
            System.out.printf("%s adaptive progress: %d of %d signatures, %d RTL executions.%n", harnessName, doneGroups, total, stats.executed.get());
        }
    }

    private static GroupLabels labelsForGroup(SignatureGroup group, RISCVTestResult[] mergedResults) {
        boolean hasPositive = false;
        boolean hasNegative = false;
        for (int ordinal : group.ordinals()) {
            RISCVTestResult result = mergedResults[ordinal];
            if (result == null) {
                continue;
            }
            if (result.isAdversaryDistinguishable()) {
                hasPositive = true;
            } else {
                hasNegative = true;
            }
        }
        return new GroupLabels(hasPositive, hasNegative);
    }

    private void executeSignatureGroup(
            AttackerHarnessClient attacker,
            List<TestCase> tests,
            List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal,
            SignatureGroup group,
            RISCVTestResult[] mergedResults,
            Stats stats,
            List<String> failures
    ) {
        boolean positiveSeen = false;
        int negativeCount = 0;
        for (int ordinal : group.ordinals()) {
            TestCase original = tests.get(ordinal);
            SpikeAtomClient.SpikeCaseAtoms spikeCase = spikeByOrdinal.get(ordinal);
            if (!disableAdaptiveSkipping && positiveSeen) {
                stats.skippedPositive.incrementAndGet();
                if (useSkippedEvidence) {
                    mergedResults[ordinal] = new RISCVTestResult(
                            spikeCase.atoms(), spikeCase.instructionPairs(), true, original.getIndex());
                }
                continue;
            }
            if (!disableAdaptiveSkipping && negativeSignatureThreshold > 0 && negativeCount >= negativeSignatureThreshold) {
                stats.skippedNegative.incrementAndGet();
                if (useSkippedEvidence) {
                    mergedResults[ordinal] = new RISCVTestResult(
                            spikeCase.atoms(), spikeCase.instructionPairs(), false, original.getIndex());
                }
                continue;
            }

            AttackerHarnessClient.AttackerResult attackerResult = attacker.runDetailed(ordinalTests.get(ordinal), 10000);
            SIMULATION_RESULT simulationResult = attackerResult.status();
            Boolean attackerLabel = switch (simulationResult) {
                case FAIL -> true;
                case SUCCESS, FALSE_POSITIVE -> false;
                case ERROR, TIMEOUT, UNKNOWN -> null;
            };
            stats.executed.incrementAndGet();
            if (attackerLabel == null) {
                addFailure(stats, failures, original.getIndex() + ": attacker harness status " + simulationResult);
                continue;
            }
            if (attackerLabel && spikeCase.atoms().isEmpty() && spikeCase.instructionPairs().isEmpty()) {
                addFailure(stats, failures, original.getIndex()
                        + ": attacker-distinguishable but Spike reported no evidence");
                continue;
            }

            Set<RISCVObservation> evidenceAtoms = spikeCase.atoms();
            Set<Pair<RISCV_TYPE, RISCV_TYPE>> evidencePairs = spikeCase.instructionPairs();
            if (attackerLabel && requireFailureCutoff) {
                OptionalInt failureCutoff = attackerResult.failureCutoff();
                if (failureCutoff.isEmpty()) {
                    addFailure(stats, failures, original.getIndex()
                            + ": attacker-distinguishable but " + harnessName + " reported no failure cutoff");
                    continue;
                }
                if (!spikeCase.firstRetire().keySet().containsAll(spikeCase.atoms())) {
                    addFailure(stats, failures, original.getIndex()
                            + ": attacker-distinguishable but Spike reported atoms without first-retire metadata");
                    continue;
                }
                if (!spikeCase.pairFirstRetire().keySet().containsAll(spikeCase.instructionPairs())) {
                    addFailure(stats, failures, original.getIndex()
                            + ": attacker-distinguishable but Spike reported instruction pairs without first-retire metadata");
                    continue;
                }
                evidenceAtoms = atomsAtOrBefore(spikeCase, failureCutoff.getAsInt());
                evidencePairs = instructionPairsAtOrBefore(spikeCase, failureCutoff.getAsInt());
                if (evidenceAtoms.isEmpty() && evidencePairs.isEmpty()) {
                    addFailure(stats, failures, original.getIndex()
                            + ": attacker-distinguishable but no Spike evidence occurs by failure cutoff "
                            + failureCutoff.getAsInt());
                    continue;
                }
            }
            if (!attackerLabel && attackerResult.executionCutoff().isPresent()) {
                int executionCutoff = attackerResult.executionCutoff().getAsInt();
                if (!spikeCase.firstRetire().keySet().containsAll(spikeCase.atoms())) {
                    addFailure(stats, failures, original.getIndex()
                            + ": " + harnessName + " reported an execution cutoff but Spike atoms lack first-retire metadata");
                    continue;
                }
                if (!spikeCase.pairFirstRetire().keySet().containsAll(spikeCase.instructionPairs())) {
                    addFailure(stats, failures, original.getIndex()
                            + ": " + harnessName + " reported an execution cutoff but Spike instruction pairs lack first-retire metadata");
                    continue;
                }
                evidenceAtoms = atomsAtExecutionBoundary(spikeCase, executionCutoff);
                evidencePairs = instructionPairsAtOrBefore(spikeCase, executionCutoff);
            }

            mergedResults[ordinal] = new RISCVTestResult(
                    evidenceAtoms, evidencePairs, attackerLabel, original.getIndex());
            if (attackerLabel) {
                positiveSeen = true;
            } else {
                negativeCount++;
            }
        }
    }

    static Set<RISCVObservation> atomsAtOrBefore(SpikeAtomClient.SpikeCaseAtoms spikeCase, int cutoff) {
        Set<RISCVObservation> filtered = observationSet(Set.of());
        for (RISCVObservation atom : spikeCase.atoms()) {
            if (spikeCase.firstRetire(atom).isPresent()
                    && spikeCase.firstRetire(atom).getAsInt() <= cutoff) {
                filtered.add(atom);
            }
        }
        return Collections.unmodifiableSet(filtered);
    }

    static Set<Pair<RISCV_TYPE, RISCV_TYPE>> instructionPairsAtOrBefore(
            SpikeAtomClient.SpikeCaseAtoms spikeCase, int cutoff) {
        Set<Pair<RISCV_TYPE, RISCV_TYPE>> filtered = new java.util.HashSet<>();
        for (Pair<RISCV_TYPE, RISCV_TYPE> pair : spikeCase.instructionPairs()) {
            if (spikeCase.firstRetire(pair).isPresent()
                    && spikeCase.firstRetire(pair).getAsInt() <= cutoff) {
                filtered.add(pair);
            }
        }
        return Collections.unmodifiableSet(filtered);
    }

    static Set<RISCVObservation> atomsAtExecutionBoundary(
            SpikeAtomClient.SpikeCaseAtoms spikeCase, int cutoff) {
        Set<RISCVObservation> filtered = observationSet(Set.of());
        for (RISCVObservation atom : spikeCase.atoms()) {
            OptionalInt firstRetire = spikeCase.firstRetire(atom);
            if (firstRetire.isEmpty()) {
                continue;
            }
            // Once both RTL paths are in the terminal NOP suffix, structural
            // and control evidence cannot be new. Dependency observations can
            // still refer to one of the four preceding retired instructions.
            boolean nopDependencyTail = atom.type() == RISCV_TYPE.ADDI
                    && (atom.observation().name().startsWith("RAW_")
                    || atom.observation().name().startsWith("WAW_"))
                    && firstRetire.getAsInt() <= cutoff + 4;
            if (firstRetire.getAsInt() <= cutoff || nopDependencyTail) {
                filtered.add(atom);
            }
        }
        return Collections.unmodifiableSet(filtered);
    }

    private static List<SignatureGroup> groupBySignature(int total, Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal) {
        Map<AtomSignature, List<Integer>> grouped = new LinkedHashMap<>();
        for (int ordinal = 0; ordinal < total; ordinal++) {
            SpikeAtomClient.SpikeCaseAtoms spikeCase = spikeByOrdinal.get(ordinal);
            AtomSignature signature = new AtomSignature(spikeCase.atoms());
            grouped.computeIfAbsent(signature, ignored -> new ArrayList<>()).add(ordinal);
        }
        return grouped.entrySet().stream()
                .map(entry -> new SignatureGroup(entry.getKey(), entry.getValue()))
                .toList();
    }

    private static void addFailure(Stats stats, List<String> failures, String failure) {
        int count = stats.failureCount.incrementAndGet();
        if (count <= MAX_FAILURES) {
            failures.add(failure);
        }
    }

    private static boolean shouldReportProgress(int done, int total) {
        if (done == total) {
            return true;
        }
        int step = Math.max(1, total / 20);
        return done % step == 0;
    }

    private record AtomSignature(Set<RISCVObservation> atoms) {
        private AtomSignature {
            atoms = Collections.unmodifiableSet(observationSet(atoms));
        }

        private boolean isStrictSubsetOf(AtomSignature other) {
            return atoms.size() < other.atoms.size() && other.atoms.containsAll(atoms);
        }
    }

    private record SignatureGroup(AtomSignature signature, List<Integer> ordinals) {
    }

    private record GroupLabels(boolean hasPositive, boolean hasNegative) {
    }

    private static boolean hasKnownPositiveSubset(AtomSignature signature, List<AtomSignature> knownPositive) {
        return knownPositive.stream().anyMatch(known -> known.isStrictSubsetOf(signature));
    }

    private static boolean hasKnownNegativeSuperset(AtomSignature signature, List<AtomSignature> knownNegative) {
        return knownNegative.stream().anyMatch(known -> signature.isStrictSubsetOf(known));
    }

    private static Set<RISCVObservation> observationSet(Set<RISCVObservation> atoms) {
        Set<RISCVObservation> out = new java.util.TreeSet<>(Comparator.comparing(RISCVObservation::type).thenComparing(RISCVObservation::observation));
        out.addAll(atoms);
        return out;
    }

    public record Result(int uniqueSignatures, RISCVTestResult[] results, Stats stats, List<String> failures) {
    }

    public static final class Stats {
        private final AtomicInteger completedGroups = new AtomicInteger();
        private final AtomicInteger executed = new AtomicInteger();
        private final AtomicInteger skippedPositive = new AtomicInteger();
        private final AtomicInteger skippedNegative = new AtomicInteger();
        private final AtomicInteger skippedPositiveSuperset = new AtomicInteger();
        private final AtomicInteger skippedNegativeSubset = new AtomicInteger();
        private final AtomicInteger relationConflicts = new AtomicInteger();
        private final AtomicInteger failureCount = new AtomicInteger();

        public int executed() {
            return executed.get();
        }

        public int skippedPositive() {
            return skippedPositive.get();
        }

        public int skippedNegative() {
            return skippedNegative.get();
        }

        public int skippedPositiveSuperset() {
            return skippedPositiveSuperset.get();
        }

        public int skippedNegativeSubset() {
            return skippedNegativeSubset.get();
        }

        public int relationConflicts() {
            return relationConflicts.get();
        }

        public int failureCount() {
            return failureCount.get();
        }
    }
}
