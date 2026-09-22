package contractgen.riscv.hazard3_test;

import contractgen.TestCases;
import contractgen.Updater;
import contractgen.riscv.ibex.IBEXTest;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Set;

import static contractgen.util.FileUtils.copyFileOrFolder;
import static contractgen.util.ScriptUtils.runScript;
import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;

/** Attacker-only Hazard3 integration. Spike supplies all contract atoms. */
public final class Hazard3Test extends IBEXTest {
    private static final String TEMPLATE_PATH = contractgen.util.RuntimePaths.resource("hazard3-test/").toString() + "/";

    public Hazard3Test(Updater updater, TestCases testCases,
                       Set<RISCV_OBSERVATION_TYPE> allowedObservations,
                       Set<RISCV_SUBSET> isa, boolean isSP) {
        super(updater, testCases, allowedObservations, isa, isSP);
        BASE_PATH = contractgen.util.RuntimePaths.work("hazard3-test/generated/").toString() + "/";
        COMPILATION_PATH = contractgen.util.RuntimePaths.work("hazard3-test/compiled/").toString() + "/";
        SIMULATION_PATH = contractgen.util.RuntimePaths.work("hazard3-test/simulation/").toString() + "/";
    }

    @Override
    public void compile() {
        try {
            copyFileOrFolder(Path.of(TEMPLATE_PATH).toFile(), Path.of(BASE_PATH).toFile(), REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        String output = runScript(java.util.List.of("bash", BASE_PATH + "compile-verilator.sh", BASE_PATH, COMPILATION_PATH), java.nio.file.Path.of(BASE_PATH), true, 240);
        if (output == null || output.contains("Process exited with code")) {
            throw new IllegalStateException("HAZARD3_TEST compilation failed:\n" + tail(output, 120));
        }
        System.out.println("Compilation finished.");
    }

    @Override
    public String getName() {
        return "hazard3_test";
    }

    private static String tail(String output, int maxLines) {
        if (output == null) return "<no output>";
        String[] lines = output.split("\\R");
        int start = Math.max(0, lines.length - maxLines);
        return String.join(System.lineSeparator(), java.util.Arrays.copyOfRange(lines, start, lines.length));
    }
}
