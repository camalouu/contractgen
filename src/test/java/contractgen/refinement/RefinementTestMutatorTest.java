package contractgen.refinement;

import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCVTestCase;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

class RefinementTestMutatorTest {
    @Test
    void differingPreStateIsVisibleAndHiddenInitializationIsIdentical() {
        RefinementTestMutator.Seed seed = new RefinementTestMutator.Seed(
                List.of(RISCVInstruction.BEQ(1, 2, 8)), Map.of(1, 7, 2, 9),
                List.of(RISCVInstruction.BEQ(1, 2, 8)), Map.of(1, 11, 2, 9));

        RefinementTestMutator.Variant variant = RefinementTestMutator.variants(seed, 1, 40).get(0);
        RISCVTestCase test = variant.test();
        RISCVProgram first = (RISCVProgram) test.getProgram1();
        RISCVProgram second = (RISCVProgram) test.getProgram2();

        assertEquals("identity", variant.mutation());
        assertEquals(first.getRegisters(), second.getRegisters());
        assertFalse(first.getRegisters().containsKey(1));
        assertEquals(9, first.getRegisters().get(2));
        assertEquals(RISCVInstruction.ADDI(1, 0, 7), first.getProgram().get(0));
        assertEquals(RISCVInstruction.ADDI(1, 0, 11), second.getProgram().get(0));
        assertEquals(RISCVInstruction.BEQ(1, 2, 8), first.getProgram().get(1));
        assertEquals(7, first.getProgram().size());
        assertEquals(first.getProgram().size() + 1, test.getMaxInstructionCount());
        assertEquals(40, test.getIndex());
        for (int i = 2; i < 7; i++) {
            assertEquals(RISCVInstruction.NOP(), first.getProgram().get(i));
            assertEquals(RISCVInstruction.NOP(), second.getProgram().get(i));
        }
    }

    @Test
    void simpleMutationsRenameRegistersAndSwapSides() {
        RefinementTestMutator.Seed seed = new RefinementTestMutator.Seed(
                List.of(RISCVInstruction.ADD(3, 1, 2)), Map.of(1, 1, 2, 2),
                List.of(RISCVInstruction.ADD(3, 1, 2)), Map.of(1, 2, 2, 2));

        List<RefinementTestMutator.Variant> variants = RefinementTestMutator.variants(seed, 4, 0);

        assertEquals(List.of("identity", "identity-pair-swapped", "register-shift-1", "register-shift-1-pair-swapped"),
                variants.stream().map(RefinementTestMutator.Variant::mutation).toList());
        RISCVProgram shifted = (RISCVProgram) variants.get(2).test().getProgram1();
        assertEquals(RISCVInstruction.ADDI(2, 0, 1), shifted.getProgram().get(0));
        assertEquals(RISCVInstruction.ADD(4, 2, 3), shifted.getProgram().get(1));

        RISCVProgram originalFirst = (RISCVProgram) variants.get(0).test().getProgram1();
        RISCVProgram swappedSecond = (RISCVProgram) variants.get(1).test().getProgram2();
        assertEquals(originalFirst.getProgram(), swappedSecond.getProgram());
    }

    @Test
    void rejectsCrossTypeTargetPair() {
        RefinementTestMutator.Seed seed = new RefinementTestMutator.Seed(
                List.of(RISCVInstruction.ADD(3, 1, 2)), Map.of(),
                List.of(RISCVInstruction.SUB(3, 1, 2)), Map.of());

        assertThrows(IllegalArgumentException.class, () -> RefinementTestMutator.variants(seed, 1, 0));
    }
}
