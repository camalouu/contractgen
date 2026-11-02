package contractgen.riscv.isa.tests.imported.contract;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import java.util.*;
import contractgen.riscv.isa.tests.imported.isa.Instruction;
import java.util.function.Predicate;
/** Targeting recipes only. These objects never supply synthesis evidence. */
public record LeakageFunction(String id, Predicate<Mnemonic> defined, Modifier recipe) {
 public String toString(){return id;}
 public Optional<Modifier> modifier(){return Optional.ofNullable(recipe);}
 public boolean isDefinedFor(Mnemonic m){return defined.test(m);}
 public static List<LeakageFunction> recipes(){return List.of(
new LeakageFunction("RD", Mnemonic::hasRD, Modifiers.field(Instruction::rd, true, Instruction::withRD)),
new LeakageFunction("RS1", Mnemonic::hasRS1, Modifiers.field(Instruction::rs1, false, Instruction::withRS1)),
new LeakageFunction("RS2", Mnemonic::hasRS2, Modifiers.field(Instruction::rs2, false, Instruction::withRS2)),
new LeakageFunction("IMM", Mnemonic::hasIMM, Modifiers.immediate()),
new LeakageFunction("REG_RS1", Mnemonic::hasRS1, Modifiers.registerValue(Instruction::rs1)),
new LeakageFunction("REG_RS2", Mnemonic::hasRS2, Modifiers.registerValue(Instruction::rs2)),
new LeakageFunction("REG_RD", Mnemonic::hasRD, Modifiers.result()),
new LeakageFunction("MEM_ADDR", Mnemonic::isMemory, Modifiers.registerValue(Instruction::rs1)),
new LeakageFunction("MEM_R_DATA", Mnemonic::isLoad, Modifiers.memoryContent()),
new LeakageFunction("MEM_W_DATA", Mnemonic::isStore, Modifiers.registerValue(Instruction::rs2)),
new LeakageFunction("BRANCH_TAKEN", Mnemonic::isControl, Modifiers.branchOutcome()),
new LeakageFunction("IS_ALIGNED", Mnemonic::isMemory, Modifiers.alignment(false)),
new LeakageFunction("IS_HALF_ALIGNED", Mnemonic::isMemory, Modifiers.alignment(true)),
new LeakageFunction("NEW_PC", Mnemonic::isControl, Modifiers.newPC()),
new LeakageFunction("RAW_RS1_1", Mnemonic::hasRS1, Modifiers.dependency(Instruction::rs1, 1)),
new LeakageFunction("RAW_RS1_2", Mnemonic::hasRS1, Modifiers.dependency(Instruction::rs1, 2)),
new LeakageFunction("RAW_RS1_3", Mnemonic::hasRS1, Modifiers.dependency(Instruction::rs1, 3)),
new LeakageFunction("RAW_RS1_4", Mnemonic::hasRS1, Modifiers.dependency(Instruction::rs1, 4)),
new LeakageFunction("RAW_RS2_1", Mnemonic::hasRS2, Modifiers.dependency(Instruction::rs2, 1)),
new LeakageFunction("RAW_RS2_2", Mnemonic::hasRS2, Modifiers.dependency(Instruction::rs2, 2)),
new LeakageFunction("RAW_RS2_3", Mnemonic::hasRS2, Modifiers.dependency(Instruction::rs2, 3)),
new LeakageFunction("RAW_RS2_4", Mnemonic::hasRS2, Modifiers.dependency(Instruction::rs2, 4)),
new LeakageFunction("WAW_1", Mnemonic::hasRD, Modifiers.dependency(Instruction::rd, 1)),
new LeakageFunction("WAW_2", Mnemonic::hasRD, Modifiers.dependency(Instruction::rd, 2)),
new LeakageFunction("WAW_3", Mnemonic::hasRD, Modifiers.dependency(Instruction::rd, 3)),
new LeakageFunction("WAW_4", Mnemonic::hasRD, Modifiers.dependency(Instruction::rd, 4)),
new LeakageFunction("REG_RS1_ZERO", Mnemonic::hasRS1, Modifiers.zero(Instruction::rs1)),
new LeakageFunction("REG_RS2_ZERO", Mnemonic::hasRS2, Modifiers.zero(Instruction::rs2)),
new LeakageFunction("REG_RD_ZERO", Mnemonic::hasRD, Modifiers.zeroOperands()),
new LeakageFunction("REG_RS1_LOG2", Mnemonic::hasRS1, Modifiers.log2(Instruction::rs1)),
new LeakageFunction("REG_RS2_LOG2", Mnemonic::hasRS2, Modifiers.log2(Instruction::rs2)),
new LeakageFunction("REG_RD_LOG2", Mnemonic::hasRD, Modifiers.result()),
new LeakageFunction("PC", m -> true, Modifiers.programCounter()),
new LeakageFunction("MEM_R_ADDR", Mnemonic::isLoad, Modifiers.registerValue(Instruction::rs1)),
new LeakageFunction("MEM_W_ADDR", Mnemonic::isStore, Modifiers.registerValue(Instruction::rs1)));}
}