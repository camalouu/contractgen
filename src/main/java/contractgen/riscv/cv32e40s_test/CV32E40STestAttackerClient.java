package contractgen.riscv.cv32e40s_test;

import com.sun.jna.Library;
import com.sun.jna.Native;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.AttackerProgramImages;

import java.nio.file.Path;
import java.util.List;
import java.util.Objects;

/** Attacker labels only; complete contract evidence is supplied by Spike. */
public final class CV32E40STestAttackerClient implements AttackerHarnessClient {
    public enum TimingMode { off, on }
    public static final String RTL_REVISION = "d45d7b4c02a353d093de3efdf0569486d9a506c5";
    private final CV32E40SLibrary library;
    private final TimingMode timing;

    private interface CV32E40SLibrary extends Library {
        int contract_cv32e40s_test_attacker_batch_v1(
                int caseCount, int maxCycles, int dataIndependentTiming,
                int[] caseIndices, int[] maxInstructionCounts,
                int[] program1, int[] program2, int[] statuses);
    }

    public CV32E40STestAttackerClient(Path path, TimingMode timing) {
        this.timing = Objects.requireNonNull(timing);
        library = Native.load(path.toAbsolutePath().toString(), CV32E40SLibrary.class);
    }

    public static String configuration(TimingMode timing) {
        return "CV32E40S: dataindtiming=" + timing
                + ", pc_hardening=off, integrity=on, rnddummy=off, rndhint=off"
                + ", RTL=" + RTL_REVISION + " (0.10.0)";
    }

    public List<SIMULATION_RESULT> runAll(List<TestCase> tests, int maxCycles) {
        if (tests.isEmpty()) return List.of();
        AttackerProgramImages.Batch input = AttackerProgramImages.encode(tests, "CV32E40S_TEST");
        int[] statuses = new int[tests.size()];
        int result;
        try {
            result = library.contract_cv32e40s_test_attacker_batch_v1(
                    tests.size(), maxCycles, timing == TimingMode.on ? 1 : 0,
                    input.caseIndices(), input.maxInstructionCounts(), input.program1(), input.program2(), statuses);
        } catch (UnsatisfiedLinkError error) {
            throw new IllegalStateException("CV32E40S_TEST library is stale: missing "
                    + "contract_cv32e40s_test_attacker_batch_v1; rebuild the library", error);
        }
        if (result != 0) throw new IllegalStateException("CV32E40S_TEST native batch failed with code " + result);
        return java.util.Arrays.stream(statuses).mapToObj(AttackerProgramImages::parseStatus).toList();
    }

    @Override
    public SIMULATION_RESULT run(TestCase test, int maxCycles) {
        return runAll(List.of(test), maxCycles).get(0);
    }
}
