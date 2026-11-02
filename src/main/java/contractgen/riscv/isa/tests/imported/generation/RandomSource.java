package contractgen.riscv.isa.tests.imported.generation;

import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.Program;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;
import contractgen.riscv.isa.tests.imported.isa.Subset;
import contractgen.riscv.isa.tests.imported.testcase.TestCase;

import java.util.*;

/**
 * Random test generation: the first program is random, and the second is a copy of it with some initial registers
 * changed and some instructions modified.
 * <p>
 * The first program gets random initial registers, as in the other sources, and a random number of random
 * instructions, each with a mnemonic drawn uniformly from the subsets and random operands. The second program gives a
 * random number of registers (distinct ones of x1..x31) a different value and modifies a random number of
 * instructions (at distinct positions). A modification changes one part of the instruction, chosen uniformly among its
 * mnemonic and its operand fields:
 * <ul>
 *     <li>a register field gets another register (never x0 for rd, as in the generated instructions);</li>
 *     <li>the immediate gets another random immediate that changes the encoding;</li>
 *     <li>the mnemonic becomes another one of the subsets; register fields both mnemonics have are kept, and so is the
 *     immediate if both have the same format (a jalr rounds it down to a multiple of 4).</li>
 * </ul>
 * The program length, the number of changed registers and the number of modified instructions each follow a
 * {@link DiscreteGaussian} ({@link Distributions}); the number of modified instructions is at most the length. If
 * both numbers are 0, both are drawn again, so that the two programs always differ.
 * <p>
 * Both programs are then aligned like those of the other sources: a jalr gets an andi before it that aligns its base
 * register, and on cores without misaligned memory accesses, andi/ori instructions align half- and word-sized
 * accesses. The test cases have no intent. Their register initializations differ, so characterization skips them by
 * default ({@code --skip-init}), as for same-programs test cases.
 */
public final class RandomSource implements TestCaseSource {

    /** Default distribution of the program length, in the text form of {@link DiscreteGaussian}. */
    public static final String DEFAULT_LENGTH = "mean=20,sd=8,min=1,max=50";
    /** Default distribution of the number of registers whose initial values differ. */
    public static final String DEFAULT_REGISTER_DIFFERENCES = "mean=1,sd=1,min=0,max=31";
    /** Default distribution of the number of modified instructions. */
    public static final String DEFAULT_INSTRUCTION_MODIFICATIONS = "mean=1,sd=1,min=0,max=50";

    /** Test cases per batch; the test cases do not depend on it. */
    private static final int BATCH = 256;
    /** Draws of the two numbers before giving up on making the programs differ. */
    private static final int ATTEMPTS = 1000;

    /**
     * The distributions of a random test case.
     *
     * @param length                   number of random instructions of the first program (alignment instructions
     *                                 are not counted)
     * @param registerDifferences      number of initial registers whose values differ between the programs (0..31)
     * @param instructionModifications number of instructions the second program modifies (at most the length)
     */
    public record Distributions(DiscreteGaussian length, DiscreteGaussian registerDifferences,
                                DiscreteGaussian instructionModifications) {

        public static final Distributions DEFAULT = new Distributions(DiscreteGaussian.parse(DEFAULT_LENGTH),
                DiscreteGaussian.parse(DEFAULT_REGISTER_DIFFERENCES), DiscreteGaussian.parse(DEFAULT_INSTRUCTION_MODIFICATIONS));

        public Distributions {
            if (length.min() < 1) throw new IllegalArgumentException("program length: min must be at least 1");
            if (registerDifferences.min() < 0 || registerDifferences.max() > RandomPrograms.REGISTERS - 1) {
                throw new IllegalArgumentException("register differences: min and max must be in 0..31");
            }
            if (instructionModifications.min() < 0) throw new IllegalArgumentException("instruction modifications: min must be at least 0");
            if (registerDifferences.max() == 0 && instructionModifications.max() == 0) {
                throw new IllegalArgumentException("the programs would always be the same: register differences and "
                        + "instruction modifications both have max 0");
            }
        }

        /**
         * Parses the text forms of {@link DiscreteGaussian#parse(String, DiscreteGaussian)}; null keeps a default, and
         * keys left out keep their default values.
         */
        public static Distributions parse(String length, String registerDifferences, String instructionModifications) {
            return new Distributions(parse("program length", length, DEFAULT.length),
                    parse("register differences", registerDifferences, DEFAULT.registerDifferences),
                    parse("instruction modifications", instructionModifications, DEFAULT.instructionModifications));
        }

        private static DiscreteGaussian parse(String what, String spec, DiscreteGaussian defaults) {
            if (spec == null) return defaults;
            try {
                return DiscreteGaussian.parse(spec, defaults);
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException(what + ": " + e.getMessage(), e);
            }
        }
    }

    /** The parts of an instruction a modification can change. */
    private enum Part {MNEMONIC, RD, RS1, RS2, IMM}

    /**
     * A test case before alignment.
     *
     * @param registerDifferences      the number of registers drawn to differ
     * @param instructionModifications the number of instructions drawn to be modified
     */
    record Draw(SortedMap<Integer, Long> firstRegisters, List<Instruction> first,
                SortedMap<Integer, Long> secondRegisters, List<Instruction> second,
                int registerDifferences, int instructionModifications) {
    }

    private int batchSize=BATCH;
    public RandomSource(Collection<Subset> subsets,long seed,long total,boolean alignMemory,RegisterValues values,Distributions distributions,int batchSize) {
        this(subsets,seed,total,alignMemory,values,distributions);
        if(batchSize<1) throw new IllegalArgumentException("Invalid batch size");
        this.batchSize=batchSize;
    }
    private final List<Mnemonic> mnemonics;
    private final boolean alignMemory;
    private final RegisterValues values;
    private final Distributions distributions;
    private final long total;
    private final Random random;
    private long produced;

    /**
     * @param subsets       the ISA subsets to draw instructions from
     * @param seed          random seed
     * @param total         number of test cases
     * @param alignMemory   whether to align all half- and word-sized memory accesses
     * @param values        the values of the initial registers
     * @param distributions the program length, register differences and instruction modifications
     */
    public RandomSource(Collection<Subset> subsets, long seed, long total, boolean alignMemory, RegisterValues values,
                        Distributions distributions) {
        this.mnemonics = Arrays.stream(Mnemonic.values()).filter(m -> subsets.contains(m.subset())).toList();
        // alignment adds up to two instructions before an access and one before a jalr
        int expansion = alignMemory ? 3 : 2;
        int capacity = Program.MEMORY_WORDS - Program.PROGRAM_START;
        if ((long)distributions.length().max() * expansion > capacity) {
            throw new IllegalArgumentException("program length: max must be at most " + capacity / expansion
                    + " on this core, so that the aligned programs fit into the instruction memory");
        }
        this.alignMemory = alignMemory;
        this.values = values;
        this.distributions = distributions;
        this.total = total;
        this.random = new Random(seed);
    }

    @Override
    public List<TestCase> nextBatch(GenerationContext context) {
        List<TestCase> batch = new ArrayList<>();
        for (; produced < total && batch.size() < batchSize; produced++) {
            Draw d = draw();
            batch.add(new TestCase(context.nextId(), new Program(d.firstRegisters(), align(d.first())),
                    new Program(d.secondRegisters(), align(d.second())), Optional.empty()));
        }
        return batch;
    }

    /** Draws the next test case. */
    Draw draw() {
        SortedMap<Integer, Long> firstRegisters = RandomPrograms.registers(random, values);
        int length = distributions.length().sample(random);
        List<Instruction> first = new ArrayList<>(length);
        for (int i = 0; i < length; i++) {
            first.add(RandomPrograms.instruction(random, mnemonics.get(random.nextInt(mnemonics.size()))));
        }

        int differences, modifications, attempts = 0;
        do {
            if (attempts++ == ATTEMPTS) {
                throw new IllegalStateException("register differences and instruction modifications are almost always 0");
            }
            differences = distributions.registerDifferences().sample(random);
            modifications = distributions.instructionModifications().sample(random, length);
        } while (differences == 0 && modifications == 0);

        SortedMap<Integer, Long> secondRegisters = new TreeMap<>(firstRegisters);
        for (int k : choose(RandomPrograms.REGISTERS - 1, differences)) {
            int register = k + 1;
            long old = firstRegisters.getOrDefault(register, 0L);
            long value;
            do {
                // distributed like the first program's registers, but different
                value = random.nextBoolean() ? RandomPrograms.value(random, values) : 0;
            } while (value == old);
            secondRegisters.put(register, value);
        }
        List<Instruction> second = new ArrayList<>(first);
        for (int position : choose(length, modifications)) second.set(position, modify(first.get(position)));
        return new Draw(firstRegisters, first, secondRegisters, second, differences, modifications);
    }

    /** @return {@code k} distinct numbers of {@code 0..n-1} (a partial Fisher-Yates shuffle) */
    private int[] choose(int n, int k) {
        int[] a = new int[n];
        for (int i = 0; i < n; i++) a[i] = i;
        for (int i = 0; i < k; i++) {
            int j = random.nextInt(i, n);
            int t = a[i];
            a[i] = a[j];
            a[j] = t;
        }
        return Arrays.copyOf(a, k);
    }

    /** The instruction with its mnemonic or one of its operand fields changed. */
    private Instruction modify(Instruction i) {
        List<Part> parts = new ArrayList<>();
        if (mnemonics.size() > 1) parts.add(Part.MNEMONIC);
        if (i.hasRD()) parts.add(Part.RD);
        if (i.hasRS1()) parts.add(Part.RS1);
        if (i.hasRS2()) parts.add(Part.RS2);
        if (i.hasIMM()) parts.add(Part.IMM);
        return switch (parts.get(random.nextInt(parts.size()))) {
            case MNEMONIC -> withOtherMnemonic(i);
            case RD -> i.withRD(otherRegister(i.rd(), 1));
            case RS1 -> i.withRS1(otherRegister(i.rs1(), 0));
            case RS2 -> i.withRS2(otherRegister(i.rs2(), 0));
            case IMM -> {
                Instruction modified;
                do {
                    modified = i.withIMM(RandomPrograms.immediate(random, i.mnemonic()));
                } while (modified.encode().equals(i.encode()));  // U-type immediates drop their low 12 bits
                yield modified;
            }
        };
    }

    /** @return a register of {@code lowest..31} other than {@code current} */
    private int otherRegister(int current, int lowest) {
        int r = random.nextInt(lowest, RandomPrograms.REGISTERS - 1);
        return r >= current ? r + 1 : r;
    }

    private Instruction withOtherMnemonic(Instruction i) {
        int k = random.nextInt(mnemonics.size() - 1);
        Mnemonic m = mnemonics.get(k >= mnemonics.indexOf(i.mnemonic()) ? k + 1 : k);
        Instruction fresh = RandomPrograms.instruction(random, m);
        Long imm = fresh.imm();
        if (fresh.hasIMM() && m.format() == i.mnemonic().format()) imm = m == Mnemonic.JALR ? i.imm() / 4 * 4 : i.imm();
        return new Instruction(m, fresh.hasRD() && i.hasRD() ? i.rd() : fresh.rd(),
                fresh.hasRS1() && i.hasRS1() ? i.rs1() : fresh.rs1(),
                fresh.hasRS2() && i.hasRS2() ? i.rs2() : fresh.rs2(), imm);
    }

    private List<Instruction> align(List<Instruction> program) {
        List<Instruction> aligned = RandomPrograms.alignJumps(program);
        return alignMemory ? RandomPrograms.alignMemoryAddresses(aligned) : aligned;
    }
}
