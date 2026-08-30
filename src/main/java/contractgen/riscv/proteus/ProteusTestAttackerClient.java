package contractgen.riscv.proteus;

import com.sun.jna.Library;
import com.sun.jna.Native;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.AttackerProgramImages;

import java.nio.file.Path;
import java.util.List;
import java.util.OptionalInt;

/** JNA adapter for the versioned Proteus attacker-only batch ABI. */
public final class ProteusTestAttackerClient implements AttackerHarnessClient {
    private final ContractProteusTestLibrary library;

    private interface ContractProteusTestLibrary extends Library {
        int contract_proteus_test_attacker_batch_v1(
                int caseCount, int maxCycles, int[] caseIndices, int[] maxInstructionCounts,
                int[] program1, int[] program2, int[] statuses,
                int[] failureCutoffs, int[] executionCutoffs);
    }

    public ProteusTestAttackerClient(Path libraryPath) {
        library = Native.load(libraryPath.toAbsolutePath().toString(), ContractProteusTestLibrary.class);
    }

    @Override
    public SIMULATION_RESULT run(TestCase test, int maxCycles) {
        return runDetailed(test, maxCycles).status();
    }

    @Override
    public AttackerResult runDetailed(TestCase test, int maxCycles) {
        AttackerProgramImages.Batch input = AttackerProgramImages.encode(List.of(test), "PROTEUS_TEST");
        int[] statuses = new int[1];
        int[] failureCutoffs = new int[1];
        int[] executionCutoffs = new int[1];
        int returnCode;
        try {
            returnCode = library.contract_proteus_test_attacker_batch_v1(
                    1, maxCycles, input.caseIndices(), input.maxInstructionCounts(),
                    input.program1(), input.program2(), statuses, failureCutoffs, executionCutoffs);
        } catch (UnsatisfiedLinkError error) {
            throw new IllegalStateException("PROTEUS_TEST attacker shared library is stale: missing "
                    + "contract_proteus_test_attacker_batch_v1; rebuild the library", error);
        }
        if (returnCode != 0) {
            throw new IllegalStateException("PROTEUS_TEST attacker library failed with code " + returnCode);
        }
        return new AttackerResult(
                AttackerProgramImages.parseStatus(statuses[0]),
                optional(failureCutoffs[0]),
                optional(executionCutoffs[0]));
    }

    private static OptionalInt optional(int value) {
        return value < 0 ? OptionalInt.empty() : OptionalInt.of(value);
    }
}
