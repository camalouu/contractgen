package contractgen.riscv;

import com.sun.jna.Library;
import com.sun.jna.Native;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;

import java.nio.file.Path;
import java.util.List;

/** JNA adapter for attacker-only harnesses that return only a simulation status. */
public final class SimpleAttackerHarnessClient implements AttackerHarnessClient {
    private final String harnessName;
    private final SimpleAttackerLibrary library;

    private interface SimpleAttackerLibrary extends Library {
        int contract_simple_attacker_batch_v1(
                int caseCount,
                int maxCycles,
                int[] caseIndices,
                int[] maxInstructionCounts,
                int[] program1,
                int[] program2,
                int[] statuses);
    }

    public SimpleAttackerHarnessClient(Path libraryPath, String harnessName) {
        this.harnessName = harnessName;
        library = Native.load(libraryPath.toAbsolutePath().toString(), SimpleAttackerLibrary.class);
    }

    @Override
    public SIMULATION_RESULT run(TestCase test, int maxCycles) {
        AttackerProgramImages.Batch input = AttackerProgramImages.encode(List.of(test), harnessName);
        int[] statuses = new int[1];
        int returnCode = library.contract_simple_attacker_batch_v1(
                1, maxCycles, input.caseIndices(), input.maxInstructionCounts(),
                input.program1(), input.program2(), statuses);
        if (returnCode != 0) {
            throw new IllegalStateException(harnessName + " attacker library failed with code " + returnCode);
        }
        return AttackerProgramImages.parseStatus(statuses[0]);
    }
}
