package contractgen.riscv.isa.tests.imported.contract;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import java.util.Set;
public record MnemonicApplicability(Mnemonic mnemonic) {
 public static MnemonicApplicability of(Mnemonic m){return new MnemonicApplicability(m);}
 public Set<Mnemonic> candidates(){return Set.of(mnemonic);}
}