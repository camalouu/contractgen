package contractgen.riscv.isa.tests;

import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import org.junit.jupiter.api.Test;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

final class RISCVTestGeneratorSafeSuffixTest {
    private static final int SCRATCH = 0x10000000;
    private static final List<RISCVInstruction> LEFT = List.of(RISCVInstruction.ADD(5, 1, 2));
    private static final List<RISCVInstruction> RIGHT = List.of(RISCVInstruction.ADD(6, 1, 2));

    @Test void suffixIncludesMemoryAndControlWithoutUsingEarlierWrittenRegisters() {
        var suffix = generator(58).safeRandomSequence(200, LEFT, RIGHT);
        assertEquals(200, suffix.size());
        assertTrue(suffix.stream().anyMatch(RISCVInstruction::isLOAD));
        assertTrue(suffix.stream().anyMatch(RISCVInstruction::isSTORE));
        assertTrue(suffix.stream().anyMatch(i -> i.type() == RISCV_TYPE.JAL));
        assertTrue(suffix.stream().anyMatch(i -> i.type() == RISCV_TYPE.JALR));
        assertTrue(suffix.stream().anyMatch(RISCVInstruction::isBRANCH));
        int jumpBase = suffix.get(0).rd();
        assertEquals(RISCVInstruction.AUIPC(jumpBase, 0), suffix.get(0));
        for (int i = 0; i < suffix.size(); i++) {
            var ins = suffix.get(i);
            for (Integer register : new Integer[]{ins.rd(), ins.rs1(), ins.rs2()}) {
                if (register != null) assertFalse(Set.of(5, 6).contains(register), ins.toString());
            }
            if (ins.isCONTROL()) {
                long target = ins.type() == RISCV_TYPE.JALR ? ins.imm() / 4 : i + ins.imm() / 4;
                assertTrue(target > i && target < suffix.size(), ins.toString());
                if (ins.type() == RISCV_TYPE.JALR) assertEquals(jumpBase, ins.rs1());
            }
        }
    }

    @Test void earlierControlOrUnequalLayoutsReceiveOnlyNops() {
        var left = List.of(RISCVInstruction.BEQ(1, 2, 8));
        var right = List.of(RISCVInstruction.BEQ(1, 2, 12));
        generator(58).safeRandomSequence(12, left, right)
                .forEach(i -> assertEquals(RISCVInstruction.NOP(), i));
        generator(58).safeRandomSequence(12, LEFT, List.of())
                .forEach(i -> assertEquals(RISCVInstruction.NOP(), i));
    }

    @Test void possibleScratchAliasesDisableMemoryButNotControlFlow() {
        var stores = List.of(RISCVInstruction.SW(7, 8, 0));
        var suffix = generator(58).safeRandomSequence(200, stores, stores);
        assertFalse(suffix.stream().anyMatch(RISCVInstruction::isMEM));
        assertTrue(suffix.stream().anyMatch(RISCVInstruction::isCONTROL));
        var zeroStores = List.of(RISCVInstruction.SW(0, 8, 0));
        assertTrue(generator(58).safeRandomSequence(200, zeroStores, zeroStores)
                .stream().anyMatch(RISCVInstruction::isLOAD));
    }

    @Test void entireHistoryIsProtectedAndTooFewRegistersFallBackSafely() {
        var history = List.of(RISCVInstruction.ADD(5, 1, 2), RISCVInstruction.ADD(6, 1, 2),
                RISCVInstruction.ADD(7, 1, 2));
        for (var ins : generator(1).safeRandomSequence(100, history, history)) {
            for (Integer register : new Integer[]{ins.rd(), ins.rs1(), ins.rs2()})
                if (register != null) assertFalse(Set.of(5, 6, 7).contains(register));
        }
        var full = new ArrayList<RISCVInstruction>();
        for (int i = 1; i < 32; i++) full.add(RISCVInstruction.ADDI(i, 0, i));
        generator(1).safeRandomSequence(20, full, full).forEach(i -> assertEquals(RISCVInstruction.NOP(), i));
    }

    @Test void executionCannotPropagateTargetDifferencesOrLeaveTheSuffix() {
        for (int seed = 0; seed < 40; seed++) {
            var suffix = generator(seed).safeRandomSequence(200, LEFT, RIGHT);
            int[] a = new int[32], b = new int[32];
            for (int i = 1; i < 32; i++) a[i] = b[i] = new Random(seed * 32L + i).nextInt();
            b[5] ^= -1;
            b[6] ^= -1;
            int original5 = b[5], original6 = b[6];
            var runA = execute(suffix, a);
            var runB = execute(suffix, b);
            assertEquals(runA, runB); // Same dynamic PCs, memory addresses, and transferred data.
            assertEquals(original5, b[5]);
            assertEquals(original6, b[6]);
            for (int i = 0; i < 32; i++) if (i != 5 && i != 6) assertEquals(a[i], b[i]);
        }
    }

    private static List<String> execute(List<RISCVInstruction> program, int[] registers) {
        byte[] memory = new byte[4];
        var trace = new ArrayList<String>();
        int pc = 0;
        while (pc < program.size()) {
            assertTrue(pc >= 0 && trace.size() < 2 * program.size());
            var ins = program.get(pc);
            trace.add("pc=" + pc);
            int a = ins.rs1() == null ? 0 : registers[ins.rs1()];
            int b = ins.rs2() == null ? 0 : registers[ins.rs2()];
            int immediate = ins.imm() == null ? 0 : ins.imm().intValue();
            int signed = immediate << 20 >> 20;
            int next = pc + 1, value = 0;
            if (ins.isMEM()) {
                int address = a + signed;
                int width = switch (ins.type()) { case LW, SW -> 4; case LH, LHU, SH -> 2; default -> 1; };
                assertTrue(address >= SCRATCH && address + width <= SCRATCH + 4);
                assertEquals(0, address % width);
                int offset = address - SCRATCH;
                for (int j = 0; j < width; j++) {
                    if (ins.isSTORE()) memory[offset + j] = (byte) (b >>> (8 * j));
                    else value |= Byte.toUnsignedInt(memory[offset + j]) << (8 * j);
                }
                if (ins.type() == RISCV_TYPE.LB) value = (byte) value;
                if (ins.type() == RISCV_TYPE.LH) value = (short) value;
                trace.add(ins.type() + ":" + address + ":" + (ins.isSTORE() ? b : value));
            } else if (ins.isCONTROL()) {
                boolean taken = switch (ins.type()) {
                    case BEQ -> a == b; case BNE -> a != b;
                    case BLT -> a < b; case BGE -> a >= b;
                    case BLTU -> Integer.compareUnsigned(a, b) < 0;
                    case BGEU -> Integer.compareUnsigned(a, b) >= 0;
                    default -> true;
                };
                if (taken) next = ins.type() == RISCV_TYPE.JALR
                        ? ((a + signed) & ~1) / 4 : pc + immediate / 4;
                value = (pc + 1) * 4;
                assertTrue(next > pc && next <= program.size());
            } else {
                value = switch (ins.type()) {
                    case LUI -> immediate; case AUIPC -> pc * 4 + immediate;
                    case ADD -> a + b; case ADDI -> a + signed; case SUB -> a - b;
                    case AND -> a & b; case ANDI -> a & signed;
                    case OR -> a | b; case ORI -> a | signed;
                    case XOR -> a ^ b; case XORI -> a ^ signed;
                    case SLT -> a < b ? 1 : 0; case SLTI -> a < signed ? 1 : 0;
                    case SLTU -> Integer.compareUnsigned(a, b) < 0 ? 1 : 0;
                    case SLTIU -> Integer.compareUnsigned(a, signed) < 0 ? 1 : 0;
                    case SLL -> a << b; case SLLI -> a << ins.rs2();
                    case SRL -> a >>> b; case SRLI -> a >>> ins.rs2();
                    case SRA -> a >> b; case SRAI -> a >> ins.rs2();
                    default -> throw new AssertionError(ins);
                };
            }
            if (ins.rd() != null && ins.rd() != 0) registers[ins.rd()] = value;
            pc = next;
        }
        return trace;
    }

    private static RISCVTestGenerator generator(long seed) {
        return new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE),
                Set.of(RISCV_OBSERVATION_TYPE.RD), seed, 1, true, 1, false, false, true, false);
    }
}
