package contractgen.riscv.isa.tests;
import contractgen.TestCase;
import contractgen.TestCases;
import java.util.List;
/** Preserves the existing partition order, IDs, seeds and natural testcase count. */
public final class CurrentTestCaseSource implements TestCaseSource {
    private final TestCases tests;
    private final int threads;
    private boolean consumed;
    public CurrentTestCaseSource(TestCases tests, int threads) { this.tests=tests; this.threads=threads; }
    public List<TestCase> nextBatch(Context context) {
        if (consumed) return List.of();
        consumed=true;
        return RISCVTestCaseIO.collect(tests::getIterator, threads);
    }
}
