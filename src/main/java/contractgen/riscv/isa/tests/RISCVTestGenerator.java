package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.util.Pair;

import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * A generator for RISC-V test cases.
 */
public class RISCVTestGenerator implements RISCVTestGenearatorInterface {
    /**
     * The number of registers in the microarchitecture.
     */
    private static final int NUMBER_REGISTERS = 32;
    static final int CONTROL_NOP_SLOTS = 16;
    static final long CONTROL_CODE_END = 0x400;
    static final long CONTROL_LAST_LANDING = 0xffffff80L;
    /**
     * The maximum value of a register.
     */
    @SuppressWarnings("unused")
    private static final long MAX_REG = 4294967296L;
    /**
     * The maximum value of a I-type immediate.
     */
    private static final int MAX_IMM_I = 4096; // 2^12
    /**
     * The maximum value of a B-type immediate.
     */
    private static final long MAX_IMM_B = 8192; // 2^13
    /**
     * The maximum value of a U-type immediate.
     */
    private static final long MAX_IMM_U = 4294967296L; // 2^32
    /**
     * The maximum value of a J-type immediate.
     */
    private static final long MAX_IMM_J = 2097152; // 2^21

    /**
     * A pseudo-random number generator.
     */
    private final Random r;
    /**
     * The number of repetitions to be generated.
     */
    private final int repetitions;
    /**
     * The instruction types to be considered.
     */
    private final List<RISCV_TYPE> types;
    /**
     * The allowed observations.
     */
    private final List<RISCV_OBSERVATION_TYPE> allowed_observations;

    private final boolean allow_misaligned_memory;
    
    private final int reps;
    
    private final boolean bitDist;
    
    private final boolean randomPrefix;
    
    private final boolean randomSuffix;
    
    private final boolean resetSequence;
    

    /**
     * @param subsets     the allowed ISA subsets.
     * @param seed        the random seed.
     * @param repetitions the number of repetitions to be generated.
     */
    RISCVTestGenerator(Set<RISCV_SUBSET> subsets, long seed, int repetitions, boolean allow_misaligned_memory, int reps, boolean bitDist, boolean randomPrefix, boolean randomSuffix, boolean resetSequence) {
        r = new Random(seed);
        this.repetitions = repetitions;
        this.types = Arrays.stream(RISCV_TYPE.values()).filter(t -> subsets.contains(t.getSubset())).toList(); //.filter(t -> !t.equals(RISCV_TYPE.SB) && !t.equals(RISCV_TYPE.SH) && !t.equals(RISCV_TYPE.SW)).toList();
        this.allowed_observations = Arrays.stream(RISCV_OBSERVATION_TYPE.values()).toList();
        this.allow_misaligned_memory = allow_misaligned_memory;
        this.reps = reps;
        this.bitDist = bitDist;
        this.randomPrefix = randomPrefix;
        this.randomSuffix = randomSuffix;
        this.resetSequence = resetSequence;
    }

    /**
     * @param subsets              the allowed ISA subsets.
     * @param allowed_observations the allowed observations.
     * @param seed                 the random seed.
     * @param repetitions          the number of repetitions to be generated.
     */
    RISCVTestGenerator(Set<RISCV_SUBSET> subsets, Set<RISCV_OBSERVATION_TYPE> allowed_observations, long seed, int repetitions, boolean allow_misaligned_memory, int reps, boolean bitDist, boolean randomPrefix, boolean randomSuffix, boolean resetSequence) {
        r = new Random(seed);
        this.repetitions = repetitions;
        this.types = Arrays.stream(RISCV_TYPE.values()).filter(t -> subsets.contains(t.getSubset())).toList();
        this.allowed_observations = allowed_observations.stream().toList();
        this.allow_misaligned_memory = allow_misaligned_memory;
        this.reps = reps;
        this.bitDist = bitDist;
        this.randomPrefix = randomPrefix;
        this.randomSuffix = randomSuffix;
        this.resetSequence = resetSequence;
    }

    /**
     * Generates a list of test cases by generating a random initial valuation for each register,
     * a random instruction of a certain type and suffix to be appended to the program.
     *
     * @return The list of test cases.
     */
    public List<TestCase> generate() {
        List<TestCase> cases = new ArrayList<>();
        for (int i = 0; i < repetitions; i++) {
            cases.addAll(nextRepetition(cases.size()));
            //if (i % 3 == 0)
            //    cases.add(new RISCVTestCase(new RISCVProgram(randomRegisters(), randomSequence(r.nextInt(5, 50))), new RISCVProgram(randomRegisters(), randomSequence(r.nextInt(5, 50))), 50, index++));
        }
        return cases;

    }

    public static <T> List<T> insertAtSecondToLast(List<T> list, T element) {
        // Create a new modifiable list
        List<T> modifiableList = new ArrayList<>(list);

        // Insert the element at the second-to-last position
        modifiableList.add(modifiableList.size() - 1, element);

        // Return an immutable copy of the new list
        return Collections.unmodifiableList(modifiableList);
    }

    public static List<RISCVInstruction> alignMemoryAddresses(List<RISCVInstruction> instructions) {
        List<RISCVInstruction> aligned_instructions = new ArrayList<>();
        for (RISCVInstruction ins: instructions) {
            if (Set.of(RISCV_TYPE.SH, RISCV_TYPE.SW, RISCV_TYPE.LH, RISCV_TYPE.LHU, RISCV_TYPE.LW).contains(ins.type())) {
                // if the base register is zero, the we need to modify the immediate since the register is read only.
                if (ins.rs1() == 0) {
                    aligned_instructions.add(new RISCVInstruction(
                        ins.type(),
                        ins.rd(),
                        ins.rs1(),
                        ins.rs2(),
                        (ins.imm() != null) ? (ins.imm() / 4 * 4) : null
                    ));
                    continue;
                }
                
                switch ((int)(ins.imm() % 4)) {
                    // the immediate ends with xxx00, so the register should end in xxx00, thus AND with 0b...11111100
                    case 0 -> aligned_instructions.add(RISCVInstruction.ANDI(ins.rs1(), ins.rs1(), MAX_IMM_I - 4));
                    // the immediate ends with xxx01, so the register should end in xxx11, thus OR with 0b...00000011
                    case 1 -> aligned_instructions.add(RISCVInstruction.ORI(ins.rs1(), ins.rs1(), 3));
                    // the immediate ends with xxx10, so the register should end in xxx10, thus AND with 0b...11111110 and OR with 0b...00000010
                    case 2 -> {
                        aligned_instructions.add(RISCVInstruction.ANDI(ins.rs1(), ins.rs1(), MAX_IMM_I - 2));
                        aligned_instructions.add(RISCVInstruction.ORI(ins.rs1(), ins.rs1(), 2));
                    }
                    // the immediate ends with xxx11, so the register should end in xxx01, thus AND with 0b...11111100 and OR with 0b...00000001
                    case 3 -> {
                        aligned_instructions.add(RISCVInstruction.ANDI(ins.rs1(), ins.rs1(), MAX_IMM_I - 3));
                        aligned_instructions.add(RISCVInstruction.ORI(ins.rs1(), ins.rs1(), 1));
                    }
                }
                
            }
            aligned_instructions.add(ins);
        }
        return aligned_instructions;
    }

    /** Align a target pair without introducing different helper instructions on either side. */
    static Pair<List<RISCVInstruction>, List<RISCVInstruction>> alignTargetPair(
            Pair<List<RISCVInstruction>, List<RISCVInstruction>> pair, boolean alignMemory) {
        if (pair.left().size() != pair.right().size())
            throw new IllegalArgumentException("Target pairs must have matching instruction slots");
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        for (int i = 0; i < pair.left().size(); i++) {
            var a = pair.left().get(i);
            var b = pair.right().get(i);
            boolean alignA = needsAlignment(a, alignMemory);
            boolean alignB = needsAlignment(b, alignMemory);
            Set<Integer> bases = new LinkedHashSet<>();
            if (alignA && a.rs1() != 0) bases.add(a.rs1());
            if (alignB && b.rs1() != 0) bases.add(b.rs1());
            for (int register : bases) {
                var helper = RISCVInstruction.ANDI(register, register, MAX_IMM_I - 4);
                left.add(helper);
                right.add(helper);
            }
            // Clear immediate low bits as well, including when the base is x0.
            left.add(alignA ? a.cloneAlteringIMM(a.imm() & ~3L) : a);
            right.add(alignB ? b.cloneAlteringIMM(b.imm() & ~3L) : b);
        }
        return new Pair<>(left, right);
    }

    private static boolean needsAlignment(RISCVInstruction instruction, boolean alignMemory) {
        return instruction.type() == RISCV_TYPE.JALR || (alignMemory &&
                Set.of(RISCV_TYPE.SH, RISCV_TYPE.SW, RISCV_TYPE.LH, RISCV_TYPE.LHU, RISCV_TYPE.LW)
                        .contains(instruction.type()));
    }

    /**
     * @param index starting index
     * @return a list of test cases.
     */
    public List<TestCase> nextRepetition(int index) {
        List<TestCase> cases = new ArrayList<>();
        for (RISCV_TYPE type : types) {
            Map<Integer, Integer> registers = randomRegisters();
            RISCVInstruction instruction = randomInstructionFromType(type);

            List<RISCVInstruction> reset = new ArrayList<>();
            if (reps > 1) {
                for (int i = 1; i < NUMBER_REGISTERS; i++) {
                    if (registers.containsKey(i) && registers.get(i) != null) {
                        reset.add(RISCVInstruction.ADDI(i, 0, registers.get(i)));
                    } else {
                        reset.add(RISCVInstruction.ADDI(i, 0, 0));
                    }
                }
            }
            
            for (RISCV_OBSERVATION_TYPE observation : allowed_observations) {
                // A transfer ends its observation window; repetitions need separate fresh testcases.
                int separateCases = instruction.isCONTROL() ? reps : 1;
                for (int sample = 0; sample < separateCases; sample++) {
                    List<RISCVInstruction> p1 = new ArrayList<>();
                    List<RISCVInstruction> p2 = new ArrayList<>();
                    Set<RISCVObservation> targets = new HashSet<>();
                    boolean valid = true;
                
                    for (int i = 0; i < (instruction.isCONTROL() ? 1 : reps); i++) {
                        List<RISCVInstruction> rprefix = randomPrefix ? randomSequence(r.nextInt(5, 25)) : List.of();
                        if (!observation.isDependency()
                                && !new RISCVObservation(type, observation).isApplicable()) {
                            valid = false;
                            break;
                        }
                    
                        if (!allow_misaligned_memory) {
                            rprefix = alignMemoryAddresses(rprefix);
                        }
                    
                        Pair<List<RISCVInstruction>, List<RISCVInstruction>> targetInstruction = alterObservation(observation, instruction);
                        if (targetInstruction == null) {
                            valid = false;
                            break;
                        }
                        RISCV_TYPE producer = null;
                        if (observation.isDependency()) {
                            for (int j = 0; j < targetInstruction.left().size(); j++) {
                                if (!targetInstruction.left().get(j).equals(targetInstruction.right().get(j))) {
                                    producer = targetInstruction.left().get(j).type();
                                    break;
                                }
                            }
                        }
                        targets.add(new RISCVObservation(producer == null ? type : producer, observation, observation.isDependency()));
                    
                        // Dependency setup preserves distances; zeroSourcePair already aligns both zero bases.
                        if (instruction.isCONTROL()) {
                            targetInstruction = controlledTarget(targetInstruction, observation);
                            if (targetInstruction == null) { valid = false; break; }
                            if (0x100L + 4L * (rprefix.size() + targetInstruction.left().size() + CONTROL_NOP_SLOTS)
                                    > CONTROL_CODE_END) throw new IllegalStateException("Control setup overlaps NOP landing space");
                        } else if (!observation.isDependency() && observation != RISCV_OBSERVATION_TYPE.RS1_IS_ZERO
                                && observation != RISCV_OBSERVATION_TYPE.RS1
                                && observation != RISCV_OBSERVATION_TYPE.RS2
                                && !isMemoryTarget(observation)) {
                            targetInstruction = alignTargetPair(targetInstruction, !allow_misaligned_memory);
                        }

                        if (resetSequence && i > 0) {
                            p1.addAll(reset);
                            p2.addAll(reset);
                        }

                        p1.addAll(rprefix);
                        p1.addAll(targetInstruction.left());
                        p2.addAll(rprefix);
                        p2.addAll(targetInstruction.right());

                        List<RISCVInstruction> suffix = instruction.isCONTROL() ? nopSequence(CONTROL_NOP_SLOTS)
                                : randomSuffix ? safeRandomSequence(r.nextInt(5, 25), p1, p2) : nopSequence(5);
                        p1.addAll(suffix);
                        p2.addAll(suffix);
                    }
                
                    if (valid) {
                        cases.add(new RISCVTestCase(
                                new RISCVProgram(registers, p1),
                                new RISCVProgram(registers, p2),
                                Integer.max(p1.size(), p2.size()), new RISCVTestResult(targets, Set.of(), true, index), index++));
                    }
                }
            }
        }
        return cases;
    }


    /**
     * @return A random initialization for each register.
     */
    private Map<Integer, Integer> randomRegisters() {
        Map<Integer, Integer> result = new HashMap<>(NUMBER_REGISTERS - 1);
        for (int i = 1; i < NUMBER_REGISTERS; i++) {
            if (r.nextBoolean()) {
                result.put(i, (int) randomImmediate(MAX_IMM_I));
            } else {
                if (r.nextBoolean()) {
                    result.put(i, null);
                }
            }
        }
        return result;
    }

    /** Change the dependency while keeping architectural values equal between sides. */
    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> dependencyPair(
            RISCV_OBSERVATION_TYPE observation, RISCVInstruction consumer) {
        boolean waw = observation.name().startsWith("WAW_");
        if (observation.name().startsWith("RAW_RS2_") && !consumer.hasArchitecturalRS2()) return null;
        Integer dependent = waw ? consumer.rd()
                : observation.name().startsWith("RAW_RS1_") ? consumer.rs1() : consumer.rs2();
        if (dependent == null || dependent == 0) return null;
        Integer otherSource = observation.name().startsWith("RAW_RS1_")
                ? (consumer.hasArchitecturalRS2() ? consumer.rs2() : null) : consumer.rs1();
        if (!waw && (Objects.equals(dependent, consumer.rd()) || Objects.equals(dependent, otherSource))) return null;
        // A WAW test must not introduce RAW on the same register.
        if (waw && (Objects.equals(dependent, consumer.rs1())
                || (consumer.hasArchitecturalRS2() && Objects.equals(dependent, consumer.rs2())))) return null;

        if (!types.contains(RISCV_TYPE.ADDI)) return null;
        List<RISCV_TYPE> producers = Stream.of(RISCV_TYPE.ADD, RISCV_TYPE.ADDI, RISCV_TYPE.SUB, RISCV_TYPE.OR, RISCV_TYPE.ORI,
                RISCV_TYPE.AND, RISCV_TYPE.ANDI, RISCV_TYPE.XOR, RISCV_TYPE.XORI, RISCV_TYPE.SLT,
                RISCV_TYPE.SLTI, RISCV_TYPE.SLTU, RISCV_TYPE.SLTIU, RISCV_TYPE.SLL, RISCV_TYPE.SLLI,
                RISCV_TYPE.SRL, RISCV_TYPE.SRLI, RISCV_TYPE.SRA, RISCV_TYPE.SRAI, RISCV_TYPE.MUL,
                RISCV_TYPE.MULH, RISCV_TYPE.MULHSU, RISCV_TYPE.MULHU, RISCV_TYPE.DIV, RISCV_TYPE.DIVU,
                RISCV_TYPE.REM, RISCV_TYPE.REMU, RISCV_TYPE.LB, RISCV_TYPE.LBU, RISCV_TYPE.LH,
                RISCV_TYPE.LHU, RISCV_TYPE.LW)
                .filter(types::contains)
                .filter(t -> !RISCVInstruction.isLOAD(t) || types.contains(RISCV_TYPE.SW)).toList();
        RISCV_TYPE producer = producers.get(r.nextInt(producers.size()));
        boolean load = RISCVInstruction.isLOAD(producer);
        boolean immediate = !load && producer.getFormat() == RISCV_FORMAT.ITYPE;
        boolean shiftImmediate = producer == RISCV_TYPE.SLLI || producer == RISCV_TYPE.SRLI
                || producer == RISCV_TYPE.SRAI;

        List<Integer> unused = new ArrayList<>();
        for (int register = 1; unused.size() < 3; register++) {
            if (!Objects.equals(register, consumer.rs1()) && !Objects.equals(register, consumer.rs2())
                    && !Objects.equals(register, consumer.rd())) unused.add(register);
        }
        int independent = unused.get(0), source1 = unused.get(1), source2 = unused.get(2);
        int a = dependencyValue(), b = dependencyValue();
        if (immediate) b = b << 20 >> 20; // Signed 12-bit instruction immediate.
        if (shiftImmediate) b &= 31;
        // Without LUI, a left-shift result must also fit the ADDI-only prefill.
        if (!types.contains(RISCV_TYPE.LUI) && (producer == RISCV_TYPE.SLL || producer == RISCV_TYPE.SLLI)) b &= 3;
        int result = switch (producer) {
            case ADD, ADDI -> a + b;
            case SUB -> a - b;
            case OR, ORI -> a | b;
            case AND, ANDI -> a & b;
            case XOR, XORI -> a ^ b;
            case SLT, SLTI -> a < b ? 1 : 0;
            case SLTU, SLTIU -> Integer.compareUnsigned(a, b) < 0 ? 1 : 0;
            case SLL, SLLI -> a << (b & 31);
            case SRL, SRLI -> a >>> (b & 31);
            case SRA, SRAI -> a >> (b & 31);
            case MUL -> a * b;
            case MULH -> (int) (((long) a * b) >> 32);
            case MULHSU -> (int) (((long) a * Integer.toUnsignedLong(b)) >> 32);
            case MULHU -> (int) ((Integer.toUnsignedLong(a) * Integer.toUnsignedLong(b)) >>> 32);
            case DIV -> b == 0 ? -1 : a / b;
            case DIVU -> b == 0 ? -1 : Integer.divideUnsigned(a, b);
            case REM -> b == 0 ? a : a % b;
            case REMU -> b == 0 ? a : Integer.remainderUnsigned(a, b);
            case LB -> (byte) b;
            case LBU -> b & 255;
            case LH -> (short) b;
            case LHU -> b & 65535;
            case LW -> b;
            default -> throw new IllegalStateException("Unexpected producer: " + producer);
        };

        List<RISCVInstruction> setup = new ArrayList<>();
        setRegister(setup, source1, a);
        setRegister(setup, source2, b);
        setRegister(setup, dependent, result);
        setRegister(setup, independent, result);
        if (load) setup.add(RISCVInstruction.SW(0, source2, 0));
        // Align the consumer through setup/immediate changes, never by inserting
        // another writer between the producer and consumer.
        boolean align = (!allow_misaligned_memory && RISCVInstruction.isMEM(consumer.type()))
                || consumer.type() == RISCV_TYPE.JALR;
        if (consumer.type() == RISCV_TYPE.JALR) {
            int base = Objects.equals(consumer.rs1(), dependent) ? result : 0;
            if (!Objects.equals(consumer.rs1(), dependent) && consumer.rs1() != 0)
                setRegister(setup, consumer.rs1(), 0);
            consumer = consumer.cloneAlteringIMM(safeJalrImmediate(base));
        } else if (align) {
            long imm = consumer.imm();
            if (Objects.equals(consumer.rs1(), dependent)) {
                imm = (imm & ~3L) | (-result & 3);
            } else if (consumer.rs1() == 0) {
                imm &= ~3L;
            } else {
                setRegister(setup, consumer.rs1(), (int) (-imm & 3));
            }
            consumer = consumer.cloneAlteringIMM(imm);
        }
        setup.addAll(nopSequence(4));

        RISCVInstruction write = load
                ? new RISCVInstruction(producer, dependent, 0, null, 0L)
                : immediate
                ? RISCVInstruction.ITYPE(producer, dependent, source1, (long) b)
                : RISCVInstruction.RTYPE(producer, dependent, source1, shiftImmediate ? b : source2);
        int distance = Character.digit(observation.name().charAt(observation.name().length() - 1), 10);
        List<RISCVInstruction> left = new ArrayList<>(setup), right = new ArrayList<>(setup);
        left.add(write);
        right.add(write.cloneAlteringRD(independent));
        left.addAll(nopSequence(distance - 1));
        right.addAll(nopSequence(distance - 1));
        left.add(consumer);
        right.add(consumer);
        return new Pair<>(left, right);
    }

    /** Only the final transfer may diverge; every possible destination is NOP-only. */
    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> controlledTarget(
            Pair<List<RISCVInstruction>, List<RISCVInstruction>> pair, RISCV_OBSERVATION_TYPE observation) {
        var a = pair.left().get(pair.left().size() - 1);
        var b = pair.right().get(pair.right().size() - 1);
        if (a.type() == RISCV_TYPE.JALR) {
            if (observation.isDependency()) return pair; // Address fixed in dependencyPair, before its producer.
            return controlledJalr(a, b, pair, observation);
        }
        int signBit = a.type() == RISCV_TYPE.JAL ? 20 : 12;
        long magnitude = controlOffset(signBit);
        long immA = magnitude | (a.imm() & (1L << signBit));
        long immB = magnitude | (b.imm() & (1L << signBit));
        if ((observation == RISCV_OBSERVATION_TYPE.IMM || observation == RISCV_OBSERVATION_TYPE.NEW_PC)
                && !a.imm().equals(b.imm())) {
            do { immB = controlOffset(signBit) | (b.imm() & (1L << signBit)); } while (immB == immA);
        }
        var left = new ArrayList<>(pair.left());
        var right = new ArrayList<>(pair.right());
        left.set(left.size() - 1, a.cloneAlteringIMM(immA));
        right.set(right.size() - 1, b.cloneAlteringIMM(immB));
        return new Pair<>(left, right);
    }

    private long controlOffset(int signBit) {
        // Flipping the sign bit must also land behind all setup, never just a few bytes back.
        return signBit == 12 ? 4L * r.nextInt(512, 769) : 4L * r.nextInt(1024, 131073);
    }

    static boolean isControlLanding(int address) {
        long pc = Integer.toUnsignedLong(address);
        return (pc & 3) == 0 && pc >= CONTROL_CODE_END && pc <= CONTROL_LAST_LANDING;
    }

    private long safeJalrImmediate(int base) {
        int start = r.nextInt(1024);
        for (int i = 0; i < 1024; i++) {
            int encoded = (((start + i) & 1023) << 2) | (-base & 3);
            if (isControlLanding(base + (encoded << 20 >> 20))) return (long) encoded;
        }
        throw new IllegalStateException("No isolated JALR landing for base " + base);
    }

    private int controlBase(long immediate) {
        int base;
        do {
            base = types.contains(RISCV_TYPE.LUI) ? r.nextInt() & ~3 : -4 * r.nextInt(64, 513);
        } while (!isControlLanding(base + ((int) immediate << 20 >> 20)));
        return base;
    }

    private void loadControlRegister(List<RISCVInstruction> program, int register, int value) {
        if (register == 0) return;
        // Fixed instruction shape on both sides, even if only one value fits in ADDI.
        if (types.contains(RISCV_TYPE.LUI)) {
            int low = value << 20 >> 20;
            program.add(RISCVInstruction.LUI(register, Integer.toUnsignedLong(value - low)));
            program.add(RISCVInstruction.ADDI(register, register, low));
        } else program.add(RISCVInstruction.ADDI(register, 0, value));
    }

    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> controlledJalr(
            RISCVInstruction a, RISCVInstruction b, Pair<List<RISCVInstruction>, List<RISCVInstruction>> original,
            RISCV_OBSERVATION_TYPE observation) {
        if (!types.contains(RISCV_TYPE.ADDI)) return null;
        if (observation == RISCV_OBSERVATION_TYPE.REG_RS1 && a.rs1() == 0) return null;
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        long immA = a.imm() & ~3L, immB = b.imm() & ~3L;
        if (observation == RISCV_OBSERVATION_TYPE.RS1_IS_ZERO) {
            left.addAll(original.left().subList(0, original.left().size() - 1));
            right.addAll(original.right().subList(0, original.right().size() - 1));
            immA = immB = 4L * r.nextInt(256, 481);
        } else {
            boolean zeroBases = observation == RISCV_OBSERVATION_TYPE.RS1
                    || observation == RISCV_OBSERVATION_TYPE.IMM
                    || observation == RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE
                    || observation == RISCV_OBSERVATION_TYPE.NEW_PC || a.rs1() == 0;
            if (zeroBases) {
                long magnitude = 4L * r.nextInt(256, 481);
                immA = magnitude | (a.imm() & 2048);
                immB = magnitude | (b.imm() & 2048);
                if ((observation == RISCV_OBSERVATION_TYPE.IMM || observation == RISCV_OBSERVATION_TYPE.NEW_PC)
                && !a.imm().equals(b.imm())) {
                    do { immB = 4L * r.nextInt(256, 481) | (b.imm() & 2048); } while (immA == immB);
                }
                for (int register : new LinkedHashSet<>(List.of(a.rs1(), b.rs1()))) {
                    loadControlRegister(left, register, 0);
                    loadControlRegister(right, register, 0);
                }
            } else {
                int baseA = controlBase(immA), baseB = baseA;
                if (observation == RISCV_OBSERVATION_TYPE.REG_RS1_ZERO
                        || observation == RISCV_OBSERVATION_TYPE.REG_RS1_LOG2) {
                    immA = immB = 4L * r.nextInt(256, 481);
                    baseA = 0;
                    baseB = -2048;
                } else if (observation == RISCV_OBSERVATION_TYPE.REG_RS1) {
                    do { baseB = controlBase(immB); } while (baseB == baseA);
                }
                loadControlRegister(left, a.rs1(), baseA);
                loadControlRegister(right, b.rs1(), baseB);
            }
            left.addAll(nopSequence(4));
            right.addAll(nopSequence(4));
        }
        left.add(a.cloneAlteringIMM(immA));
        right.add(b.cloneAlteringIMM(immB));
        return new Pair<>(left, right);
    }

    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> branchOutcomePair(RISCVInstruction instruction) {
        if (!instruction.isBRANCH() || !types.contains(RISCV_TYPE.ADDI)) return null;
        int rs1 = r.nextInt(1, NUMBER_REGISTERS), rs2;
        do { rs2 = r.nextInt(1, NUMBER_REGISTERS); } while (rs2 == rs1);
        int pivot = types.contains(RISCV_TYPE.LUI) ? r.nextInt(1, 1000000) : 1;
        int taken, notTaken, other;
        switch (instruction.type()) {
            case BEQ -> { taken = pivot; notTaken = pivot ^ 1; other = pivot; }
            case BNE -> { taken = pivot ^ 1; notTaken = pivot; other = pivot; }
            case BLT, BLTU -> { taken = pivot - 1; notTaken = pivot + 1; other = pivot; }
            case BGE, BGEU -> { taken = pivot + 1; notTaken = pivot - 1; other = pivot; }
            default -> throw new IllegalStateException();
        }
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        loadControlRegister(left, rs1, taken);
        loadControlRegister(right, rs1, notTaken);
        loadControlRegister(left, rs2, other);
        loadControlRegister(right, rs2, other);
        left.addAll(nopSequence(4)); right.addAll(nopSequence(4));
        var branch = new RISCVInstruction(instruction.type(), null, rs1, rs2, instruction.imm());
        left.add(branch); right.add(branch);
        return new Pair<>(left, right);
    }

    private int dependencyValue() {
        // Without LUI, keep the entire setup representable with ADDI alone.
        if (!types.contains(RISCV_TYPE.LUI)) return r.nextInt(32);
        return switch (r.nextInt(8)) {
            case 0 -> 0;
            case 1 -> 1;
            case 2 -> -1;
            case 3 -> Integer.MIN_VALUE;
            case 4 -> Integer.MAX_VALUE;
            default -> r.nextInt();
        };
    }

    private static void setRegister(List<RISCVInstruction> program, int register, int value) {
        int low = value << 20 >> 20; // Signed 12-bit ADDI immediate.
        if (value == low) {
            program.add(RISCVInstruction.ADDI(register, 0, value));
        } else {
            program.add(RISCVInstruction.LUI(register, Integer.toUnsignedLong(value - low)));
            program.add(RISCVInstruction.ADDI(register, register, low));
        }
    }

    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> alterObservation(RISCV_OBSERVATION_TYPE type, RISCVInstruction instruction) {
        return switch (type) {
            case FORMAT, OPCODE, FUNCT7, FUNCT3 -> null; //new Pair<>(List.of(instruction), randomSequence(1));
            case RD_IS_ZERO -> {
                if (instruction.rd() == null) yield null;
                yield new Pair<>(List.of(instruction.cloneAlteringRD(0)),
                        List.of(instruction.cloneAlteringRD(r.nextInt(1, NUMBER_REGISTERS))));
            }
            case RS1_IS_ZERO, RS2_IS_ZERO -> zeroSourcePair(type, instruction);
            case IMM_IS_NEGATIVE -> {
                if (!RISCVInstruction.hasIMM(instruction.type())) yield null;
                int signBit = switch (instruction.type().getFormat()) {
                    case ITYPE, STYPE -> 11;
                    case BTYPE -> 12;
                    case JTYPE -> 20;
                    case UTYPE -> 31;
                    case RTYPE -> throw new IllegalStateException("R-type has no signed immediate");
                };
                long positive = instruction.imm() & ((1L << signBit) - 1);
                if (RISCVInstruction.isCONTROL(instruction.type())) positive &= ~3L;
                yield new Pair<>(List.of(instruction.cloneAlteringIMM(positive)),
                        List.of(instruction.cloneAlteringIMM(positive | (1L << signBit))));
            }
            case RD -> {
                if (instruction.rd() == null) yield null;
                RISCVInstruction ins1 = instruction.cloneAlteringRD(r.nextInt(1, NUMBER_REGISTERS));
                RISCVInstruction ins2 = instruction.cloneAlteringRD(differentRegister(ins1.rd(), false));
                yield new Pair<>(List.of(ins1), List.of(ins2));
            }
            case RS1, RS2 -> sourceIndexPair(type, instruction);
            case IMM -> {
                if (instruction.imm() == null) yield null;
                long imm_1 = targetImmediate(instruction), imm_2;
                do { imm_2 = targetImmediate(instruction); } while (imm_1 == imm_2);
                RISCVInstruction ins1 = instruction.cloneAlteringIMM(imm_1);
                RISCVInstruction ins2 = instruction.cloneAlteringIMM(imm_2);
                yield new Pair<>(List.of(ins1), List.of(ins2));
            }
            case REG_RS1, REG_RS2, REG_RS2_LOW5, REG_RS1_ZERO, REG_RS2_ZERO,
                    REG_RS1_LOG2, REG_RS2_LOG2 -> operandValuePair(type, instruction);
            case REG_RD, REG_RD_ZERO, REG_RD_LOG2 -> resultValuePair(type, instruction);
            case MEM_ADDR, MEM_R_DATA, MEM_W_DATA, IS_ALIGNED, IS_HALF_ALIGNED ->
                    memoryPair(type, instruction);
            case IS_BRANCH -> null;
            case BRANCH_TAKEN -> branchOutcomePair(instruction);
            case NEW_PC -> instruction.isBRANCH() ? branchOutcomePair(instruction)
                    : alterObservation(RISCV_OBSERVATION_TYPE.IMM, instruction);
            case RAW_RS1_1, RAW_RS1_2, RAW_RS1_3, RAW_RS1_4,
                    RAW_RS2_1, RAW_RS2_2, RAW_RS2_3, RAW_RS2_4 ->
                    dependencyPair(type, instruction);
            case WAW_1, WAW_2, WAW_3, WAW_4 -> dependencyPair(type, instruction);
        };
    }

    private int differentRegister(int original, boolean allowZero) {
        int register;
        do { register = r.nextInt(allowZero ? 0 : 1, NUMBER_REGISTERS); } while (register == original);
        return register;
    }

    private int scratchRegister(RISCVInstruction instruction, int... reserved) {
        for (int register = 1; register < NUMBER_REGISTERS; register++) {
            if (Objects.equals(register, instruction.rd()) || Objects.equals(register, instruction.rs1())
                    || Objects.equals(register, instruction.rs2())) continue;
            boolean used = false;
            for (int other : reserved) used |= register == other;
            if (!used) return register;
        }
        throw new IllegalStateException("No scratch register");
    }

    private long targetImmediate(RISCVInstruction instruction) {
        long immediate = randomImmediate(getBound(instruction));
        if (instruction.type().getFormat() == RISCV_FORMAT.UTYPE) immediate &= ~4095L;
        if (instruction.isCONTROL() || (!allow_misaligned_memory && instruction.isMEM())) immediate &= ~3L;
        return immediate;
    }

    /** Equal instruction shapes prevent value setup from introducing FORMAT differences. */
    private void setRegisterPair(List<RISCVInstruction> left, List<RISCVInstruction> right,
                                 int register, int a, int b) {
        if (register == 0) throw new IllegalArgumentException("Cannot prepare x0");
        if (types.contains(RISCV_TYPE.LUI)) {
            int lowA = a << 20 >> 20, lowB = b << 20 >> 20;
            left.add(RISCVInstruction.LUI(register, Integer.toUnsignedLong(a - lowA)));
            right.add(RISCVInstruction.LUI(register, Integer.toUnsignedLong(b - lowB)));
            left.add(RISCVInstruction.ADDI(register, register, lowA));
            right.add(RISCVInstruction.ADDI(register, register, lowB));
        } else {
            if (a != (a << 20 >> 20) || b != (b << 20 >> 20))
                throw new IllegalArgumentException("Value needs LUI");
            left.add(RISCVInstruction.ADDI(register, 0, a));
            right.add(RISCVInstruction.ADDI(register, 0, b));
        }
    }

    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> finishValuePair(
            List<RISCVInstruction> left, List<RISCVInstruction> right,
            RISCVInstruction a, RISCVInstruction b) {
        left.addAll(nopSequence(4)); right.addAll(nopSequence(4));
        left.add(a); right.add(b);
        return new Pair<>(left, right);
    }

    /** Change a source register number while preserving its value and the other operands. */
    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> sourceIndexPair(
            RISCV_OBSERVATION_TYPE observation, RISCVInstruction instruction) {
        boolean first = observation == RISCV_OBSERVATION_TYPE.RS1;
        if (first ? instruction.rs1() == null : instruction.rs2() == null) return null;
        if (!first && !instruction.hasArchitecturalRS2()) {
            // Structural RS2 also names the shift-immediate field; it is not a register read.
            int a = r.nextInt(NUMBER_REGISTERS), b = differentRegister(a, true);
            return new Pair<>(List.of(instruction.cloneAlteringRS2(a)),
                    List.of(instruction.cloneAlteringRS2(b)));
        }
        if (!types.contains(RISCV_TYPE.ADDI)) return null;
        List<Integer> candidates = new ArrayList<>();
        for (int register = 1; register < NUMBER_REGISTERS; register++) {
            if (!Objects.equals(register, instruction.rd()) && !Objects.equals(register, instruction.rs1())
                    && !Objects.equals(register, instruction.rs2())) candidates.add(register);
        }
        // Dedicated RS*_IS_ZERO templates cover x0 with equal zero-valued operands.
        int a = candidates.remove(r.nextInt(candidates.size()));
        int b = candidates.get(r.nextInt(candidates.size()));
        int value = dependencyValue();
        boolean align = instruction.isMEM() && !allow_misaligned_memory;
        if (align && first) value &= ~3;
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        setRegisterPair(left, right, a, value, value);
        setRegisterPair(left, right, b, value, value);
        if (align) {
            instruction = instruction.cloneAlteringIMM(instruction.imm() & ~3L);
            if (!first && instruction.rs1() != 0) {
                var helper = RISCVInstruction.ANDI(instruction.rs1(), instruction.rs1(), MAX_IMM_I - 4);
                left.add(helper); right.add(helper);
            }
        }
        return finishValuePair(left, right,
                first ? instruction.cloneAlteringRS1(a) : instruction.cloneAlteringRS2(a),
                first ? instruction.cloneAlteringRS1(b) : instruction.cloneAlteringRS2(b));
    }

    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> operandValuePair(
            RISCV_OBSERVATION_TYPE observation, RISCVInstruction instruction) {
        boolean first = observation.name().startsWith("REG_RS1");
        if (!types.contains(RISCV_TYPE.ADDI)
                || (first ? instruction.rs1() == null : !instruction.hasArchitecturalRS2())) return null;
        int register = scratchRegister(instruction);
        instruction = first ? instruction.cloneAlteringRS1(register) : instruction.cloneAlteringRS2(register);
        int a = dependencyValue(), b;
        if (observation.name().endsWith("_ZERO")) {
            a = 0;
            do { b = dependencyValue(); } while (b == 0);
        } else if (observation.name().endsWith("_LOG2")) {
            a = 1 << r.nextInt(types.contains(RISCV_TYPE.LUI) ? 31 : 5);
            do { b = dependencyValue(); } while (b == 0 || Integer.numberOfLeadingZeros(a) == Integer.numberOfLeadingZeros(b));
        } else if (observation == RISCV_OBSERVATION_TYPE.REG_RS2_LOW5) {
            b = a ^ (1 << r.nextInt(5));
        } else {
            do { b = dependencyValue(); } while (a == b);
        }
        if (first && !allow_misaligned_memory && instruction.isMEM()) {
            a &= ~3; b &= ~3;
            // Alignment must preserve the requested value/zero/log2 distinction.
            if (a == b || (observation == RISCV_OBSERVATION_TYPE.REG_RS1_LOG2
                    && Integer.numberOfLeadingZeros(a) == Integer.numberOfLeadingZeros(b))) { a = 0; b = 4; }
        }
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        setRegisterPair(left, right, register, a, b);
        return finishValuePair(left, right, instruction, instruction);
    }

    private static boolean isMemoryTarget(RISCV_OBSERVATION_TYPE observation) {
        return switch (observation) {
            case MEM_ADDR, MEM_R_DATA, MEM_W_DATA, IS_ALIGNED, IS_HALF_ALIGNED -> true;
            default -> false;
        };
    }

    /** Prepare the actual accessed location; all scratch registers exclude target operands. */
    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> memoryPair(
            RISCV_OBSERVATION_TYPE observation, RISCVInstruction instruction) {
        if (!instruction.isMEM() || !types.contains(RISCV_TYPE.ADDI)) return null;
        boolean load = RISCVInstruction.isLOAD(instruction.type());
        if ((observation == RISCV_OBSERVATION_TYPE.MEM_R_DATA && !load)
                || (observation == RISCV_OBSERVATION_TYPE.MEM_W_DATA && load)) return null;
        int width = switch (instruction.type()) {
            case LW, SW -> 4;
            case LH, LHU, SH -> 2;
            default -> 1;
        };
        boolean alignment = observation == RISCV_OBSERVATION_TYPE.IS_ALIGNED
                || observation == RISCV_OBSERVATION_TYPE.IS_HALF_ALIGNED;
        int offset = observation == RISCV_OBSERVATION_TYPE.IS_HALF_ALIGNED ? 3 : 2;
        if (alignment && !allow_misaligned_memory && offset % width != 0) return null;
        if (load && !types.contains(RISCV_TYPE.SW)) return null;
        int base = scratchRegister(instruction), data = scratchRegister(instruction, base);
        int address = 4 * r.nextInt(-256, 256);
        int targetOffset = alignment ? offset
                : observation == RISCV_OBSERVATION_TYPE.MEM_ADDR ? 4 : 0;
        int valueA = 0, valueB = 0;
        boolean result = observation == RISCV_OBSERVATION_TYPE.REG_RD
                || observation == RISCV_OBSERVATION_TYPE.REG_RD_ZERO
                || observation == RISCV_OBSERVATION_TYPE.REG_RD_LOG2;
        if (result) {
            do { valueB = dependencyValue(); } while ((valueB & (width == 1 ? 255 : width == 2 ? 65535 : -1)) == 0);
        } else if (observation == RISCV_OBSERVATION_TYPE.MEM_R_DATA
                || observation == RISCV_OBSERVATION_TYPE.MEM_W_DATA) {
            valueA = dependencyValue();
            do { valueB = dependencyValue(); } while ((valueA & (width == 1 ? 255 : width == 2 ? 65535 : -1))
                    == (valueB & (width == 1 ? 255 : width == 2 ? 65535 : -1)));
        }
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        setRegisterPair(left, right, base, address, address);
        setRegisterPair(left, right, data, valueA, valueB);
        if (load) {
            // Initialize through the same base and offset that the target load will use.
            if (alignment) {
                // Byte stores can initialize either alignment without requiring a misaligned SW.
                if (!types.contains(RISCV_TYPE.SB)) return null;
                for (int i = 0; i < width + targetOffset; i++) {
                    left.add(RISCVInstruction.SB(base, data, i));
                    right.add(RISCVInstruction.SB(base, data, i));
                }
            } else {
                left.add(RISCVInstruction.SW(base, data, 0));
                right.add(RISCVInstruction.SW(base, data, 0));
                if (targetOffset != 0) {
                    left.add(RISCVInstruction.SW(base, data, targetOffset));
                    right.add(RISCVInstruction.SW(base, data, targetOffset));
                }
            }
        }
        instruction = instruction.cloneAlteringRS1(base).cloneAlteringIMM(0L);
        if (!load) instruction = instruction.cloneAlteringRS2(data);
        return finishValuePair(left, right, instruction, instruction.cloneAlteringIMM((long) targetOffset));
    }

    /** Choose operands with a known zero/nonzero result, keeping the destination fixed. */
    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> resultValuePair(
            RISCV_OBSERVATION_TYPE observation, RISCVInstruction instruction) {
        if (instruction.rd() == null || !types.contains(RISCV_TYPE.ADDI) || instruction.isCONTROL()) return null;
        if (RISCVInstruction.isLOAD(instruction.type()))
            return memoryPair(observation, instruction);
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        if (instruction.type().getFormat() == RISCV_FORMAT.UTYPE) {
            if (instruction.type() == RISCV_TYPE.AUIPC && observation == RISCV_OBSERVATION_TYPE.REG_RD_ZERO) return null;
            long nonzero = types.contains(RISCV_TYPE.LUI) ? 0x80000000L : 4096L;
            return finishValuePair(left, right, instruction.cloneAlteringIMM(0L), instruction.cloneAlteringIMM(nonzero));
        }
        int source1 = scratchRegister(instruction), source2 = scratchRegister(instruction, source1);
        int a = 0, b = 1, other;
        do { other = dependencyValue(); } while (other == 0);
        switch (instruction.type()) {
            case AND, ANDI -> b = -1;
            case OR, ORI, XOR, XORI, ADD, ADDI, SUB -> b = 0;
            case SLL, SLLI, SRL, SRLI, SRA, SRAI -> b = 0;
            case SLT, SLTI, SLTU, SLTIU -> { a = 1; other = 0; }
            case MULH -> { b = Integer.MIN_VALUE; other = Integer.MIN_VALUE; }
            case MULHSU, MULHU -> { b = -1; other = -1; }
            case REM, REMU -> { b = 2; other = 1; }
            default -> { } // MUL and DIV use multiplication/division by one.
        }
        // High-half multiplication witnesses require full-width constants.
        if (!types.contains(RISCV_TYPE.LUI)
                && (instruction.type() == RISCV_TYPE.MULH || instruction.type() == RISCV_TYPE.MULHSU
                || instruction.type() == RISCV_TYPE.MULHU)) return null;
        setRegisterPair(left, right, source1, a, other);
        instruction = instruction.cloneAlteringRS1(source1);
        if (instruction.hasArchitecturalRS2()) {
            setRegisterPair(left, right, source2, b, b);
            instruction = instruction.cloneAlteringRS2(source2);
        } else if (instruction.rs2() != null) instruction = instruction.cloneAlteringRS2(b & 31);
        else instruction = instruction.cloneAlteringIMM((long) b);
        return finishValuePair(left, right, instruction, instruction);
    }

    /** Read x0 versus an ordinary register holding zero, with the same operand value. */
    private Pair<List<RISCVInstruction>, List<RISCVInstruction>> zeroSourcePair(
            RISCV_OBSERVATION_TYPE observation, RISCVInstruction instruction) {
        boolean rs1 = observation == RISCV_OBSERVATION_TYPE.RS1_IS_ZERO;
        if (rs1 ? instruction.rs1() == null : !instruction.hasArchitecturalRS2()) return null;
        if (!types.contains(RISCV_TYPE.ADDI)) return null;
        int register;
        do { register = r.nextInt(1, NUMBER_REGISTERS); }
        while (Objects.equals(register, instruction.rd()) || Objects.equals(register, instruction.rs1())
                || Objects.equals(register, instruction.rs2()));
        if (rs1 && (RISCVInstruction.isMEM(instruction.type()) || instruction.type() == RISCV_TYPE.JALR)) {
            instruction = instruction.cloneAlteringIMM(instruction.imm() & ~3L);
        }
        List<RISCVInstruction> left = new ArrayList<>(), right = new ArrayList<>();
        left.add(RISCVInstruction.ADDI(register, 0, 0));
        left.addAll(nopSequence(4)); // Keep setup outside the dependency observation window.
        right.addAll(left);
        left.add(rs1 ? instruction.cloneAlteringRS1(0) : instruction.cloneAlteringRS2(0));
        right.add(rs1 ? instruction.cloneAlteringRS1(register) : instruction.cloneAlteringRS2(register));
        return new Pair<>(left, right);
    }

    /**
     * @param instruction an instruction
     * @return the maximum immediate value.
     */
    private static long getBound(RISCVInstruction instruction) {
        return switch (instruction.type().getFormat()) {
            case RTYPE -> 0L;
            case ITYPE, STYPE -> MAX_IMM_I;
            case BTYPE -> MAX_IMM_B;
            case UTYPE -> MAX_IMM_U;
            case JTYPE -> MAX_IMM_J;
        };
    }

    /**
     * @param size The length of the sequence
     * @return A sequence of given length of random instructions.
     */
    private List<RISCVInstruction> randomSequence(int size) {
        // Prefixes must reach the target once, rather than escape or re-enter it.
        var candidates = types.stream().filter(type -> !RISCVInstruction.isCONTROL(type)).toList();
        if (candidates.isEmpty()) return nopSequence(size);
        List<RISCVInstruction> result = new ArrayList<>(size);
        for (int i = 0; i < size; i++)
            result.add(randomInstructionFromType(candidates.get(r.nextInt(candidates.size()))));
        return result;
    }

    /** Shared suffix: no earlier written registers, private memory, forward-only control flow. */
    List<RISCVInstruction> safeRandomSequence(
            int size, List<RISCVInstruction> history1, List<RISCVInstruction> history2) {
        // Divergent paths may enter a suffix at different PCs or skip its setup.
        if (size < 5 || history1.size() != history2.size()
                || Stream.concat(history1.stream(), history2.stream()).anyMatch(RISCVInstruction::isCONTROL)) {
            return nopSequence(size);
        }
        Set<Integer> written = Stream.concat(history1.stream(), history2.stream())
                .filter(RISCVInstruction::hasRD).map(RISCVInstruction::rd)
                .filter(Objects::nonNull).collect(Collectors.toSet());
        List<Integer> registers = Stream.iterate(1, register -> register + 1)
                .limit(NUMBER_REGISTERS - 1L).filter(register -> !written.contains(register))
                .collect(Collectors.toCollection(ArrayList::new));
        if (registers.isEmpty()) return nopSequence(size);

        List<RISCVInstruction> result = new ArrayList<>(size);
        Integer jumpBase = null, memoryBase = null;
        if (registers.size() >= 2 && types.containsAll(List.of(RISCV_TYPE.AUIPC, RISCV_TYPE.JALR))) {
            jumpBase = registers.remove(r.nextInt(registers.size()));
            result.add(RISCVInstruction.AUIPC(jumpBase, 0));
        }
        // x0-based stores cannot reach the scratch word at 0x10000000 with a 12-bit offset.
        // Any other earlier store may alias it, so omit memory operations in that case.
        boolean privateMemory = Stream.concat(history1.stream(), history2.stream())
                .filter(i -> RISCVInstruction.isSTORE(i.type())).allMatch(i -> i.rs1() == 0);
        if (privateMemory && registers.size() >= 2
                && types.containsAll(List.of(RISCV_TYPE.LUI, RISCV_TYPE.SW))) {
            memoryBase = registers.remove(r.nextInt(registers.size()));
            result.add(RISCVInstruction.LUI(memoryBase, 0x10000000L));
            result.add(RISCVInstruction.SW(memoryBase, 0, 0)); // Initialize before any suffix load.
        }
        final Integer memory = memoryBase, jump = jumpBase;
        List<RISCV_TYPE> candidates = types.stream()
                .filter(t -> !RISCVInstruction.isMEM(t) || memory != null)
                .filter(t -> t != RISCV_TYPE.JALR || jump != null).toList();
        if (candidates.isEmpty()) return nopSequence(size);
        while (result.size() < size - 1) {
            int position = result.size();
            RISCV_TYPE type = candidates.get(r.nextInt(candidates.size()));
            RISCVInstruction instruction = randomInstructionFromType(type);
            if (instruction.hasRD()) instruction = instruction.cloneAlteringRD(randomElement(registers));
            if (instruction.hasRS1()) instruction = instruction.cloneAlteringRS1(randomElement(registers));
            if (instruction.hasRS2()) instruction = instruction.cloneAlteringRS2(randomElement(registers));
            if (instruction.isMEM()) {
                int width = switch (type) {
                    case LW, SW -> 4;
                    case LH, LHU, SH -> 2;
                    default -> 1;
                };
                instruction = instruction.cloneAlteringRS1(memory)
                        .cloneAlteringIMM((long) (r.nextInt(4 / width) * width));
            } else if (instruction.isCONTROL()) {
                int target = r.nextInt(position + 1, size); // Never setup, target code, or a loop.
                instruction = instruction.cloneAlteringIMM(4L * (target - position));
                if (type == RISCV_TYPE.JALR) {
                    // AUIPC is the first suffix instruction; its value anchors all JALR targets.
                    instruction = instruction.cloneAlteringRS1(jump).cloneAlteringIMM(4L * target);
                }
            }
            result.add(instruction);
        }
        result.add(RISCVInstruction.NOP()); // Every forward path has an in-suffix landing slot.
        return result;
    }

    private int randomElement(List<Integer> values) {
        return values.get(r.nextInt(values.size()));
    }

    private static List<RISCVInstruction> nopSequence(int size) {
        return Stream.generate(RISCVInstruction::NOP).limit(size).toList();
    }

    /**
     * @param type the type of the desired instruction
     * @return a random instance of an instruction of the given type.
     */
    private RISCVInstruction randomInstructionFromType(RISCV_TYPE type) {
        return switch (type.getFormat()) {
            case RTYPE ->
                    RISCVInstruction.RTYPE(type, r.nextInt(1, NUMBER_REGISTERS), r.nextInt(NUMBER_REGISTERS), r.nextInt(NUMBER_REGISTERS));
            case ITYPE -> {
                if (type == RISCV_TYPE.JALR) {
                    yield RISCVInstruction.ITYPE(type, r.nextInt(1, NUMBER_REGISTERS), r.nextInt(NUMBER_REGISTERS), randomImmediate(MAX_IMM_I) / 4 * 4);
                }
                yield RISCVInstruction.ITYPE(type, r.nextInt(1, NUMBER_REGISTERS), r.nextInt(NUMBER_REGISTERS), randomImmediate(MAX_IMM_I));
            }
            case STYPE ->
                    RISCVInstruction.STYPE(type, r.nextInt(NUMBER_REGISTERS), r.nextInt(NUMBER_REGISTERS), randomImmediate(MAX_IMM_I));
            case BTYPE ->
                    RISCVInstruction.BTYPE(type, r.nextInt(NUMBER_REGISTERS), r.nextInt(NUMBER_REGISTERS), (randomImmediate(MAX_IMM_B) / 4 * 4));
            case UTYPE ->
                    RISCVInstruction.UTYPE(type, r.nextInt(1, NUMBER_REGISTERS), r.nextLong(MAX_IMM_I - 1, MAX_IMM_U));
            case JTYPE -> RISCVInstruction.JTYPE(type, r.nextInt(1, NUMBER_REGISTERS), (randomImmediate(MAX_IMM_J) / 4 * 4));
        };
    }
    
    private long randomImmediate(long bound) {
        if (!bitDist) {
            if (bound <= 0) return 0;
            return r.nextLong(bound);
        }
        if (bound <= 1) return 0;

        int maxBits = 64 - Long.numberOfLeadingZeros(bound - 1);
        int bits = r.nextInt(maxBits) + 1;

        long subBound = 1L << bits;

        if (subBound > bound || subBound < 0) {
            subBound = bound;
        }

        return r.nextLong(subBound);
    }
}
