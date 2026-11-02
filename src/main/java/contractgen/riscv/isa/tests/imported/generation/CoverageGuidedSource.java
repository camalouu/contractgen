package contractgen.riscv.isa.tests.imported.generation;

import contractgen.riscv.isa.tests.imported.contract.ContractAtom;
import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;
import contractgen.riscv.isa.tests.imported.isa.Subset;
import contractgen.riscv.isa.tests.imported.testcase.TestCase;

import java.util.*;

/**
 * Coverage-guided test generation (feedback-driven): test cases are built like those of
 * {@link DifferentProgramsSource}, but each one targets an atom of the universe chosen by how rarely the atom has
 * distinguished the runs of earlier test cases. Test cases thus concentrate on atoms whose leakage has not been
 * observed yet, instead of spreading evenly over all of them.
 * <p>
 * Every atom whose leakage function has a modifier is a target. An atom counts as observed in a test case if it is
 * strongly distinguishing or on either side of an xor-distinguishing pair. Target A is drawn with weight
 * 1 / (1 + observed(A) + attempts(A) / 10), where attempts(A) counts the earlier test cases that targeted A, so that
 * atoms that never distinguish anything are not tried forever. Counts lag by one batch (the runner keeps two batches in
 * flight); the test cases depend only on the seed.
 */
public final class CoverageGuidedSource implements TestCaseSource {

    private static final int ATTEMPTS_PER_TARGET = 16;

    private final List<Mnemonic> mnemonics;
    private final List<ContractAtom> targets = new ArrayList<>();
    private final Map<ContractAtom, Integer> observed = new HashMap<>();
    private final Map<ContractAtom, Integer> attempts = new HashMap<>();
    private final boolean alignMemory;
    private final RegisterValues values;
    private final int batchSize;
    private final long total;
    private final Random random;
    private long produced;

    /**
     * @param universe    the candidate atoms; those whose leakage function has a usable modifier are targeted
     * @param subsets     the ISA subsets to draw instructions from
     * @param seed        random seed
     * @param total       number of test cases
     * @param batchSize   test cases per batch; the counts are updated between batches
     * @param alignMemory whether to align all half- and word-sized memory accesses
     * @param values      the register values of the initial registers and the modifiers
     */
    public CoverageGuidedSource(List<ContractAtom> universe, Collection<Subset> subsets, long seed, long total, int batchSize,
                                boolean alignMemory, RegisterValues values) {
        this.mnemonics = Arrays.stream(Mnemonic.values()).filter(m -> subsets.contains(m.subset())).toList();
        for (ContractAtom a : universe) {
            if (DifferentProgramsSource.targetable(a.leakageFunction(), alignMemory) && !targetMnemonics(a).isEmpty()) {
                targets.add(a);
            }
        }
        if (targets.isEmpty()) throw new IllegalArgumentException("no atom of the universe can be targeted");
        this.alignMemory = alignMemory;
        this.values = values;
        this.batchSize = batchSize;
        this.total = total;
        this.random = new Random(new Random(seed).nextLong());
    }

    @Override
    public List<TestCase> nextBatch(GenerationContext context) {
        List<TestCase> batch = new ArrayList<>();
        double[] cumulative = new double[targets.size()];
        double sum = 0;
        for (int k = 0; k < targets.size(); k++) {
            ContractAtom a = targets.get(k);
            sum += 1.0 / (1 + observed.getOrDefault(a, 0) + attempts.getOrDefault(a, 0) / 10.0);
            cumulative[k] = sum;
        }
        // give up on a batch (and the run) if hardly any target can be turned into a test case
        for (int tries = 0; produced < total && batch.size() < batchSize && tries < 100 * batchSize; tries++) {
            int k = Arrays.binarySearch(cumulative, random.nextDouble() * sum);
            ContractAtom target = targets.get(k >= 0 ? k : -k - 1);
            attempts.merge(target, 1, Integer::sum);
            generate(target).ifPresent(tc -> {
                batch.add(new TestCase(context.nextId(), tc.first(), tc.second(), tc.intent()));
                produced++;
            });
        }
        if(produced<total && batch.size()<batchSize) throw new IllegalStateException("Coverage generation attempts exhausted at "+produced+" of "+total);
        return batch;
    }

    /** A test case for the atom: a random instruction it applies to, modified by its leakage function's modifier. */
    private Optional<TestCase> generate(ContractAtom atom) {
        List<Mnemonic> candidates = targetMnemonics(atom);
        for (int attempt = 0; attempt < ATTEMPTS_PER_TARGET; attempt++) {
            SortedMap<Integer, Long> registers = RandomPrograms.registers(random, values);
            List<Instruction> suffix = RandomPrograms.sequence(random, mnemonics, random.nextInt(5, 25));
            if (alignMemory) suffix = RandomPrograms.alignMemoryAddresses(suffix);
            Instruction target = RandomPrograms.instruction(random, candidates.get(random.nextInt(candidates.size())));
            if (!atom.appliesTo(target)) continue;
            Optional<TestCase> tc = DifferentProgramsSource.assemble(registers, suffix, target, atom.leakageFunction(), atom,
                    random, alignMemory, values);
            if (tc.isPresent()) return tc;
        }
        return Optional.empty();
    }

    private List<Mnemonic> targetMnemonics(ContractAtom atom) {
        return mnemonics.stream()
                .filter(m -> atom.applicability().candidates().contains(m) && atom.leakageFunction().isDefinedFor(m))
                .toList();
    }

    public void onEvidence(List<Set<ContractAtom>> cases) {
        for (Set<ContractAtom> atoms : cases) for (ContractAtom a : atoms) observed.merge(a, 1, Integer::sum);
    }

    /** @return how often the atom was observed so far (for tests and progress reports). */
    public int observed(ContractAtom atom) {
        return observed.getOrDefault(atom, 0);
    }
}
