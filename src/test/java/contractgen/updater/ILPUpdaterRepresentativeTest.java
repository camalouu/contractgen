package contractgen.updater;

import contractgen.TestResult;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ILPUpdaterRepresentativeTest {
    private static final RISCVObservation ADD_RS1 =
            new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.REG_RS1);
    private static final RISCVObservation SUB_RS1 =
            new RISCVObservation(RISCV_TYPE.SUB, RISCV_OBSERVATION_TYPE.REG_RS1);

    @Test
    void repeatedNegativeObservationsRetainOneObjectiveTerm() {
        List<TestResult> results = new ArrayList<>();
        results.add(new RISCVTestResult(Set.of(ADD_RS1), Set.of(), true, 0));
        for (int i = 1; i <= 1000; i++) {
            results.add(new RISCVTestResult(Set.of(ADD_RS1), Set.of(), false, i));
        }

        ILPUpdater.Solution result = new ILPUpdater().solve(
                Set.of(ADD_RS1, SUB_RS1), results, Set.of(), Set.of(), Set.of());

        assertTrue(result.isOptimal());
        assertEquals(Set.of(ADD_RS1), result.contract());
        assertEquals(1, result.falsePositives());
        assertEquals(1, result.size());
    }

    @Test
    void lastEqualNegativeDeterminesTheExistingObjective() {
        var coveredPair = new Pair<>(RISCV_TYPE.ADD, RISCV_TYPE.SUB);
        var uncoveredPair = new Pair<>(RISCV_TYPE.SUB, RISCV_TYPE.SUB);
        var positive = new RISCVTestResult(Set.of(ADD_RS1), Set.of(), true, 0);
        var covered = new RISCVTestResult(Set.of(), Set.of(coveredPair), false, 1);
        var uncovered = new RISCVTestResult(Set.of(), Set.of(uncoveredPair), false, 2);

        ILPUpdater.Solution uncoveredLast = new ILPUpdater().solve(
                Set.of(ADD_RS1, SUB_RS1), List.of(positive, covered, uncovered),
                Set.of(), Set.of(), Set.of(SUB_RS1));
        ILPUpdater.Solution coveredLast = new ILPUpdater().solve(
                Set.of(ADD_RS1, SUB_RS1), List.of(positive, uncovered, covered),
                Set.of(), Set.of(), Set.of(SUB_RS1));

        assertTrue(uncoveredLast.isOptimal());
        assertTrue(coveredLast.isOptimal());
        assertEquals(Set.of(ADD_RS1), uncoveredLast.contract());
        assertEquals(Set.of(ADD_RS1), coveredLast.contract());
        assertEquals(0, uncoveredLast.falsePositives());
        assertEquals(1, coveredLast.falsePositives());
    }
}
