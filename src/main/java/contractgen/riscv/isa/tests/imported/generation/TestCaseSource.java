package contractgen.riscv.isa.tests.imported.generation;
import java.util.List;
import contractgen.riscv.isa.tests.imported.testcase.TestCase;
public interface TestCaseSource { List<TestCase> nextBatch(GenerationContext context); }
