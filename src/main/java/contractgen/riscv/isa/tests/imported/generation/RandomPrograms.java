package contractgen.riscv.isa.tests.imported.generation;

import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;

import java.util.*;
import java.util.random.RandomGenerator;

/**
 * Random registers, instructions and instruction sequences, ported from the original test generator. Random numbers
 * are drawn in the same order as there; the values differ only where a parity-ledger bug was fixed (see MIGRATION.md
 * → "Behaviour changes").
 */
final class RandomPrograms {

    static final int REGISTERS = 32;
    static final long MAX_IMM_I = 4096;
    private static final long MAX_IMM_B = 8192;
    private static final long MAX_IMM_U = 4294967296L;
    private static final long MAX_IMM_J = 2097152;
    private static final Set<Mnemonic> ALIGNMENT_SENSITIVE = EnumSet.of(Mnemonic.SH, Mnemonic.SW, Mnemonic.LH, Mnemonic.LHU, Mnemonic.LW);

    private RandomPrograms() {
    }

    /**
     * Each of x1..x31 gets a random value with probability 1/2 and stays 0 otherwise. With
     * {@link RegisterValues#LEGACY} the value is the sign extension of a random 12-bit immediate (the original drew the
     * immediate of an addi), with {@link RegisterValues#FULL} a 32-bit value.
     */
    static SortedMap<Integer, Long> registers(RandomGenerator r, RegisterValues values) {
        SortedMap<Integer, Long> result = new TreeMap<>();
        for (int i = 1; i < REGISTERS; i++) {
            if (r.nextBoolean()) {
                result.put(i, value(r, values));
            } else {
                r.nextBoolean();  // the original drew whether to store an explicit null
            }
        }
        return result;
    }

    /** A random register value of the distribution, as {@link #registers} draws the values it does not leave at 0. */
    static long value(RandomGenerator r, RegisterValues values) {
        return values == RegisterValues.LEGACY
                ? Instruction.signExtend12(r.nextInt((int) MAX_IMM_I)) & 0xffffffffL
                : RegisterValues.random(r);
    }

    /**
     * A random sequence of {@code size} instructions of the given mnemonics (a jalr is preceded by an andi that aligns
     * its base register and counts twice).
     */
    static List<Instruction> sequence(RandomGenerator r, List<Mnemonic> mnemonics, int size) {
        List<Instruction> result = new ArrayList<>(size);
        for (int i = 0; i < size; i++) {
            Mnemonic m = mnemonics.get(r.nextInt(mnemonics.size()));
            Instruction instruction = instruction(r, m);
            if (m == Mnemonic.JALR) {
                result.add(Instruction.andi(instruction.rs1(), instruction.rs1(), MAX_IMM_I - 4));
                i++;
            }
            result.add(instruction);
        }
        return result;
    }

    /** A random instruction with the given mnemonic. */
    static Instruction instruction(RandomGenerator r, Mnemonic m) {
        return switch (m.format()) {
            case R -> new Instruction(m, r.nextInt(1, REGISTERS), r.nextInt(REGISTERS), r.nextInt(REGISTERS), null);
            case I -> {
                int rd = r.nextInt(1, REGISTERS);
                int rs1 = r.nextInt(REGISTERS);
                yield new Instruction(m, rd, rs1, null, immediate(r, m));
            }
            case S, B -> {
                int rs1 = r.nextInt(REGISTERS);
                int rs2 = r.nextInt(REGISTERS);
                yield new Instruction(m, null, rs1, rs2, immediate(r, m));
            }
            case U, J -> {
                int rd = r.nextInt(1, REGISTERS);
                yield new Instruction(m, rd, null, null, immediate(r, m));
            }
        };
    }

    /**
     * A random immediate for the mnemonic, as {@link #instruction} draws it. Jump and branch offsets are multiples of
     * 4.
     */
    static long immediate(RandomGenerator r, Mnemonic m) {
        return switch (m.format()) {
            case R -> throw new IllegalArgumentException(m + " has no immediate");
            case I -> m == Mnemonic.JALR ? r.nextLong(MAX_IMM_I) / 4 * 4 : r.nextLong(MAX_IMM_I);
            case S -> r.nextLong(MAX_IMM_I);
            case B -> r.nextLong(MAX_IMM_B) / 4 * 4;
            case U -> r.nextLong(MAX_IMM_I - 1, MAX_IMM_U);
            case J -> r.nextLong(MAX_IMM_J) / 4 * 4;
        };
    }

    /**
     * A uniformly random selection of {@code k} elements, in their original order (all of them if there are no more
     * than {@code k}). Used to truncate the last batch without favouring the mnemonics that come first.
     */
    static <T> List<T> sample(Random r, List<T> list, long k) {
        if (k >= list.size()) return list;
        List<Integer> indices = new ArrayList<>(list.size());
        for (int i = 0; i < list.size(); i++) indices.add(i);
        Collections.shuffle(indices, r);
        return indices.subList(0, (int) k).stream().sorted().map(list::get).toList();
    }

    /** Inserts an andi before every jalr that clears the low bits of its base register, so that its target is aligned. */
    static List<Instruction> alignJumps(List<Instruction> instructions) {
        List<Instruction> aligned = new ArrayList<>();
        for (Instruction i : instructions) {
            if (i.mnemonic() == Mnemonic.JALR) aligned.add(Instruction.andi(i.rs1(), i.rs1(), MAX_IMM_I - 4));
            aligned.add(i);
        }
        return aligned;
    }

    /** Inserts andi/ori instructions so that half- and word-sized memory accesses are aligned. */
    static List<Instruction> alignMemoryAddresses(List<Instruction> instructions) {
        List<Instruction> aligned = new ArrayList<>();
        for (Instruction i : instructions) {
            if (ALIGNMENT_SENSITIVE.contains(i.mnemonic())) {
                if (i.rs1() == 0) {
                    // x0 cannot be changed, so align the immediate instead
                    aligned.add(i.withIMM(i.imm() / 4 * 4));
                    continue;
                }
                switch ((int) (i.imm() % 4)) {
                    case 0 -> aligned.add(Instruction.andi(i.rs1(), i.rs1(), MAX_IMM_I - 4));
                    case 1 -> aligned.add(Instruction.ori(i.rs1(), i.rs1(), 3));
                    case 2 -> {
                        aligned.add(Instruction.andi(i.rs1(), i.rs1(), MAX_IMM_I - 2));
                        aligned.add(Instruction.ori(i.rs1(), i.rs1(), 2));
                    }
                    default -> {
                        aligned.add(Instruction.andi(i.rs1(), i.rs1(), MAX_IMM_I - 3));
                        aligned.add(Instruction.ori(i.rs1(), i.rs1(), 1));
                    }
                }
            }
            aligned.add(i);
        }
        return aligned;
    }
}
