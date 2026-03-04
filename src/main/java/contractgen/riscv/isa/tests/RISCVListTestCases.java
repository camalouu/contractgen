package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.TestCases;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class RISCVListTestCases extends TestCases {

    private static List<Iterator<TestCase>> createIterators(List<TestCase> tests, int threads) {
        int count = Math.max(1, threads);
        List<Iterator<TestCase>> iterators = new ArrayList<>(count);
        int offset = 0;
        for (int i = 0; i < count; i++) {
            int size = tests.size() / count + (tests.size() % count > i ? 1 : 0);
            iterators.add(tests.subList(offset, offset + size).iterator());
            offset += size;
        }
        return iterators;
    }

    public RISCVListTestCases(List<TestCase> tests, int threads) {
        super(createIterators(tests, threads), tests.size());
    }
}
