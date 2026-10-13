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
    void schedulingOptionsAreSharedByDirectAndReplayWorkflows() {
        var direct=new SynthesizeNew();
        new picocli.CommandLine(direct).parseArgs("-p","IBEX_TEST","-i","BASE,M","-c","BASE","-n","10","-t","4",
                "-s","35","-o","unused.json","--scheduling-policy","breadth-once",
                "--breadth-continuation","random","--scheduling-seed","42","--query-log","queries.jsonl");
        assertEquals(contractgen.riscv.AdaptiveAttackerRunner.Policy.BREADTH_ONCE,direct.scheduling.policy);
        assertEquals(contractgen.riscv.AdaptiveAttackerRunner.Continuation.RANDOM,direct.scheduling.continuation);
        assertEquals(42,direct.scheduling.seed);
        assertEquals(35,direct.seed);
        assertEquals(new File("queries.jsonl"),direct.scheduling.queryLog);
        var replay=new ReplaySynthesizeSpike();
        new picocli.CommandLine(replay).parseArgs("-i","BASE,M","-c","BASE","-t","4",
                "-e","cases.json","-o","unused.json","--scheduling-policy","breadth-every-round");
        assertEquals(contractgen.riscv.AdaptiveAttackerRunner.Policy.BREADTH_EVERY_ROUND,replay.scheduling.policy);
        assertEquals(contractgen.riscv.AdaptiveAttackerRunner.Policy.GROUPED,new SynthesizeNew().scheduling.policy);
        assertThrows(IllegalArgumentException.class,()->direct.scheduling.validate(true));
        replay.scheduling.queryLog=new File("cases.json");
        assertThrows(IllegalArgumentException.class,()->replay.scheduling.validatePaths(Path.of("unused.json"),Path.of("cases.json"),null));
    }

    @Test
    void executionModelIsExplicitAndValidatedSeparatelyFromProcessor() {
        var direct = new SynthesizeNew();
        new picocli.CommandLine(direct).parseArgs("-p", "ROCKET_TEST", "-i", "BASE,M",
                "-c", "BASE", "-n", "1", "-t", "1", "-s", "1", "-o", "unused.json",
                "--execution-model", "rv32-v1", "--rocket-test-lib", "/tmp/rocket.so");
        assertEquals(contractgen.riscv.isa.spike.ExecutionModel.RV32_V1, direct.executionModel);
        assertEquals(new File("/tmp/rocket.so"), direct.rocketTestLib);
        ReplaySynthesizeSpike.validateExecutionModel(direct.processor, direct.executionModel);
        for (var processor : ReplayAttackerHarness.values())
            ReplaySynthesizeSpike.validateExecutionModel(processor, direct.executionModel);
        assertThrows(picocli.CommandLine.ParameterException.class, () ->
                new picocli.CommandLine(new SynthesizeNew()).parseArgs("--execution-model", "legacy-v1"));
        assertEquals(contractgen.riscv.isa.spike.ExecutionModel.RV32_V1, new SynthesizeNew().executionModel);
        assertEquals(contractgen.riscv.isa.spike.ExecutionModel.RV32_V1, new ReplaySynthesizeSpike().executionModel);
    }

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
    void preventsArtifactsSummariesAndSidecarsFromOverwritingEachOther() {
        assertThrows(IllegalArgumentException.class, () -> SynthesizeNew.resolveOutputs(null,
                new File("same.json"), new File("./same.json"), null));
        assertThrows(IllegalArgumentException.class, () -> SynthesizeNew.resolveOutputs(null,
                new File("cases.json.execution.json"), new File("cases.json"), null));
        assertThrows(IllegalArgumentException.class, () -> SynthesizeNew.resolveOutputs(null,
                new File("contract.json"), new File("cases.json"), new File("contract.json.execution.json")));
        var replay = new ReplaySynthesizeSpike();
        replay.testcases = new File("cases.json");
        replay.out = new File("cases.json.execution.json");
        assertThrows(IllegalArgumentException.class, replay::call);
        replay.out = new File("./cases.json");
        assertThrows(IllegalArgumentException.class, replay::call);
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
    void importedMInstructionsCannotBypassRv32ICoreValidation() {
        var program = new contractgen.riscv.isa.RISCVProgram(java.util.Map.of(),
                java.util.List.of(contractgen.riscv.isa.RISCVInstruction.MUL(1, 2, 3)));
        var testcase = new contractgen.riscv.isa.RISCVTestCase(program, program, 2, 7);
        for (var processor : java.util.List.of(ReplayAttackerHarness.SODOR_2_TEST,
                ReplayAttackerHarness.DARKRISCV_2_TEST))
            assertThrows(IllegalArgumentException.class, () ->
                    ReplaySynthesizeSpike.validateImportedHarnessIsa(processor, java.util.List.of(testcase)));
        ReplaySynthesizeSpike.validateImportedHarnessIsa(ReplayAttackerHarness.ROCKET_TEST,
                java.util.List.of(testcase));
    }

    @Test
    void permitsMForFwrisc() {
        ReplaySynthesizeSpike.validateHarnessIsa(
                ReplayAttackerHarness.FWRISC_TEST, Set.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M));
    }
}
