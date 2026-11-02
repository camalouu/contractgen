package contractgen.riscv.isa.tests.imported.isa;

import java.util.Locale;

/**
 * RISC-V ISA subsets that test cases can draw instructions from.
 */
public enum Subset {
    /** RV32I, the base integer instruction set (legacy name: BASE). */
    I,
    /** The M extension: multiplication and division. */
    M;

    /**
     * @param name a subset name; the legacy name BASE is accepted for {@link #I}.
     * @return the subset with that name.
     */
    public static Subset parse(String name) {
        String n = name.strip().toUpperCase(Locale.ROOT);
        return n.equals("BASE") ? I : valueOf(n);
    }
}
