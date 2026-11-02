package contractgen.riscv.isa.tests.imported.contract;

import contractgen.riscv.isa.tests.imported.isa.Format;
import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.function.Function;
import java.util.random.RandomGenerator;

import static contractgen.riscv.isa.tests.imported.isa.Instruction.*;

/**
 * The modifier functions of the built-in leakage functions, ported from the original test generator
 * ({@code RISCVTestGenerator.alterObservation}) and extended in M8 to the leakage functions the original never
 * targeted. The ported ones draw random numbers in the same order as the original, except for the memory modifiers,
 * which were rewritten (parity ledger #4).
 * <p>
 * Modifiers that load values into registers do so with {@link #set}: with {@link RegisterValues#LEGACY} values and a
 * single addi exactly as the original, with {@link RegisterValues#FULL} 32-bit values and lui + addi.
 */
final class Modifiers {

    static final int REGISTERS = 32;
    static final long MAX_IMM_I = 4096;

    private Modifiers() {
    }

    /** Two random values for a register field, optionally excluding x0. */
    static Modifier field(Function<Instruction, Integer> get, boolean excludeZero, Retarget with) {
        return (i, r, v) -> {
            if (get.apply(i) == null) return Optional.empty();
            int a = excludeZero ? r.nextInt(1, REGISTERS) : r.nextInt(REGISTERS);
            int b = excludeZero ? r.nextInt(1, REGISTERS) : r.nextInt(REGISTERS);
            return Optional.of(new Modifier.Modification(List.of(with.apply(i, a)), List.of(with.apply(i, b))));
        };
    }

    interface Retarget {
        Instruction apply(Instruction i, int value);
    }

    /** Two random immediates (word-aligned for branches and jumps). */
    static Modifier immediate() {
        return (i, r, v) -> {
            if (i.imm() == null) return Optional.empty();
            long bound = immediateBound(i.mnemonic().format());
            long a = r.nextLong(bound);
            long b = r.nextLong(bound);
            if (i.mnemonic().format() == Format.B || i.mnemonic() == Mnemonic.JAL || i.mnemonic() == Mnemonic.JALR) {
                a = a / 4 * 4;
                b = b / 4 * 4;
            }
            return Optional.of(new Modifier.Modification(List.of(i.withIMM(a)), List.of(i.withIMM(b))));
        };
    }

    /** A different value in a source register, set right before the instruction. */
    static Modifier registerValue(Function<Instruction, Integer> register) {
        return (i, r, v) -> {
            Integer reg = register.apply(i);
            if (reg == null) return Optional.empty();
            List<Instruction> a = set(reg, random(r, v), v);
            List<Instruction> b = set(reg, random(r, v), v);
            return Optional.of(new Modifier.Modification(concat(a, i), concat(b, i)));
        };
    }

    /**
     * The same address but different memory contents there (for loads): both programs put two random values into two
     * registers other than rs1 and set rs1 to a random address; the first program then stores one value to the address
     * the load reads, the second the other. The registers are the same in both programs.
     */
    static Modifier memoryContent() {
        return (i, r, v) -> {
            if (i.rs1() == null || i.imm() == null) return Optional.empty();
            int register1 = i.rs1() == 31 ? 29 : 31;
            int register2 = i.rs1() == 30 ? 29 : 30;
            List<Instruction> setAddress = set(i.rs1(), random(r, v), v);
            List<Instruction> setValues = new ArrayList<>(set(register1, random(r, v), v));
            setValues.addAll(set(register2, random(r, v), v));
            setValues.addAll(setAddress);
            return Optional.of(new Modifier.Modification(
                    concat(setValues, sw(i.rs1(), register1, i.imm()), i),
                    concat(setValues, sw(i.rs1(), register2, i.imm()), i)));
        };
    }

    /**
     * A write to the register {@code distance} instructions before the instruction in the first program only (the
     * second program writes x0); nops fill the distance.
     */
    static Modifier dependency(Function<Instruction, Integer> register, int distance) {
        return (i, r, v) -> {
            Integer reg = register.apply(i);
            if (reg == null) return Optional.empty();
            List<Instruction> first = new ArrayList<>(List.of(add(reg, 0, 0)));
            List<Instruction> second = new ArrayList<>(List.of(add(0, 0, 0)));
            for (int k = 1; k < distance; k++) {
                first.add(nop());
                second.add(nop());
            }
            first.add(i);
            second.add(i);
            return Optional.of(new Modifier.Modification(first, second));
        };
    }

    /** The branch is taken in the first program and not taken in the second (operands set right before it). */
    static Modifier branchOutcome() {
        return (i, r, v) -> {
            if (!i.mnemonic().isBranch()) return Optional.empty();
            Optional<long[]> taken = branchOperands(i, r, v, true);
            Optional<long[]> notTaken = branchOperands(i, r, v, false);
            if (taken.isEmpty() || notTaken.isEmpty()) return Optional.empty();
            return Optional.of(new Modifier.Modification(
                    concat(set(i.rs1(), taken.get()[0], v), set(i.rs2(), taken.get()[1], v), i),
                    concat(set(i.rs1(), notTaken.get()[0], v), set(i.rs2(), notTaken.get()[1], v), i)));
        };
    }

    /**
     * Up to 64 attempts to find values for rs1 and rs2 with the wanted branch outcome; every other attempt uses equal
     * operand values (as beq needs to be taken).
     */
    private static Optional<long[]> branchOperands(Instruction i, RandomGenerator r, RegisterValues values, boolean wanted) {
        for (int attempt = 0; attempt < 64; attempt++) {
            long a = random(r, values);
            long b = i.rs1().equals(i.rs2()) ? a : random(r, values);
            if (attempt % 2 == 1) {
                if (i.rs1() == 0) b = 0;
                else if (i.rs2() == 0) a = 0;
                else b = a;
            }
            // the second write wins if both set the same register
            long rs2 = i.rs2() == 0 ? 0 : b;
            long rs1 = i.rs1() == 0 ? 0 : i.rs1().equals(i.rs2()) ? rs2 : a;
            if (taken(i.mnemonic(), rs1, rs2) == wanted) return Optional.of(new long[]{a, b});
        }
        return Optional.empty();
    }

    static boolean taken(Mnemonic m, long rs1, long rs2) {
        int a = (int) rs1, b = (int) rs2;
        return switch (m) {
            case BEQ -> a == b;
            case BNE -> a != b;
            case BLT -> a < b;
            case BGE -> a >= b;
            case BLTU -> Integer.compareUnsigned(a, b) < 0;
            case BGEU -> Integer.compareUnsigned(a, b) >= 0;
            default -> throw new IllegalArgumentException(m + " is not a branch");
        };
    }

    /**
     * A different next PC: the branch outcome for branches (with a target other than the next instruction), the
     * immediate for jal, and the base register for jalr (its immediate if the base is x0).
     */
    static Modifier newPC() {
        Modifier branch = branchOutcome(), immediate = immediate(), base = registerValue(Instruction::rs1);
        return (i, r, v) -> {
            if (i.mnemonic().isBranch()) return branch.modify(i.imm() == 4 ? i.withIMM(8) : i, r, v);
            if (i.mnemonic() == Mnemonic.JAL || i.mnemonic() == Mnemonic.JALR && i.rs1() == 0) return immediate.modify(i, r, v);
            if (i.mnemonic() == Mnemonic.JALR) return base.modify(i, r, v);
            return Optional.empty();
        };
    }

    /**
     * The instruction at a different address but the same retirement step and after the same kind of instruction:
     * both programs jump to it, the first over a nop ({@code jal x0, 8; nop; i}), the second to the next instruction
     * ({@code jal x0, 4; i}).
     */
    static Modifier programCounter() {
        return (i, r, v) -> Optional.of(new Modifier.Modification(List.of(jump(8), nop(), i), List.of(jump(4), i)));
    }

    private static Instruction jump(long offset) {
        return new Instruction(Mnemonic.JAL, 0, null, null, offset);
    }

    /**
     * An aligned address in the first program and a misaligned one in the second ({@code half}: an address that is
     * not half-word aligned, i.e. ends in 0b11). The base register is set right before the access; with base x0, the
     * immediate is changed instead. Needs a core that handles misaligned accesses.
     */
    static Modifier alignment(boolean half) {
        return misaligned((i, r, v) -> {
            if (!i.mnemonic().isMemory()) return Optional.empty();
            long low1 = half ? r.nextLong(3) : 0;
            long low2 = half ? 3 : r.nextLong(1, 4);
            if (i.rs1() == 0) {
                return Optional.of(new Modifier.Modification(List.of(i.withIMM(i.imm() / 4 * 4 + low1)),
                        List.of(i.withIMM(i.imm() / 4 * 4 + low2))));
            }
            long base = v == RegisterValues.LEGACY ? r.nextLong(512) * 4 : RegisterValues.random(r) & 0xfffffffcL;
            return Optional.of(new Modifier.Modification(
                    concat(set(i.rs1(), base + ((low1 - i.imm()) & 3), v), i),
                    concat(set(i.rs1(), base + ((low2 - i.imm()) & 3), v), i)));
        });
    }

    /** The register is zero in the first program and a random non-zero value in the second. */
    static Modifier zero(Function<Instruction, Integer> register) {
        return (i, r, v) -> {
            Integer reg = register.apply(i);
            if (reg == null || reg == 0) return Optional.empty();
            return Optional.of(new Modifier.Modification(concat(set(reg, 0, v), i), concat(set(reg, randomNonZero(r, v), v), i)));
        };
    }

    /**
     * Powers of two with different exponents in the register: below 2^11 with {@link RegisterValues#LEGACY} (so that
     * addi writes them unchanged), any 32-bit power of two otherwise.
     */
    static Modifier log2(Function<Instruction, Integer> register) {
        return (i, r, v) -> {
            Integer reg = register.apply(i);
            if (reg == null || reg == 0) return Optional.empty();
            int exponents = v == RegisterValues.LEGACY ? 11 : 32;
            int a = r.nextInt(exponents);
            int b = (a + r.nextInt(1, exponents)) % exponents;
            return Optional.of(new Modifier.Modification(concat(set(reg, 1L << a, v), i), concat(set(reg, 1L << b, v), i)));
        };
    }

    /**
     * A different result (written to rd): different source operands where the instruction has a source register
     * other than x0, a different immediate for lui and auipc, and otherwise (jal, or a source x0) a destination that
     * is x0 in one program only, which RVFI reports as the value 0.
     */
    static Modifier result() {
        Modifier operand = registerValue(Instruction::rs1), immediate = immediate(),
                destination = field(Instruction::rd, false, Instruction::withRD);
        return (i, r, v) -> {
            if (i.rd() == null) return Optional.empty();
            if (i.rs1() != null && i.rs1() != 0) return operand.modify(i, r, v);
            if (i.mnemonic().format() == Format.U) return immediate.modify(i, r, v);
            return destination.modify(i, r, v);
        };
    }

    /** Both source operands zero in the first program and random in the second (aims at a zero result). */
    static Modifier zeroOperands() {
        return (i, r, v) -> {
            if (i.rd() == null || i.rs1() == null || i.rs1() == 0) return Optional.empty();
            List<Instruction> first = new ArrayList<>(set(i.rs1(), 0, v));
            List<Instruction> second = new ArrayList<>(set(i.rs1(), randomNonZero(r, v), v));
            if (i.rs2() != null && i.rs2() != 0) {
                first.addAll(set(i.rs2(), 0, v));
                second.addAll(set(i.rs2(), randomNonZero(r, v), v));
            }
            first.add(i);
            second.add(i);
            return Optional.of(new Modifier.Modification(first, second));
        };
    }

    /** Marks a modifier whose test cases need misaligned memory accesses. */
    static Modifier misaligned(Modifier m) {
        return new Modifier() {
            @Override
            public Optional<Modification> modify(Instruction target, RandomGenerator random, RegisterValues values) {
                return m.modify(target, random, values);
            }

            @Override
            public boolean needsMisalignedMemory() {
                return true;
            }
        };
    }

    /**
     * The instructions that set a register to a value: with {@link RegisterValues#LEGACY} a single addi from x0, which
     * needs a value it can write (the sign extension of a 12-bit immediate); with {@link RegisterValues#FULL} lui +
     * addi.
     *
     * @param value a 32-bit value; negative values are taken modulo 2^32
     */
    static List<Instruction> set(int register, long value, RegisterValues values) {
        if (values == RegisterValues.FULL) return li(register, value);
        long lo = value & 0xfff;
        if ((signExtend12(lo) & 0xffffffffL) != (value & 0xffffffffL)) {
            throw new IllegalArgumentException("a single addi cannot set " + Long.toHexString(value));
        }
        return List.of(addi(register, 0, lo));
    }

    /** A random register value: the sign extension of a random 12-bit immediate, or any 32-bit value. */
    static long random(RandomGenerator r, RegisterValues values) {
        return values == RegisterValues.LEGACY ? signExtend12(r.nextLong(MAX_IMM_I)) & 0xffffffffL : RegisterValues.random(r);
    }

    private static long randomNonZero(RandomGenerator r, RegisterValues values) {
        return values == RegisterValues.LEGACY ? signExtend12(r.nextLong(1, MAX_IMM_I)) & 0xffffffffL
                : RegisterValues.randomNonZero(r);
    }

    private static List<Instruction> concat(List<Instruction> prefix, Instruction... more) {
        List<Instruction> l = new ArrayList<>(prefix);
        l.addAll(List.of(more));
        return l;
    }

    private static List<Instruction> concat(List<Instruction> a, List<Instruction> b, Instruction last) {
        List<Instruction> l = new ArrayList<>(a);
        l.addAll(b);
        l.add(last);
        return l;
    }

    static long immediateBound(Format f) {
        return switch (f) {
            case R -> 0L;
            case I, S -> MAX_IMM_I;
            case B -> 8192;
            case U -> 4294967296L;
            case J -> 2097152;
        };
    }
}
