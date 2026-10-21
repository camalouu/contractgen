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
import java.util.ArrayDeque;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.OptionalInt;
import java.util.PriorityQueue;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Function;
import java.util.function.Consumer;
import java.util.function.IntPredicate;

public final class AdaptiveAttackerRunner {
    private static final int MAX_FAILURES = 10;

    public enum Policy {
        GROUPED, INPUT_ORDER, BREADTH_ONCE, BREADTH_EVERY_ROUND;
        @Override public String toString() { return name().toLowerCase(java.util.Locale.ROOT).replace('_', '-'); }
    }

    public enum Continuation {
        INPUT, RANDOM;
        @Override public String toString() { return name().toLowerCase(java.util.Locale.ROOT); }
    }

    /** Random continuation shuffles candidate group slots, preserving order inside each signature. */
    public record Scheduling(Policy policy, Continuation continuation, long seed) {
        public Scheduling {
            java.util.Objects.requireNonNull(policy);
            java.util.Objects.requireNonNull(continuation);
        }
        public static Scheduling grouped() { return new Scheduling(Policy.GROUPED, Continuation.INPUT, 0); }
    }

    /** Recorded completion order, including filtered evidence; elapsed time starts at run(). */
    public record Execution(int sequence, int ordinal, int testcaseIndex, long elapsedNanos, RISCVTestResult result) {}

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
    private final IntPredicate eligible;
    private final Scheduling scheduling;
    private final Consumer<Execution> executionObserver;
    private final Object observerLock = new Object();
    private int completionSequence;
    private long startedNanos;
    private SignatureReport.Outcome[] measuredOutcomes;

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
        this(attackerLibrary,harnessName,attackerFactory,requireFailureCutoff,threads,
                negativeSignatureThreshold,useSkippedEvidence,skipPositiveSupersets,skipNegativeSubsets,
                disableAdaptiveSkipping, ordinal -> true);
    }

    public AdaptiveAttackerRunner(Path attackerLibrary, String harnessName,
            Function<Path, AttackerHarnessClient> attackerFactory, boolean requireFailureCutoff,
            int threads, int negativeSignatureThreshold, boolean useSkippedEvidence,
            boolean skipPositiveSupersets, boolean skipNegativeSubsets, boolean disableAdaptiveSkipping,
            IntPredicate eligible) {
        this(attackerLibrary,harnessName,attackerFactory,requireFailureCutoff,threads,
                negativeSignatureThreshold,useSkippedEvidence,skipPositiveSupersets,skipNegativeSubsets,
                disableAdaptiveSkipping,eligible,Scheduling.grouped(),null);
    }

    public AdaptiveAttackerRunner(Path attackerLibrary, String harnessName,
            Function<Path, AttackerHarnessClient> attackerFactory, boolean requireFailureCutoff,
            int threads, int negativeSignatureThreshold, boolean useSkippedEvidence,
            boolean skipPositiveSupersets, boolean skipNegativeSubsets, boolean disableAdaptiveSkipping,
            IntPredicate eligible, Scheduling scheduling, Consumer<Execution> executionObserver) {
        this.scheduling = java.util.Objects.requireNonNull(scheduling);
        this.executionObserver = executionObserver;
        validateScheduling(scheduling, !disableAdaptiveSkipping && (skipPositiveSupersets || skipNegativeSubsets));
        this.eligible = java.util.Objects.requireNonNull(eligible);
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

    public static void validateScheduling(Scheduling scheduling, boolean relationSkipping) {
        if (relationSkipping && scheduling.policy() != Policy.GROUPED) {
            throw new IllegalArgumentException("Signature-relation skipping requires --scheduling-policy=grouped.");
        }
        if (scheduling.continuation() != Continuation.INPUT && scheduling.policy() != Policy.BREADTH_ONCE) {
            throw new IllegalArgumentException("Random continuation requires --scheduling-policy=breadth-once.");
        }
    }

    public Result run(
            List<TestCase> tests,
            List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal
    ) {
        measuredOutcomes = new SignatureReport.Outcome[tests.size()];
        startedNanos = System.nanoTime();
        completionSequence = 0;
        List<SignatureGroup> signatureGroups = groupBySignature(tests.size(), spikeByOrdinal, eligible);
        System.out.printf("Running %s adaptive attacker labels for %d cases across %d exact signatures.%n", harnessName, tests.size(), signatureGroups.size());
        if (!disableAdaptiveSkipping && (skipPositiveSupersets || skipNegativeSubsets)) {
            return runWithSignatureRelations(tests, ordinalTests, spikeByOrdinal, signatureGroups);
        }
        if (scheduling.policy() != Policy.GROUPED) {
            return runScheduled(tests, ordinalTests, spikeByOrdinal, signatureGroups);
        }
        RISCVTestResult[] mergedResults = new RISCVTestResult[tests.size()];
        Stats stats = new Stats();
        stats.unsupported.set(tests.size() - signatureGroups.stream().mapToInt(g -> g.ordinals().size()).sum());
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
        return new Result(signatureGroups.size(), mergedResults, stats, List.copyOf(failures),
                SignatureReport.collect(tests.size(), spikeByOrdinal, eligible, measuredOutcomes));
    }

    private Result runScheduled(List<TestCase> tests, List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal, List<SignatureGroup> groups) {
        RISCVTestResult[] results = new RISCVTestResult[tests.size()];
        Stats stats = new Stats();
        stats.unsupported.set(tests.size() - groups.stream().mapToInt(g -> g.ordinals().size()).sum());
        List<String> failures = Collections.synchronizedList(new ArrayList<>());
        Scheduler scheduler = new Scheduler(groups, tests.size());
        AtomicReference<Throwable> failure = new AtomicReference<>();
        List<Thread> workers = new ArrayList<>();
        for (int id = 1; id <= threads; id++) {
            workers.add(new Thread(() -> {
                try {
                    AttackerHarnessClient attacker = attackerFactory.apply(attackerLibrary);
                    Work work;
                    while ((work = scheduler.next()) != null) {
                        executeCase(attacker, tests, ordinalTests, spikeByOrdinal, work.ordinal(), results, stats, failures);
                        scheduler.complete(work, results[work.ordinal()], tests, spikeByOrdinal, results, stats);
                    }
                } catch (Throwable error) {
                    failure.compareAndSet(null, error);
                    scheduler.fail();
                }
            }, harnessName + "_Scheduled_Runner_" + id));
        }
        workers.forEach(Thread::start);
        for (Thread worker : workers) {
            try {
                worker.join();
            } catch (InterruptedException error) {
                scheduler.fail();
                workers.forEach(Thread::interrupt);
                Thread.currentThread().interrupt();
                throw new RuntimeException(error);
            }
        }
        if (failure.get() != null) throw new IllegalStateException(harnessName + " scheduled execution failed", failure.get());
        return new Result(groups.size(), results, stats, List.copyOf(failures),
                SignatureReport.collect(tests.size(), spikeByOrdinal, eligible, measuredOutcomes));
    }

    private static final class GroupState {
        final SignatureGroup group;
        final List<Integer> priorities = new ArrayList<>();
        int cursor;
        int priorityCursor;
        int negatives;
        boolean positive;
        boolean closed;
        GroupState(SignatureGroup group) { this.group = group; }
        int priority() { return priorities.get(priorityCursor); }
    }

    private record Work(GroupState state, int ordinal) {}

    /** One reservation per signature. Blocked signatures never consume another candidate slot. */
    private final class Scheduler {
        private final List<GroupState> states;
        private final PriorityQueue<GroupState> ready = new PriorityQueue<>(Comparator.comparingInt(GroupState::priority));
        private ArrayDeque<GroupState> round;
        private boolean inRounds;
        private int inFlight;
        private boolean failed;

        Scheduler(List<SignatureGroup> groups, int total) {
            states = groups.stream().map(GroupState::new).toList();
            inRounds = scheduling.policy() != Policy.INPUT_ORDER;
            if (inRounds) round = new ArrayDeque<>(states);
            if (scheduling.policy() != Policy.BREADTH_EVERY_ROUND) {
                int[] membership = new int[total];
                java.util.Arrays.fill(membership, -1);
                for (int i = 0; i < states.size(); i++) {
                    GroupState state = states.get(i);
                    int first = inRounds ? 1 : 0;
                    for (int j = first; j < state.group.ordinals().size(); j++)
                        membership[state.group.ordinals().get(j)] = i;
                }
                List<Integer> slots = new ArrayList<>();
                for (int member : membership) if (member >= 0) slots.add(member);
                if (scheduling.continuation() == Continuation.RANDOM)
                    Collections.shuffle(slots, new Random(scheduling.seed()));
                for (int priority = 0; priority < slots.size(); priority++)
                    states.get(slots.get(priority)).priorities.add(priority);
                if (!inRounds) ready.addAll(states);
            }
        }

        synchronized Work next() throws InterruptedException {
            while (!failed) {
                if (inRounds) {
                    if (!round.isEmpty()) return reserve(round.removeFirst());
                    if (inFlight == 0) {
                        List<GroupState> active = states.stream().filter(g -> !g.closed).toList();
                        if (active.isEmpty()) return null;
                        if (scheduling.policy() == Policy.BREADTH_EVERY_ROUND) {
                            round = new ArrayDeque<>(active);
                        } else {
                            inRounds = false;
                            ready.addAll(active);
                        }
                        continue;
                    }
                } else {
                    if (!ready.isEmpty()) {
                        GroupState state = ready.remove();
                        Work work = reserve(state);
                        state.priorityCursor++;
                        return work;
                    }
                    if (inFlight == 0) return null;
                }
                wait();
            }
            return null;
        }

        private Work reserve(GroupState state) {
            inFlight++;
            return new Work(state, state.group.ordinals().get(state.cursor++));
        }

        synchronized void complete(Work work, RISCVTestResult result, List<TestCase> tests,
                Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spike, RISCVTestResult[] results, Stats stats) {
            GroupState state = work.state();
            if (result != null) {
                if (result.isAdversaryDistinguishable()) state.positive = true; else state.negatives++;
            }
            boolean stop = !disableAdaptiveSkipping && (state.positive ||
                    (negativeSignatureThreshold > 0 && state.negatives >= negativeSignatureThreshold));
            if (stop || state.cursor == state.group.ordinals().size()) {
                while (state.cursor < state.group.ordinals().size()) {
                    int ordinal = state.group.ordinals().get(state.cursor++);
                    if (state.positive) stats.skippedPositive.incrementAndGet(); else stats.skippedNegative.incrementAndGet();
                    if (useSkippedEvidence) {
                        var evidence = spike.get(ordinal);
                        results[ordinal] = new RISCVTestResult(evidence.atoms(), evidence.instructionPairs(),
                                state.positive, tests.get(ordinal).getIndex());
                    }
                }
                state.closed = true;
                int done = stats.completedGroups.incrementAndGet();
                if (shouldReportProgress(done, states.size()))
                    System.out.printf("%s %s progress: %d of %d signatures, %d RTL executions.%n",
                            harnessName, scheduling.policy(), done, states.size(), stats.executed());
            } else if (!inRounds) {
                ready.add(state);
            }
            inFlight--;
            notifyAll();
        }

        synchronized void fail() { failed = true; notifyAll(); }
    }

    private Result runWithSignatureRelations(
            List<TestCase> tests,
            List<TestCase> ordinalTests,
            Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal,
            List<SignatureGroup> signatureGroups
    ) {
        RISCVTestResult[] mergedResults = new RISCVTestResult[tests.size()];
        Stats stats = new Stats();
        stats.unsupported.set(tests.size() - signatureGroups.stream().mapToInt(g -> g.ordinals().size()).sum());
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
        return new Result(signatureGroups.size(), mergedResults, stats, List.copyOf(failures),
                SignatureReport.collect(tests.size(), spikeByOrdinal, eligible, measuredOutcomes));
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

            executeCase(attacker, tests, ordinalTests, spikeByOrdinal, ordinal, mergedResults, stats, failures);
            RISCVTestResult result = mergedResults[ordinal];
            if (result != null) {
                if (result.isAdversaryDistinguishable()) positiveSeen = true; else negativeCount++;
            }
        }
    }

    private void executeCase(AttackerHarnessClient attacker, List<TestCase> tests,
            List<TestCase> ordinalTests, Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal,
            int ordinal, RISCVTestResult[] mergedResults, Stats stats, List<String> failures) {
        TestCase original = tests.get(ordinal);
        SpikeAtomClient.SpikeCaseAtoms spikeCase = spikeByOrdinal.get(ordinal);
        AttackerHarnessClient.AttackerResult attackerResult = attacker.runDetailed(ordinalTests.get(ordinal), 10000);
        SIMULATION_RESULT simulationResult = attackerResult.status();
        Boolean attackerLabel = switch (simulationResult) {
            case FAIL -> true;
            case SUCCESS, FALSE_POSITIVE -> false;
            case ERROR, TIMEOUT, UNKNOWN -> null;
        };
        stats.executed.incrementAndGet();
        measuredOutcomes[ordinal] = SignatureReport.Outcome.FAILURE;
        if (attackerLabel == null) {
            addFailure(stats, failures, original.getIndex() + ": attacker harness status " + simulationResult);
            return;
        }
        if (attackerLabel && spikeCase.atoms().isEmpty() && spikeCase.instructionPairs().isEmpty()) {
            addFailure(stats, failures, original.getIndex()
                    + ": attacker-distinguishable but Spike reported no evidence");
            return;
        }

        Set<RISCVObservation> evidenceAtoms = spikeCase.atoms();
        Set<Pair<RISCV_TYPE, RISCV_TYPE>> evidencePairs = spikeCase.instructionPairs();
        if (attackerLabel && requireFailureCutoff) {
            OptionalInt failureCutoff = attackerResult.failureCutoff();
            if (failureCutoff.isEmpty()) {
                addFailure(stats, failures, original.getIndex()
                        + ": attacker-distinguishable but " + harnessName + " reported no failure cutoff");
                return;
            }
            if (!spikeCase.firstRetire().keySet().containsAll(spikeCase.atoms())) {
                addFailure(stats, failures, original.getIndex()
                        + ": attacker-distinguishable but Spike reported atoms without first-retire metadata");
                return;
            }
            if (!spikeCase.pairFirstRetire().keySet().containsAll(spikeCase.instructionPairs())) {
                addFailure(stats, failures, original.getIndex()
                        + ": attacker-distinguishable but Spike reported instruction pairs without first-retire metadata");
                return;
            }
            evidenceAtoms = atomsAtOrBefore(spikeCase, failureCutoff.getAsInt());
            evidencePairs = instructionPairsAtOrBefore(spikeCase, failureCutoff.getAsInt());
            if (evidenceAtoms.isEmpty() && evidencePairs.isEmpty()) {
                addFailure(stats, failures, original.getIndex()
                        + ": attacker-distinguishable but no Spike evidence occurs by failure cutoff "
                        + failureCutoff.getAsInt());
                return;
            }
        }
        if (!attackerLabel && attackerResult.executionCutoff().isPresent()) {
            int executionCutoff = attackerResult.executionCutoff().getAsInt();
            if (!spikeCase.firstRetire().keySet().containsAll(spikeCase.atoms())) {
                addFailure(stats, failures, original.getIndex()
                        + ": " + harnessName + " reported an execution cutoff but Spike atoms lack first-retire metadata");
                return;
            }
            if (!spikeCase.pairFirstRetire().keySet().containsAll(spikeCase.instructionPairs())) {
                addFailure(stats, failures, original.getIndex()
                        + ": " + harnessName + " reported an execution cutoff but Spike instruction pairs lack first-retire metadata");
                return;
            }
            evidenceAtoms = atomsAtExecutionBoundary(spikeCase, executionCutoff);
            evidencePairs = instructionPairsAtOrBefore(spikeCase, executionCutoff);
        }

        mergedResults[ordinal] = new RISCVTestResult(
                evidenceAtoms, evidencePairs, attackerLabel, original.getIndex());
        measuredOutcomes[ordinal] = attackerLabel
                ? SignatureReport.Outcome.LEAKING : SignatureReport.Outcome.NON_LEAKING;
        if (executionObserver != null) {
            synchronized (observerLock) {
                executionObserver.accept(new Execution(++completionSequence, ordinal, original.getIndex(),
                        System.nanoTime() - startedNanos, mergedResults[ordinal]));
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

    private static List<SignatureGroup> groupBySignature(int total, Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal,
                                                        IntPredicate eligible) {
        Map<AtomSignature, List<Integer>> grouped = new LinkedHashMap<>();
        for (int ordinal = 0; ordinal < total; ordinal++) {
            if (!eligible.test(ordinal)) continue;
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
        Set<RISCVObservation> out = new java.util.TreeSet<>(RISCVObservation.ORDER);
        out.addAll(atoms);
        return out;
    }

    public record Result(int uniqueSignatures, RISCVTestResult[] results, Stats stats, List<String> failures,
                         List<SignatureReport.Entry> signatures) {
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
        private final AtomicInteger unsupported = new AtomicInteger();

        public int unsupported() { return unsupported.get(); }

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
