package contractgen.riscv.isa.tests.imported.contract;

import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;

import java.util.List;
import java.util.Optional;
import java.util.random.RandomGenerator;

/**
 * Modifier function of a leakage function (CCS 2025): turns an instruction into two instruction sequences that
 * differ in the value of the leakage function, so that a test case exercises it.
 */
@FunctionalInterface
public interface Modifier {

    /**
     * @param values the values to load into registers: with {@link RegisterValues#LEGACY} a single addi sets a
     *               register, as in the original generator; with {@link RegisterValues#FULL} lui + addi set any
     *               32-bit value
     * @return the two sequences (each ends with the targeted instruction), or empty if the leakage function cannot be
     * exercised on this instruction
     */
    Optional<Modification> modify(Instruction target, RandomGenerator random, RegisterValues values);

    /**
     * @return whether the test cases rely on misaligned memory accesses, so that they are useless on cores where test
     * generation aligns all accesses
     */
    default boolean needsMisalignedMemory() {
        return false;
    }

    /**
     * The instructions that precede the shared suffix in the first and in the second program.
     */
    record Modification(List<Instruction> first, List<Instruction> second) {
        public Modification {
            first = List.copyOf(first);
            second = List.copyOf(second);
        }
    }
}
