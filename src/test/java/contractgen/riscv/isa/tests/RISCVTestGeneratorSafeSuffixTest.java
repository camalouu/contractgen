package contractgen.riscv.isa.tests;

import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import org.junit.jupiter.api.Test;

import java.util.EnumSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

final class RISCVTestGeneratorSafeSuffixTest {

    @Test
    void safeSuffixAvoidsControlMemoryAndTargetDestinationRegisters() {
        RISCVTestGenerator generator = generator();
        List<RISCVInstruction> left = List.of(RISCVInstruction.ADD(5, 1, 2));
        List<RISCVInstruction> right = List.of(RISCVInstruction.ADD(6, 1, 2));

        List<RISCVInstruction> suffix = generator.safeRandomSequence(200, left, right);

        assertEquals(200, suffix.size());
        for (RISCVInstruction instruction : suffix) {
            assertFalse(instruction.isCONTROL(), instruction.toString());
            assertFalse(instruction.isMEM(), instruction.toString());
            if (instruction.hasRD()) {
                assertNotEquals(0, instruction.rd());
                assertNotEquals(5, instruction.rd());
                assertNotEquals(6, instruction.rd());
            }
            if (instruction.hasRS1()) {
                assertNotEquals(0, instruction.rs1());
                assertNotEquals(5, instruction.rs1());
                assertNotEquals(6, instruction.rs1());
            }
            if (instruction.hasRS2()) {
                assertNotEquals(0, instruction.rs2());
                assertNotEquals(5, instruction.rs2());
                assertNotEquals(6, instruction.rs2());
            }
        }
    }

    @Test
    void controlFlowTargetsReceiveOnlyNops() {
        RISCVTestGenerator generator = generator();
        List<RISCVInstruction> left = List.of(RISCVInstruction.BEQ(1, 2, 8));
        List<RISCVInstruction> right = List.of(RISCVInstruction.BEQ(1, 2, 12));

        List<RISCVInstruction> suffix = generator.safeRandomSequence(12, left, right);

        assertEquals(12, suffix.size());
        suffix.forEach(instruction -> assertEquals(RISCVInstruction.NOP(), instruction));
    }

    private static RISCVTestGenerator generator() {
        return new RISCVTestGenerator(
                EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                Set.of(RISCV_OBSERVATION_TYPE.RD),
                58L,
                1,
                true,
                1,
                false,
                false,
                true,
                false
        );
    }
}
