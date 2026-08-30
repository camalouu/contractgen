package contractgen.riscv;

import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;

import java.util.OptionalInt;

/** A single-case adapter for an attacker-only RTL harness. */
@FunctionalInterface
public interface AttackerHarnessClient {
    SIMULATION_RESULT run(TestCase test, int maxCycles);

    default AttackerResult runDetailed(TestCase test, int maxCycles) {
        return new AttackerResult(run(test, maxCycles), OptionalInt.empty(), OptionalInt.empty());
    }

    record AttackerResult(SIMULATION_RESULT status, OptionalInt failureCutoff, OptionalInt executionCutoff) {
        public AttackerResult {
            failureCutoff = failureCutoff == null ? OptionalInt.empty() : failureCutoff;
            executionCutoff = executionCutoff == null ? OptionalInt.empty() : executionCutoff;
        }
    }
}
