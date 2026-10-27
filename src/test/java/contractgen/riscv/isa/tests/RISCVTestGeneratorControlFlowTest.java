package contractgen.riscv.isa.tests;

import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.*;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

final class RISCVTestGeneratorControlFlowTest {
    private static final Set<RISCV_OBSERVATION_TYPE> ORDINARY = EnumSet.of(
            RISCV_OBSERVATION_TYPE.IMM, RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE,
            RISCV_OBSERVATION_TYPE.RD, RISCV_OBSERVATION_TYPE.RD_IS_ZERO,
            RISCV_OBSERVATION_TYPE.RS1, RISCV_OBSERVATION_TYPE.RS1_IS_ZERO,
            RISCV_OBSERVATION_TYPE.REG_RS1, RISCV_OBSERVATION_TYPE.REG_RS2,
            RISCV_OBSERVATION_TYPE.BRANCH_TAKEN);

    @Test void everyTransferIsFollowedOnlyByNopsAndAllDestinationsAvoidSetup() {
        var seen = EnumSet.noneOf(RISCV_TYPE.class);
        Set<Boolean> directions = new HashSet<>();
        for (int seed = 0; seed < 20; seed++) {
            for (var testcase : generator(ORDINARY, seed, false, 1).generate()) {
                var atom = (RISCVObservation) testcase.getLikelyCTX().getDistinguishingObservations().iterator().next();
                if (!RISCVInstruction.isCONTROL(atom.type())) continue;
                var a = (RISCVProgram) testcase.getProgram1();
                var b = (RISCVProgram) testcase.getProgram2();
                int index = a.getProgram().size() - RISCVTestGenerator.CONTROL_NOP_SLOTS - 1;
                assertEquals(a.getProgram().size(), b.getProgram().size());
                assertTrue(0x100 + a.getProgram().size() * 4 <= RISCVTestGenerator.CONTROL_CODE_END);
                for (var program : List.of(a, b)) {
                    assertLayout(program.getProgram(), index);
                    int[] registers = setup(program, index);
                    var transfer = program.getProgram().get(index);
                    int destination = destination(transfer, registers, 0x100 + index * 4);
                    assertTrue(RISCVTestGenerator.isControlLanding(destination), transfer + " -> " + destination);
                    if (transfer.type() != RISCV_TYPE.JALR) directions.add(destination < 0x100 + index * 4);
                    seen.add(transfer.type());
                }
                var left = a.getProgram().get(index);
                var right = b.getProgram().get(index);
                if (atom.observation() == RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE) {
                    assertEquals(0x80000000L, Long.parseUnsignedLong(left.toBinaryEncoding(), 2)
                            ^ Long.parseUnsignedLong(right.toBinaryEncoding(), 2));
                }
                if (atom.observation() == RISCV_OBSERVATION_TYPE.REG_RS1 && left.type() == RISCV_TYPE.JALR)
                    assertNotEquals(setup(a, index)[left.rs1()], setup(b, index)[right.rs1()]);
                if (atom.observation() == RISCV_OBSERVATION_TYPE.BRANCH_TAKEN) {
                    assertTrue(taken(left, setup(a, index)));
                    assertFalse(taken(right, setup(b, index)));
                }
            }
        }
        assertEquals(EnumSet.of(RISCV_TYPE.JAL, RISCV_TYPE.JALR, RISCV_TYPE.BEQ, RISCV_TYPE.BNE,
                RISCV_TYPE.BLT, RISCV_TYPE.BGE, RISCV_TYPE.BLTU, RISCV_TYPE.BGEU), seen);
        assertEquals(Set.of(true, false), directions);
    }

    @Test void randomPrefixesCannotEscapeAndRepetitionsAreSeparateCases() {
        var counts = new EnumMap<RISCV_TYPE, Integer>(RISCV_TYPE.class);
        for (var testcase : generator(EnumSet.of(RISCV_OBSERVATION_TYPE.IMM), 81, true, 3).generate()) {
            var atom = (RISCVObservation) testcase.getLikelyCTX().getDistinguishingObservations().iterator().next();
            if (!RISCVInstruction.isCONTROL(atom.type())) continue;
            counts.merge(atom.type(), 1, Integer::sum);
            for (var p : List.of(testcase.getProgram1(), testcase.getProgram2())) {
                var program = ((RISCVProgram) p).getProgram();
                assertLayout(program, program.size() - RISCVTestGenerator.CONTROL_NOP_SLOTS - 1);
            }
        }
        assertEquals(8, counts.size());
        counts.values().forEach(n -> assertEquals(3, n));
    }

    @Test void compactionKeepsControlTrialsIndependent() {
        var tests = generator(EnumSet.of(RISCV_OBSERVATION_TYPE.IMM), 81, false, 3).generate();
        long original = tests.stream().filter(tc -> ((RISCVProgram) tc.getProgram1()).getProgram()
                .stream().anyMatch(RISCVInstruction::isCONTROL)).count();
        var compacted = RISCVTestCaseIO.compact(tests, 8, true);
        long retained = compacted.stream().filter(tc -> ((RISCVProgram) tc.getProgram1()).getProgram()
                .stream().anyMatch(RISCVInstruction::isCONTROL)).count();
        assertEquals(24, original);
        assertEquals(original, retained);
        compacted.forEach(tc -> assertTrue(((RISCVProgram) tc.getProgram1()).getProgram().stream()
                .filter(RISCVInstruction::isCONTROL).count() <= 1));
    }

    @Test void randomPrefixesNeverBypassOrdinaryTargets() {
        for (var testcase : generator(EnumSet.of(RISCV_OBSERVATION_TYPE.RD), 55, true, 1).generate()) {
            var atom = (RISCVObservation) testcase.getLikelyCTX().getDistinguishingObservations().iterator().next();
            var program = ((RISCVProgram) testcase.getProgram1()).getProgram();
            assertEquals(RISCVInstruction.isCONTROL(atom.type()) ? 1 : 0,
                    program.stream().filter(RISCVInstruction::isCONTROL).count());
        }
    }

    @Test void dependencyConsumersKeepTheirProducerDistanceAndEqualInputValues() throws Exception {
        var observations = EnumSet.noneOf(RISCV_OBSERVATION_TYPE.class);
        for (var o : RISCV_OBSERVATION_TYPE.values()) if (o.isDependency()) observations.add(o);
        var before = RISCVTestGeneratorDependencyTest.class.getDeclaredMethod("beforeConsumer", List.class);
        before.setAccessible(true);
        var distances = new HashSet<Integer>();
        var consumers = EnumSet.noneOf(RISCV_TYPE.class);
        for (var testcase : generator(observations, 35, false, 1).generate()) {
            var a = ((RISCVProgram) testcase.getProgram1()).getProgram();
            int index = a.size() - RISCVTestGenerator.CONTROL_NOP_SLOTS - 1;
            if (index < 0 || !a.get(index).isCONTROL()) continue;
            var b = ((RISCVProgram) testcase.getProgram2()).getProgram();
            var atom = (RISCVObservation) testcase.getLikelyCTX().getDistinguishingObservations().iterator().next();
            int distance = Character.digit(atom.observation().name().charAt(atom.observation().name().length() - 1), 10);
            assertNotEquals(a.get(index - distance).rd(), b.get(index - distance).rd());
            for (int i = index - distance + 1; i < index; i++) assertEquals(RISCVInstruction.NOP(), a.get(i));
            int[] ra = (int[]) before.invoke(null, a.subList(0, index + 1));
            int[] rb = (int[]) before.invoke(null, b.subList(0, index + 1));
            assertArrayEquals(ra, rb);
            assertEquals(destination(a.get(index), ra, 0x100 + index * 4), destination(b.get(index), rb, 0x100 + index * 4));
            assertTrue(RISCVTestGenerator.isControlLanding(destination(a.get(index), ra, 0x100 + index * 4)));
            consumers.add(a.get(index).type()); distances.add(distance);
        }
        assertEquals(8, consumers.size());
        assertEquals(Set.of(1, 2, 3, 4), distances);
    }

    private static void assertLayout(List<RISCVInstruction> program, int target) {
        assertTrue(program.get(target).isCONTROL());
        assertEquals(1, program.stream().filter(RISCVInstruction::isCONTROL).count());
        program.subList(target + 1, program.size()).forEach(i -> assertEquals(RISCVInstruction.NOP(), i));
    }

    private static int[] setup(RISCVProgram program, int target) {
        int[] registers = new int[32];
        program.getRegisters().forEach((r, value) -> { if (value != null) registers[r] = value << 20 >> 20; });
        for (var i : program.getProgram().subList(0, target)) {
            int value = switch (i.type()) {
                case LUI -> i.imm().intValue();
                case ADDI -> registers[i.rs1()] + (i.imm().intValue() << 20 >> 20);
                default -> throw new AssertionError(i);
            };
            if (i.rd() != 0) registers[i.rd()] = value;
        }
        return registers;
    }

    private static int destination(RISCVInstruction i, int[] registers, int pc) {
        if (i.type() == RISCV_TYPE.JALR) return (registers[i.rs1()] + (i.imm().intValue() << 20 >> 20)) & ~1;
        int width = i.type() == RISCV_TYPE.JAL ? 21 : 13;
        return pc + (i.imm().intValue() << (32 - width) >> (32 - width));
    }

    private static boolean taken(RISCVInstruction i, int[] r) {
        int a = r[i.rs1()], b = r[i.rs2()];
        return switch (i.type()) {
            case BEQ -> a == b; case BNE -> a != b; case BLT -> a < b; case BGE -> a >= b;
            case BLTU -> Integer.compareUnsigned(a, b) < 0; case BGEU -> Integer.compareUnsigned(a, b) >= 0;
            default -> throw new AssertionError(i);
        };
    }

    private static RISCVTestGenerator generator(Set<RISCV_OBSERVATION_TYPE> observations, long seed, boolean prefix, int reps) {
        return new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M), observations,
                seed, 1, false, reps, false, prefix, false, false);
    }
}
