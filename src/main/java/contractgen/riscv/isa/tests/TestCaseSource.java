package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.riscv.isa.spike.SpikeAtomClient.SpikeCaseAtoms;
import java.util.List;

/** Called by the generation coordinator, never by simulation workers. */
public interface TestCaseSource {
    List<TestCase> nextBatch(Context context);
    default void onEvidence(List<SpikeCaseAtoms> evidence) { }
    final class Context {
        private int nextId;
        public int nextId() { return nextId++; }
    }
}
