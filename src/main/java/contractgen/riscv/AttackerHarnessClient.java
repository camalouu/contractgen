package contractgen.riscv;

import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;

/** A single-case adapter for an attacker-only RTL harness. */
@FunctionalInterface
public interface AttackerHarnessClient {
    SIMULATION_RESULT run(TestCase test, int maxCycles);
}
