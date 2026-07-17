package contractgen.riscv.cva6_test;

import com.sun.jna.Library;
import com.sun.jna.Native;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class CVA6TestAttackerClient {
    private static final int MAX_INSTR = 2048;
    private static final int NOP = unsignedWord(RISCVInstruction.NOP().toHexEncoding());

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
        int[] caseIndices = new int[tests.size()];
        int[] maxInstructionCounts = new int[tests.size()];
        int[] program1 = new int[tests.size() * MAX_INSTR];
        int[] program2 = new int[tests.size() * MAX_INSTR];
        int[] statuses = new int[tests.size()];
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            TestCase test = tests.get(ordinal);
            caseIndices[ordinal] = test.getIndex();
            maxInstructionCounts[ordinal] = test.getMaxInstructionCount() + 31;
            fillProgramImage((RISCVProgram) test.getProgram1(), program1, ordinal * MAX_INSTR);
            fillProgramImage((RISCVProgram) test.getProgram2(), program2, ordinal * MAX_INSTR);
        }
        int returnCode = library.contract_cva6_test_attacker_batch(
                tests.size(),
                maxCycles,
                caseIndices,
                maxInstructionCounts,
                program1,
                program2,
                statuses
        );
        if (returnCode != 0) {
            throw new IllegalStateException("CVA6_TEST attacker library failed with code " + returnCode);
        }
        List<Cva6AttackerCase> out = new ArrayList<>(tests.size());
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            SIMULATION_RESULT status = parseStatus(statuses[ordinal]);
            out.add(new Cva6AttackerCase(ordinal, caseIndices[ordinal], status, status == SIMULATION_RESULT.FAIL, null));
        }
        return out;
    }

    private static void fillProgramImage(RISCVProgram program, int[] image, int offset) {
        if (32 + program.getProgram().size() > MAX_INSTR) {
            throw new IllegalArgumentException("CVA6_TEST program image exceeds " + MAX_INSTR + " instructions");
        }
        for (int i = 0; i < MAX_INSTR; i++) {
            image[offset + i] = NOP;
        }
        Map<Integer, Integer> registers = program.getRegisters();
        for (int i = 1; i < 32; i++) {
            Integer value = registers.get(i);
            if (value != null) {
                image[offset + i - 1] = unsignedWord(RISCVInstruction.ADDI(i, 0, value).toHexEncoding());
            }
        }
        int instrOffset = offset + 32;
        for (RISCVInstruction instruction : program.getProgram()) {
            image[instrOffset++] = unsignedWord(instruction.toHexEncoding());
        }
    }

    private static int unsignedWord(String hex) {
        return (int) Long.parseUnsignedLong(hex, 16);
    }

    private static SIMULATION_RESULT parseStatus(int status) {
        return switch (status) {
            case 0 -> SIMULATION_RESULT.SUCCESS;
            case 1 -> SIMULATION_RESULT.FAIL;
            case 2 -> SIMULATION_RESULT.TIMEOUT;
            case 3 -> SIMULATION_RESULT.ERROR;
            default -> SIMULATION_RESULT.UNKNOWN;
        };
    }

    public record Cva6AttackerCase(int ordinal, int caseIndex, SIMULATION_RESULT status, boolean attackerDistinguishable, String error) {
    }
}
