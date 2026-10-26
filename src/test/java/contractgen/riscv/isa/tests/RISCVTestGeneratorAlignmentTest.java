package contractgen.riscv.isa.tests;

import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

final class RISCVTestGeneratorAlignmentTest {
    @Test void memoryPairsShareHelpersAcrossBaseRegistersAndImmediateLowBits() {
        for (var type : List.of(RISCV_TYPE.LH, RISCV_TYPE.LHU, RISCV_TYPE.LW, RISCV_TYPE.SH, RISCV_TYPE.SW)) {
            for (int base : new int[]{0, 5, 7}) {
                for (int low = 0; low < 4; low++) {
                    boolean load = RISCVInstruction.isLOAD(type);
                    var a = new RISCVInstruction(type, load ? 9 : null, base, load ? null : 10, 2044L + low);
                    var b = new RISCVInstruction(type, load ? 9 : null, 5, load ? null : 10, 4095L - low);
                    var pair = RISCVTestGenerator.alignTargetPair(new Pair<>(List.of(a), List.of(b)), true);
                    int last = pair.left().size() - 1;
                    assertEquals(pair.left().size(), pair.right().size());
                    assertEquals(pair.left().subList(0, last), pair.right().subList(0, last));
                    int[] registers = new int[32];
                    Arrays.fill(registers, -1);
                    registers[0] = 0;
                    for (var helper : pair.left().subList(0, last)) {
                        assertEquals(RISCV_TYPE.ANDI, helper.type());
                        registers[helper.rd()] &= helper.imm().intValue();
                    }
                    for (var program : List.of(pair.left(), pair.right())) {
                        var target = program.get(last);
                        assertEquals(0, (registers[target.rs1()] + target.imm()) & 3L);
                    }
                    assertEquals(a.cloneAlteringIMM(a.imm() & ~3L), pair.left().get(last));
                    assertEquals(b.cloneAlteringIMM(b.imm() & ~3L), pair.right().get(last));
                }
            }
        }
    }

    @Test void zeroSourceTestsNeedNoExtraAlignmentInstructions() {
        for (long seed : new long[]{1, 2, 81}) {
            var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE),
                    EnumSet.of(RISCV_OBSERVATION_TYPE.RS1_IS_ZERO), seed, 1, false, 1,
                    false, false, false, false);
            for (var test : generator.generate()) {
                var left = ((RISCVProgram) test.getProgram1()).getProgram();
                var right = ((RISCVProgram) test.getProgram2()).getProgram();
                assertEquals(11, left.size()); // Zero prefill, four NOPs, target, five NOPs.
                assertEquals(left.size(), right.size());
                assertEquals(left.subList(0, 5), right.subList(0, 5));
                assertEquals(left.subList(6, 11), right.subList(6, 11));
                assertEquals(left.get(5).cloneAlteringRS1(right.get(5).rs1()), right.get(5));
                if (RISCVInstruction.isMEM(left.get(5).type()) || left.get(5).type() == RISCV_TYPE.JALR)
                    assertEquals(0, left.get(5).imm() & 3L);
            }
        }
    }

    @Test void jalrUsesSharedPreparationEvenWhenMisalignedMemoryIsAllowed() {
        var a = RISCVInstruction.JALR(9, 5, 12);
        var b = RISCVInstruction.JALR(9, 7, 16);
        var pair = RISCVTestGenerator.alignTargetPair(new Pair<>(List.of(a), List.of(b)), false);
        var helpers = List.of(RISCVInstruction.ANDI(5, 5, 4092), RISCVInstruction.ANDI(7, 7, 4092));
        assertEquals(helpers, pair.left().subList(0, 2));
        assertEquals(helpers, pair.right().subList(0, 2));
        var memory = new Pair<>(List.of(RISCVInstruction.LW(9, 5, 1)), List.of(RISCVInstruction.LW(9, 5, 3)));
        assertEquals(memory, RISCVTestGenerator.alignTargetPair(memory, false));
    }

    @Test void generatedPairsHaveMatchingInstructionTypesWithAndWithoutSuffix() {
        for (boolean suffix : new boolean[]{false, true}) {
            var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                    2, 2, false, 1, false, false, suffix, false);
            for (var test : generator.generate()) {
                var left = ((RISCVProgram) test.getProgram1()).getProgram();
                var right = ((RISCVProgram) test.getProgram2()).getProgram();
                assertEquals(left.stream().map(RISCVInstruction::type).toList(),
                        right.stream().map(RISCVInstruction::type).toList());
            }
        }
    }
}
