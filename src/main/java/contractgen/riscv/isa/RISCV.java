package contractgen.riscv.isa;

import contractgen.Contract;
import contractgen.ISA;
import contractgen.Observation;
import contractgen.TestCases;
import contractgen.Updater;
import contractgen.riscv.isa.contract.RISCVContract;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * The RISC-V instruction set architecture.
 */
public class RISCV extends ISA {

    /**
     * The contract object.
     */
    private RISCVContract contract;

    /**
     * @param updater   The updater to be used to compute the contract.
     * @param testCases The test cases to be used for generation or evaluation.
     */
    public RISCV(Set<RISCV_OBSERVATION_TYPE> observations, Set<RISCV_SUBSET> isa, Updater updater, TestCases testCases) {
        this(observations, isa, updater, testCases, false);
    }

    public RISCV(Set<RISCV_OBSERVATION_TYPE> observations, Set<RISCV_SUBSET> isa, Updater updater,
                 TestCases testCases, boolean producerDependencies) {
        super(testCases);
        Set<RISCV_TYPE> types = isa.stream().flatMap(subset -> Arrays.stream(RISCV_TYPE.values()).filter(type -> type.getSubset() == subset)).collect(Collectors.toSet());
        contract = new RISCVContract(atoms(types, observations, producerDependencies), updater,
                producerDependencies ? RISCVObservation.DEPENDENCY_SCHEMA : RISCVObservation.LEGACY_SCHEMA);
    }

    public static Set<Observation> atoms(Set<RISCV_TYPE> types, Set<RISCV_OBSERVATION_TYPE> observations,
                                         boolean producerDependencies) {
        Set<Observation> atoms = new java.util.HashSet<>();
        for (RISCV_TYPE type : types) for (RISCV_OBSERVATION_TYPE observation : observations) {
            if (producerDependencies && observation.isDependency()) {
                for (RISCV_TYPE producer : types) {
                    var atom = new RISCVObservation(type, observation, producer);
                    if (atom.isApplicable()) atoms.add(atom);
                }
            } else {
                var atom = new RISCVObservation(type, observation);
                if (atom.isApplicable()) atoms.add(atom);
            }
        }
        return atoms;
    }

    @Override
    public Contract getContract() {
        return contract;
    }

    @Override
    public void loadContract(Path path) throws IOException {
        this.contract = RISCVContract.fromJSON(Files.readString(path));
        this.contract.update(true);
    }
}
