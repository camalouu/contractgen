package contractgen.riscv.isa.tests.imported.isa;

import java.util.Arrays;
import java.util.EnumSet;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Categories of instructions, for atoms that apply to a whole category instead of a single mnemonic.
 */
public enum Category {
    /** lui, auipc */
    UPPER_IMMEDIATE,
    /** jal, jalr */
    JUMP,
    /** conditional branches */
    BRANCH,
    LOAD,
    STORE,
    /** register-immediate arithmetic, logic, comparisons and shifts */
    ALU_IMMEDIATE,
    /** register-register arithmetic, logic, comparisons and shifts */
    ALU,
    /** mul, mulh, mulhsu, mulhu */
    MULTIPLY,
    /** div, divu, rem, remu */
    DIVIDE;

    public static Category of(Mnemonic m) {
        if (m.format() == Format.U) return UPPER_IMMEDIATE;
        if (m.isJump()) return JUMP;
        if (m.isBranch()) return BRANCH;
        if (m.isLoad()) return LOAD;
        if (m.isStore()) return STORE;
        if (m.opcode().equals("0010011")) return ALU_IMMEDIATE;
        if (m.subset() == Subset.I) return ALU;
        return m.funct3().charAt(0) == '0' ? MULTIPLY : DIVIDE;
    }

    /** @return the mnemonics of this category. */
    public Set<Mnemonic> mnemonics() {
        return Arrays.stream(Mnemonic.values()).filter(m -> of(m) == this)
                .collect(Collectors.toCollection(() -> EnumSet.noneOf(Mnemonic.class)));
    }
}
