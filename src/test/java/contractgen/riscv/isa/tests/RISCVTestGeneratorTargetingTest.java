package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.*;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import org.junit.jupiter.api.Test;

import java.nio.file.*;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

final class RISCVTestGeneratorTargetingTest {
    @Test void sourceIndexTargetsPreserveValuesAndHaveIdenticalPreparation() {
        for (int seed = 0; seed < 20; seed++) {
            for (var test : sourceTests(seed, EnumSet.of(RISCV_OBSERVATION_TYPE.RS1,
                    RISCV_OBSERVATION_TYPE.RS2))) {
                var atom = target(test);
                if (atom.observation() == RISCV_OBSERVATION_TYPE.RS2
                        && !RISCVInstruction.hasArchitecturalRS2(atom.type())) continue;
                var a = ((RISCVProgram) test.getProgram1()).getProgram();
                var b = ((RISCVProgram) test.getProgram2()).getProgram();
                int index = a.size() - (RISCVInstruction.isCONTROL(atom.type())
                        ? RISCVTestGenerator.CONTROL_NOP_SLOTS : 5) - 1;
                assertEquals(a.subList(0, index), b.subList(0, index), atom.toString());
                boolean first = atom.observation() == RISCV_OBSERVATION_TYPE.RS1;
                assertNotEquals(first ? a.get(index).rs1() : a.get(index).rs2(),
                        first ? b.get(index).rs1() : b.get(index).rs2());
                assertEquals(first ? a.get(index).cloneAlteringRS1(b.get(index).rs1())
                        : a.get(index).cloneAlteringRS2(b.get(index).rs2()), b.get(index));
                String value = first ? "REG_RS1" : "REG_RS2";
                assertEquals(targetValue(a, index, value), targetValue(b, index, value), atom.toString());
            }
        }
    }

    @Test void spikeSeparatesSourceIndicesFromSourceValues() {
        String library = System.getenv("CONTRACT_SPIKE_LIB");
        assumeTrue(library != null && Files.isRegularFile(Path.of(library)), "Set CONTRACT_SPIKE_LIB to run native targeting checks");
        var spike = new SpikeAtomClient(Path.of(library));
        int checked = 0;
        for (int seed : new int[]{1, 35, 81}) {
            var tests = sourceTests(seed, EnumSet.of(RISCV_OBSERVATION_TYPE.RS1,
                    RISCV_OBSERVATION_TYPE.RS2, RISCV_OBSERVATION_TYPE.REG_RS1,
                    RISCV_OBSERVATION_TYPE.REG_RS2));
            var evidence = spike.runAll(RISCVTestCaseIO.toJSON(tests), "rv32im",
                    EnumSet.allOf(RISCV_OBSERVATION_TYPE.class));
            for (int i = 0; i < tests.size(); i++) {
                var atom = target(tests.get(i));
                var actual = evidence.get(i);
                assertNull(actual.error(), atom.toString());
                assertTrue(actual.atoms().contains(atom), atom.toString());
                if (atom.observation() == RISCV_OBSERVATION_TYPE.RS2
                        && !RISCVInstruction.hasArchitecturalRS2(atom.type())) continue;
                if (atom.observation() == RISCV_OBSERVATION_TYPE.RS1
                        || atom.observation() == RISCV_OBSERVATION_TYPE.RS2) {
                    assertEquals(Set.of(atom), actual.atoms(), "Index targeting introduced other differences: " + atom);
                } else {
                    assertFalse(actual.atoms().contains(new RISCVObservation(atom.type(), RISCV_OBSERVATION_TYPE.RS1)));
                    assertFalse(actual.atoms().contains(new RISCVObservation(atom.type(), RISCV_OBSERVATION_TYPE.RS2)));
                }
                checked++;
            }
        }
        System.out.println("Spike verified index/value separation for " + checked + " generated pairs.");
    }

    private static List<TestCase> sourceTests(int seed, Set<RISCV_OBSERVATION_TYPE> observations) {
        return new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                observations, seed, 1, false, 1, false, false, false, false).generate();
    }

    @Test void allGeneratedTargetsAreApplicableAndPairsHaveMatchingShapes() {
        for (boolean misaligned : new boolean[]{false, true}) {
            for (int seed : new int[]{1, 35, 81}) {
                for (var test : generator(seed, misaligned, false, false, 1).generate()) {
                    var atom = target(test);
                    assertTrue(atom.isApplicable(), atom.toString());
                    var a = ((RISCVProgram) test.getProgram1()).getProgram();
                    var b = ((RISCVProgram) test.getProgram2()).getProgram();
                    assertEquals(a.stream().map(RISCVInstruction::type).toList(),
                            b.stream().map(RISCVInstruction::type).toList(), atom.toString());
                    assertNotEquals(a, b, atom.toString());
                }
            }
        }
    }

    @Test void addressTargetsUseSharedSetupAndWriteDataTargetsChangeTheActualStore() {
        var observations = EnumSet.of(RISCV_OBSERVATION_TYPE.MEM_ADDR,
                RISCV_OBSERVATION_TYPE.MEM_R_DATA, RISCV_OBSERVATION_TYPE.MEM_W_DATA,
                RISCV_OBSERVATION_TYPE.IS_ALIGNED, RISCV_OBSERVATION_TYPE.IS_HALF_ALIGNED);
        for (int seed = 0; seed < 20; seed++) {
            var tests = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE), observations,
                    seed, 1, true, 1, false, false, false, false).generate();
            for (var test : tests) {
                var atom = target(test);
                var a = ((RISCVProgram) test.getProgram1()).getProgram();
                var b = ((RISCVProgram) test.getProgram2()).getProgram();
                int index = a.size() - 6;
                if (atom.observation() == RISCV_OBSERVATION_TYPE.MEM_ADDR
                        || atom.observation() == RISCV_OBSERVATION_TYPE.IS_ALIGNED
                        || atom.observation() == RISCV_OBSERVATION_TYPE.IS_HALF_ALIGNED) {
                    assertEquals(a.subList(0, index), b.subList(0, index), atom.toString());
                    assertNotEquals(a.get(index).imm(), b.get(index).imm());
                    assertEquals(a.get(index).cloneAlteringIMM(b.get(index).imm()), b.get(index));
                } else {
                    assertEquals(a.get(index), b.get(index));
                    for (int i = 0; i < index; i++) {
                        if (RISCVInstruction.isSTORE(a.get(i).type())) assertEquals(a.get(i), b.get(i));
                    }
                    if (atom.observation() == RISCV_OBSERVATION_TYPE.MEM_W_DATA) {
                        assertTrue(a.subList(0, index).stream().noneMatch(i -> RISCVInstruction.isSTORE(i.type())));
                        assertNotEquals(0, a.get(index).rs2());
                    }
                }
            }
        }
    }

    @Test void valueTargetsStillDifferAtTheTargetWhenSetupUsesTheSameOpcode() {
        for (int seed = 0; seed < 20; seed++) {
            for (var test : generator(seed, false, false, false, 1).generate()) {
                var atom = target(test);
                String observation = atom.observation().name();
                if (!observation.startsWith("REG_RS") && !(observation.startsWith("REG_RD")
                        && Set.of(RISCV_TYPE.ADDI, RISCV_TYPE.LUI, RISCV_TYPE.AUIPC).contains(atom.type()))) continue;
                var a = ((RISCVProgram) test.getProgram1()).getProgram();
                var b = ((RISCVProgram) test.getProgram2()).getProgram();
                int index = a.size() - (RISCVInstruction.isCONTROL(atom.type())
                        ? RISCVTestGenerator.CONTROL_NOP_SLOTS : 5) - 1;
                int x = targetValue(a, index, observation), y = targetValue(b, index, observation);
                if (observation.endsWith("_ZERO")) assertNotEquals(x == 0, y == 0, atom.toString());
                else if (observation.endsWith("_LOG2"))
                    assertNotEquals(Integer.numberOfLeadingZeros(x), Integer.numberOfLeadingZeros(y), atom.toString());
                else if (observation.endsWith("_LOW5")) assertNotEquals(x & 31, y & 31, atom.toString());
                else assertNotEquals(x, y, atom.toString());
            }
        }
    }

    private static int targetValue(List<RISCVInstruction> program, int index, String observation) {
        int[] registers = new int[32];
        for (var instruction : program.subList(0, index)) {
            int value = switch (instruction.type()) {
                case LUI -> instruction.imm().intValue();
                case ADDI -> registers[instruction.rs1()] + (instruction.imm().intValue() << 20 >> 20);
                case ANDI -> registers[instruction.rs1()] & (instruction.imm().intValue() << 20 >> 20);
                default -> throw new AssertionError(instruction);
            };
            if (instruction.rd() != 0) registers[instruction.rd()] = value;
        }
        var target = program.get(index);
        if (observation.startsWith("REG_RS1")) return registers[target.rs1()];
        if (observation.startsWith("REG_RS2")) return registers[target.rs2()];
        return switch (target.type()) {
            case ADDI -> registers[target.rs1()] + (target.imm().intValue() << 20 >> 20);
            case LUI -> target.imm().intValue();
            case AUIPC -> 0x100 + index * 4 + target.imm().intValue();
            default -> throw new AssertionError(target);
        };
    }

    @Test void spikeConfirmsRequestedAtomsIncludingPrefixesSuffixesAndRepetitions() {
        String library = System.getenv("CONTRACT_SPIKE_LIB");
        assumeTrue(library != null && Files.isRegularFile(Path.of(library)), "Set CONTRACT_SPIKE_LIB to run native targeting checks");
        var spike = new SpikeAtomClient(Path.of(library));
        List<String> failures = new ArrayList<>();
        var seen = EnumSet.noneOf(RISCV_OBSERVATION_TYPE.class);
        int checked = 0;
        for (int seed : new int[]{1, 35, 81}) {
            for (boolean misaligned : new boolean[]{false, true}) {
                boolean prefix = seed == 35, suffix = seed == 81;
                var tests = generator(seed, misaligned, prefix, suffix, seed == 35 ? 2 : 1).generate();
                for (int start = 0; start < tests.size(); start += 128) {
                    var batch = tests.subList(start, Math.min(start + 128, tests.size()));
                    var evidence = spike.runAll(RISCVTestCaseIO.toJSON(batch), "rv32im",
                            EnumSet.allOf(RISCV_OBSERVATION_TYPE.class));
                    assertEquals(batch.size(), evidence.size());
                    for (int i = 0; i < batch.size(); i++) {
                        checked++;
                        var atom = target(batch.get(i));
                        var actual = evidence.get(i);
                        seen.add(atom.observation());
                        if (actual.error() != null || !actual.atoms().contains(atom)) {
                            failures.add("seed=" + seed + " misaligned=" + misaligned + " index="
                                    + batch.get(i).getIndex() + " target=" + atom + " error=" + actual.error()
                                    + " actual=" + actual.atoms());
                        }
                        if (!misaligned) assertFalse(actual.requiresMisalignedDataAccess(), atom.toString());
                        if (seed != 35 && (atom.observation().name().startsWith("MEM_")
                                || atom.observation() == RISCV_OBSERVATION_TYPE.IS_ALIGNED
                                || atom.observation() == RISCV_OBSERVATION_TYPE.IS_HALF_ALIGNED
                                || (atom.observation().name().startsWith("REG_RD")
                                && atom.type() != RISCV_TYPE.ADDI && atom.type() != RISCV_TYPE.LUI))) {
                            var program = ((RISCVProgram) batch.get(i).getProgram1()).getProgram();
                            int targetIndex = program.size() - 6; // Target followed by five NOPs or a shared suffix.
                            if (suffix) {
                                // Find the target after its four-NOP setup gap.
                                targetIndex = -1;
                                for (int j = 4; j < program.size(); j++) {
                                    if (program.get(j).type() == atom.type()
                                            && (program.subList(j - 4, j).stream().allMatch(ins -> ins.equals(RISCVInstruction.NOP()))
                                            || (j >= 5 && program.get(j - 1).type() == RISCV_TYPE.ANDI
                                            && program.subList(j - 5, j - 1).stream().allMatch(ins -> ins.equals(RISCVInstruction.NOP()))))) {
                                        targetIndex = j;
                                        break;
                                    }
                                }
                            }
                            assertTrue(targetIndex >= 0, atom.toString());
                            assertEquals(33 + targetIndex, actual.firstRetire(atom).orElseThrow(), atom.toString());
                        }
                    }
                }
            }
        }
        System.out.println("Spike verified " + checked + " generated pairs across " + seen.size() + " target observation kinds.");
        assertTrue(failures.isEmpty(), failures.size() + " missed targets: " + failures.stream().limit(20).toList());
        assertTrue(seen.containsAll(EnumSet.of(RISCV_OBSERVATION_TYPE.REG_RD_ZERO,
                RISCV_OBSERVATION_TYPE.REG_RD_LOG2, RISCV_OBSERVATION_TYPE.REG_RS1_ZERO,
                RISCV_OBSERVATION_TYPE.REG_RS2_ZERO, RISCV_OBSERVATION_TYPE.REG_RS1_LOG2,
                RISCV_OBSERVATION_TYPE.REG_RS2_LOG2, RISCV_OBSERVATION_TYPE.IS_ALIGNED,
                RISCV_OBSERVATION_TYPE.IS_HALF_ALIGNED, RISCV_OBSERVATION_TYPE.NEW_PC)));
    }

    private static RISCVObservation target(TestCase test) {
        return (RISCVObservation) test.getLikelyCTX().getDistinguishingObservations().iterator().next();
    }

    private static RISCVTestGenerator generator(int seed, boolean misaligned, boolean prefix, boolean suffix, int reps) {
        return new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                seed, 1, misaligned, reps, false, prefix, suffix, false);
    }
}
