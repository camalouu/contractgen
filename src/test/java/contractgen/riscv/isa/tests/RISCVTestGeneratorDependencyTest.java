package contractgen.riscv.isa.tests;

import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

final class RISCVTestGeneratorDependencyTest {
    @Test
    void dependencyPairsPreserveValuesAndExerciseProducerKinds() throws Exception {
        for (boolean multiplyDivide : new boolean[]{false, true}) {
            var subsets = EnumSet.of(RISCV_SUBSET.BASE);
            if (multiplyDivide) subsets.add(RISCV_SUBSET.M);
            var generator = new RISCVTestGenerator(subsets, 55, 1, false, 1, false, false, false, false);
            var method = RISCVTestGenerator.class.getDeclaredMethod("dependencyPair",
                    RISCV_OBSERVATION_TYPE.class, RISCVInstruction.class);
            method.setAccessible(true);
            Set<RISCV_TYPE> producers = EnumSet.noneOf(RISCV_TYPE.class);
            for (String operand : List.of("RS1", "RS2", "WAW")) {
                for (int distance = 1; distance <= 4; distance++) {
                    for (int sample = 0; sample < 32; sample++) {
                        var observation = RISCV_OBSERVATION_TYPE.valueOf((operand.equals("WAW") ? "WAW" : "RAW_" + operand) + "_" + distance);
                        @SuppressWarnings("unchecked")
                        var pair = (Pair<List<RISCVInstruction>, List<RISCVInstruction>>) method.invoke(
                                generator, observation, RISCVInstruction.ADD(20, 21, 22));
                        assertArrayEquals(beforeConsumer(pair.left()), beforeConsumer(pair.right()));
                        int producerIndex = pair.left().size() - 1 - distance;
                        var left = pair.left().get(producerIndex);
                        var right = pair.right().get(producerIndex);
                        assertEquals(operand.equals("WAW") ? 20 : operand.equals("RS1") ? 21 : 22, left.rd());
                        assertNotEquals(left.rd(), right.rd());
                        assertNotEquals(0, right.rd());
                        assertEquals(left.type(), right.type());
                        producers.add(left.type());
                    }
                }
            }
            assertEquals(multiplyDivide ? EnumSet.of(RISCV_TYPE.ADD, RISCV_TYPE.LW, RISCV_TYPE.MUL, RISCV_TYPE.DIV)
                    : EnumSet.of(RISCV_TYPE.ADD, RISCV_TYPE.LW), producers);
        }
    }

    @Test
    void wawRejectsMissingZeroOrReadDestination() throws Exception {
        var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE), 55,
                1, false, 1, false, false, false, false);
        var method = RISCVTestGenerator.class.getDeclaredMethod("dependencyPair",
                RISCV_OBSERVATION_TYPE.class, RISCVInstruction.class);
        method.setAccessible(true);
        for (var observation : List.of(RISCV_OBSERVATION_TYPE.WAW_1, RISCV_OBSERVATION_TYPE.WAW_2,
                RISCV_OBSERVATION_TYPE.WAW_3, RISCV_OBSERVATION_TYPE.WAW_4)) {
            for (var instruction : List.of(RISCVInstruction.ADD(0, 21, 22),
                    RISCVInstruction.ADD(20, 20, 22), RISCVInstruction.ADD(20, 21, 20),
                    RISCVInstruction.SW(21, 22, 0))) {
                assertNull(method.invoke(generator, observation, instruction));
            }
        }
        // Verify the public generation path actually enables all four WAW arms.
        var waw = EnumSet.of(RISCV_OBSERVATION_TYPE.WAW_1, RISCV_OBSERVATION_TYPE.WAW_2,
                RISCV_OBSERVATION_TYPE.WAW_3, RISCV_OBSERVATION_TYPE.WAW_4);
        var observed = EnumSet.noneOf(RISCV_OBSERVATION_TYPE.class);
        for (var testcase : new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE), waw,
                55, 1, false, 1, false, false, false, false).generate()) {
            var atom = (contractgen.riscv.isa.contract.RISCVObservation) testcase.getLikelyCTX()
                    .getDistinguishingObservations().iterator().next();
            observed.add(atom.observation());
        }
        assertEquals(waw, observed);
    }

    @Test
    void producerSelectionUsesOnlyEnabledInstructions() throws Exception {
        var method = RISCVTestGenerator.class.getDeclaredMethod("dependencyPair",
                RISCV_OBSERVATION_TYPE.class, RISCVInstruction.class);
        method.setAccessible(true);
        var types = RISCVTestGenerator.class.getDeclaredField("types");
        types.setAccessible(true);
        for (var enabled : List.of(
                List.of(RISCV_TYPE.ADDI, RISCV_TYPE.ADD),
                List.of(RISCV_TYPE.ADDI, RISCV_TYPE.MUL),
                List.of(RISCV_TYPE.ADDI, RISCV_TYPE.DIV),
                List.of(RISCV_TYPE.ADDI, RISCV_TYPE.LW, RISCV_TYPE.SW),
                List.of(RISCV_TYPE.ADDI, RISCV_TYPE.LW),
                List.of(RISCV_TYPE.MUL))) {
            var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE), 55,
                    1, false, 1, false, false, false, false);
            types.set(generator, enabled);
            @SuppressWarnings("unchecked")
            var pair = (Pair<List<RISCVInstruction>, List<RISCVInstruction>>) method.invoke(generator,
                    RISCV_OBSERVATION_TYPE.WAW_1, RISCVInstruction.ADDI(20, 21, 0));
            if (!enabled.contains(RISCV_TYPE.ADDI)
                    || enabled.equals(List.of(RISCV_TYPE.ADDI, RISCV_TYPE.LW))) {
                assertNull(pair); // No supported producer/setup combination.
            } else {
                assertNotNull(pair);
                for (var program : List.of(pair.left(), pair.right())) {
                    for (var instruction : program) assertTrue(enabled.contains(instruction.type()));
                }
                assertArrayEquals(beforeConsumer(pair.left()), beforeConsumer(pair.right()));
            }
        }
    }

    private static int[] beforeConsumer(List<RISCVInstruction> program) {
        int[] registers = new int[32];
        int memory = 99;
        for (var ins : program.subList(0, program.size() - 1)) {
            if (ins.type() == RISCV_TYPE.SW) { memory = registers[ins.rs2()]; continue; }
            int value = switch (ins.type()) {
                case ADDI -> registers[ins.rs1()] + ins.imm().intValue();
                case ADD -> registers[ins.rs1()] + registers[ins.rs2()];
                case MUL -> registers[ins.rs1()] * registers[ins.rs2()];
                case DIV -> registers[ins.rs1()] / registers[ins.rs2()];
                case LW -> memory;
                default -> throw new AssertionError(ins);
            };
            if (ins.rd() != 0) registers[ins.rd()] = value;
        }
        return registers;
    }

    public static void main(String[] args) throws Exception {
        new RISCVTestGeneratorDependencyTest().dependencyPairsPreserveValuesAndExerciseProducerKinds();
        new RISCVTestGeneratorDependencyTest().wawRejectsMissingZeroOrReadDestination();
        new RISCVTestGeneratorDependencyTest().producerSelectionUsesOnlyEnabledInstructions();
        System.out.println("Dependency generator checks passed: 768 pairs, BASE and BASE,M, distances 1-4.");
    }
}
