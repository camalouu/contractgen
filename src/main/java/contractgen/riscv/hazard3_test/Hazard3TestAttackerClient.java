package contractgen.riscv.hazard3_test;

import com.sun.jna.Library;
import com.sun.jna.Native;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.AttackerProgramImages;

import java.nio.file.Path;
import java.util.List;

public final class Hazard3TestAttackerClient implements AttackerHarnessClient {
    private final ContractHazard3TestLibrary library;

    private interface ContractHazard3TestLibrary extends Library {
        int contract_hazard3_test_attacker_batch(
                int caseCount, int maxCycles, int[] caseIndices, int[] maxInstructionCounts,
                int[] program1, int[] program2, int[] statuses);
    }

    public Hazard3TestAttackerClient(Path libraryPath) {
        library = Native.load(libraryPath.toAbsolutePath().toString(), ContractHazard3TestLibrary.class);
    }

    @Override
    public SIMULATION_RESULT run(TestCase test, int maxCycles) {
        AttackerProgramImages.Batch input = AttackerProgramImages.encode(List.of(test), "HAZARD3_TEST");
        int[] statuses = new int[1];
        int returnCode = library.contract_hazard3_test_attacker_batch(
                1, maxCycles, input.caseIndices(), input.maxInstructionCounts(),
                input.program1(), input.program2(), statuses);
        if (returnCode != 0) {
            throw new IllegalStateException("HAZARD3_TEST attacker library failed with code " + returnCode);
        }
        return AttackerProgramImages.parseStatus(statuses[0]);
    }
}
