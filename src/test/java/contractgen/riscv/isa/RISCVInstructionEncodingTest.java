package contractgen.riscv.isa;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

final class RISCVInstructionEncodingTest {

    @Test
    void encodesNegativeRegisterInitializationAsTwelveBitImmediate() {
        RISCVInstruction instruction = RISCVInstruction.ADDI(2, 0, -1);

        assertEquals("fff00113", instruction.toHexEncoding());
        assertEquals(32, instruction.toBinaryEncoding().length());
    }

    @Test
    void negativeImmediatesStayWithinEveryInstructionEncoding() {
        List<RISCVInstruction> instructions = List.of(
                RISCVInstruction.ADDI(1, 0, -2048),
                RISCVInstruction.SW(1, 2, -4),
                RISCVInstruction.BEQ(1, 2, -4),
                RISCVInstruction.LUI(1, -4096),
                RISCVInstruction.JAL(1, -4)
        );

        for (RISCVInstruction instruction : instructions) {
            assertEquals(32, instruction.toBinaryEncoding().length(), instruction.toString());
            assertEquals(8, instruction.toHexEncoding().length(), instruction.toString());
        }
    }
}
