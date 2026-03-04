package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;

import java.util.Iterator;
import java.util.List;
import java.util.Set;

/**
 *
 */
public class RISCVTestIterator implements Iterator<TestCase> {

    /**
     * The test generator.
     */
    private final RISCVTestGenearatorInterface generator;
    /**
     * The total number of test cases to be evaluated.
     */
    private final int total;
    /**
     * The current count.
     */
    private int count = 0;
    /**
     * The global index offset assigned to this iterator.
     */
    private final int startIndex;
    /**
     * The currently generated chunk.
     */
    private List<TestCase> chunk;

    /**
     * @param subsets              the allowed ISA subsets.
     * @param allowed_observations the allowed observation types.
     * @param seed                 the random seed.
     * @param total                the total number of test cases to be generated.
     */
    public RISCVTestIterator(Set<RISCV_SUBSET> subsets, Set<RISCV_OBSERVATION_TYPE> allowed_observations, long seed, int total, int startIndex, boolean isSP, boolean allow_misaligned_memory, int reps, boolean bitDist, boolean randomPrefix, boolean randomSuffix, boolean resetSequence) {
        generator = isSP ?  new RISCVTestGeneratorSP(subsets, allowed_observations, seed, 0) : new RISCVTestGenerator(subsets, allowed_observations, seed, 0, allow_misaligned_memory, reps, bitDist, randomPrefix, randomSuffix, resetSequence);
        this.total = total;
        this.startIndex = startIndex;
        this.chunk = generator.nextRepetition(this.startIndex + count);
    }

    @Override
    public boolean hasNext() {
        return total > count;
    }

    @Override
    public TestCase next() {
        if (total < count) return null;
        if (chunk.isEmpty())
            chunk = generator.nextRepetition(startIndex + count + 1);
        count++;
        return chunk.remove(0);
    }
}
