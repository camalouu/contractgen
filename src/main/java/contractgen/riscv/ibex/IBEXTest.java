package contractgen.riscv.ibex;

import contractgen.MARCH;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.TestCases;
import contractgen.TestResult;
import contractgen.Updater;
import contractgen.riscv.isa.RISCV;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.util.StringUtils;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;

import static contractgen.util.FileUtils.copyFileOrFolder;
import static contractgen.util.ScriptUtils.runScript;
import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;

/**
 * Lean Verilator-only Ibex integration for replay/export parity experiments.
 */
public class IBEXTest extends MARCH {

    private static final String TEMPLATE_PATH = "/home/yosys/resources/ibex-test/";

    protected String BASE_PATH = "/home/yosys/output/ibex-test/generated/";
    protected String COMPILATION_PATH = "/home/yosys/output/ibex-test/compiled/";
    protected String SIMULATION_PATH = "/home/yosys/output/ibex-test/simulation/";

    public IBEXTest(Updater updater, TestCases testCases, Set<RISCV_OBSERVATION_TYPE> allowed_observations, Set<RISCV_SUBSET> isa, boolean isSP) {
        super(new RISCV(allowed_observations, isa, updater, testCases), (path, adversaryDistinguishable, index) -> new RISCVTestResult(Set.of(), Set.of(), adversaryDistinguishable, index));
    }

    @Override
    public boolean producesContractAtoms() {
        return false;
    }

    @Override
    public void generateSources(TestCase testCase, Integer max_count) {
        throw new UnsupportedOperationException("Not implemented");
    }

    @Override
    public String runCover(int steps) {
        throw new UnsupportedOperationException("Not implemented");
    }

    @Override
    public int extractSteps(String coverTrace) {
        throw new UnsupportedOperationException("Not implemented");
    }

    @Override
    public boolean run(int steps) {
        throw new UnsupportedOperationException("Not implemented");
    }

    @Override
    public TestResult extractCTX(TestCase testCase) {
        return extractCTX(SIMULATION_PATH, testCase);
    }

    @Override
    public TestResult extractCTX(int id, TestCase testCase) {
        return extractCTX(SIMULATION_PATH + id + "/", testCase);
    }

    private TestResult extractCTX(String path, TestCase testCase) {
        return extractDifferences(path, true, testCase.getIndex());
    }

    @Override
    public TestResult extractDifferences(int index) {
        return extractDifferences(SIMULATION_PATH, false, index);
    }

    @Override
    public TestResult extractDifferences(int id, int index) {
        return extractDifferences(SIMULATION_PATH + id + "/", false, index);
    }

    private TestResult extractDifferences(String path, boolean adversaryDistinguishable, int index) {
        return getExtractor().extractResults(path, adversaryDistinguishable, index);
    }

    @Override
    public void compile() {
        try {
            copyFileOrFolder(Path.of(TEMPLATE_PATH).toFile(), Path.of(BASE_PATH).toFile(), REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        String output = runScript("/bin/bash " + BASE_PATH + "compile-verilator.sh " + BASE_PATH + " " + COMPILATION_PATH, true, 240);
        if (output == null || output.contains("Process exited with code")) {
            throw new IllegalStateException("IBEX_TEST compilation failed:\n" + tail(output, 120));
        }
        System.out.println("Compilation finished.");
    }

    private static String tail(String output, int maxLines) {
        if (output == null) {
            return "<no output>";
        }
        String[] lines = output.split("\\R");
        int start = Math.max(0, lines.length - maxLines);
        return String.join(System.lineSeparator(), java.util.Arrays.copyOfRange(lines, start, lines.length));
    }

    @Override
    public void writeTestCase(TestCase testCase) {
        writeTestCase(SIMULATION_PATH, testCase);
    }

    @Override
    public void writeTestCase(int id, TestCase testCase) {
        writeTestCase(SIMULATION_PATH + id + "/", testCase);
    }

    private void writeTestCase(String path, TestCase testCase) {
        try {
            copyFileOrFolder(Path.of(COMPILATION_PATH + "ibex").toFile(), Path.of(path + "ibex").toFile(), REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        testCase.getProgram1().printInit(path + "init_1.dat");
        testCase.getProgram1().printInstr(path + "memory_1.dat");
        testCase.getProgram2().printInit(path + "init_2.dat");
        testCase.getProgram2().printInstr(path + "memory_2.dat");
        try {
            String content = StringUtils.toHexEncoding((long) (testCase.getMaxInstructionCount() + 31)) + System.lineSeparator();
            Files.writeString(Paths.get(path + "count.dat"), content);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public SIMULATION_RESULT simulate() {
        return simulate(SIMULATION_PATH);
    }

    @Override
    public SIMULATION_RESULT simulate(int id) {
        return simulate(SIMULATION_PATH + id + "/");
    }

    @Override
    public String getName() {
        return "ibex_test";
    }

    @Override
    public String getSimulationTracePath(int id) {
        return SIMULATION_PATH + id + "/" + "sim.vcd";
    }

    private SIMULATION_RESULT simulate(String path) {
        String output = runScript(path + "ibex", true, 30);
        assert output != null;
        if (output.contains("FAIL"))
            return SIMULATION_RESULT.FAIL;
        if (output.contains("FALSE_POSITIVE"))
            return SIMULATION_RESULT.FALSE_POSITIVE;
        if (output.contains("SUCCESS"))
            return SIMULATION_RESULT.SUCCESS;
        if (output.contains("TIMEOUT"))
            return SIMULATION_RESULT.TIMEOUT;
        if (output.contains("ERROR"))
            return SIMULATION_RESULT.ERROR;
        System.out.println(output);
        return SIMULATION_RESULT.UNKNOWN;
    }

}
