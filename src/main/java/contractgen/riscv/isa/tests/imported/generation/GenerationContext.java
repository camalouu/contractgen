package contractgen.riscv.isa.tests.imported.generation;
public final class GenerationContext {
 private long nextId; private long batch;
 public long nextId(){return nextId++;}
 public long batch(){return batch;}
 public void startNextBatch(){batch++;}
}