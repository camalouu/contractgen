package contractgen.riscv.proteus;

import contractgen.riscv.AttackerProgramImages;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import org.junit.jupiter.api.Test;

import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ProteusTestAttackerClientTest {
    @Test
    void constructsTheSharedSpikeHarnessImageLayout() {
        RISCVInstruction instruction = RISCVInstruction.ADDI(4, 3, 7);
        RISCVProgram program = new RISCVProgram(Map.of(1, 11, 31, -1), List.of(instruction));
        int[] image = new int[AttackerProgramImages.MAX_INSTRUCTIONS];

        AttackerProgramImages.fill(program, image, 0, "PROTEUS_TEST");

        assertEquals(word(RISCVInstruction.ADDI(1, 0, 11)), image[0]);
        assertEquals(word(RISCVInstruction.NOP()), image[1]);
        assertEquals(word(RISCVInstruction.ADDI(31, 0, -1)), image[30]);
        assertEquals(word(RISCVInstruction.NOP()), image[31]);
        assertEquals(word(instruction), image[32]);
        assertEquals(word(RISCVInstruction.NOP()), image[33]);
    }

    @Test
    void rejectsProgramsThatDoNotFitTheFixedImage() {
        RISCVProgram program = new RISCVProgram(Map.of(),
                Collections.nCopies(AttackerProgramImages.MAX_INSTRUCTIONS - 31, RISCVInstruction.NOP()));
        int[] image = new int[AttackerProgramImages.MAX_INSTRUCTIONS];
        assertThrows(IllegalArgumentException.class,
                () -> AttackerProgramImages.fill(program, image, 0, "PROTEUS_TEST"));
    }

    private static int word(RISCVInstruction instruction) {
        return (int) Long.parseUnsignedLong(instruction.toHexEncoding(), 16);
    }
}
