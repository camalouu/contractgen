import com.google.ortools.Loader;
import com.google.ortools.linearsolver.MPSolver;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.SimpleAttackerHarnessClient;
import contractgen.riscv.ibex.IBEXTestAttackerClient;
import contractgen.riscv.cva6_test.CVA6TestAttackerClient;
import contractgen.riscv.hazard3_test.Hazard3TestAttackerClient;
import contractgen.riscv.proteus.ProteusTestAttackerClient;
import contractgen.riscv.cv32e40s_test.CV32E40STestAttackerClient;
import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.*;
import contractgen.riscv.isa.spike.*;
import java.nio.file.Path;
import java.util.*;

public class NativeSmoke {
    static void checkpoint(String message) {
        System.out.println("native-smoke: " + message);
        System.out.flush();
    }
    static Path library(String atom) {
        return Path.of(Objects.requireNonNull(System.getenv("CONTRACT_" + atom.toUpperCase() + "_LIB")));
    }
    static void runClient(AttackerHarnessClient client, TestCase testCase) {
        checkpoint("running " + client.getClass().getSimpleName());
        if (client.run(testCase, 10000) != SIMULATION_RESULT.SUCCESS)
            throw new AssertionError("Identical pair failed: " + client.getClass());
    }
    public static void main(String[] args) {
        if (args.length != 1) throw new IllegalArgumentException("expected one smoke target");
        var program = new RISCVProgram(Map.of(1, 17), List.of(RISCVInstruction.ADD(2, 1, 1)));
        TestCase identical = new RISCVTestCase(program, program, 4, 0);
        switch (args[0]) {
            case "ortools" -> {
                checkpoint("loading OR-Tools");
                Loader.loadNativeLibraries();
                var solver = MPSolver.createSolver("SCIP");
                if (solver == null) throw new AssertionError("SCIP unavailable");
                var x = solver.makeIntVar(0, 7, "x");
                solver.objective().setCoefficient(x, 1);
                solver.objective().setMaximization();
                if (solver.solve() != MPSolver.ResultStatus.OPTIMAL || x.solutionValue() != 7)
                    throw new AssertionError("OR-Tools solve failed");
                solver.delete();
                checkpoint("OR-Tools solve passed");
            }
            case "ibex_test" -> runClient(new IBEXTestAttackerClient(library(args[0])), identical);
            case "cva6_test" -> runClient(new CVA6TestAttackerClient(library(args[0])), identical);
            case "hazard3_test" -> runClient(new Hazard3TestAttackerClient(library(args[0])), identical);
            case "proteus_test" -> runClient(new ProteusTestAttackerClient(library(args[0])), identical);
            case "sodor_2_test", "darkriscv_2_test", "fwrisc_test", "cv32e40p_test" ->
                runClient(new SimpleAttackerHarnessClient(library(args[0]), args[0].toUpperCase()), identical);
            case "cv32e40s_test" -> {
                var off = new CV32E40STestAttackerClient(library(args[0]), CV32E40STestAttackerClient.TimingMode.off);
                var on = new CV32E40STestAttackerClient(library(args[0]), CV32E40STestAttackerClient.TimingMode.on);
                runClient(off, identical);
                runClient(on, identical);
                checkpoint("running CV32E40S timing fixture");
                var instructions = List.of(RISCVInstruction.DIVU(3, 1, 2), RISCVInstruction.NOP());
                TestCase variableDivision = new RISCVTestCase(
                        new RISCVProgram(Map.of(1, 100, 2, 1), instructions),
                        new RISCVProgram(Map.of(1, 100, 2, 100), instructions), 8, 1);
                if (off.run(variableDivision, 10000) != SIMULATION_RESULT.FAIL
                        || on.run(variableDivision, 10000) != SIMULATION_RESULT.SUCCESS)
                    throw new AssertionError("CV32E40S timing-mode fixture failed");
            }
            case "spike" -> {
                var atoms = new SpikeAtomParallelRunner(library(args[0]), "rv32im",
                        EnumSet.allOf(RISCV_OBSERVATION_TYPE.class), 2).run(List.of(identical));
                if (atoms.size() != 1 || !atoms.get(0).atoms().isEmpty() || atoms.get(0).error() != null)
                    throw new AssertionError("Identical pair produced atoms: " + atoms);
                checkpoint("parallel Spike workers passed");
            }
            default -> throw new IllegalArgumentException("unknown smoke target: " + args[0]);
        }
    }
}
