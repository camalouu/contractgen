package contractgen.riscv.ibex;

import com.sun.jna.Library;
import com.sun.jna.Native;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.AttackerProgramImages;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.OptionalInt;

public final class IBEXTestAttackerClient implements AttackerHarnessClient {
    private final ContractIbexTestLibrary library;

    private interface ContractIbexTestLibrary extends Library {
        int contract_ibex_test_attacker_batch_v4(
                int caseCount,
                int maxCycles,
                int[] caseIndices,
                int[] maxInstructionCounts,
                int[] program1,
                int[] program2,
                int[] statuses,
                int[] failureCutoffs,
                int[] executionCutoffs
        );
    }

    public IBEXTestAttackerClient(Path libraryPath) {
        this.library = Native.load(libraryPath.toAbsolutePath().toString(), ContractIbexTestLibrary.class);
    }

    public List<IbexAttackerCase> runAll(List<TestCase> tests, int maxCycles) {
        if (tests.isEmpty()) {
            return List.of();
        }
        AttackerProgramImages.Batch input = AttackerProgramImages.encode(tests, "IBEX_TEST");
        int[] statuses = new int[tests.size()];
        int[] failureCutoffs = new int[tests.size()];
        int[] executionCutoffs = new int[tests.size()];
        int returnCode;
        try {
            returnCode = library.contract_ibex_test_attacker_batch_v4(
                    tests.size(),
                    maxCycles,
                    input.caseIndices(),
                    input.maxInstructionCounts(),
                    input.program1(),
                    input.program2(),
                    statuses,
                    failureCutoffs,
                    executionCutoffs
            );
        } catch (UnsatisfiedLinkError error) {
            throw new IllegalStateException("IBEX_TEST attacker shared library is stale: missing "
                    + "contract_ibex_test_attacker_batch_v4; rebuild the library", error);
        }
        if (returnCode != 0) {
            throw new IllegalStateException("IBEX_TEST attacker library failed with code " + returnCode);
        }
        List<IbexAttackerCase> out = new ArrayList<>(tests.size());
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            SIMULATION_RESULT status = AttackerProgramImages.parseStatus(statuses[ordinal]);
            Integer failureCutoff = failureCutoffs[ordinal] < 0 ? null : failureCutoffs[ordinal];
            Integer executionCutoff = executionCutoffs[ordinal] < 0 ? null : executionCutoffs[ordinal];
            out.add(new IbexAttackerCase(ordinal, input.caseIndices()[ordinal], status,
                    status == SIMULATION_RESULT.FAIL, failureCutoff, executionCutoff, null));
        }
        return out;
    }

    @Override
    public SIMULATION_RESULT run(TestCase test, int maxCycles) {
        List<IbexAttackerCase> results = runAll(List.of(test), maxCycles);
        return results.isEmpty() ? SIMULATION_RESULT.UNKNOWN : results.get(0).status();
    }

    @Override
    public AttackerResult runDetailed(TestCase test, int maxCycles) {
        List<IbexAttackerCase> results = runAll(List.of(test), maxCycles);
        if (results.isEmpty()) {
            return new AttackerResult(SIMULATION_RESULT.UNKNOWN, OptionalInt.empty(), OptionalInt.empty());
        }
        IbexAttackerCase result = results.get(0);
        OptionalInt cutoff = result.failureCutoff() == null
                ? OptionalInt.empty()
                : OptionalInt.of(result.failureCutoff());
        OptionalInt executionCutoff = result.executionCutoff() == null
                ? OptionalInt.empty()
                : OptionalInt.of(result.executionCutoff());
        return new AttackerResult(result.status(), cutoff, executionCutoff);
    }

    public record IbexAttackerCase(int ordinal, int caseIndex, SIMULATION_RESULT status,
                                   boolean attackerDistinguishable, Integer failureCutoff,
                                   Integer executionCutoff, String error) {
    }
}
