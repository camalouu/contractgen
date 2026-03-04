package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.TestCases;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;

import java.util.*;

/**
 * An iterative test generation method.
 */
public class RISCVIterativeTests extends TestCases {
    /**
     * @param subsets              the ISA subsets to consider.
     * @param allowed_observations the observations under consideration.
     * @param seed                 a random seed.
     * @param THREADS              the number of threads that will be used for generation
     * @param count                the total number of testcases to be generated.
     * @return A list of testcase iterators.
     */
    private static List<Iterator<TestCase>> createIterators(Set<RISCV_SUBSET> subsets, Set<RISCV_OBSERVATION_TYPE> allowed_observations, long seed, int THREADS, int count, boolean isSP, boolean allow_misaligned_memory, int reps, boolean bitDist, boolean randomPrefix) {
        List<Iterator<TestCase>> iterators = new ArrayList<>(THREADS);
        Random r = new Random(seed);
        int startIndex = 0;
        for (int i = 0; i < THREADS; i++) {
            int perThreadCount = count / THREADS + (count % THREADS > i ? 1 : 0);
            iterators.add(new RISCVTestIterator(subsets, allowed_observations, r.nextLong(), perThreadCount, startIndex, isSP, allow_misaligned_memory, reps, bitDist, randomPrefix));
            startIndex += perThreadCount;
        }
        return iterators;
    }

    /**
     * @param subsets              the ISA subsets to consider.
     * @param allowed_observations the observations under consideration.
     * @param seed                 a random seed.
     * @param THREADS              the number of threads that will be used for generation
     * @param count                the total number of testcases to be generated.
     */
    public RISCVIterativeTests(Set<RISCV_SUBSET> subsets, Set<RISCV_OBSERVATION_TYPE> allowed_observations, long seed, int THREADS, int count, boolean allow_misaligned_memory) {
        super(createIterators(subsets, allowed_observations, seed, THREADS, count, false, allow_misaligned_memory, 1, false, false), count);
    }

    /**
     * @param subsets              the ISA subsets to consider.
     * @param allowed_observations the observations under consideration.
     * @param seed                 a random seed.
     * @param THREADS              the number of threads that will be used for generation
     * @param count                the total number of testcases to be generated.
     */
    public RISCVIterativeTests(Set<RISCV_SUBSET> subsets, Set<RISCV_OBSERVATION_TYPE> allowed_observations, long seed, int THREADS, int count, boolean isSP, boolean allow_misaligned_memory) {
        super(createIterators(subsets, allowed_observations, seed, THREADS, count, isSP, allow_misaligned_memory, 1, false, false), count);
    }
    
    public RISCVIterativeTests(Set<RISCV_SUBSET> subsets, Set<RISCV_OBSERVATION_TYPE> allowed_observations, long seed, int THREADS, int count, boolean isSP, boolean allow_misaligned_memory, int reps, boolean bitDist, boolean randomPrefix) {
        super(createIterators(subsets, allowed_observations, seed, THREADS, count, isSP, allow_misaligned_memory, reps, bitDist, randomPrefix), count);
    }
}
