package contractgen.riscv.isa.tests.imported.isa;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

/**
 * A decoded RV32IM instruction. Fields the format does not have are null.
 * <p>
 * Immediates are kept as the unsigned value of their bit pattern (not sign-extended), as in the original toolchain;
 * the I-type immediate of {@code addi x1, x0, -1} is 4095.
 */
public record Instruction(Mnemonic mnemonic, Integer rd, Integer rs1, Integer rs2, Long imm) {

    public static Instruction addi(int rd, int rs1, long imm) {
        return new Instruction(Mnemonic.ADDI, rd, rs1, null, imm);
    }

    public static Instruction andi(int rd, int rs1, long imm) {
        return new Instruction(Mnemonic.ANDI, rd, rs1, null, imm);
    }

    public static Instruction ori(int rd, int rs1, long imm) {
        return new Instruction(Mnemonic.ORI, rd, rs1, null, imm);
    }

    public static Instruction add(int rd, int rs1, int rs2) {
        return new Instruction(Mnemonic.ADD, rd, rs1, rs2, null);
    }

    public static Instruction sw(int rs1, int rs2, long imm) {
        return new Instruction(Mnemonic.SW, null, rs1, rs2, imm);
    }

    public static Instruction nop() {
        return addi(0, 0, 0);
    }

    /** @param upper the upper 20 bits of the immediate, as the instruction shifts them: {@code (upper & 0xfffff) << 12} */
    public static Instruction lui(int rd, long upper) {
        return new Instruction(Mnemonic.LUI, rd, null, null, (upper & 0xfffffL) << 12);
    }

    /**
     * The pseudo-instruction {@code li rd, value}, always expanded into the same two instructions {@code lui; addi}
     * (also for values a single addi could set), so that the sequence does not depend on the value.
     *
     * @param value a 32-bit value (only the low 32 bits are used)
     */
    public static List<Instruction> li(int rd, long value) {
        long v = value & 0xffffffffL;
        // addi sign-extends its immediate, so round the upper part up when bit 11 is set
        return List.of(lui(rd, (v + 0x800) >>> 12), addi(rd, rd, v & 0xfff));
    }

    /** @return the value an I-type instruction like addi adds for a 12-bit immediate (given as its bit pattern) */
    public static long signExtend12(long imm) {
        return imm >= 2048 ? imm - 4096 : imm;
    }

    public Instruction withRD(int rd) {
        return new Instruction(mnemonic, rd, rs1, rs2, imm);
    }

    public Instruction withRS1(int rs1) {
        return new Instruction(mnemonic, rd, rs1, rs2, imm);
    }

    public Instruction withRS2(int rs2) {
        return new Instruction(mnemonic, rd, rs1, rs2, imm);
    }

    public Instruction withIMM(long imm) {
        return new Instruction(mnemonic, rd, rs1, rs2, imm);
    }

    public boolean hasRD() {
        return rd != null;
    }

    public boolean hasRS1() {
        return rs1 != null;
    }

    public boolean hasRS2() {
        return rs2 != null;
    }

    public boolean hasIMM() {
        return imm != null;
    }

    /**
     * @param word a binary string of up to 32 bits (shorter strings are zero-extended, as VCD values are).
     * @return the decoded instruction, or empty if the word contains non-binary digits (x, z) or is no RV32IM
     * instruction.
     */
    public static Optional<Instruction> decode(String word) {
        if (word.length() > 32) return Optional.empty();
        String w = "0".repeat(32 - word.length()) + word;
        if (!w.chars().allMatch(c -> c == '0' || c == '1')) return Optional.empty();

        String opcode = w.substring(25);
        String funct3 = w.substring(17, 20);
        String funct7 = w.substring(0, 7);
        List<Mnemonic> candidates = Arrays.stream(Mnemonic.values()).filter(m -> m.opcode().equals(opcode)).toList();
        if (candidates.size() > 1)
            candidates = candidates.stream().filter(m -> funct3.equals(m.funct3())).toList();
        if (candidates.size() > 1)
            candidates = candidates.stream().filter(m -> funct7.equals(m.funct7())).toList();
        if (candidates.size() != 1) return Optional.empty();
        Mnemonic m = candidates.get(0);

        int rd = Integer.parseInt(w.substring(20, 25), 2);
        int rs1 = Integer.parseInt(w.substring(12, 17), 2);
        int rs2 = Integer.parseInt(w.substring(7, 12), 2);
        return Optional.of(switch (m.format()) {
            case R -> new Instruction(m, rd, rs1, rs2, null);
            case I -> new Instruction(m, rd, rs1, null, Long.parseLong(w.substring(0, 12), 2));
            case S -> new Instruction(m, null, rs1, rs2, Long.parseLong(w.substring(0, 7) + w.substring(20, 25), 2));
            case B -> new Instruction(m, null, rs1, rs2,
                    Long.parseLong(w.charAt(0) + w.substring(24, 25) + w.substring(1, 7) + w.substring(20, 24) + "0", 2));
            case U -> new Instruction(m, rd, null, null, Long.parseLong(w.substring(0, 20) + "0".repeat(12), 2));
            case J -> new Instruction(m, rd, null, null,
                    Long.parseLong(w.charAt(0) + w.substring(12, 20) + w.charAt(11) + w.substring(1, 11) + "0", 2));
        });
    }

    /** @return the 32-bit encoding as a binary string. */
    public String encode() {
        Format f = mnemonic.format();
        return switch (f) {
            case R -> mnemonic.funct7() + bits(rs2, 5) + bits(rs1, 5) + mnemonic.funct3() + bits(rd, 5) + mnemonic.opcode();
            case I -> bits(imm, 12) + bits(rs1, 5) + mnemonic.funct3() + bits(rd, 5) + mnemonic.opcode();
            case S -> {
                String i = bits(imm, 12);
                yield i.substring(0, 7) + bits(rs2, 5) + bits(rs1, 5) + mnemonic.funct3() + i.substring(7, 12) + mnemonic.opcode();
            }
            case B -> {
                String s = bits(imm, 13);
                String i = s.charAt(0) + s.substring(2, 8) + s.substring(8, 12) + s.charAt(1);
                yield i.substring(0, 7) + bits(rs2, 5) + bits(rs1, 5) + mnemonic.funct3() + i.substring(7, 12) + mnemonic.opcode();
            }
            case U -> bits(imm, 32).substring(0, 20) + bits(rd, 5) + mnemonic.opcode();
            case J -> {
                String s = bits(imm, 21);
                yield s.charAt(0) + s.substring(10, 20) + s.charAt(9) + s.substring(1, 9) + bits(rd, 5) + mnemonic.opcode();
            }
        };
    }

    /** @return the 32-bit encoding as 8 hexadecimal digits. */
    public String encodeHex() {
        return String.format("%08x", Long.parseLong(encode(), 2));
    }

    private static String bits(long value, int width) {
        String s = Long.toBinaryString(value);
        if (s.length() > width) s = s.substring(s.length() - width);
        return "0".repeat(width - s.length()) + s;
    }
}
