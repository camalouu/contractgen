package contractgen.refinement;

import contractgen.Observation;
import contractgen.TestResult;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ContractAmbiguityAnalyzerTest {
    private final RISCVObservation opcode = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.OPCODE);
    private final RISCVObservation funct3 = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.FUNCT3);

    @Test
    void findsAlternativeWithTheSameLexicographicObjective() {
        List<TestResult> evidence = List.of(result(Set.of(opcode, funct3), true, 0));

        ContractAmbiguityAnalyzer.Analysis analysis = new ContractAmbiguityAnalyzer().analyze(
                atoms(), evidence, Set.of(opcode));

        assertEquals(0, analysis.baseline().falsePositives());
        assertEquals(1, analysis.baseline().size());
        assertEquals(1, analysis.alternatives().size());
        ContractAmbiguityAnalyzer.Alternative alternative = analysis.alternatives().get(0);
        assertEquals(1, alternative.removed().size());
        assertEquals(1, alternative.added().size());
    }

    @Test
    void rejectsReplacementThatWorsensFalsePositives() {
        List<TestResult> evidence = List.of(
                result(Set.of(opcode, funct3), true, 0),
                result(Set.of(opcode), false, 1));

        ContractAmbiguityAnalyzer.Analysis analysis = new ContractAmbiguityAnalyzer().analyze(
                atoms(), evidence, Set.of(funct3));

        assertEquals(Set.of(funct3), analysis.baseline().contract());
        assertTrue(analysis.alternatives().isEmpty());
    }

    private Set<Observation> atoms() {
        return Set.of(opcode, funct3);
    }

    private static RISCVTestResult result(Set<RISCVObservation> observations, boolean distinguishable, int index) {
        return new RISCVTestResult(observations, Set.of(), distinguishable, index);
    }
}
