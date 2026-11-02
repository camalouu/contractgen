package contractgen.riscv.isa.tests.imported.generation;

import contractgen.riscv.isa.tests.imported.contract.ContractAtom;
import contractgen.riscv.isa.tests.imported.contract.LeakageFunction;
import contractgen.riscv.isa.tests.imported.contract.MnemonicApplicability;
import contractgen.riscv.isa.tests.imported.contract.Modifier;
import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.Program;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;
import contractgen.riscv.isa.tests.imported.isa.Subset;
import contractgen.riscv.isa.tests.imported.testcase.TestCase;

import java.util.*;
import java.util.stream.Stream;

/**
 * Different-programs test generation (CCS 2025; was {@code RISCVTestGenerator}): both programs share the initial
 * registers and a random suffix and differ in a trigger prefix created by a leakage function's modifier.
 * <p>
 * Each batch holds, for every mnemonic of the subsets, one test case per leakage function that is defined for that
 * mnemonic and has a modifier applicable to a random instruction of it. If the last batch has to be truncated, a random selection of
 * its test cases is kept.
 */
public final class DifferentProgramsSource implements TestCaseSource {

    private final List<Mnemonic> mnemonics;
    private final List<LeakageFunction> functions;
    private final boolean alignMemory;
    private final RegisterValues values;
    private final long total;
    private final Random random;
    private long produced;

    /**
     * @param subsets     the ISA subsets to draw instructions from
     * @param functions   the leakage functions to target, in this order
     * @param seed        random seed
     * @param total       number of test cases
     * @param alignMemory whether to align all half- and word-sized memory accesses
     * @param values      the register values of the initial registers and the modifiers
     */
    public DifferentProgramsSource(Collection<Subset> subsets, List<LeakageFunction> functions, long seed, long total,
                                   boolean alignMemory, RegisterValues values) {
        this.mnemonics = Arrays.stream(Mnemonic.values()).filter(m -> subsets.contains(m.subset())).toList();
        this.functions = List.copyOf(functions);
        this.alignMemory = alignMemory;
        this.values = values;
        this.total = total;
        // the original derived the generator seed of each of its threads from the run seed
        this.random = new Random(new Random(seed).nextLong());
    }

    @Override
    public List<TestCase> nextBatch(GenerationContext context) {
        if (produced >= total) return List.of();
        List<TestCase> batch = new ArrayList<>();
        for (Mnemonic m : mnemonics) {
            SortedMap<Integer, Long> registers = RandomPrograms.registers(random, values);
            List<Instruction> suffix = RandomPrograms.sequence(random, mnemonics, random.nextInt(5, 25));
            if (alignMemory) suffix = RandomPrograms.alignMemoryAddresses(suffix);
            Instruction target = RandomPrograms.instruction(random, m);
            for (LeakageFunction f : functions) {
                if (!f.isDefinedFor(m) || !targetable(f, alignMemory)) continue;
                assemble(registers, suffix, target, f, new ContractAtom(MnemonicApplicability.of(m), f), random, alignMemory,
                        values).ifPresent(batch::add);
            }
        }
        List<TestCase> result = new ArrayList<>();
        for (TestCase tc : RandomPrograms.sample(random, batch, total - produced)) {
            result.add(new TestCase(context.nextId(), tc.first(), tc.second(), tc.intent()));
        }
        produced += result.size();
        return result;
    }

    /** Whether test cases can be generated for the leakage function: it has a modifier usable on the core. */
    static boolean targetable(LeakageFunction f, boolean alignMemory) {
        return f.modifier().isPresent() && !(alignMemory && f.modifier().get().needsMisalignedMemory());
    }

    /**
     * A test case (with id -1) whose programs share the registers and the suffix and start with the two prefixes the
     * leakage function's modifier makes of the target instruction; empty if the modifier does not apply to it.
     */
    static Optional<TestCase> assemble(SortedMap<Integer, Long> registers, List<Instruction> suffix, Instruction target,
                                       LeakageFunction f, ContractAtom intent, Random random, boolean alignMemory,
                                       RegisterValues values) {
        Optional<Modifier.Modification> modification = f.modifier().flatMap(x -> x.modify(target, random, values));
        if (modification.isEmpty()) return Optional.empty();
        List<Instruction> first = modification.get().first();
        List<Instruction> second = modification.get().second();
        if (target.mnemonic() == Mnemonic.JALR) {
            first = alignJumpTarget(first);
            second = alignJumpTarget(second);
        }
        if (alignMemory) {
            first = RandomPrograms.alignMemoryAddresses(first);
            second = RandomPrograms.alignMemoryAddresses(second);
        }
        return Optional.of(new TestCase(-1, new Program(registers, concat(first, suffix)),
                new Program(registers, concat(second, suffix)), Optional.of(intent)));
    }

    /** Inserts an andi before the final jalr that clears the low bits of its base register. */
    private static List<Instruction> alignJumpTarget(List<Instruction> prefix) {
        List<Instruction> l = new ArrayList<>(prefix);
        int rs1 = l.get(l.size() - 1).rs1();
        l.add(l.size() - 1, Instruction.andi(rs1, rs1, RandomPrograms.MAX_IMM_I - 4));
        return l;
    }

    private static List<Instruction> concat(List<Instruction> a, List<Instruction> b) {
        return Stream.concat(a.stream(), b.stream()).toList();
    }
}
