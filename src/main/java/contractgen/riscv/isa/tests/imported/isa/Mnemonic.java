package contractgen.riscv.isa.tests.imported.isa;

/**
 * RV32IM instruction mnemonics with their encoding (was {@code contractgen.riscv.isa.RISCV_TYPE}).
 * <p>
 * The constant names are part of the JSON formats (v1 and v2). The shift-immediate instructions are encoded as
 * {@link Format#R} with the shift amount in the rs2 field, as in the original toolchain.
 */
public enum Mnemonic {
    LUI("lui", Subset.I, Format.U, "0110111"),
    AUIPC("auipc", Subset.I, Format.U, "0010111"),
    JAL("jal", Subset.I, Format.J, "1101111"),
    JALR("jalr", Subset.I, Format.I, "1100111", "000"),
    BEQ("beq", Subset.I, Format.B, "1100011", "000"),
    BNE("bne", Subset.I, Format.B, "1100011", "001"),
    BLT("blt", Subset.I, Format.B, "1100011", "100"),
    BGE("bge", Subset.I, Format.B, "1100011", "101"),
    BLTU("bltu", Subset.I, Format.B, "1100011", "110"),
    BGEU("bgeu", Subset.I, Format.B, "1100011", "111"),
    LB("lb", Subset.I, Format.I, "0000011", "000"),
    LH("lh", Subset.I, Format.I, "0000011", "001"),
    LW("lw", Subset.I, Format.I, "0000011", "010"),
    LBU("lbu", Subset.I, Format.I, "0000011", "100"),
    LHU("lhu", Subset.I, Format.I, "0000011", "101"),
    SB("sb", Subset.I, Format.S, "0100011", "000"),
    SH("sh", Subset.I, Format.S, "0100011", "001"),
    SW("sw", Subset.I, Format.S, "0100011", "010"),
    ADDI("addi", Subset.I, Format.I, "0010011", "000"),
    SLTI("slti", Subset.I, Format.I, "0010011", "010"),
    SLTIU("sltiu", Subset.I, Format.I, "0010011", "011"),
    XORI("xori", Subset.I, Format.I, "0010011", "100"),
    ORI("ori", Subset.I, Format.I, "0010011", "110"),
    ANDI("andi", Subset.I, Format.I, "0010011", "111"),
    SLLI("slli", Subset.I, Format.R, "0010011", "001", "0000000"),
    SRLI("srli", Subset.I, Format.R, "0010011", "101", "0000000"),
    SRAI("srai", Subset.I, Format.R, "0010011", "101", "0100000"),
    ADD("add", Subset.I, Format.R, "0110011", "000", "0000000"),
    SUB("sub", Subset.I, Format.R, "0110011", "000", "0100000"),
    SLL("sll", Subset.I, Format.R, "0110011", "001", "0000000"),
    SLT("slt", Subset.I, Format.R, "0110011", "010", "0000000"),
    SLTU("sltu", Subset.I, Format.R, "0110011", "011", "0000000"),
    XOR("xor", Subset.I, Format.R, "0110011", "100", "0000000"),
    SRL("srl", Subset.I, Format.R, "0110011", "101", "0000000"),
    SRA("sra", Subset.I, Format.R, "0110011", "101", "0100000"),
    OR("or", Subset.I, Format.R, "0110011", "110", "0000000"),
    AND("and", Subset.I, Format.R, "0110011", "111", "0000000"),
    MUL("mul", Subset.M, Format.R, "0110011", "000", "0000001"),
    MULH("mulh", Subset.M, Format.R, "0110011", "001", "0000001"),
    MULHSU("mulhsu", Subset.M, Format.R, "0110011", "010", "0000001"),
    MULHU("mulhu", Subset.M, Format.R, "0110011", "011", "0000001"),
    DIV("div", Subset.M, Format.R, "0110011", "100", "0000001"),
    DIVU("divu", Subset.M, Format.R, "0110011", "101", "0000001"),
    REM("rem", Subset.M, Format.R, "0110011", "110", "0000001"),
    REMU("remu", Subset.M, Format.R, "0110011", "111", "0000001");

    private final String assemblyName;
    private final Subset subset;
    private final Format format;
    private final String opcode;
    private final String funct3;
    private final String funct7;

    Mnemonic(String assemblyName, Subset subset, Format format, String opcode) {
        this(assemblyName, subset, format, opcode, null, null);
    }

    Mnemonic(String assemblyName, Subset subset, Format format, String opcode, String funct3) {
        this(assemblyName, subset, format, opcode, funct3, null);
    }

    Mnemonic(String assemblyName, Subset subset, Format format, String opcode, String funct3, String funct7) {
        this.assemblyName = assemblyName;
        this.subset = subset;
        this.format = format;
        this.opcode = opcode;
        this.funct3 = funct3;
        this.funct7 = funct7;
    }

    public String assemblyName() {
        return assemblyName;
    }

    public Subset subset() {
        return subset;
    }

    public Format format() {
        return format;
    }

    /** @return the 7-bit opcode as a binary string. */
    public String opcode() {
        return opcode;
    }

    /** @return the 3-bit funct3 field as a binary string, or null if the encoding has none. */
    public String funct3() {
        return funct3;
    }

    /** @return the 7-bit funct7 field as a binary string, or null if the encoding has none. */
    public String funct7() {
        return funct7;
    }

    public boolean hasFunct3() {
        return funct3 != null;
    }

    public boolean hasFunct7() {
        return funct7 != null;
    }

    public boolean hasRD() {
        return format.hasRD();
    }

    public boolean hasRS1() {
        return format.hasRS1();
    }

    public boolean hasRS2() {
        return format.hasRS2();
    }

    public boolean hasIMM() {
        return format.hasIMM();
    }

    public boolean isLoad() {
        return this == LB || this == LH || this == LW || this == LBU || this == LHU;
    }

    public boolean isStore() {
        return this == SB || this == SH || this == SW;
    }

    public boolean isMemory() {
        return isLoad() || isStore();
    }

    public boolean isBranch() {
        return this == BEQ || this == BNE || this == BLT || this == BGE || this == BLTU || this == BGEU;
    }

    public boolean isJump() {
        return this == JAL || this == JALR;
    }

    public boolean isControl() {
        return isBranch() || isJump();
    }
}
