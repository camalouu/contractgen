package contractgen.riscv;

import contractgen.Observation;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCVTestCase;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.OptionalInt;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Tests cutoff filtering independently of a native attacker implementation. */
class AdaptiveAttackerRunnerTest {
    @Test
    void producerSpecificSignaturesDoNotSkipEachOthersRtlQueries() {
        var load = new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.RAW_RS1_1, true);
        var add = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.RAW_RS1_1, true);
        var tests = List.of(test(0), test(1));
        var spike = Map.of(0, new SpikeAtomClient.SpikeCaseAtoms(0, 0, Set.of(load), null),
                1, new SpikeAtomClient.SpikeCaseAtoms(1, 1, Set.of(add), null));
        var result = new AdaptiveAttackerRunner(Path.of("unused"), "mock", ignored ->
                (t, cycles) -> t.getIndex() == 0 ? SIMULATION_RESULT.FAIL : SIMULATION_RESULT.SUCCESS,
                false, 1, 1, true, true, true, false, ordinal -> true,
                new AdaptiveAttackerRunner.Scheduling(AdaptiveAttackerRunner.Policy.GROUPED,
                        AdaptiveAttackerRunner.Continuation.INPUT, 0), ignored -> {})
                .run(tests, tests, spike);
        assertEquals(2, result.uniqueSignatures());
        assertEquals(2, result.stats().executed());
        assertEquals(Set.of(load), result.results()[0].getDistinguishingObservations());
        assertEquals(Set.of(add), result.results()[1].getDistinguishingObservations());
        assertTrue(result.results()[0].isAdversaryDistinguishable());
        assertFalse(result.results()[1].isAdversaryDistinguishable());
    }
    @Test
    void serialPoliciesPreserveSelectionButChangeQueryOrder() {
        int[] signatures = {0,0,1,1,1,2,2,2,0,1,2,0};
        var tests = new java.util.ArrayList<TestCase>();
        var atoms = new java.util.HashMap<Integer,SpikeAtomClient.SpikeCaseAtoms>();
        for (int i=0;i<signatures.length;i++) {
            tests.add(test(i));
            atoms.put(i,new SpikeAtomClient.SpikeCaseAtoms(i,i,
                    Set.of(new RISCVObservation(RISCV_TYPE.values()[signatures[i]],RISCV_OBSERVATION_TYPE.IMM)),null));
        }
        for (var policy : AdaptiveAttackerRunner.Policy.values()) {
            var observed = new java.util.ArrayList<AdaptiveAttackerRunner.Execution>();
            var result = new AdaptiveAttackerRunner(Path.of("unused"),"mock", ignored ->
                    (t,cycles) -> t.getIndex()==1 ? SIMULATION_RESULT.FAIL : SIMULATION_RESULT.SUCCESS,
                    false,1,3,true,false,false,false,ordinal -> true,
                    new AdaptiveAttackerRunner.Scheduling(policy,AdaptiveAttackerRunner.Continuation.INPUT,0),observed::add)
                    .run(tests,tests,atoms);
            List<Integer> expected = switch (policy) {
                case GROUPED, INPUT_ORDER -> List.of(0,1,2,3,4,5,6,7);
                case BREADTH_ONCE -> List.of(0,2,5,1,3,4,6,7);
                case BREADTH_EVERY_ROUND -> List.of(0,2,5,1,3,6,4,7);
            };
            assertEquals(expected,observed.stream().map(AdaptiveAttackerRunner.Execution::ordinal).toList());
            assertEquals(8,result.stats().executed());
            assertEquals(12, result.signatures().stream().mapToInt(SignatureReport.Entry::occurrences).sum());
            assertEquals(8, result.signatures().stream().mapToInt(SignatureReport.Entry::executions).sum());
            assertEquals(1, result.signatures().stream().mapToInt(SignatureReport.Entry::leaking).sum());
            assertEquals(7, result.signatures().stream().mapToInt(SignatureReport.Entry::nonLeaking).sum());
            assertEquals(4, result.signatures().stream().mapToInt(SignatureReport.Entry::skipped).sum());
            assertEquals(2,result.stats().skippedPositive());
            assertEquals(2,result.stats().skippedNegative());
            for (var r:result.results()) assertTrue(r != null);
            assertTrue(result.results()[8].isAdversaryDistinguishable());
            assertFalse(result.results()[9].isAdversaryDistinguishable());
        }
    }

    @Test
    @org.junit.jupiter.api.Timeout(10)
    void parallelPoliciesHaveOneInflightCasePerSignatureAndRespectSweepBarriers() {
        int groups=30, size=10;
        var tests=new java.util.ArrayList<TestCase>();
        var atoms=new java.util.HashMap<Integer,SpikeAtomClient.SpikeCaseAtoms>();
        for(int i=0;i<groups*size;i++) {
            tests.add(test(i));
            atoms.put(i,new SpikeAtomClient.SpikeCaseAtoms(i,i,
                    Set.of(new RISCVObservation(RISCV_TYPE.values()[i%groups],RISCV_OBSERVATION_TYPE.IMM)),null));
        }
        for (var policy:AdaptiveAttackerRunner.Policy.values()) {
            var active=java.util.concurrent.ConcurrentHashMap.<Integer>newKeySet();
            var completedFirst=new java.util.concurrent.atomic.AtomicInteger();
            var concurrency=new java.util.concurrent.atomic.AtomicInteger();
            var maximum=new java.util.concurrent.atomic.AtomicInteger();
            var events=new java.util.ArrayList<AdaptiveAttackerRunner.Execution>();
            var result=new AdaptiveAttackerRunner(Path.of("unused"),"mock",ignored -> (t,cycles) -> {
                int ordinal=t.getIndex(),group=ordinal%groups;
                assertTrue(active.add(group),"Two concurrent cases in a signature");
                maximum.accumulateAndGet(concurrency.incrementAndGet(),Math::max);
                if (policy==AdaptiveAttackerRunner.Policy.BREADTH_ONCE || policy==AdaptiveAttackerRunner.Policy.BREADTH_EVERY_ROUND)
                    if(ordinal>=groups)assertEquals(groups,completedFirst.get(),"Continuation started before first sweep completed");
                try { Thread.sleep(2); } catch (InterruptedException e) { throw new RuntimeException(e); }
                if(ordinal<groups)completedFirst.incrementAndGet();
                concurrency.decrementAndGet();active.remove(group);
                return group%3==0 && ordinal/groups==1 ? SIMULATION_RESULT.FAIL : SIMULATION_RESULT.SUCCESS;
            },false,4,3,false,false,false,false,ordinal -> true,
                    new AdaptiveAttackerRunner.Scheduling(policy,
                            policy==AdaptiveAttackerRunner.Policy.BREADTH_ONCE?AdaptiveAttackerRunner.Continuation.RANDOM:AdaptiveAttackerRunner.Continuation.INPUT,42),events::add)
                    .run(tests,tests,atoms);
            assertTrue(maximum.get()>1,"RTL work did not run concurrently");
            assertEquals(80,result.stats().executed());
            assertEquals(0,result.stats().failureCount());
            assertEquals(80,events.size());
            int[] previous=new int[groups];java.util.Arrays.fill(previous,-1);
            long elapsed=0;
            for(int i=0;i<events.size();i++) {
                var event=events.get(i);int group=event.ordinal()%groups;
                assertEquals(i+1,event.sequence());
                assertTrue(event.elapsedNanos()>=elapsed);elapsed=event.elapsedNanos();
                assertTrue(event.ordinal()>previous[group]);previous[group]=event.ordinal();
            }
            for(int i=0;i<groups*size;i++) {
                boolean queried=i/groups < (i%groups%3==0?2:3);
                assertEquals(queried,result.results()[i]!=null,"Selected IDs differ across schedulers");
            }
        }
    }

    @Test
    @org.junit.jupiter.api.Timeout(10)
    void schedulerFailureWakesOtherWorkers() {
        var tests=List.of(test(0),test(1));
        var atoms=Map.of(0,new SpikeAtomClient.SpikeCaseAtoms(0,0,Set.of(EARLY),null),
                1,new SpikeAtomClient.SpikeCaseAtoms(1,1,Set.of(LATE),null));
        for(var policy:List.of(AdaptiveAttackerRunner.Policy.BREADTH_ONCE,AdaptiveAttackerRunner.Policy.BREADTH_EVERY_ROUND)) {
            var runner=new AdaptiveAttackerRunner(Path.of("unused"),"mock",ignored -> (t,cycles) -> {
                if(t.getIndex()==0)throw new IllegalStateException("native failure");
                return SIMULATION_RESULT.SUCCESS;
            },false,4,8,false,false,false,false,ordinal -> true,
                    new AdaptiveAttackerRunner.Scheduling(policy,AdaptiveAttackerRunner.Continuation.INPUT,0),null);
            org.junit.jupiter.api.Assertions.assertThrows(IllegalStateException.class,()->runner.run(tests,tests,atoms));
        }
    }

    @Test
    void randomContinuationIsRepeatableWithOneWorker() {
        var tests=new java.util.ArrayList<TestCase>();
        var atoms=new java.util.HashMap<Integer,SpikeAtomClient.SpikeCaseAtoms>();
        for(int i=0;i<60;i++) {
            tests.add(test(i));
            atoms.put(i,new SpikeAtomClient.SpikeCaseAtoms(i,i,
                    Set.of(new RISCVObservation(RISCV_TYPE.values()[i%6],RISCV_OBSERVATION_TYPE.IMM)),null));
        }
        var sequences=new java.util.ArrayList<List<Integer>>();
        for(int repeat=0;repeat<2;repeat++) {
            var events=new java.util.ArrayList<AdaptiveAttackerRunner.Execution>();
            var result=new AdaptiveAttackerRunner(Path.of("unused"),"mock",ignored ->(t,cycles)->SIMULATION_RESULT.SUCCESS,
                    false,1,8,false,false,false,false,ordinal -> true,
                    new AdaptiveAttackerRunner.Scheduling(AdaptiveAttackerRunner.Policy.BREADTH_ONCE,
                            AdaptiveAttackerRunner.Continuation.RANDOM,42),events::add).run(tests,tests,atoms);
            assertEquals(48,result.stats().executed());
            sequences.add(events.stream().map(AdaptiveAttackerRunner.Execution::ordinal).toList());
        }
        assertEquals(sequences.get(0),sequences.get(1));
        assertEquals(List.of(0,1,2,3,4,5),sequences.get(0).subList(0,6));
    }

    @Test
    void newPoliciesRejectOrderDependentRelationSkipping() {
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,()->
                new AdaptiveAttackerRunner(Path.of("unused"),"mock",ignored -> (t,cycles)->SIMULATION_RESULT.SUCCESS,
                        false,4,8,false,true,false,false,ordinal -> true,
                        new AdaptiveAttackerRunner.Scheduling(AdaptiveAttackerRunner.Policy.BREADTH_ONCE,
                                AdaptiveAttackerRunner.Continuation.INPUT,0),null));
    }

    @Test
    void scheduledPoliciesRespectEligibilityInvalidResultsAndDisabledSkipping() {
        var tests = new java.util.ArrayList<TestCase>();
        var atoms = new java.util.HashMap<Integer,SpikeAtomClient.SpikeCaseAtoms>();
        for (int i=0;i<8;i++) {
            tests.add(test(i));
            atoms.put(i,new SpikeAtomClient.SpikeCaseAtoms(i,i,
                    Set.of(new RISCVObservation(RISCV_TYPE.values()[i<6?i%2:2],RISCV_OBSERVATION_TYPE.IMM)),null));
        }
        for (var policy:AdaptiveAttackerRunner.Policy.values()) for (boolean disabled:new boolean[]{false,true}) {
            var events=new java.util.ArrayList<AdaptiveAttackerRunner.Execution>();
            var result=new AdaptiveAttackerRunner(Path.of("unused"),"mock",ignored -> (t,cycles) ->
                    t.getIndex()==0?SIMULATION_RESULT.ERROR:t.getIndex()%2==0?SIMULATION_RESULT.FAIL:SIMULATION_RESULT.SUCCESS,
                    false,4,2,true,false,false,disabled,ordinal -> ordinal<6,
                    new AdaptiveAttackerRunner.Scheduling(policy,AdaptiveAttackerRunner.Continuation.INPUT,0),events::add)
                    .run(tests,tests,atoms);
            assertEquals(2,result.uniqueSignatures());
            assertEquals(2,result.stats().unsupported());
            assertEquals(1,result.stats().failureCount());
            assertEquals(disabled?6:4,result.stats().executed());
            assertEquals(disabled?5:3,events.size());
            assertEquals(disabled?0:1,result.stats().skippedPositive());
            assertEquals(disabled?0:1,result.stats().skippedNegative());
            assertNull(result.results()[0]);
            assertNull(result.results()[6]);
            assertNull(result.results()[7]);
            assertTrue(result.results()[4].isAdversaryDistinguishable());
            assertFalse(result.results()[5].isAdversaryDistinguishable());
        }
    }

    @Test
    void unsupportedCasesAreExcludedBeforeSignaturesAndNeverBecomeNegativeEvidence() {
        var tests = List.of(test(20), test(21));
        var evidence = Map.of(0, timedAtoms(), 1, withOrdinal(timedAtoms(),1,21));
        for (boolean relations : new boolean[]{false,true}) {
            var calls = new java.util.concurrent.atomic.AtomicInteger();
            var runner = new AdaptiveAttackerRunner(Path.of("unused"),"ROCKET_TEST", ignored ->
                    (test,maxCycles) -> { calls.incrementAndGet(); assertEquals(21,test.getIndex());
                        return SIMULATION_RESULT.SUCCESS; }, false,2,1,true,relations,relations,false,
                    ordinal -> ordinal == 1);
            var result = runner.run(tests,tests,evidence);
            assertEquals(1,calls.get());
            assertEquals(1,result.stats().unsupported());
            assertEquals(1,result.stats().executed());
            assertEquals(0,result.stats().failureCount());
            assertNull(result.results()[0]);
            assertFalse(result.results()[1].isAdversaryDistinguishable());
            assertEquals(21,result.results()[1].getIndex());
        }
    }
    private static final RISCVObservation EARLY =
            new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.IMM);
    private static final RISCVObservation LATE =
            new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.REG_RD);
    private static final RISCVObservation NOP_TAIL_DEPENDENCY =
            new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.RAW_RS1_4);
    private static final RISCVObservation FALSE_SUFFIX_CONTROL =
            new RISCVObservation(RISCV_TYPE.JALR, RISCV_OBSERVATION_TYPE.IS_BRANCH);
    private static final Pair<RISCV_TYPE, RISCV_TYPE> EARLY_PAIR =
            new Pair<>(RISCV_TYPE.JALR, RISCV_TYPE.ADDI);
    private static final Pair<RISCV_TYPE, RISCV_TYPE> LATE_PAIR =
            new Pair<>(RISCV_TYPE.ANDI, RISCV_TYPE.ADDI);

    @Test
    void filtersExecutedPositiveButPreservesSkippedPositiveEvidence() {
        List<TestCase> tests = List.of(test(10), test(11));
        SpikeAtomClient.SpikeCaseAtoms timed = timedAtoms();
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spike = Map.of(
                0, withOrdinal(timed, 0, 10),
                1, withOrdinal(timed, 1, 11));

        AdaptiveAttackerRunner.Result result = runner(SIMULATION_RESULT.FAIL, OptionalInt.of(34), true)
                .run(tests, tests, spike);

        assertEquals(Set.of(EARLY), observations(result.results()[0]));
        assertEquals(Set.of(EARLY, LATE), observations(result.results()[1]));
        assertEquals(Set.of(EARLY_PAIR), instructionPairs(result.results()[0]));
        assertEquals(Set.of(EARLY_PAIR, LATE_PAIR), instructionPairs(result.results()[1]));
        assertEquals(1, result.stats().executed());
        assertEquals(1, result.stats().skippedPositive());
    }

    @Test
    void disablingAdaptiveSkippingExecutesEveryPositiveInAnExactSignature() {
        List<TestCase> tests = List.of(test(12), test(13));
        SpikeAtomClient.SpikeCaseAtoms timed = timedAtoms();
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spike = Map.of(
                0, withOrdinal(timed, 0, 12),
                1, withOrdinal(timed, 1, 13));

        AdaptiveAttackerRunner.Result result = runner(
                SIMULATION_RESULT.FAIL, OptionalInt.of(34), false, true)
                .run(tests, tests, spike);

        assertEquals(Set.of(EARLY), observations(result.results()[0]));
        assertEquals(Set.of(EARLY), observations(result.results()[1]));
        assertEquals(Set.of(EARLY_PAIR), instructionPairs(result.results()[0]));
        assertEquals(Set.of(EARLY_PAIR), instructionPairs(result.results()[1]));
        assertEquals(2, result.stats().executed());
        assertEquals(0, result.stats().skippedPositive());
        assertEquals(0, result.stats().skippedNegative());
        assertEquals(0, result.stats().skippedPositiveSuperset());
        assertEquals(0, result.stats().skippedNegativeSubset());
    }

    @Test
    void executedNegativeWithoutBoundaryRetainsAllBoundedSpikeAtoms() {
        TestCase test = test(20);
        AdaptiveAttackerRunner.Result result = runner(SIMULATION_RESULT.SUCCESS, OptionalInt.empty(), false)
                .run(List.of(test), List.of(test), Map.of(0, timedAtoms()));

        assertEquals(Set.of(EARLY, LATE), observations(result.results()[0]));
        assertEquals(Set.of(EARLY_PAIR, LATE_PAIR), instructionPairs(result.results()[0]));
        assertFalse(result.results()[0].isAdversaryDistinguishable());
        assertEquals(0, result.stats().failureCount());
    }

    @Test
    void executedNegativeFiltersEvidenceAfterNativeExecutionCutoff() {
        TestCase test = test(21);
        AdaptiveAttackerRunner.Result result = runner(
                SIMULATION_RESULT.SUCCESS, OptionalInt.empty(), OptionalInt.of(34), false, false)
                .run(List.of(test), List.of(test), Map.of(0, timedAtoms()));

        assertEquals(Set.of(EARLY), observations(result.results()[0]));
        assertEquals(Set.of(EARLY_PAIR), instructionPairs(result.results()[0]));
        assertFalse(result.results()[0].isAdversaryDistinguishable());
        assertEquals(0, result.stats().failureCount());
    }

    @Test
    void negativeBoundaryKeepsOnlyAddiDependencyTail() {
        TestCase test = test(22);
        SpikeAtomClient.SpikeCaseAtoms spike = new SpikeAtomClient.SpikeCaseAtoms(
                0, 22,
                Set.of(EARLY, NOP_TAIL_DEPENDENCY, FALSE_SUFFIX_CONTROL),
                Map.of(EARLY, 34, NOP_TAIL_DEPENDENCY, 38, FALSE_SUFFIX_CONTROL, 36),
                Set.of(LATE_PAIR), Map.of(LATE_PAIR, 36), null);
        AdaptiveAttackerRunner.Result result = runner(
                SIMULATION_RESULT.SUCCESS, OptionalInt.empty(), OptionalInt.of(34), false, false)
                .run(List.of(test), List.of(test), Map.of(0, spike));

        assertEquals(Set.of(EARLY, NOP_TAIL_DEPENDENCY), observations(result.results()[0]));
        assertEquals(Set.of(), instructionPairs(result.results()[0]));
    }

    @Test
    void positiveWithoutCutoffIsRejected() {
        TestCase test = test(30);
        AdaptiveAttackerRunner.Result result = runner(SIMULATION_RESULT.FAIL, OptionalInt.empty(), false)
                .run(List.of(test), List.of(test), Map.of(0, timedAtoms()));

        assertNull(result.results()[0]);
        assertEquals(1, result.stats().failureCount());
        assertTrue(result.failures().get(0).contains("no failure cutoff"));
    }

    @Test
    void positiveWithOnlyPostCutoffAtomsIsRejected() {
        TestCase test = test(40);
        SpikeAtomClient.SpikeCaseAtoms lateOnly = new SpikeAtomClient.SpikeCaseAtoms(
                0, 40, Set.of(LATE), Map.of(LATE, 36), null);
        AdaptiveAttackerRunner.Result result = runner(SIMULATION_RESULT.FAIL, OptionalInt.of(34), false)
                .run(List.of(test), List.of(test), Map.of(0, lateOnly));

        assertNull(result.results()[0]);
        assertEquals(1, result.stats().failureCount());
        assertTrue(result.failures().get(0).contains("no Spike evidence occurs by failure cutoff"));
    }

    private static AdaptiveAttackerRunner runner(
            SIMULATION_RESULT status,
            OptionalInt cutoff,
            boolean useSkippedEvidence
    ) {
        return runner(status, cutoff, useSkippedEvidence, false);
    }

    private static AdaptiveAttackerRunner runner(
            SIMULATION_RESULT status,
            OptionalInt cutoff,
            boolean useSkippedEvidence,
            boolean disableAdaptiveSkipping
    ) {
        return runner(status, cutoff, OptionalInt.empty(), useSkippedEvidence, disableAdaptiveSkipping);
    }

    private static AdaptiveAttackerRunner runner(
            SIMULATION_RESULT status,
            OptionalInt cutoff,
            OptionalInt executionCutoff,
            boolean useSkippedEvidence,
            boolean disableAdaptiveSkipping
    ) {
        return new AdaptiveAttackerRunner(
                Path.of("unused"),
                "IBEX_TEST",
                ignored -> new AttackerHarnessClient() {
                    @Override
                    public SIMULATION_RESULT run(TestCase test, int maxCycles) {
                        return status;
                    }

                    @Override
                    public AttackerResult runDetailed(TestCase test, int maxCycles) {
                        return new AttackerResult(status, cutoff, executionCutoff);
                    }
                },
                true, 1, 0, useSkippedEvidence, false, false, disableAdaptiveSkipping);
    }

    private static SpikeAtomClient.SpikeCaseAtoms timedAtoms() {
        return new SpikeAtomClient.SpikeCaseAtoms(
                0, 20,
                Set.of(EARLY, LATE), Map.of(EARLY, 34, LATE, 36),
                Set.of(EARLY_PAIR, LATE_PAIR), Map.of(EARLY_PAIR, 34, LATE_PAIR, 36),
                null);
    }

    private static SpikeAtomClient.SpikeCaseAtoms withOrdinal(
            SpikeAtomClient.SpikeCaseAtoms source,
            int ordinal,
            int index
    ) {
        return new SpikeAtomClient.SpikeCaseAtoms(
                ordinal, index, source.atoms(), source.firstRetire(),
                source.instructionPairs(), source.pairFirstRetire(), source.error());
    }

    private static TestCase test(int index) {
        RISCVProgram program = new RISCVProgram(Map.of(), List.of(RISCVInstruction.NOP()));
        return new RISCVTestCase(program, program, 2, index);
    }

    private static Set<Observation> observations(RISCVTestResult result) {
        return Set.copyOf(result.getDistinguishingObservations());
    }

    private static Set<Pair<RISCV_TYPE, RISCV_TYPE>> instructionPairs(RISCVTestResult result) {
        return result.getDistinguishingInstructions().stream()
                .map(pair -> new Pair<>((RISCV_TYPE) pair.left(), (RISCV_TYPE) pair.right()))
                .collect(java.util.stream.Collectors.toSet());
    }
}
