package contractgen.riscv.isa.tests;

import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.math.BigInteger;
import static org.junit.jupiter.api.Assertions.*;

final class RISCVTestGeneratorDependencyTest {
    private static final Set<RISCV_OBSERVATION_TYPE> PREDICATES = EnumSet.of(
            RISCV_OBSERVATION_TYPE.RD_IS_ZERO, RISCV_OBSERVATION_TYPE.RS1_IS_ZERO,
            RISCV_OBSERVATION_TYPE.RS2_IS_ZERO, RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE);

    @Test void predicatesBelongToBaseAndRespectArchitecturalFields() {
        assertTrue(RISCV_OBSERVATION_TYPE.getBase().containsAll(PREDICATES));
        assertFalse(new RISCVObservation(RISCV_TYPE.SW, RISCV_OBSERVATION_TYPE.RD_IS_ZERO).isApplicable());
        assertFalse(new RISCVObservation(RISCV_TYPE.LUI, RISCV_OBSERVATION_TYPE.RS1_IS_ZERO).isApplicable());
        for (var type : List.of(RISCV_TYPE.SLLI, RISCV_TYPE.SRLI, RISCV_TYPE.SRAI, RISCV_TYPE.ADDI))
            assertFalse(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS2_IS_ZERO).isApplicable());
        assertFalse(new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE).isApplicable());
        assertTrue(new RISCVObservation(RISCV_TYPE.BEQ, RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE).isApplicable());
        for (var predicate : PREDICATES) {
            assertEquals("", predicate.generateObservation("1", false));
            assertThrows(UnsupportedOperationException.class, () -> predicate.generateObservation("1", true));
        }
    }

    @Test void generationTargetsEachPredicateWithoutTreatingShamtAsRs2() {
        Set<RISCV_OBSERVATION_TYPE> seen = EnumSet.noneOf(RISCV_OBSERVATION_TYPE.class);
        Set<RISCV_FORMAT> signedFormats = EnumSet.noneOf(RISCV_FORMAT.class);
        for (long seed : new long[]{11, 35, 81}) {
            var cases = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                    PREDICATES, seed, 1, false, 1, false, false, false, false).generate();
            for (var test : cases) {
                var atom = (RISCVObservation) test.getLikelyCTX().getDistinguishingObservations().iterator().next();
                assertTrue(atom.isApplicable());
                var left = ((RISCVProgram) test.getProgram1()).getProgram();
                var right = ((RISCVProgram) test.getProgram2()).getProgram();
                var a = left.get(left.size() - 6); // Target followed by five NOPs.
                var b = right.get(right.size() - 6);
                seen.add(atom.observation());
                switch (atom.observation()) {
                    case RD_IS_ZERO -> { assertEquals(0, a.rd()); assertNotEquals(0, b.rd()); }
                    case RS1_IS_ZERO, RS2_IS_ZERO -> {
                        boolean first = atom.observation() == RISCV_OBSERVATION_TYPE.RS1_IS_ZERO;
                        int register = first ? b.rs1() : b.rs2();
                        assertEquals(0, first ? a.rs1() : a.rs2());
                        assertNotEquals(0, register);
                        assertEquals(RISCVInstruction.ADDI(register, 0, 0), left.get(0));
                        assertEquals(left.get(0), right.get(0));
                        if (!first) assertTrue(a.hasArchitecturalRS2());
                    }
                    case IMM_IS_NEGATIVE -> {
                        signedFormats.add(a.type().getFormat());
                        assertEquals('0', a.toBinaryEncoding().charAt(0));
                        assertEquals('1', b.toBinaryEncoding().charAt(0));
                        long bits1 = Long.parseUnsignedLong(a.toBinaryEncoding(), 2);
                        long bits2 = Long.parseUnsignedLong(b.toBinaryEncoding(), 2);
                        assertEquals(0x80000000L, bits1 ^ bits2);
                    }
                    default -> fail("Unexpected target " + atom);
                }
            }
        }
        assertEquals(PREDICATES, seen);
        assertEquals(EnumSet.of(RISCV_FORMAT.ITYPE, RISCV_FORMAT.STYPE, RISCV_FORMAT.BTYPE,
                RISCV_FORMAT.JTYPE, RISCV_FORMAT.UTYPE), signedFormats);
    }


    private static final Set<RISCV_TYPE> PRODUCERS = EnumSet.of(RISCV_TYPE.ADD, RISCV_TYPE.ADDI, RISCV_TYPE.SUB, RISCV_TYPE.OR, RISCV_TYPE.ORI,
                RISCV_TYPE.AND, RISCV_TYPE.ANDI, RISCV_TYPE.XOR, RISCV_TYPE.XORI, RISCV_TYPE.SLT,
                RISCV_TYPE.SLTI, RISCV_TYPE.SLTU, RISCV_TYPE.SLTIU, RISCV_TYPE.SLL, RISCV_TYPE.SLLI,
                RISCV_TYPE.SRL, RISCV_TYPE.SRLI, RISCV_TYPE.SRA, RISCV_TYPE.SRAI, RISCV_TYPE.MUL,
                RISCV_TYPE.MULH, RISCV_TYPE.MULHSU, RISCV_TYPE.MULHU, RISCV_TYPE.DIV, RISCV_TYPE.DIVU,
                RISCV_TYPE.REM, RISCV_TYPE.REMU, RISCV_TYPE.LB, RISCV_TYPE.LBU,
                RISCV_TYPE.LH, RISCV_TYPE.LHU, RISCV_TYPE.LW);

    private static Pair<List<RISCVInstruction>, List<RISCVInstruction>> pair(
            RISCVTestGenerator generator, RISCV_OBSERVATION_TYPE observation, RISCVInstruction consumer) throws Exception {
        var method = RISCVTestGenerator.class.getDeclaredMethod("dependencyPair",
                RISCV_OBSERVATION_TYPE.class, RISCVInstruction.class);
        method.setAccessible(true);
        @SuppressWarnings("unchecked")
        var pair = (Pair<List<RISCVInstruction>, List<RISCVInstruction>>) method.invoke(generator, observation, consumer);
        return pair;
    }

    @Test
    void dependencyPairsUseSupportedProducersAndPreserveValues() throws Exception {
        for (boolean multiplyDivide : new boolean[]{false, true}) {
            var subsets = EnumSet.of(RISCV_SUBSET.BASE);
            if (multiplyDivide) subsets.add(RISCV_SUBSET.M);
            var generator = new RISCVTestGenerator(subsets, 55, 1, false, 1, false, false, false, false);
            Set<RISCV_TYPE> producers = EnumSet.noneOf(RISCV_TYPE.class);
            Set<Integer> operands = new HashSet<>();
            for (String operand : List.of("RS1", "RS2", "WAW")) {
                for (int distance = 1; distance <= 4; distance++) {
                    for (int sample = 0; sample < 32; sample++) {
                        var observation = RISCV_OBSERVATION_TYPE.valueOf(
                                (operand.equals("WAW") ? "WAW" : "RAW_" + operand) + "_" + distance);
                        var pair = pair(generator, observation, RISCVInstruction.ADD(20, 21, 22));
                        assertArrayEquals(beforeConsumer(pair.left()), beforeConsumer(pair.right()));
                        int producerIndex = pair.left().size() - 1 - distance;
                        var left = pair.left().get(producerIndex);
                        var right = pair.right().get(producerIndex);
                        assertEquals(operand.equals("WAW") ? 20 : operand.equals("RS1") ? 21 : 22, left.rd());
                        assertNotEquals(left.rd(), right.rd());
                        assertNotEquals(0, right.rd());
                        assertEquals(left.cloneAlteringRD(right.rd()), right);
                        producers.add(left.type());
                        int[] setup = execute(pair.left().subList(0, producerIndex));
                        operands.add(setup[left.rs1()]);
                        if (left.type() == RISCV_TYPE.SLLI || left.type() == RISCV_TYPE.SRLI || left.type() == RISCV_TYPE.SRAI) {
                            assertTrue(left.rs2() >= 0 && left.rs2() < 32);
                        } else if (left.rs2() != null) operands.add(setup[left.rs2()]);
                        else {
                            assertTrue(left.imm() >= -2048 && left.imm() <= 2047);
                            operands.add(left.imm().intValue());
                        }
                        for (int i = producerIndex + 1; i < pair.left().size() - 1; i++) {
                            assertEquals(RISCVInstruction.NOP(), pair.left().get(i));
                            assertEquals(RISCVInstruction.NOP(), pair.right().get(i));
                        }
                    }
                }
            }
            var expected = EnumSet.copyOf(PRODUCERS);
            if (!multiplyDivide) expected.removeIf(type -> type.getSubset() == RISCV_SUBSET.M);
            assertEquals(expected, producers);
            assertTrue(operands.size() > 20);
            assertTrue(operands.containsAll(List.of(0, 1, -1, Integer.MIN_VALUE, Integer.MAX_VALUE)));
        }
    }

    @Test
    void wawRejectsMissingZeroOrReadDestination() throws Exception {
        var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE), 55,
                1, false, 1, false, false, false, false);
        var waw = EnumSet.of(RISCV_OBSERVATION_TYPE.WAW_1, RISCV_OBSERVATION_TYPE.WAW_2,
                RISCV_OBSERVATION_TYPE.WAW_3, RISCV_OBSERVATION_TYPE.WAW_4);
        for (var observation : waw) {
            for (var instruction : List.of(RISCVInstruction.ADD(0, 21, 22),
                    RISCVInstruction.ADD(20, 20, 22), RISCVInstruction.ADD(20, 21, 20),
                    RISCVInstruction.SW(21, 22, 0))) {
                assertNull(pair(generator, observation, instruction));
            }
        }
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
    void targetingUsesOnlyEnabledInstructions() throws Exception {
        var types = RISCVTestGenerator.class.getDeclaredField("types");
        types.setAccessible(true);
        for (var producer : PRODUCERS) {
            for (boolean lui : new boolean[]{false, true}) {
                var enabled = EnumSet.of(RISCV_TYPE.ADDI, producer);
                if (RISCVInstruction.isLOAD(producer)) enabled.add(RISCV_TYPE.SW);
                if (lui) enabled.add(RISCV_TYPE.LUI);
                var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE), 55,
                        1, false, 1, false, false, false, false);
                types.set(generator, List.copyOf(enabled));
                Set<RISCV_TYPE> observed = EnumSet.noneOf(RISCV_TYPE.class);
                for (int sample = 0; sample < 64; sample++) {
                    var pair = pair(generator, RISCV_OBSERVATION_TYPE.WAW_1, RISCVInstruction.ADDI(20, 21, 0));
                    assertNotNull(pair);
                    observed.add(pair.left().get(pair.left().size() - 2).type());
                    for (var program : List.of(pair.left(), pair.right())) {
                        for (var instruction : program) assertTrue(enabled.contains(instruction.type()));
                    }
                    assertArrayEquals(beforeConsumer(pair.left()), beforeConsumer(pair.right()));
                }
                assertEquals(EnumSet.of(RISCV_TYPE.ADDI, producer), observed);
            }
        }
        for (var enabled : List.of(List.of(RISCV_TYPE.ADD), List.of(RISCV_TYPE.OR, RISCV_TYPE.LUI),
                List.of(RISCV_TYPE.LW, RISCV_TYPE.MUL))) {
            var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE), 55,
                    1, false, 1, false, false, false, false);
            types.set(generator, enabled);
            assertNull(pair(generator, RISCV_OBSERVATION_TYPE.WAW_1, RISCVInstruction.ADDI(20, 21, 0)));
        }
    }

    @Test
    void memoryAlignmentPreservesTheTargetedDistanceAndEqualValues() throws Exception {
        var generator = new RISCVTestGenerator(EnumSet.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M), 60,
                1, false, 1, false, false, false, false);
        for (int distance = 1; distance <= 4; distance++) {
            for (int i = 0; i < 64; i++) {
                var pair = pair(generator, RISCV_OBSERVATION_TYPE.valueOf("RAW_RS1_" + distance),
                        RISCVInstruction.LW(21, 20, 3));
                var consumer = pair.left().get(pair.left().size() - 1);
                int[] before = beforeConsumer(pair.left());
                assertArrayEquals(before, beforeConsumer(pair.right()));
                assertEquals(0, (before[consumer.rs1()] + consumer.imm().intValue()) & 3);
                int producerIndex = pair.left().size() - 1 - distance;
                assertEquals(20, pair.left().get(producerIndex).rd());
                for (int j = producerIndex + 1; j < pair.left().size() - 1; j++)
                    assertEquals(RISCVInstruction.NOP(), pair.left().get(j));
            }
        }
        assertNull(pair(generator, RISCV_OBSERVATION_TYPE.RAW_RS2_1, RISCVInstruction.SLLI(21, 22, 20)));
    }

    @Test
    void setupEncodesFullWidthValues() throws Exception {
        var set = RISCVTestGenerator.class.getDeclaredMethod("setRegister", List.class, int.class, int.class);
        set.setAccessible(true);
        for (int value : new int[]{0, -1, 2047, 2048, -2048, -2049, 4095, Integer.MIN_VALUE, Integer.MAX_VALUE}) {
            List<RISCVInstruction> program = new ArrayList<>();
            set.invoke(null, program, 5, value);
            assertEquals(value, execute(program)[5]);
        }
    }

    private static int[] beforeConsumer(List<RISCVInstruction> program) {
        return execute(program.subList(0, program.size() - 1));
    }

    private static int[] execute(List<RISCVInstruction> program) {
        int[] registers = new int[32];
        int memory = 0;
        for (var encoded : program) {
            var ins = RISCVInstruction.parseBinaryString(encoded.toBinaryEncoding());
            if (ins.type() == RISCV_TYPE.SW) {
                assertEquals(0, registers[ins.rs1()] + ins.imm().intValue());
                memory = registers[ins.rs2()];
                continue;
            }
            int a = ins.rs1() == null ? 0 : registers[ins.rs1()];
            int b = ins.type().getFormat() == RISCV_FORMAT.ITYPE
                    ? ins.imm().intValue() << 20 >> 20
                    : ins.rs2() == null ? 0 : registers[ins.rs2()];
            int value = switch (ins.type()) {
                case LUI -> ins.imm().intValue();
                case ADDI -> a + (ins.imm().intValue() << 20 >> 20);
                case ADD -> a + registers[ins.rs2()];
                case OR -> a | registers[ins.rs2()];
                case AND -> a & registers[ins.rs2()];
                case ORI -> a | (ins.imm().intValue() << 20 >> 20);
                case ANDI -> a & (ins.imm().intValue() << 20 >> 20);
                case SUB -> a - b;
                case XOR, XORI -> a ^ b;
                case SLT, SLTI -> a < b ? 1 : 0;
                case SLTU, SLTIU -> Integer.toUnsignedLong(a) < Integer.toUnsignedLong(b) ? 1 : 0;
                case SLL -> a << b;
                case SRL -> a >>> b;
                case SRA -> a >> b;
                case SLLI -> a << ins.rs2();
                case SRLI -> a >>> ins.rs2();
                case SRAI -> a >> ins.rs2();
                case MUL -> a * b;
                case MULH, MULHSU, MULHU -> {
                    var x = BigInteger.valueOf(ins.type() == RISCV_TYPE.MULHU ? Integer.toUnsignedLong(a) : a);
                    var y = BigInteger.valueOf(ins.type() == RISCV_TYPE.MULH ? b : Integer.toUnsignedLong(b));
                    yield x.multiply(y).shiftRight(32).intValue();
                }
                case DIV -> b == 0 ? -1 : a / b;
                case DIVU -> b == 0 ? -1 : Integer.divideUnsigned(a, b);
                case REM -> b == 0 ? a : a % b;
                case REMU -> b == 0 ? a : Integer.remainderUnsigned(a, b);
                case LB -> (byte) memory;
                case LBU -> memory & 255;
                case LH -> (short) memory;
                case LHU -> memory & 65535;
                case LW -> memory;
                default -> throw new AssertionError(ins);
            };
            if (ins.rd() != 0) registers[ins.rd()] = value;
        }
        return registers;
    }
}
