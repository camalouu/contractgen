package contractgen.riscv.isa.tests.imported.contract;
import contractgen.riscv.isa.tests.imported.isa.Instruction;
public record ContractAtom(MnemonicApplicability applicability, LeakageFunction leakageFunction) {
 public boolean appliesTo(Instruction i){return applicability.candidates().contains(i.mnemonic())&&leakageFunction.isDefinedFor(i.mnemonic());}
}