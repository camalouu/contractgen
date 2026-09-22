package contractgen.riscv.hazard3;

import contractgen.*;
import contractgen.riscv.isa.RISCV;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.extractor.RVFIExtractor;
import contractgen.util.StringUtils;
import contractgen.util.vcd.VcdFile;

import java.util.Set;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import static contractgen.util.FileUtils.copyFileOrFolder;
import static contractgen.util.ScriptUtils.runScript;
import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;

/**
 * The Hazard3 microarchitecture.
 */
public class HAZARD3 extends MARCH {

    private static final String TEMPLATE_PATH = contractgen.util.RuntimePaths.resource("hazard3/").toString() + "/";
    protected String BASE_PATH = contractgen.util.RuntimePaths.work("hazard3/generated/").toString() + "/";
    protected String COMPILATION_PATH = contractgen.util.RuntimePaths.work("hazard3/compiled/").toString() + "/";
    protected String SIMULATION_PATH = contractgen.util.RuntimePaths.work("hazard3/simulation/").toString() + "/";

    private final boolean useVerilator;

    public HAZARD3(Updater updater, TestCases testCases, Set<RISCV_OBSERVATION_TYPE> allowed_observations, Set<RISCV_SUBSET> isa, boolean isSP, boolean useVerilator) {
        super(new RISCV(allowed_observations, isa, updater, testCases), new RVFIExtractor(allowed_observations, isSP));
        this.useVerilator = useVerilator;
    }

    public HAZARD3(Updater updater, TestCases testCases, Set<RISCV_OBSERVATION_TYPE> allowed_observations, Set<RISCV_SUBSET> isa, boolean isSP, Set<RISCV_TYPE> unsafeInstructions, boolean useVerilator) {
        super(new RISCV(allowed_observations, isa, updater, testCases), new RVFIExtractor(allowed_observations, isSP, unsafeInstructions));
        this.useVerilator = useVerilator;
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

    private TestResult extractCTX(String PATH, TestCase testCase) {
        VcdFile vcd;
        try {
            vcd = new VcdFile(Files.readString(Path.of(PATH + "sim.vcd")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        int failTime = vcd.getTop().getChild("atk").getWire("atk_equiv_o").getLastChangeTime();
        int fetch_1 = (int) StringUtils.fromBinary(vcd.getTop().getChild("control").getWire("fetch_1_count").getValueAt(failTime));
        int fetch_2 = (int) StringUtils.fromBinary(vcd.getTop().getChild("control").getWire("fetch_2_count").getValueAt(failTime));
        int retire = (int) StringUtils.fromBinary(vcd.getTop().getChild("control").getWire("retire_count").getValueAt(failTime));
        int currentGuess = Integer.max(fetch_1, fetch_2);
        while (currentGuess >= retire && simulateSteps(PATH, currentGuess) == SIMULATION_RESULT.FAIL) {
            currentGuess--;
        }
        simulateSteps(PATH, currentGuess + 1);
        return extractDifferences(PATH, true, testCase.getIndex());
    }

    @Override
    public TestResult extractDifferences(int index) {
        return extractDifferences(SIMULATION_PATH, false, index);
    }

    @Override
    public TestResult extractDifferences(int id, int index) {
        return extractDifferences(SIMULATION_PATH + id + "/", false, index);
    }

    private TestResult extractDifferences(String PATH, boolean adversaryDistinguishable, int index) {
        return getExtractor().extractResults(PATH, adversaryDistinguishable, index);
    }

    @Override
    public void compile() {
        try {
            copyFileOrFolder(Path.of(TEMPLATE_PATH).toFile(), Path.of(BASE_PATH).toFile(), REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        // No inline contract replacement here, verilator config handles the rest.
        String output;
        if (useVerilator) {
            output = runScript(java.util.List.of("bash", BASE_PATH + "compile-verilator.sh", BASE_PATH, COMPILATION_PATH), java.nio.file.Path.of(BASE_PATH), false, 240);
        } else {
            output = runScript(java.util.List.of("bash", BASE_PATH + "compile.sh", BASE_PATH, COMPILATION_PATH), java.nio.file.Path.of(BASE_PATH), false, 240);
        }
        System.out.println(output);
        System.out.println("Compilation finished.");
    }

    @Override
    public void writeTestCase(TestCase testCase) {
        writeTestCase(SIMULATION_PATH, testCase);
    }

    @Override
    public void writeTestCase(int id, TestCase testCase) {
        writeTestCase(SIMULATION_PATH + id + "/", testCase);
    }

    private void writeTestCase(String PATH, TestCase testCase) {
        try {
            copyFileOrFolder(Path.of(COMPILATION_PATH + "hazard3").toFile(), Path.of(PATH + "hazard3").toFile(), REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        testCase.getProgram1().printInit(PATH + "init_1.dat");
        testCase.getProgram1().printInstr(PATH + "memory_1.dat");
        testCase.getProgram2().printInit(PATH + "init_2.dat");
        testCase.getProgram2().printInstr(PATH + "memory_2.dat");
        try {
            String content = StringUtils.toHexEncoding((long) (testCase.getMaxInstructionCount() + 31)) + System.lineSeparator();
            Files.writeString(Paths.get(PATH + "count.dat"), content);
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
        return "hazard3";
    }

    private SIMULATION_RESULT simulate(String PATH) {
        String output = runScript(PATH + "hazard3", true, 30);
        assert output != null;
        if (output.contains("FAIL"))
            return SIMULATION_RESULT.FAIL;
        if (output.contains("FALSE_POSITIVE"))
            return SIMULATION_RESULT.FALSE_POSITIVE;
        if (output.contains("SUCCESS"))
            return SIMULATION_RESULT.SUCCESS;
        if (output.contains("TIMEOUT"))
            return SIMULATION_RESULT.TIMEOUT;
        if (output.contains("ERROR")) {
            System.out.println(output);
            return SIMULATION_RESULT.ERROR;
        }
        System.out.println(output);
        return SIMULATION_RESULT.UNKNOWN;
    }

    private SIMULATION_RESULT simulateSteps(String PATH, int steps) {
        try {
            String content = StringUtils.toHexEncoding((long) steps) + System.lineSeparator();
            Files.writeString(Paths.get(PATH + "count.dat"), content);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return simulate(PATH);
    }

    public String getSimulationTracePath(int id) {
        return SIMULATION_PATH + id + "/" + "sim.vcd";
    }
}
