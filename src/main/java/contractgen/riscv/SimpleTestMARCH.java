package contractgen.riscv;

import contractgen.TestCases;
import contractgen.Updater;
import contractgen.riscv.ibex.IBEXTest;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Set;

import static contractgen.util.FileUtils.copyFileOrFolder;
import static contractgen.util.ScriptUtils.runScript;
import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;

/**
 * Minimal MARCH adapter for attacker-only shared-library harnesses.
 * Contract atoms are supplied by Spike; this class only builds the RTL side.
 */
public final class SimpleTestMARCH extends IBEXTest {
    private final String resourceName;
    private final String displayName;

    public SimpleTestMARCH(
            Updater updater,
            TestCases testCases,
            Set<RISCV_OBSERVATION_TYPE> allowedObservations,
            Set<RISCV_SUBSET> isa,
            String resourceName,
            String displayName
    ) {
        super(updater, testCases, allowedObservations, isa, false);
        this.resourceName = resourceName;
        this.displayName = displayName;
        BASE_PATH = contractgen.util.RuntimePaths.work(resourceName + "/generated").toString() + "/";
        COMPILATION_PATH = contractgen.util.RuntimePaths.work(resourceName + "/compiled").toString() + "/";
        SIMULATION_PATH = contractgen.util.RuntimePaths.work(resourceName + "/simulation").toString() + "/";
    }

    @Override
    public void compile() {
        String configuredTimeout = System.getenv("CONTRACT_BUILD_TIMEOUT_SECONDS");
        int timeout = configuredTimeout == null || configuredTimeout.isBlank()
                ? 240 : Integer.parseInt(configuredTimeout);
        if (timeout <= 0) throw new IllegalArgumentException("CONTRACT_BUILD_TIMEOUT_SECONDS must be positive");
        String templatePath = contractgen.util.RuntimePaths.resource(resourceName).toString() + "/";
        try {
            copyFileOrFolder(Path.of(templatePath).toFile(), Path.of(BASE_PATH).toFile(), REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        String output = runScript(
                java.util.List.of("bash", BASE_PATH + "compile-verilator.sh", BASE_PATH, COMPILATION_PATH), java.nio.file.Path.of(BASE_PATH),
                true,
                timeout);
        if (output == null || output.contains("Process exited with code")) {
            throw new IllegalStateException(displayName + " compilation failed:\n" + tail(output, 120));
        }
        System.out.println(displayName + " compilation finished.");
    }

    @Override
    public String getName() {
        return displayName.toLowerCase(java.util.Locale.ROOT);
    }

    private static String tail(String output, int maxLines) {
        if (output == null) {
            return "<no output>";
        }
        String[] lines = output.split("\\R");
        int start = Math.max(0, lines.length - maxLines);
        return String.join(System.lineSeparator(), Arrays.copyOfRange(lines, start, lines.length));
    }
}
