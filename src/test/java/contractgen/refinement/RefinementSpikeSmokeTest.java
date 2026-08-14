package contractgen.refinement;

import contractgen.TestCase;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.spike.SpikeAtomParallelRunner;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

class RefinementSpikeSmokeTest {
    @Test
    void visibleSetupAndRegisterMutationsKeepTheCompleteAtomSignature() {
        String configured = System.getProperty("contract.spike.lib", "riscv-isa-sim/build/libcontract_spike_atom.so");
        Path spikeLibrary = Path.of(configured).toAbsolutePath();
        assumeTrue(Files.isRegularFile(spikeLibrary), "adapted Spike library is not available");

        RefinementTestMutator.Seed seed = new RefinementTestMutator.Seed(
                List.of(RISCVInstruction.DIVU(3, 1, 2)), Map.of(1, 0, 2, 1),
                List.of(RISCVInstruction.DIVU(3, 1, 2)), Map.of(1, 0, 2, 2));
        List<RefinementTestMutator.Variant> variants = RefinementTestMutator.variants(seed, 6, 0);
        List<TestCase> tests = variants.stream().map(RefinementTestMutator.Variant::test)
                .map(test -> (TestCase) test).toList();

        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> results = new SpikeAtomParallelRunner(
                spikeLibrary,
                "RV32IM_Zicclsm",
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),
                1).run(tests);
        Set<RISCVObservation> expected = Set.of(
                new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.IMM),
                new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.REG_RD),
                new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.REG_RD_LOG2),
                new RISCVObservation(RISCV_TYPE.DIVU, RISCV_OBSERVATION_TYPE.REG_RS2),
                new RISCVObservation(RISCV_TYPE.DIVU, RISCV_OBSERVATION_TYPE.REG_RS2_LOG2));

        assertEquals(6, results.size());
        for (int ordinal = 0; ordinal < variants.size(); ordinal++) {
            assertNull(results.get(ordinal).error());
            assertEquals(expected, results.get(ordinal).atoms(), variants.get(ordinal).mutation());
        }
    }

    @Test
    void reportsZeroAndLog2ValueAtomsForVisibleSetupAndTargetInstruction() {
        String configured = System.getProperty("contract.spike.lib", "riscv-isa-sim/build/libcontract_spike_atom.so");
        Path spikeLibrary = Path.of(configured).toAbsolutePath();
        assumeTrue(Files.isRegularFile(spikeLibrary), "adapted Spike library is not available");

        RefinementTestMutator.Seed seed = new RefinementTestMutator.Seed(
                List.of(RISCVInstruction.DIVU(3, 1, 2)), Map.of(1, 1, 2, 0),
                List.of(RISCVInstruction.DIVU(3, 1, 2)), Map.of(1, 1, 2, 1));
        TestCase test = RefinementTestMutator.variants(seed, 1, 0).get(0).test();

        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> results = new SpikeAtomParallelRunner(
                spikeLibrary,
                "RV32IM_Zicclsm",
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),
                1).run(List.of(test));
        Set<RISCVObservation> expected = Set.of(
                new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.IMM),
                new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.REG_RD),
                new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.REG_RD_ZERO),
                new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.REG_RD_LOG2),
                new RISCVObservation(RISCV_TYPE.DIVU, RISCV_OBSERVATION_TYPE.REG_RS2),
                new RISCVObservation(RISCV_TYPE.DIVU, RISCV_OBSERVATION_TYPE.REG_RS2_ZERO),
                new RISCVObservation(RISCV_TYPE.DIVU, RISCV_OBSERVATION_TYPE.REG_RS2_LOG2),
                new RISCVObservation(RISCV_TYPE.DIVU, RISCV_OBSERVATION_TYPE.REG_RD),
                new RISCVObservation(RISCV_TYPE.DIVU, RISCV_OBSERVATION_TYPE.REG_RD_LOG2));

        assertEquals(1, results.size());
        assertNull(results.get(0).error());
        assertEquals(expected, results.get(0).atoms());
    }

    @Test
    void continuesComparingAlongEachPathAfterBranchDivergence() {
        String configured = System.getProperty("contract.spike.lib", "riscv-isa-sim/build/libcontract_spike_atom.so");
        Path spikeLibrary = Path.of(configured).toAbsolutePath();
        assumeTrue(Files.isRegularFile(spikeLibrary), "adapted Spike library is not available");

        List<RISCVInstruction> program = List.of(
                RISCVInstruction.BEQ(1, 0, 8),
                RISCVInstruction.ADDI(2, 0, 1),
                RISCVInstruction.SUB(3, 2, 1),
                RISCVInstruction.NOP());
        TestCase test = new contractgen.riscv.isa.RISCVTestCase(
                new contractgen.riscv.isa.RISCVProgram(Map.of(1, 0), program),
                new contractgen.riscv.isa.RISCVProgram(Map.of(1, 1), program),
                6,
                0);

        SpikeAtomClient.SpikeCaseAtoms result = new SpikeAtomParallelRunner(
                spikeLibrary,
                "RV32IM_Zicclsm",
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),
                1).run(List.of(test)).get(0);

        RISCVObservation followingAddi = new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.OPCODE);
        RISCVObservation followingSub = new RISCVObservation(RISCV_TYPE.SUB, RISCV_OBSERVATION_TYPE.OPCODE);
        assertNull(result.error());
        assertEquals(34, result.firstRetire(followingAddi).orElseThrow());
        assertEquals(34, result.firstRetire(followingSub).orElseThrow());
    }

    @Test
    void recordsTheFirstNativeRetirementWhenAnAtomRepeats() {
        String configured = System.getProperty("contract.spike.lib", "riscv-isa-sim/build/libcontract_spike_atom.so");
        Path spikeLibrary = Path.of(configured).toAbsolutePath();
        assumeTrue(Files.isRegularFile(spikeLibrary), "adapted Spike library is not available");

        TestCase test = new contractgen.riscv.isa.RISCVTestCase(
                new contractgen.riscv.isa.RISCVProgram(Map.of(), List.of(
                        RISCVInstruction.ADDI(1, 0, 1), RISCVInstruction.ADDI(1, 0, 2))),
                new contractgen.riscv.isa.RISCVProgram(Map.of(), List.of(
                        RISCVInstruction.ADDI(1, 0, 3), RISCVInstruction.ADDI(1, 0, 4))),
                3,
                0);

        SpikeAtomClient.SpikeCaseAtoms result = new SpikeAtomParallelRunner(
                spikeLibrary,
                "RV32IM_Zicclsm",
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),
                1).run(List.of(test)).get(0);

        RISCVObservation repeated = new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.IMM);
        assertNull(result.error());
        assertEquals(33, result.firstRetire(repeated).orElseThrow());
    }

    @Test
    void arbitraryLoadAddressUsesSparseMemoryAndExecutionContinues() {
        String configured = System.getProperty("contract.spike.lib", "riscv-isa-sim/build/libcontract_spike_atom.so");
        Path spikeLibrary = Path.of(configured).toAbsolutePath();
        assumeTrue(Files.isRegularFile(spikeLibrary), "adapted Spike library is not available");

        TestCase test = new contractgen.riscv.isa.RISCVTestCase(
                new contractgen.riscv.isa.RISCVProgram(Map.of(), List.of(
                        RISCVInstruction.ADD(15, 0, 0),
                        RISCVInstruction.LB(15, 13, 155),
                        RISCVInstruction.XORI(20, 7, 1))),
                new contractgen.riscv.isa.RISCVProgram(Map.of(), List.of(
                        RISCVInstruction.ADD(0, 0, 0),
                        RISCVInstruction.LB(15, 13, 155),
                        RISCVInstruction.XORI(20, 7, 2))),
                4,
                0);

        SpikeAtomClient.SpikeCaseAtoms result = new SpikeAtomParallelRunner(
                spikeLibrary,
                "RV32IM_Zicclsm",
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),
                1).run(List.of(test)).get(0);

        RISCVObservation followingInstruction = new RISCVObservation(RISCV_TYPE.XORI, RISCV_OBSERVATION_TYPE.IMM);
        assertNull(result.error());
        assertEquals(35, result.firstRetire(followingInstruction).orElseThrow());
        assertEquals(Set.of(), result.atoms().stream()
                .filter(atom -> atom.type() == RISCV_TYPE.ADDI)
                .filter(atom -> atom.observation().name().startsWith("RAW_") || atom.observation().name().startsWith("WAW_"))
                .collect(java.util.stream.Collectors.toSet()));
    }

    @Test
    void untouchedAddressesReturnTheSameZeroValue() {
        String configured = System.getProperty("contract.spike.lib", "riscv-isa-sim/build/libcontract_spike_atom.so");
        Path spikeLibrary = Path.of(configured).toAbsolutePath();
        assumeTrue(Files.isRegularFile(spikeLibrary), "adapted Spike library is not available");

        TestCase test = new contractgen.riscv.isa.RISCVTestCase(
                new contractgen.riscv.isa.RISCVProgram(Map.of(13, 100), List.of(RISCVInstruction.LW(15, 13, 0))),
                new contractgen.riscv.isa.RISCVProgram(Map.of(13, 200), List.of(RISCVInstruction.LW(15, 13, 0))),
                2,
                0);

        SpikeAtomClient.SpikeCaseAtoms result = new SpikeAtomParallelRunner(
                spikeLibrary,
                "RV32IM_Zicclsm",
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),
                1).run(List.of(test)).get(0);

        assertNull(result.error());
        assertTrue(result.atoms().contains(new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.MEM_ADDR)));
        assertFalse(result.atoms().contains(new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.MEM_R_DATA)));
        assertFalse(result.atoms().contains(new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.REG_RD)));
    }

    @Test
    void loadsObserveValuesWrittenToSparseMemory() {
        String configured = System.getProperty("contract.spike.lib", "riscv-isa-sim/build/libcontract_spike_atom.so");
        Path spikeLibrary = Path.of(configured).toAbsolutePath();
        assumeTrue(Files.isRegularFile(spikeLibrary), "adapted Spike library is not available");

        List<RISCVInstruction> program = List.of(
                RISCVInstruction.SW(1, 2, 0),
                RISCVInstruction.LW(3, 1, 0));
        TestCase test = new contractgen.riscv.isa.RISCVTestCase(
                new contractgen.riscv.isa.RISCVProgram(Map.of(1, 256, 2, 17), program),
                new contractgen.riscv.isa.RISCVProgram(Map.of(1, 256, 2, 34), program),
                3,
                0);

        SpikeAtomClient.SpikeCaseAtoms result = new SpikeAtomParallelRunner(
                spikeLibrary,
                "RV32IM_Zicclsm",
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class),
                1).run(List.of(test)).get(0);

        assertNull(result.error());
        assertTrue(result.atoms().contains(new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.MEM_R_DATA)),
                result.atoms().toString());
        assertTrue(result.atoms().contains(new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.REG_RD)),
                result.atoms().toString());
    }
}
