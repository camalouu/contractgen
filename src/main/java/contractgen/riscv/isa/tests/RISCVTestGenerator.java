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
                List<RISCVInstruction> p1 = new ArrayList<>();
                List<RISCVInstruction> p2 = new ArrayList<>();
                Set<RISCVObservation> targets = new HashSet<>();
                boolean valid = true;
                
                for (int i = 0; i < reps; i++) {
                    List<RISCVInstruction> rprefix = randomPrefix ? randomSequence(r.nextInt(5, 25)) : List.of();
                    
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
                    
                    if (!allow_misaligned_memory && !observation.isDependency()) {
                        targetInstruction = new Pair<List<RISCVInstruction>,List<RISCVInstruction>>(
                            alignMemoryAddresses(targetInstruction.left()),
                            alignMemoryAddresses(targetInstruction.right()));                
                    }

                    // ensure jalr are always aligned
                    if (type == RISCV_TYPE.JALR && !observation.isDependency()) {
                        targetInstruction = new Pair<List<RISCVInstruction>,List<RISCVInstruction>>(
                            insertAtSecondToLast(targetInstruction.left(), RISCVInstruction.ANDI(targetInstruction.left().get(targetInstruction.left().size() - 1).rs1(), targetInstruction.left().get(targetInstruction.left().size() - 1).rs1(), MAX_IMM_I - 4)), 
                            insertAtSecondToLast(targetInstruction.right(), RISCVInstruction.ANDI(targetInstruction.right().get(targetInstruction.right().size() - 1).rs1(), targetInstruction.right().get(targetInstruction.right().size() - 1).rs1(), MAX_IMM_I - 4)));
                    }

                    List<RISCVInstruction> suffix = randomSuffix
                            ? safeRandomSequence(r.nextInt(5, 25), targetInstruction.left(), targetInstruction.right())
                            : nopSequence(5);

                    if (resetSequence && i > 0) {
                        p1.addAll(reset);
                        p2.addAll(reset);
                    }
                    
                    p1.addAll(rprefix);
                    p1.addAll(targetInstruction.left());
                    p1.addAll(suffix);
                    
                    p2.addAll(rprefix);
                    p2.addAll(targetInstruction.right());
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
        if (align) {
            long imm = consumer.imm();
            if (Objects.equals(consumer.rs1(), dependent)) {
                imm = (imm & ~3L) | (-result & 3);
            } else if (consumer.rs1() == 0) {
                imm &= ~3L;
            } else {
                setRegister(setup, consumer.rs1(), (int) (-imm & 3));
            }
            consumer = new RISCVInstruction(consumer.type(), consumer.rd(), consumer.rs1(), consumer.rs2(), imm);
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
                RISCVInstruction ins2 = instruction.cloneAlteringRD(r.nextInt(1, NUMBER_REGISTERS));
                yield new Pair<>(List.of(ins1), List.of(ins2));
            }
            case RS1 -> {
                if (instruction.rs1() == null) yield null;
                RISCVInstruction ins1 = instruction.cloneAlteringRS1(r.nextInt(NUMBER_REGISTERS));
                RISCVInstruction ins2 = instruction.cloneAlteringRS1(r.nextInt(NUMBER_REGISTERS));
                yield new Pair<>(List.of(ins1), List.of(ins2));
            }
            case RS2 -> {
                if (instruction.rs2() == null) yield null;
                RISCVInstruction ins1 = instruction.cloneAlteringRS2(r.nextInt(NUMBER_REGISTERS));
                RISCVInstruction ins2 = instruction.cloneAlteringRS2(r.nextInt(NUMBER_REGISTERS));
                yield new Pair<>(List.of(ins1), List.of(ins2));
            }
            case IMM -> {
                if (instruction.imm() == null) yield null;
                long imm_1 = randomImmediate(getBound(instruction));
                long imm_2 = randomImmediate(getBound(instruction));
                if (instruction.type().getFormat() == RISCV_FORMAT.BTYPE || instruction.type() == RISCV_TYPE.JAL || instruction.type() == RISCV_TYPE.JALR) {
                    imm_1 = imm_1 / 4 * 4;
                    imm_2 = imm_2 / 4 * 4;
                }
                RISCVInstruction ins1 = instruction.cloneAlteringIMM(imm_1);
                RISCVInstruction ins2 = instruction.cloneAlteringIMM(imm_2);
                yield new Pair<>(List.of(ins1), List.of(ins2));
            }
            case REG_RS1 -> {
                if (instruction.rs1() == null) yield null;
                RISCVInstruction ins1 = RISCVInstruction.ADDI(instruction.rs1(), 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction ins2 = RISCVInstruction.ADDI(instruction.rs1(), 0, randomImmediate(MAX_IMM_I));
                yield new Pair<>(List.of(ins1, instruction), List.of(ins2, instruction));
            }
            case REG_RS2 -> {
                if (instruction.rs2() == null) yield null;
                RISCVInstruction ins1 = RISCVInstruction.ADDI(instruction.rs2(), 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction ins2 = RISCVInstruction.ADDI(instruction.rs2(), 0, randomImmediate(MAX_IMM_I));
                yield new Pair<>(List.of(ins1, instruction), List.of(ins2, instruction));
            }
            case REG_RS2_LOW5 -> {
                if (!instruction.hasArchitecturalRS2() || instruction.rs2() == 0) yield null;
                long value1 = randomImmediate(MAX_IMM_I);
                long value2 = value1 ^ 1L;
                RISCVInstruction ins1 = RISCVInstruction.ADDI(instruction.rs2(), 0, value1);
                RISCVInstruction ins2 = RISCVInstruction.ADDI(instruction.rs2(), 0, value2);
                yield new Pair<>(List.of(ins1, instruction), List.of(ins2, instruction));
            }
            case MEM_ADDR -> {
                if (instruction.rs1() == null) yield null;
                long address = randomImmediate(MAX_IMM_I);
                RISCVInstruction val1 = RISCVInstruction.ADDI(31, 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction val2 = RISCVInstruction.ADDI(30, 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction instr_addr = RISCVInstruction.ADDI(instruction.rs1(), 0, address);
                RISCVInstruction ins1 = RISCVInstruction.SW(instruction.rs1(), 31, 0);
                RISCVInstruction ins2 = RISCVInstruction.SW(instruction.rs1(), 30, 0);
                yield new Pair<>(List.of(val1, val2, instr_addr, ins1, instruction), List.of(val1, val2, instr_addr, ins2, instruction));
            }
            case MEM_W_DATA -> {
                if (instruction.rs2() == null) yield null;
                long address = randomImmediate(MAX_IMM_I);
                RISCVInstruction val1 = RISCVInstruction.ADDI(31, 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction val2 = RISCVInstruction.ADDI(30, 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction instr_addr = RISCVInstruction.ADDI(instruction.rs2(), 0, address);
                RISCVInstruction ins1 = RISCVInstruction.SW(instruction.rs2(), 31, 0);
                RISCVInstruction ins2 = RISCVInstruction.SW(instruction.rs2(), 30, 0);
                yield new Pair<>(List.of(val1, val2, instr_addr, ins1, instruction), List.of(val1, val2, instr_addr, ins2, instruction));
            }
            case REG_RD -> {
                if (instruction.rd() == null) yield null;
                RISCVInstruction ins1 = instruction.cloneAlteringRD(r.nextInt(NUMBER_REGISTERS));
                RISCVInstruction ins2 = instruction.cloneAlteringRD(r.nextInt(NUMBER_REGISTERS));
                yield new Pair<>(List.of(ins1), List.of(ins2));
            }
            case MEM_R_DATA -> {
                if (instruction.imm() == null || instruction.rs1() == null) yield null;
                long address = randomImmediate(MAX_IMM_I);
                RISCVInstruction val1 = RISCVInstruction.ADDI(31, 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction val2 = RISCVInstruction.ADDI(30, 0, randomImmediate(MAX_IMM_I));
                RISCVInstruction instr_addr_1 = RISCVInstruction.ADDI(instruction.rs1(), 0, address);
                RISCVInstruction ins1 = RISCVInstruction.SW(instruction.rs1(), 31, 0);
                RISCVInstruction ins2 = RISCVInstruction.SW(instruction.rs1(), 30, 0);
                RISCVInstruction instr_addr_2 = RISCVInstruction.ADDI(instruction.rs1(), instruction.rs1(), instruction.imm());
                yield new Pair<>(List.of(val1, val2, instr_addr_1, ins1, instr_addr_2, instruction), List.of(val1, val2, instr_addr_1, ins2, instr_addr_2, instruction));
            }
            case IS_BRANCH -> null;
            case BRANCH_TAKEN -> null;
            case IS_ALIGNED -> null;
            case IS_HALF_ALIGNED -> null;
            case NEW_PC -> null;
            case RAW_RS1_1, RAW_RS1_2, RAW_RS1_3, RAW_RS1_4,
                    RAW_RS2_1, RAW_RS2_2, RAW_RS2_3, RAW_RS2_4 ->
                    dependencyPair(type, instruction);
            case WAW_1, WAW_2, WAW_3, WAW_4 -> dependencyPair(type, instruction);
            case REG_RS1_ZERO, REG_RS1_LOG2, REG_RS2_ZERO, REG_RS2_LOG2, REG_RD_ZERO, REG_RD_LOG2 -> null;
        };
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
        List<RISCVInstruction> result = new ArrayList<>(size);
        for (int i = 0; i < size; i++) {
            RISCV_TYPE type = types.get(r.nextInt(types.size() - 1));
            RISCVInstruction instruction = randomInstructionFromType(type);
            // ensure jalr are always aligned
            if (type == RISCV_TYPE.JALR) {
                result.add(RISCVInstruction.ANDI(instruction.rs1(), instruction.rs1(), MAX_IMM_I - 4));
                i++;
            }
            result.add(instruction);
        }
        return result;
    }

    /**
     * Generates a shared suffix that cannot introduce memory accesses or change
     * control flow. The suffix only uses non-zero registers that neither target
     * sequence writes, so a value difference created by the target is not
     * consumed or overwritten by the suffix. This also prevents dependency
     * observations at the target/suffix boundary from matching a target
     * destination register on only one side.
     *
     * <p>If the target itself contains a control-flow instruction, subsequent
     * dynamic instructions are not guaranteed to stay synchronized. In that
     * case the safest suffix is NOP-only.</p>
     */
    List<RISCVInstruction> safeRandomSequence(
            int size,
            List<RISCVInstruction> target1,
            List<RISCVInstruction> target2
    ) {
        if (Stream.concat(target1.stream(), target2.stream()).anyMatch(RISCVInstruction::isCONTROL)) {
            return nopSequence(size);
        }

        Set<Integer> writtenByTarget = Stream.concat(target1.stream(), target2.stream())
                .filter(RISCVInstruction::hasRD)
                .map(RISCVInstruction::rd)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        List<Integer> safeRegisters = Stream.iterate(1, register -> register + 1)
                .limit(NUMBER_REGISTERS - 1L)
                .filter(register -> !writtenByTarget.contains(register))
                .toList();
        List<RISCV_TYPE> safeTypes = types.stream()
                .filter(candidate -> !RISCVInstruction.isMEM(candidate))
                .filter(candidate -> !RISCVInstruction.isCONTROL(candidate))
                .toList();

        if (safeRegisters.isEmpty() || safeTypes.isEmpty()) {
            return nopSequence(size);
        }

        List<RISCVInstruction> result = new ArrayList<>(size);
        for (int i = 0; i < size; i++) {
            RISCV_TYPE type = safeTypes.get(r.nextInt(safeTypes.size()));
            RISCVInstruction instruction = randomInstructionFromType(type);
            if (instruction.hasRD()) {
                instruction = instruction.cloneAlteringRD(randomElement(safeRegisters));
            }
            if (instruction.hasRS1()) {
                instruction = instruction.cloneAlteringRS1(randomElement(safeRegisters));
            }
            if (instruction.hasRS2()) {
                instruction = instruction.cloneAlteringRS2(randomElement(safeRegisters));
            }
            result.add(instruction);
        }
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
