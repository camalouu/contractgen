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
    void parsesCv32e40sOptionsInBothNewWorkflowCommands() {
        var direct = new SynthesizeNew();
        new picocli.CommandLine(direct).parseArgs("-p", "CV32E40S_TEST", "-i", "BASE,M",
                "-c", "BASE", "-n", "1", "-t", "1", "-s", "1", "-o", "unused.json",
                "--cv32e40s-test-lib", "/tmp/cv32e40s.so", "--cv32e40s-data-independent-timing=on");
        assertEquals(ReplayAttackerHarness.CV32E40S_TEST, direct.processor);
        assertEquals(contractgen.riscv.cv32e40s_test.CV32E40STestAttackerClient.TimingMode.on, direct.cv32e40sTiming);
        assertEquals(new File("/tmp/cv32e40s.so"), direct.cv32e40sTestLib);

        var replay = new ReplaySynthesizeSpike();
        new picocli.CommandLine(replay).parseArgs("-p", "CV32E40S_TEST", "-i", "BASE,M",
                "-c", "BASE", "-t", "1", "-e", "unused-tests.json", "-o", "unused.json");
        assertEquals(contractgen.riscv.cv32e40s_test.CV32E40STestAttackerClient.TimingMode.off, replay.cv32e40sTiming);
        ReplaySynthesizeSpike.validateHarnessIsa(replay.processor, replay.isa);
    }

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
