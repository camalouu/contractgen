package contractgen.riscv.isa.tests.imported.generation;
import contractgen.riscv.isa.tests.imported.contract.*;
import contractgen.riscv.isa.tests.imported.isa.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class CoverageFeedbackTest {
 @Test void feedbackCountsOncePerCaseAndReducesTargetFrequency() {
  var recipes=LeakageFunction.recipes().stream().filter(f->Set.of("RS1","RS2","IMM","RD").contains(f.id())).toList();
  List<ContractAtom> targets=new ArrayList<>();
  for(var m:Mnemonic.values())if(m.subset()==Subset.I)for(var f:recipes)if(f.isDefinedFor(m))targets.add(new ContractAtom(MnemonicApplicability.of(m),f));
  var source=new CoverageGuidedSource(targets,Set.of(Subset.I),9,10000,500,false,RegisterValues.FULL);
  var context=new GenerationContext();
  Set<ContractAtom> rs1=new HashSet<>(targets.stream().filter(a->a.leakageFunction().id().equals("RS1")).toList());
  long before=source.nextBatch(context).stream().filter(t->rs1.contains(t.intent().orElseThrow())).count();
  source.onEvidence(Collections.nCopies(100,rs1));
  assertEquals(100,source.observed(rs1.iterator().next()));
  long after=source.nextBatch(context).stream().filter(t->rs1.contains(t.intent().orElseThrow())).count();
  assertTrue(before>20);assertTrue(after*10<before);
 }
}
