package contractgen.riscv.ibex;

import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.spike.SpikeAtomClient;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;

public final class IBEXTestAdaptiveRunner {
    private static final int MAX_FAILURES = 10;

    private final Path attackerLibrary;
    private final String harnessName;
    private final Function<Path, AttackerHarnessClient> attackerFactory;
    private final int threads;
    private final int negativeSignatureThreshold;
    private final boolean useSkippedEvidence;
    private final boolean skipPositiveSupersets;
    private final boolean skipNegativeSubsets;

    public IBEXTestAdaptiveRunner(Path ibexTestLibrary, int threads, int negativeSignatureThreshold, boolean useSkippedEvidence) {
        this(ibexTestLibrary, threads, negativeSignatureThreshold, useSkippedEvidence, false, false);
    }

    public IBEXTestAdaptiveRunner(Path ibexTestLibrary, int threads, int negativeSignatureThreshold, boolean useSkippedEvidence, boolean skipPositiveSupersets, boolean skipNegativeSubsets) {
        this(ibexTestLibrary, "IBEX_TEST", IBEXTestAttackerClient::new, threads, negativeSignatureThreshold, useSkippedEvidence, skipPositiveSupersets, skipNegativeSubsets);
    }

    /**
     * Reuses the Spike-signature adaptive strategy with any attacker-only RTL harness.
     */
    public IBEXTestAdaptiveRunner(
            Path attackerLibrary,
            String harnessName,
            Function<Path, AttackerHarnessClient> attackerFactory,
            int threads,
            int negativeSignatureThreshold,
            boolean useSkippedEvidence,
            boolean skipPositiveSupersets,
            boolean skipNegativeSubsets
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
    }

    public Result run(
            List<TestCase> tests,
            List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal
    ) {
        List<SignatureGroup> signatureGroups = groupBySignature(tests.size(), spikeByOrdinal);
        System.out.printf("Running %s adaptive attacker labels for %d cases across %d exact signatures.%n", harnessName, tests.size(), signatureGroups.size());
        if (skipPositiveSupersets || skipNegativeSubsets) {
            return runWithSignatureRelations(tests, ordinalTests, spikeByOrdinal, signatureGroups);
        }
        RISCVTestResult[] mergedResults = new RISCVTestResult[tests.size()];
        Stats stats = new Stats();
        List<String> failures = Collections.synchronizedList(new ArrayList<>());
        AtomicInteger groupCursor = new AtomicInteger();
        List<Thread> runners = new ArrayList<>();
        for (int id = 1; id <= threads; id++) {
            runners.add(new Thread(() -> {
                AttackerHarnessClient attacker = attackerFactory.apply(attackerLibrary);
                int groupIndex;
                while ((groupIndex = groupCursor.getAndIncrement()) < signatureGroups.size()) {
                    executeSignatureGroup(attacker, tests, ordinalTests, spikeByOrdinal, signatureGroups.get(groupIndex), mergedResults, stats, failures);
                    int doneGroups = stats.completedGroups.incrementAndGet();
                    if (shouldReportProgress(doneGroups, signatureGroups.size())) {
                        System.out.printf("%s adaptive progress: %d of %d signatures, %d RTL executions.%n", harnessName, doneGroups, signatureGroups.size(), stats.executed.get());
                    }
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
                mergedResults[ordinal] = new RISCVTestResult(spikeCase.atoms(), Set.of(), attackerLabel, original.getIndex());
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
            if (positiveSeen) {
                stats.skippedPositive.incrementAndGet();
                if (useSkippedEvidence) {
                    mergedResults[ordinal] = new RISCVTestResult(spikeCase.atoms(), Set.of(), true, original.getIndex());
                }
                continue;
            }
            if (negativeSignatureThreshold > 0 && negativeCount >= negativeSignatureThreshold) {
                stats.skippedNegative.incrementAndGet();
                if (useSkippedEvidence) {
                    mergedResults[ordinal] = new RISCVTestResult(spikeCase.atoms(), Set.of(), false, original.getIndex());
                }
                continue;
            }

            SIMULATION_RESULT simulationResult = attacker.run(ordinalTests.get(ordinal), 10000);
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
            if (attackerLabel && spikeCase.atoms().isEmpty()) {
                addFailure(stats, failures, original.getIndex() + ": attacker-distinguishable but Spike reported no atoms");
                continue;
            }

            mergedResults[ordinal] = new RISCVTestResult(spikeCase.atoms(), Set.of(), attackerLabel, original.getIndex());
            if (attackerLabel) {
                positiveSeen = true;
            } else {
                negativeCount++;
            }
        }
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
