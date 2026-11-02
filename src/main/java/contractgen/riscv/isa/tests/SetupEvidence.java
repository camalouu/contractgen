package contractgen.riscv.isa.tests;
/** Boundary is a count of body-image instructions before generated instructions, excluding rv32-v1 initializer slots. */
public record SetupEvidence(int setupInstructions, boolean includeSetup) {
    public SetupEvidence {
        if (setupInstructions < 0 || setupInstructions > 2016)
            throw new IllegalArgumentException("Invalid setup instruction boundary: " + setupInstructions);
    }
}
