package contractgen.riscv.isa.tests;

import contractgen.TestCase;
import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.*;
import contractgen.riscv.isa.spike.SpikeAtomClient.SpikeCaseAtoms;
import contractgen.riscv.isa.tests.imported.generation.*;
import contractgen.riscv.isa.tests.imported.contract.*;
import contractgen.riscv.isa.tests.imported.isa.*;
import java.util.*;

/** Rewrite generation recipes lowered into the native execution model. Intent is never synthesis evidence. */
public final class ImportedTestCaseSource implements TestCaseSource {
    // Imported values are materialized in setup instructions; native initializer slots are always zero.
    // Share this immutable map instead of retaining 31 TreeMap entries for each side of every case.
    private static final SortedMap<Integer,Integer> ZERO_REGISTERS;
    static {
        SortedMap<Integer,Integer> zeros=new TreeMap<>();
        for(int r=1;r<32;r++) zeros.put(r,0);
        ZERO_REGISTERS=Collections.unmodifiableSortedMap(zeros);
    }
    public static final String REVISION="a4bfd9d391088f0265aea40fb57a5023784a4e83";
    private final contractgen.riscv.isa.tests.imported.generation.TestCaseSource source;
    private final GenerationContext context=new GenerationContext();
    private final boolean skipInit;
    private final List<ContractAtom> targets;
    public final List<String> untargeted;
    public ImportedTestCaseSource(String strategy, Set<RISCV_SUBSET> isa, Set<RISCV_OBSERVATION_TYPE> allowed,
            long seed, int count, boolean align, String values, int batchSize,
            RandomSource.Distributions distributions, boolean skipInit) {
        this(strategy, isa, allowed, seed, count, align, values, batchSize, distributions, skipInit, true);
    }
    public ImportedTestCaseSource(String strategy, Set<RISCV_SUBSET> isa, Set<RISCV_OBSERVATION_TYPE> allowed,
            long seed, int count, boolean align, String values, int batchSize,
            RandomSource.Distributions distributions, boolean skipInit, boolean varyInstructionTypes) {
        if (!varyInstructionTypes && !strategy.equals("random"))
            throw new IllegalArgumentException("Fixed instruction types require strategy random");
        if(count<1 || batchSize<1) throw new IllegalArgumentException("Count and generation batch size must be positive");
        List<Subset> subsets=isa.stream().map(s->Subset.parse(s.name())).toList();
        if(subsets.isEmpty()) throw new IllegalArgumentException("Empty generation ISA");
        RegisterValues rv=RegisterValues.valueOf(values.toUpperCase(Locale.ROOT));
        List<LeakageFunction> functions=LeakageFunction.recipes().stream().filter(f->allowed.stream().anyMatch(a->a.name().equals(f.id()))).toList();
        untargeted=allowed.stream().map(Enum::name).filter(a->functions.stream().noneMatch(f->f.id().equals(a))).sorted().toList();
        targets=new ArrayList<>();
        // Rewrite AtomUniverse orders functions by registry, then applicability by canonical mnemonic name.
        for(LeakageFunction f:functions) for(Mnemonic m:Arrays.stream(Mnemonic.values()).sorted(Comparator.comparing(Enum::name)).toList())
            if(subsets.contains(m.subset()) && f.isDefinedFor(m)) targets.add(new ContractAtom(MnemonicApplicability.of(m),f));
        source=switch(strategy) {
            case "different_programs" -> new DifferentProgramsSource(subsets,functions,seed,count,align,rv);
            case "same_programs" -> new SameProgramsSource(subsets,seed,count,align,rv);
            case "coverage_guided" -> new CoverageGuidedSource(targets,subsets,seed,count,batchSize,align,rv);
            case "random" -> new RandomSource(subsets,seed,count,align,rv,distributions,batchSize,varyInstructionTypes);
            default -> throw new IllegalArgumentException("Unknown imported strategy: "+strategy);
        };
        this.skipInit=skipInit;
    }
    public List<TestCase> nextBatch(Context ids) {
        List<TestCase> batch=source.nextBatch(context).stream().<TestCase>map(t->lower(t,ids.nextId(),skipInit)).toList();
        context.startNextBatch();
        return batch;
    }
    public static RISCVTestCase lower(contractgen.riscv.isa.tests.imported.testcase.TestCase t,int id,boolean skip) {
        RISCVProgram a=lower(t.first()), b=lower(t.second());
        RISCVTestCase result=new RISCVTestCase(a,b,Math.max(a.getProgram().size(),b.getProgram().size())+1,id);
        result.setSetupEvidence(new SetupEvidence(63,!skip));
        t.intent().ifPresent(intent -> {
            var f=RISCV_OBSERVATION_TYPE.valueOf(intent.leakageFunction().id());
            var consumer=RISCV_TYPE.valueOf(intent.applicability().mnemonic().name());
            result.setGenerationTarget(new GenerationTarget(new RISCVObservation(f.isDependency()?RISCV_TYPE.ADD:consumer,f,f.isDependency()),consumer));
        });
        return result;
    }
    private static RISCVProgram lower(Program p) {
        List<RISCVInstruction> instructions=new ArrayList<>();
        for(int r=1;r<32;r++) for(Instruction i:Instruction.li(r,p.registers().getOrDefault(r,0L))) instructions.add(lower(i));
        instructions.add(RISCVInstruction.NOP());
        p.instructions().stream().map(ImportedTestCaseSource::lower).forEach(instructions::add);
        if(instructions.size()>2048-32) throw new IllegalArgumentException("Generated program exceeds rv32-v1 instruction image");
        return new RISCVProgram(ZERO_REGISTERS,instructions);
    }
    private static RISCVInstruction lower(Instruction i) {
        Long imm=i.imm();
        return new RISCVInstruction(RISCV_TYPE.valueOf(i.mnemonic().name()),i.rd(),i.rs1(),i.rs2(),imm);
    }
    public void onEvidence(List<SpikeCaseAtoms> evidence) {
        if(!(source instanceof CoverageGuidedSource guided)) return;
        List<Set<ContractAtom>> counts=new ArrayList<>();
        for(SpikeCaseAtoms c:evidence) {
            Set<ContractAtom> seen=new HashSet<>();
            if(c.error()==null) for(ContractAtom a:targets) {
                RISCV_OBSERVATION_TYPE f=RISCV_OBSERVATION_TYPE.valueOf(a.leakageFunction().id());
                RISCV_TYPE type=f.isDependency()?RISCV_TYPE.ADD:RISCV_TYPE.valueOf(a.applicability().mnemonic().name());
                if(c.atoms().stream().anyMatch(o->o.type()==type && o.observation()==f)
                    || (!f.isDependency() && c.instructionPairs().stream().anyMatch(p->p.left()==type||p.right()==type))) seen.add(a);
            }
            counts.add(seen);
        }
        guided.onEvidence(counts);
    }
}
