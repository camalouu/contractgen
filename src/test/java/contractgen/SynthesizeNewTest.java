package contractgen;

import org.junit.jupiter.api.Test;

import java.io.File;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;

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
}
