package contractgen.riscv.isa.tests;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
/** Intended atom and consumer context; never treated as extracted evidence. */
public record GenerationTarget(RISCVObservation atom, RISCV_TYPE consumer) { }
