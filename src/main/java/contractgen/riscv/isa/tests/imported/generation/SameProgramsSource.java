package contractgen.riscv.isa.tests.imported.generation;

import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.Program;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;
import contractgen.riscv.isa.tests.imported.isa.Subset;
import contractgen.riscv.isa.tests.imported.testcase.TestCase;

import java.util.*;

/**
 * Same-programs test generation (CCS 2025, for validation sets; was {@code RISCVTestGeneratorSP}, CLI {@code --sp}):
 * both runs execute the same program from different random initial registers. Each batch has one test case per
 * mnemonic, whose program starts with an instruction of that mnemonic; if the last batch has to be truncated, a
 * random selection of its test cases is kept.
 * <p>
 * As in the other sources, a jalr gets an andi before it that aligns its base register, and on cores without
 * misaligned memory accesses, andi/ori instructions align half- and word-sized accesses; the program then starts
 * with these instructions.
 */
public final class SameProgramsSource implements TestCaseSource {

    private final List<Mnemonic> mnemonics;
    private final boolean alignMemory;
    private final RegisterValues values;
    private final long total;
    private final Random random;
    private long produced;

    /**
     * @param alignMemory whether to align all half- and word-sized memory accesses
     * @param values      the values of the initial registers
     */
    public SameProgramsSource(Collection<Subset> subsets, long seed, long total, boolean alignMemory, RegisterValues values) {
        this.mnemonics = Arrays.stream(Mnemonic.values()).filter(m -> subsets.contains(m.subset())).toList();
        this.alignMemory = alignMemory;
        this.values = values;
        this.total = total;
        this.random = new Random(new Random(seed).nextLong());
    }

    @Override
    public List<TestCase> nextBatch(GenerationContext context) {
        if (produced >= total) return List.of();
        List<Program[]> batch = new ArrayList<>();
        for (Mnemonic m : mnemonics) {
            SortedMap<Integer, Long> registers1 = RandomPrograms.registers(random, values);
            SortedMap<Integer, Long> registers2 = RandomPrograms.registers(random, values);
            List<Instruction> suffix = RandomPrograms.sequence(random, mnemonics, random.nextInt(5, 25));
            Instruction target = RandomPrograms.instruction(random, m);
            List<Instruction> program = new ArrayList<>();
            if (m == Mnemonic.JALR) program.add(Instruction.andi(target.rs1(), target.rs1(), RandomPrograms.MAX_IMM_I - 4));
            program.add(target);
            program.addAll(suffix);
            if (alignMemory) program = RandomPrograms.alignMemoryAddresses(program);
            batch.add(new Program[]{new Program(registers1, program), new Program(registers2, program)});
        }
        List<TestCase> result = new ArrayList<>();
        for (Program[] p : RandomPrograms.sample(random, batch, total - produced)) {
            result.add(new TestCase(context.nextId(), p[0], p[1], Optional.empty()));
        }
        produced += result.size();
        return result;
    }
}
