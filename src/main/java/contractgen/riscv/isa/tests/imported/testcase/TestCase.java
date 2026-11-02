package contractgen.riscv.isa.tests.imported.testcase;

import contractgen.riscv.isa.tests.imported.contract.ContractAtom;
import contractgen.riscv.isa.tests.imported.isa.Program;

import java.util.Optional;

/**
 * A test case T = (σ, σ′): two programs that run side by side on two instances of a core.
 *
 * @param id     unique within a run
 * @param first  the program of the first run
 * @param second the program of the second run
 * @param intent the atom the test case was generated to exercise, if any (was {@code getLikelyCTX})
 */
public record TestCase(long id, Program first, Program second, Optional<ContractAtom> intent) {

    /**
     * @return how many instructions each core fetches: the register initialization plus the longer program
     */
    public int instructionCount() {
        return Program.INIT_INSTRUCTIONS + Math.max(first.instructions().size(), second.instructions().size());
    }
}
