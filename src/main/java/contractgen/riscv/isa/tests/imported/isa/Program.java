package contractgen.riscv.isa.tests.imported.isa;
import java.util.*;
/** Generation-only architectural state; lowered into rv32-v1 before execution. */
public record Program(SortedMap<Integer,Long> registers, List<Instruction> instructions) {
 public static final int MEMORY_WORDS=2048, PROGRAM_START=32+63, INIT_INSTRUCTIONS=31;
 public List<String> programWords(){return instructions.stream().map(Instruction::encodeHex).toList();}
 public Program {
  registers=Collections.unmodifiableSortedMap(new TreeMap<>(registers)); instructions=List.copyOf(instructions);
  if(instructions.size()>MEMORY_WORDS-PROGRAM_START) throw new IllegalArgumentException("program too long: "+instructions.size());
  registers.forEach((r,v)->{if(r<1||r>31||v<0||v>0xffffffffL) throw new IllegalArgumentException("invalid architectural register value");});
 }
}