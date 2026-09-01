package contractgen;

import org.junit.jupiter.api.Test;

import java.io.File;
import java.nio.file.Path;
import java.util.Set;

import contractgen.riscv.isa.RISCV_SUBSET;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SynthesizeNewTest {
    @Test
    void derivesTestcasePathBesideContractOutput() {
        assertEquals(
                Path.of("results/hazard3-testcases.json"),
                SynthesizeNew.resolveTestcasesOutput(new File("results/hazard3.json"), null));
    }

    @Test
    void derivesTestcasePathWhenContractHasNoExtension() {
        assertEquals(
                Path.of("results/hazard3-testcases.json"),
                SynthesizeNew.resolveTestcasesOutput(new File("results/hazard3"), null));
    }

    @Test
    void honorsExplicitTestcasePath() {
        assertEquals(
                Path.of("exports/exact-tests.json"),
                SynthesizeNew.resolveTestcasesOutput(
                        new File("results/hazard3.json"), new File("exports/exact-tests.json")));
    }

    @Test
    void derivesStableNamesFromOutputDirectory() {
        assertEquals(
                new SynthesizeNew.OutputPaths(
                        Path.of("results/run/contract.json"),
                        Path.of("results/run/testcases.json"),
                        Path.of("results/run/summary.txt")),
                SynthesizeNew.resolveOutputs(new File("results/run"), null, null, null));
    }

    @Test
    void rejectsMixedOutputStyles() {
        assertThrows(IllegalArgumentException.class, () -> SynthesizeNew.resolveOutputs(
                new File("results/run"), new File("contract.json"), null, null));
    }

    @Test
    void requiresOneOutputStyle() {
        assertThrows(IllegalArgumentException.class,
                () -> SynthesizeNew.resolveOutputs(null, null, null, null));
    }

    @Test
    void rejectsMForCheckedInSodorAndDarkriscvVariants() {
        assertThrows(IllegalArgumentException.class, () -> ReplaySynthesizeSpike.validateHarnessIsa(
                ReplayAttackerHarness.SODOR_2_TEST, Set.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M)));
        assertThrows(IllegalArgumentException.class, () -> ReplaySynthesizeSpike.validateHarnessIsa(
                ReplayAttackerHarness.DARKRISCV_2_TEST, Set.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M)));
    }

    @Test
    void permitsMForFwrisc() {
        ReplaySynthesizeSpike.validateHarnessIsa(
                ReplayAttackerHarness.FWRISC_TEST, Set.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M));
    }
}
