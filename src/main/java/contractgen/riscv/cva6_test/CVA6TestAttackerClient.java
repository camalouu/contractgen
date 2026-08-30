package contractgen.riscv.cva6_test;

import com.sun.jna.Library;
import com.sun.jna.Native;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.AttackerProgramImages;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public final class CVA6TestAttackerClient implements AttackerHarnessClient {
    private final ContractCva6TestLibrary library;

    private interface ContractCva6TestLibrary extends Library {
        int contract_cva6_test_attacker_batch(
                int caseCount,
                int maxCycles,
                int[] caseIndices,
                int[] maxInstructionCounts,
                int[] program1,
                int[] program2,
                int[] statuses
        );
    }

    public CVA6TestAttackerClient(Path libraryPath) {
        this.library = Native.load(libraryPath.toAbsolutePath().toString(), ContractCva6TestLibrary.class);
    }

    public List<Cva6AttackerCase> runAll(List<TestCase> tests, int maxCycles) {
        if (tests.isEmpty()) {
            return List.of();
        }
        AttackerProgramImages.Batch input = AttackerProgramImages.encode(tests, "CVA6_TEST");
        int[] statuses = new int[tests.size()];
        int returnCode = library.contract_cva6_test_attacker_batch(
                tests.size(),
                maxCycles,
                input.caseIndices(),
                input.maxInstructionCounts(),
                input.program1(),
                input.program2(),
                statuses
        );
        if (returnCode != 0) {
            throw new IllegalStateException("CVA6_TEST attacker library failed with code " + returnCode);
        }
        List<Cva6AttackerCase> out = new ArrayList<>(tests.size());
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            SIMULATION_RESULT status = AttackerProgramImages.parseStatus(statuses[ordinal]);
            out.add(new Cva6AttackerCase(ordinal, input.caseIndices()[ordinal], status, status == SIMULATION_RESULT.FAIL, null));
        }
        return out;
    }

    @Override
    public SIMULATION_RESULT run(TestCase test, int maxCycles) {
        List<Cva6AttackerCase> results = runAll(List.of(test), maxCycles);
        return results.isEmpty() ? SIMULATION_RESULT.UNKNOWN : results.get(0).status();
    }

    public record Cva6AttackerCase(int ordinal, int caseIndex, SIMULATION_RESULT status, boolean attackerDistinguishable, String error) {
    }
}
