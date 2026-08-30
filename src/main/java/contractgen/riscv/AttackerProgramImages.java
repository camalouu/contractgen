package contractgen.riscv;

import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;

import java.util.Arrays;
import java.util.List;

/** Shared encoding for the fixed-size program images used by attacker-only RTL harnesses. */
public final class AttackerProgramImages {
    public static final int MAX_INSTRUCTIONS = 2048;
    private static final int PROGRAM_OFFSET = 32;
    private static final int NOP = word(RISCVInstruction.NOP());

    private AttackerProgramImages() {
    }

    public static Batch encode(List<TestCase> tests, String harnessName) {
        int[] caseIndices = new int[tests.size()];
        int[] maxInstructionCounts = new int[tests.size()];
        int[] program1 = new int[tests.size() * MAX_INSTRUCTIONS];
        int[] program2 = new int[tests.size() * MAX_INSTRUCTIONS];
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            TestCase test = tests.get(ordinal);
            caseIndices[ordinal] = test.getIndex();
            maxInstructionCounts[ordinal] = test.getMaxInstructionCount() + PROGRAM_OFFSET - 1;
            fill((RISCVProgram) test.getProgram1(), program1, ordinal * MAX_INSTRUCTIONS, harnessName);
            fill((RISCVProgram) test.getProgram2(), program2, ordinal * MAX_INSTRUCTIONS, harnessName);
        }
        return new Batch(caseIndices, maxInstructionCounts, program1, program2);
    }

    public static void fill(RISCVProgram program, int[] image, int offset, String harnessName) {
        if (PROGRAM_OFFSET + program.getProgram().size() > MAX_INSTRUCTIONS) {
            throw new IllegalArgumentException(harnessName + " program image exceeds "
                    + MAX_INSTRUCTIONS + " instructions");
        }
        Arrays.fill(image, offset, offset + MAX_INSTRUCTIONS, NOP);
        for (int register = 1; register < 32; register++) {
            Integer value = program.getRegisters().get(register);
            if (value != null) {
                image[offset + register - 1] = word(RISCVInstruction.ADDI(register, 0, value));
            }
        }
        int instructionOffset = offset + PROGRAM_OFFSET;
        for (RISCVInstruction instruction : program.getProgram()) {
            image[instructionOffset++] = word(instruction);
        }
    }

    public static SIMULATION_RESULT parseStatus(int status) {
        return switch (status) {
            case 0 -> SIMULATION_RESULT.SUCCESS;
            case 1 -> SIMULATION_RESULT.FAIL;
            case 2 -> SIMULATION_RESULT.TIMEOUT;
            case 3 -> SIMULATION_RESULT.ERROR;
            default -> SIMULATION_RESULT.UNKNOWN;
        };
    }

    private static int word(RISCVInstruction instruction) {
        return (int) Long.parseUnsignedLong(instruction.toHexEncoding(), 16);
    }

    public record Batch(int[] caseIndices, int[] maxInstructionCounts, int[] program1, int[] program2) {
    }
}
