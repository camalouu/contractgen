package contractgen.riscv.isa.tests;
import contractgen.*;
import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.*;
import contractgen.riscv.isa.tests.imported.generation.RandomSource;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class PluggableSourcesTest {
 @TempDir Path temp;
 private ImportedTestCaseSource source(String strategy,int batch,boolean align) {
  return new ImportedTestCaseSource(strategy,Set.of(RISCV_SUBSET.BASE),EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),42,79,align,"full",batch,RandomSource.Distributions.DEFAULT,true);
 }
 private List<TestCase> all(TestCaseSource source) {
  List<TestCase> out=new ArrayList<>();var c=new TestCaseSource.Context();
  for(var b=source.nextBatch(c);!b.isEmpty();b=source.nextBatch(c)) {out.addAll(b);assertTrue(out.size()<10000);}
  return out;
 }
 @Test void nativeZeroInitializerIsSharedImmutableAndSerializesIdentically() {
  var tests=all(source("random",17,true));
  var registers=((RISCVProgram)tests.get(0).getProgram1()).getRegisters();
  for(var t:tests)for(var p:List.of(t.getProgram1(),t.getProgram2()))
   assertSame(registers,((RISCVProgram)p).getRegisters());
  assertThrows(UnsupportedOperationException.class,()->registers.put(1,1));
  var t=(RISCVTestCase)tests.get(0);
  var a=(RISCVProgram)t.getProgram1();var b=(RISCVProgram)t.getProgram2();
  var copy=new RISCVTestCase(new RISCVProgram(new TreeMap<>(a.getRegisters()),a.getProgram()),
      new RISCVProgram(new TreeMap<>(b.getRegisters()),b.getProgram()),t.getMaxInstructionCount(),t.getIndex());
  copy.setSetupEvidence(t.getSetupEvidence());
  assertEquals(RISCVTestCaseIO.toJSON(List.of(t)),RISCVTestCaseIO.toJSON(List.of(copy)));
 }
 @Test void deterministicExactCountsAndBatchIndependentRandom() {
  for(String strategy:List.of("different_programs","same_programs","coverage_guided","random")) {
   var a=all(source(strategy,17,false));var b=all(source(strategy,17,false));
   assertEquals(79,a.size());assertEquals(RISCVTestCaseIO.toJSON(a),RISCVTestCaseIO.toJSON(b));
   for(int i=0;i<a.size();i++)assertEquals(i,a.get(i).getIndex());
   if(strategy.equals("random"))assertEquals(RISCVTestCaseIO.toJSON(a),RISCVTestCaseIO.toJSON(all(source(strategy,1,false))));
   for(var t:a)for(var p:List.of(t.getProgram1(),t.getProgram2())) {
    var rp=(RISCVProgram)p;
    assertTrue(rp.getProgram().stream().allMatch(i->i.type().getSubset()==RISCV_SUBSET.BASE));
    assertEquals(Math.max(((RISCVProgram)t.getProgram1()).getProgram().size(),((RISCVProgram)t.getProgram2()).getProgram().size())+1,t.getMaxInstructionCount());
    assertEquals(31,rp.getRegisters().size());assertTrue(rp.getRegisters().values().stream().allMatch(v->v==0));
   }
  }
 }
 @Test void sameProgramsBodyIsIdenticalAndMetadataRoundTrips() throws Exception {
  var tests=all(source("same_programs",10,true));
  for(var t:tests) {
   assertEquals(((RISCVProgram)t.getProgram1()).getProgram().subList(63,((RISCVProgram)t.getProgram1()).getProgram().size()),
    ((RISCVProgram)t.getProgram2()).getProgram().subList(63,((RISCVProgram)t.getProgram2()).getProgram().size()));
   assertEquals(new SetupEvidence(63,false),((RISCVTestCase)t).getSetupEvidence());
  }
  Path file=temp.resolve("cases.json");RISCVTestCaseIO.write(file,tests);
  assertEquals(RISCVTestCaseIO.toJSON(tests),RISCVTestCaseIO.toJSON(RISCVTestCaseIO.read(file)));
 }
 @Test void wrappingCurrentPreservesEveryFingerprint() {
  for(boolean sp:List.of(false,true))for(boolean prefix:List.of(false,true))for(int reps:List.of(1,3)) {
   var original=new RISCVIterativeTests(Set.of(RISCV_SUBSET.BASE),Set.of(RISCV_OBSERVATION_TYPE.REG_RS1),7,4,40,sp,true,reps,false,prefix,true,true);
   var wrapped=new RISCVIterativeTests(Set.of(RISCV_SUBSET.BASE),Set.of(RISCV_OBSERVATION_TYPE.REG_RS1),7,4,40,sp,true,reps,false,prefix,true,true);
   assertEquals(RISCVTestCaseIO.toJSON(RISCVTestCaseIO.collect(original::getIterator,4)),RISCVTestCaseIO.toJSON(all(new CurrentTestCaseSource(wrapped,4))));
  }
 }
 @Test void fullWidthLoweringAndHistoricalReplay() throws Exception {
  Path f=temp.resolve("rewrite.jsonl");
  Files.writeString(f,"{\"format\":\"contract-synthesis/testcases/2\",\"id\":9,\"first\":{\"registers\":{\"1\":2147483648,\"2\":4294967295},\"instructions\":[\"00108093\"]},\"second\":{\"registers\":{},\"instructions\":[\"00000013\"]}}\n");
  var t=(RISCVTestCase)RISCVTestCaseIO.read(f).get(0);var p=((RISCVProgram)t.getProgram1()).getProgram();
  assertEquals(0x800000b7L,Long.parseUnsignedLong(p.get(0).toHexEncoding(),16));
  assertEquals(0xfff10113L,Long.parseUnsignedLong(p.get(3).toHexEncoding(),16));
  assertEquals(new SetupEvidence(63,true),t.getSetupEvidence());
  Path old=temp.resolve("old.json");Files.writeString(old,"[{\"registers1\":{},\"registers2\":{},\"program1\":[],\"program2\":[],\"maxInstructionCount\":0,\"index\":0}]");
  assertNull(((RISCVTestCase)RISCVTestCaseIO.read(old).get(0)).getSetupEvidence());
 }
 @Test void rejectsOversizeAndMalformedBoundary() {
  assertThrows(IllegalArgumentException.class,()->new ImportedTestCaseSource("random",Set.of(RISCV_SUBSET.BASE),Set.of(),1,1,true,"full",2,RandomSource.Distributions.parse("2147483647",null,null),false));
  var t=new RISCVTestCase(new RISCVProgram(Map.of(),List.of()),new RISCVProgram(Map.of(),List.of()),1,0);
  assertThrows(IllegalArgumentException.class,()->t.setSetupEvidence(new SetupEvidence(63,false)));
 }
}
