package contractgen.riscv.ibex;

import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
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

public final class IBEXTestAdaptiveRunner {
    private static final int MAX_FAILURES = 10;

    private final Path ibexTestLibrary;
    private final int threads;
    private final int negativeSignatureThreshold;
    private final boolean useSkippedEvidence;

    public IBEXTestAdaptiveRunner(Path ibexTestLibrary, int threads, int negativeSignatureThreshold, boolean useSkippedEvidence) {
        if (negativeSignatureThreshold < 0) {
            throw new IllegalArgumentException("negativeSignatureThreshold must be >= 0.");
        }
        this.ibexTestLibrary = ibexTestLibrary;
        this.threads = Math.max(1, threads);
        this.negativeSignatureThreshold = negativeSignatureThreshold;
        this.useSkippedEvidence = useSkippedEvidence;
    }

    public Result run(
            List<TestCase> tests,
            List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal
    ) {
        List<SignatureGroup> signatureGroups = groupBySignature(tests.size(), spikeByOrdinal);
        System.out.printf("Running IBEX_TEST adaptive attacker labels for %d cases across %d exact signatures.%n", tests.size(), signatureGroups.size());
        RISCVTestResult[] mergedResults = new RISCVTestResult[tests.size()];
        Stats stats = new Stats();
        List<String> failures = Collections.synchronizedList(new ArrayList<>());
        AtomicInteger groupCursor = new AtomicInteger();
        List<Thread> runners = new ArrayList<>();
        for (int id = 1; id <= threads; id++) {
            runners.add(new Thread(() -> {
                IBEXTestAttackerClient ibexAttacker = new IBEXTestAttackerClient(ibexTestLibrary);
                int groupIndex;
                while ((groupIndex = groupCursor.getAndIncrement()) < signatureGroups.size()) {
                    executeSignatureGroup(ibexAttacker, tests, ordinalTests, spikeByOrdinal, signatureGroups.get(groupIndex), mergedResults, stats, failures);
                    int doneGroups = stats.completedGroups.incrementAndGet();
                    if (shouldReportProgress(doneGroups, signatureGroups.size())) {
                        System.out.printf("IBEX_TEST adaptive progress: %d of %d signatures, %d RTL executions.%n", doneGroups, signatureGroups.size(), stats.executed.get());
                    }
                }
            }, "IBEX_TEST_Adaptive_Replay_Runner_" + id));
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

    private void executeSignatureGroup(
            IBEXTestAttackerClient ibexAttacker,
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

            List<IBEXTestAttackerClient.IbexAttackerCase> nativeResults = ibexAttacker.runAll(List.of(ordinalTests.get(ordinal)), 10000);
            IBEXTestAttackerClient.IbexAttackerCase nativeResult = nativeResults.isEmpty() ? null : nativeResults.get(0);
            SIMULATION_RESULT simulationResult = nativeResult == null ? SIMULATION_RESULT.UNKNOWN : nativeResult.status();
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
    }

    private record SignatureGroup(AtomSignature signature, List<Integer> ordinals) {
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

        public int failureCount() {
            return failureCount.get();
        }
    }
}
