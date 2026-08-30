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
