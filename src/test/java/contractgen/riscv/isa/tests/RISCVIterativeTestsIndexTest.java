package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import org.junit.jupiter.api.Test;

import java.util.EnumSet;
import java.util.Iterator;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

final class RISCVIterativeTestsIndexTest {

    @Test
    void assignsEveryIndexExactlyOnceAcrossThreadAndRepetitionBoundaries() {
        int count = 25_000;
        int threads = 8;
        Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> groups = EnumSet.of(
                RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BASE,
                RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.ALIGNED,
                RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BRANCH,
                RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.DEPENDENCIES,
                RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.VALUE
        );
        RISCVIterativeTests tests = new RISCVIterativeTests(
                EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                RISCV_OBSERVATION_TYPE.getGroups(groups),
                58L,
                threads,
                count,
                false,
                true,
                1,
                false,
                false,
                false,
                false
        );

        boolean[] seen = new boolean[count];
        int generated = 0;
        for (int thread = 0; thread < threads; thread++) {
            Iterator<TestCase> iterator = tests.getIterator(thread);
            while (iterator.hasNext()) {
                int index = iterator.next().getIndex();
                assertTrue(index >= 0 && index < count, "out-of-range index: " + index);
                assertFalse(seen[index], "duplicate index: " + index);
                seen[index] = true;
                generated++;
            }
        }

        assertEquals(count, generated);
        for (int index = 0; index < count; index++) {
            assertTrue(seen[index], "missing index: " + index);
        }
    }
}
