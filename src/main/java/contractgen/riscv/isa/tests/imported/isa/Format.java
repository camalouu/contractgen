package contractgen.riscv.isa.tests.imported.isa;

/**
 * RISC-V instruction encoding formats.
 */
public enum Format {
    R, I, S, B, U, J;

    public boolean hasRD() {
        return this == R || this == I || this == U || this == J;
    }

    public boolean hasRS1() {
        return this == R || this == I || this == S || this == B;
    }

    public boolean hasRS2() {
        return this == R || this == S || this == B;
    }

    public boolean hasIMM() {
        return this != R;
    }
}
