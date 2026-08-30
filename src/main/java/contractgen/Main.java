package contractgen;

import com.google.gson.GsonBuilder;
import contractgen.generator.iverilog.Falsifier;
import contractgen.generator.iverilog.ParallelIverilogGenerator;
import contractgen.riscv.cva6.CVA6;
import contractgen.riscv.cva6_test.CVA6Test;
import contractgen.riscv.cva6_test.CVA6TestAttackerClient;
import contractgen.riscv.AdaptiveAttackerRunner;
import contractgen.riscv.AttackerHarnessClient;
import contractgen.riscv.darkriscv.DARKRISCV_2;
import contractgen.riscv.darkriscv.DARKRISCV_3;
import contractgen.riscv.hazard3_test.Hazard3Test;
import contractgen.riscv.hazard3_test.Hazard3TestAttackerClient;
import contractgen.riscv.ibex.IBEX;
import contractgen.riscv.ibex.IBEXTest;
import contractgen.riscv.ibex.IBEXTestAttackerClient;
import contractgen.riscv.isa.RISCVTestCase;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVContract;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.extractor.BMCExtractor;
import contractgen.riscv.isa.extractor.DarkRISCVExtractor;
import contractgen.riscv.isa.extractor.Sodor5Extractor;
import contractgen.riscv.isa.extractor.SodorExtractor;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import contractgen.riscv.isa.spike.SpikeAtomParallelRunner;
import contractgen.riscv.isa.spike.SpikeAtomsWorker;
import contractgen.riscv.isa.tests.RISCVIterativeTests;
import contractgen.riscv.isa.tests.RISCVListTestCases;
import contractgen.riscv.isa.tests.RISCVTestCaseIO;
import contractgen.riscv.proteus.ProteusTest;
import contractgen.riscv.proteus.ProteusTestAttackerClient;
import contractgen.riscv.sodor.SODOR_2;
import contractgen.riscv.sodor.SODOR_5;
import contractgen.updater.ILPUpdater;
import contractgen.refinement.RefineZ3;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import java.util.concurrent.Callable;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;
import java.util.stream.Collectors;

@Command(name = "main", subcommands = {Synthesize.class, SynthesizeNew.class, ExportTests.class, CompactTests.class, ReplaySynthesize.class, ReplaySynthesizeSpike.class, RefineZ3.class, CompareSpikeRvfiAtoms.class, CompareIbexTestAttacker.class, CompareCva6TestAttacker.class, CompareContracts.class, SpikeAtomsWorker.class, ILP.class, Analyze.class, Update.class, Evaluate.class, Falsify.class, PrintAtoms.class, UnsafeInstructions.class, Stats.class}, description = "Main application command.")
public class Main implements Callable<Integer> {
    public static void main(String[] args) {
        int exitCode = new CommandLine(new Main()).execute(args);
        System.exit(exitCode);
    }

    @Override
    public Integer call() throws Exception {
        // The default command when no subcommand is specified
        System.out.println("No command specified, defaulting to classic contactgen.");
        try {
            ContractGen.main(null);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

enum LegacySynthesisProcessor {
    IBEX,
    CVA6
}

@Command(name = "synthesize", description = "Legacy contract synthesis using RTL for both attacker labels and contract atoms.")
class Synthesize implements Callable<Integer> {
    // select the processor
    @Option(names = {"-p", "--processor"}, required = true, description = "The processor to use. Options: ${COMPLETION-CANDIDATES}")
    LegacySynthesisProcessor processor;

    // select ISA
    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    // select contract template
    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    // select number of test cases
    @Option(names = {"-n"}, required = true, description = "Number of test cases")
    int number;

    // select number of threads
    @Option(names = {"-t"}, required = true, description = "Number of threads")
    int threads;

    // select seed
    @Option(names = {"-s"}, required = true, description = "Seed")
    long seed;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--txt"}, description = "Output path for txt-summary")
    File txt;

    @Option(names = {"--sp"}, description = "Only consider identical programs (same program mode)")
    boolean isSP = false;

    @Option(names = {"--skipILP"}, description = "Skip ILP after evaluating the test cases.")
    boolean skipILP = false;

    @Option(names = {"--instruction"}, description = "Always leak the instruction and the PC.")
    boolean leakInstruction = false;

    @Option(names = {"--verilator"}, description = "Use Verilator for simulation. Applies to IBEX.")
    boolean useVerilator = false;

    @Option(names = {"--random-suffix"}, description = "Add state-isolated non-memory, non-control random instructions after the target atom", defaultValue = "false")
    boolean randomSuffix = false;

    @Option(names = {"--reset-sequence"}, description = "Insert reset sequence between repetitions", defaultValue = "false")
    boolean resetSequence = false;

    @Option(names = {"--reps"}, description = "Number of times to test an atom in one test case.", defaultValue = "1")
    int reps = 1;
    
    @Option(names = {"--bit-dist"}, description = "Use bit length distribution for immediates", defaultValue = "false")
    boolean bitDist = false;
    
    @Option(names = {"--random-prefix"}, description = "Add random instructions before the target atom", defaultValue = "false")
    boolean randomPrefix = false;

    @Override
    public Integer call() {
        TestCases tc = new RISCVIterativeTests(isa, RISCV_OBSERVATION_TYPE.getGroups(template), seed, threads, number, isSP, processor != LegacySynthesisProcessor.CVA6 || !useVerilator, reps, bitDist, randomPrefix, randomSuffix, resetSequence);
        Generator generator = new 
        ParallelIverilogGenerator(
            switch (processor) {
                case IBEX -> new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                case CVA6 -> new CVA6(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
            },
            threads, false, null, skipILP);

        long start = System.currentTimeMillis();
        Contract contract;
        try {
            contract = generator.generate();
            if (leakInstruction) {
                int index = number + 1;
                for (RISCV_TYPE type : RISCV_TYPE.values()) {
                    if (isa.contains(type.getSubset())) {
                        if (Set.of(RISCV_TYPE.BEQ, RISCV_TYPE.BGE, RISCV_TYPE.BLT, RISCV_TYPE.BNE, RISCV_TYPE.BGEU, RISCV_TYPE.BLTU, RISCV_TYPE.JAL, RISCV_TYPE.JALR).contains(type)) {
                            contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.NEW_PC)), Set.of(), true, index++));
                        }
                        switch (type.getFormat()) {
                            case RTYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS2)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT7)), Set.of(), true, index++));
                                break;
                            case ITYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                                break;
                            case STYPE, BTYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS2)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                                break;
                            case UTYPE, JTYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                                break;
                        }
                    }
                }
                if (!skipILP) {
                    contract.update(true);
                }
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        long finish = System.currentTimeMillis();
        long timeElapsed = finish - start;
        System.out.println("\nGeneration time: " + timeElapsed);
        System.out.println(contract);
        if (txt != null) {
            try {
                StringBuilder sb = new StringBuilder();
                sb.append("Summary:\n");
                sb.append("\tGeneration Time: ").append(timeElapsed).append(" ms\n");
                sb.append("\tProcessor: ").append(processor).append("\n");
                sb.append("\tISA: ").append(isa).append("\n");
                sb.append("\tTemplate: ").append(template).append("\n");
                sb.append("\tCount: ").append(number).append("\n");
                sb.append("\tThreads: ").append(threads).append("\n");
                sb.append("\tRepeats: ").append(reps).append("\n");
                sb.append("\tBit-Dist: ").append(bitDist).append("\n");
                sb.append("\tRandom-Prefix: ").append(randomPrefix).append("\n");
                sb.append("\tRandom-Suffix: ").append(randomSuffix).append("\n");
                sb.append("\tReset-Sequence: ").append(resetSequence).append("\n");
                sb.append("\tSeed: ").append(seed).append("\n");
                sb.append("\n");
                sb.append(contract.toString());
                Files.write(Path.of(txt.getPath()), sb.toString().getBytes());
            } catch (IOException e) {
            }
        }
        try (FileWriter writer = new FileWriter(out)) {
            contract.toJSON(writer);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

@Command(name = "synth_new", description = "Synthesize using Spike for contract atoms and an attacker-only RTL harness for attacker labels.")
class SynthesizeNew implements Callable<Integer> {
    @Option(names = {"-p", "--processor"}, required = true, description = "Attacker-only RTL harness: ${COMPLETION-CANDIDATES}")
    ReplayAttackerHarness processor;

    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    @Option(names = {"-n"}, required = true, description = "Number of test cases")
    int number;

    @Option(names = {"-t"}, required = true, description = "Number of simulation threads")
    int threads;

    @Option(names = {"-s"}, required = true, description = "Seed")
    long seed;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--testcases-output"}, description = "Output path for the exact generated testcase set. Defaults to <output>-testcases.json.")
    File testcasesOut;

    @Option(names = {"--txt"}, description = "Output path for txt-summary")
    File txt;

    @Option(names = {"--sp"}, description = "Only consider identical programs (same program mode)")
    boolean isSP;

    @Option(names = {"--skipILP"}, description = "Skip ILP after evaluating the test cases.")
    boolean skipILP;

    @Option(names = {"--instruction"}, description = "Always leak the instruction and the PC.")
    boolean leakInstruction;

    @Option(names = {"--random-suffix"}, description = "Add state-isolated non-memory, non-control random instructions after the target atom")
    boolean randomSuffix;

    @Option(names = {"--reset-sequence"}, description = "Insert reset sequence between repetitions")
    boolean resetSequence;

    @Option(names = {"--reps"}, description = "Number of times to test an atom in one test case.", defaultValue = "1")
    int reps;

    @Option(names = {"--bit-dist"}, description = "Use bit length distribution for immediates")
    boolean bitDist;

    @Option(names = {"--random-prefix"}, description = "Add random instructions before the target atom")
    boolean randomPrefix;

    @Option(names = {"--spike-lib"}, description = "Path to libcontract_spike_atom.so. Defaults to CONTRACT_SPIKE_LIB or riscv-isa-sim/build/libcontract_spike_atom.so")
    File spikeLib;

    @Option(names = {"--ibex-test-lib"}, description = "Path to libcontract_ibex_test_attacker.so.")
    File ibexTestLib;

    @Option(names = {"--cva6-test-lib"}, description = "Path to libcontract_cva6_test_attacker.so.")
    File cva6TestLib;

    @Option(names = {"--hazard3-test-lib"}, description = "Path to libcontract_hazard3_test_attacker.so.")
    File hazard3TestLib;

    @Option(names = {"--proteus-test-lib"}, description = "Path to libcontract_proteus_test_attacker.so.")
    File proteusTestLib;

    @Option(names = {"--spike-isa"}, description = "Spike ISA string.", defaultValue = "RV32IM_Zicclsm")
    String spikeIsa;

    @Option(names = {"--negative-signature-threshold"}, description = "Maximum negative executions per exact Spike signature; zero means unlimited.", defaultValue = "0")
    int negativeSignatureThreshold;

    @Option(names = {"--use-skipped-evidence"}, description = "Add adaptively skipped cases as inferred evidence.")
    boolean useSkippedEvidence;

    @Option(names = {"--skip-positive-supersets"}, description = "Enable positive-superset signature skipping.")
    boolean skipPositiveSupersets;

    @Option(names = {"--skip-negative-subsets"}, description = "Enable negative-subset signature skipping.")
    boolean skipNegativeSubsets;

    @Option(names = {"--disable-adaptive-skipping"}, description = "Execute the attacker RTL for every generated testcase.")
    boolean disableAdaptiveSkipping;

    @Override
    public Integer call() {
        if (processor == ReplayAttackerHarness.PROTEUS_TEST && reps != 1) {
            throw new IllegalArgumentException("PROTEUS_TEST direct synthesis currently requires --reps=1.");
        }
        if (processor == ReplayAttackerHarness.PROTEUS_TEST && resetSequence) {
            throw new IllegalArgumentException("PROTEUS_TEST direct synthesis does not support --reset-sequence.");
        }

        boolean allowMisalignedMemory = processor == ReplayAttackerHarness.IBEX_TEST;
        TestCases generated = new RISCVIterativeTests(
                isa,
                RISCV_OBSERVATION_TYPE.getGroups(template),
                seed,
                threads,
                number,
                isSP,
                allowMisalignedMemory,
                reps,
                bitDist,
                randomPrefix,
                randomSuffix,
                resetSequence
        );
        List<TestCase> tests = RISCVTestCaseIO.collect(generated::getIterator, threads);
        Path testcasePath = resolveTestcasesOutput(out, testcasesOut);
        try {
            RISCVTestCaseIO.write(testcasePath, tests);
        } catch (IOException e) {
            throw new RuntimeException("Failed to write generated testcases to " + testcasePath, e);
        }
        System.out.println("Exported " + tests.size() + " generated testcases to " + testcasePath);

        ReplaySynthesizeSpike runner = new ReplaySynthesizeSpike();
        runner.isa = isa;
        runner.template = template;
        runner.threads = threads;
        runner.out = out;
        runner.txt = txt;
        runner.leakInstruction = leakInstruction;
        runner.skipILP = skipILP;
        runner.spikeLib = spikeLib;
        runner.ibexTestLib = ibexTestLib;
        runner.cva6TestLib = cva6TestLib;
        runner.hazard3TestLib = hazard3TestLib;
        runner.proteusTestLib = proteusTestLib;
        runner.spikeIsa = spikeIsa;
        runner.processor = processor;
        runner.negativeSignatureThreshold = negativeSignatureThreshold;
        runner.useSkippedEvidence = useSkippedEvidence;
        runner.skipPositiveSupersets = skipPositiveSupersets;
        runner.skipNegativeSubsets = skipNegativeSubsets;
        runner.disableAdaptiveSkipping = disableAdaptiveSkipping;

        String source = "generated seed=" + seed
                + ", count=" + number
                + ", reps=" + reps
                + ", bitDist=" + bitDist
                + ", randomPrefix=" + randomPrefix
                + ", randomSuffix=" + randomSuffix
                + ", resetSequence=" + resetSequence
                + ", testcases=" + testcasePath;
        return runner.runTests(tests, source);
    }

    static Path resolveTestcasesOutput(File contractOutput, File explicitOutput) {
        if (explicitOutput != null) {
            return explicitOutput.toPath();
        }
        Path contractPath = contractOutput.toPath();
        String filename = contractPath.getFileName().toString();
        String stem = filename.toLowerCase(java.util.Locale.ROOT).endsWith(".json")
                ? filename.substring(0, filename.length() - 5)
                : filename;
        return contractPath.resolveSibling(stem + "-testcases.json");
    }
}

@Command(name = "unsafeInstructions", description = "Check if a program contains unsafe Instructions.")
class UnsafeInstructions implements Callable<Integer> {
    // select the processor
    @Option(names = {"-p", "--processor"}, required = true, description = "The processor to use. Options: ${COMPLETION-CANDIDATES}")
    CONFIG.PROCESSOR processor;

    // select ISA
    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    // select contract template
    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    @Option(names = {"-u", "--unsafe"}, required = true, description = "The unsafe instructions to check for. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_TYPE> unsafeInstructions;

    // select number of test cases
    @Option(names = {"-n"}, required = true, description = "Number of test cases")
    int number;

    // select number of threads
    @Option(names = {"-t"}, required = true, description = "Number of threads")
    int threads;

    // select seed
    @Option(names = {"-s"}, required = true, description = "Seed")
    long seed;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--txt"}, description = "Output path for txt-summary")
    File txt;

    @Option(names = {"--sp"}, description = "Only consider identical programs (same program mode)")
    boolean isSP = false;

    @Override
    public Integer call() {
        if (processor != CONFIG.PROCESSOR.IBEX) {
            System.out.println("Only IBEX is supported.");
            return 0;
        }
        TestCases tc = new RISCVIterativeTests(isa, RISCV_OBSERVATION_TYPE.getGroups(template), seed, threads, number, isSP, true);
        Generator generator = new 
        ParallelIverilogGenerator(
            new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, unsafeInstructions, false),
            threads, false, null, false
        );
        
        long start = System.currentTimeMillis();
        Contract contract;
        try {
            contract = generator.generate();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        long finish = System.currentTimeMillis();
        long timeElapsed = finish - start;
        System.out.println("\nGeneration time: " + timeElapsed);
        System.out.println(contract);
        if (txt != null) {
            try {
                Files.write(Path.of(txt.getPath()), contract.toString().getBytes());
            } catch (IOException e) {
            }
        }
        try (FileWriter writer = new FileWriter(out)) {
            contract.toJSON(writer);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

@Command(name = "analyze", description = "Analyze a counterexample from leave-bmc")
class Analyze implements Callable<Integer> {

    @Option(names = {"-f", "--file"}, required = true, description = "The trace vcd from bmc")
    File bmc_file;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    // select the processor
    @Option(names = {"-p", "--processor"}, required = true, description = "The processor to use. Options: ${COMPLETION-CANDIDATES}")
    CONFIG.PROCESSOR processor;

    // select contract template
    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    @Override
    public Integer call() {
        Extractor extractor = 
            switch (processor) {
                case IBEX -> new BMCExtractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case IBEX_TEST -> new BMCExtractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case IBEX_SMALL -> new BMCExtractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case IBEX_CACHE -> new BMCExtractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case CVA6 -> throw new RuntimeException("CVA6 not supported.");
                case SODOR_2 -> new SodorExtractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case SODOR_5 -> new Sodor5Extractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case DARKRISCV_2 -> new DarkRISCVExtractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case DARKRISCV_3 -> new DarkRISCVExtractor(RISCV_OBSERVATION_TYPE.getGroups(template));
                case HAZARD3 -> throw new RuntimeException("HAZARD3 not supported.");
            };
        TestResult res = extractor.extractResults(bmc_file.getPath(), true, 0);
        RISCVContract ctr = new RISCVContract(res.getDistinguishingObservations().stream().collect(Collectors.toSet()), List.of(res), new ILPUpdater());
        System.out.println(ctr.toJSON());
        try (FileWriter writer = new FileWriter(out)) {
            ctr.toJSON(writer);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

@Command(name = "update", description = "Update a synthesized contract with one or more new results.")
class Update implements Callable<Integer> {

    @Option(names = {"-c", "--contract"}, required = true, description = "Old contract (JSON)")
    File old_ctr;

    @Option(names = {"-r", "--results"}, required = true,  description = "New results (JSON)")
    File new_results;

    @Option(names = {"-o", "--output"}, required = true,  description = "Output path (JSON)")
    File out;

    @Option(names = {"--txt"}, description = "Output path for txt-summary")
    File txt;

    @Override
    public Integer call() {
        try {
            RISCVContract contract = RISCVContract.fromJSON(new FileReader(old_ctr));
            System.out.println(contract);
            RISCVContract results = RISCVContract.fromJSON(new FileReader(new_results));
            for (TestResult res : results.getTestResults()) {
                contract.add(res);
            }
            contract.update(true);
            System.out.println(contract);
            contract.toJSON(new FileWriter(out));
            if (txt != null) {
                try (FileWriter writer = new FileWriter(txt)) {
                    writer.write(contract.toString());
                }
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

@Command(name = "ilp", description = "Run the ILP.")
class ILP implements Callable<Integer> {

    @Option(names = {"-r", "--results"}, required = true,  description = "Results (JSON)")
    File results;

    @Option(names = {"-o", "--output"}, required = true,  description = "Output path (JSON)")
    File out;

    @Option(names = {"--txt"}, description = "Output path for txt-summary")
    File txt;

    @Override
    public Integer call() {
        try {
            RISCVContract contract = RISCVContract.fromJSON(new FileReader(results));
            contract.update(true);
            contract.toJSON(new FileWriter(out));
            if (txt != null) {
                try (FileWriter writer = new FileWriter(txt)) {
                    writer.write(contract.toString());
                }
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

@Command(name = "print_atoms", description = "Print all applicable atoms.")
class PrintAtoms implements Callable<Integer> {

    // select ISA
    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    // select contract template
    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;
    
    @Override
    public Integer call() {
        List<RISCV_TYPE> types = Arrays.stream(RISCV_TYPE.values()).filter(type -> isa.contains(type.getSubset())).toList();
        List<RISCV_OBSERVATION_TYPE> observations = RISCV_OBSERVATION_TYPE.getGroups(template).stream().toList();
        List<RISCVObservation> observationList = types.stream().map(type -> observations.stream().map(observation -> new RISCVObservation(type, observation)).toList()).flatMap(List::stream).toList();
        observationList = observationList.stream().filter(RISCVObservation::isApplicable).toList();
        observationList.forEach(System.out::println);
        return 0;
    }
}

@Command(name = "evaluate", description = "Evaluate a contract against a set of test cases.")
class Evaluate implements Callable<Integer> {

    @Option(names = {"-c", "--contract"}, required = true, description = "Verified contract (JSON)")
    File contract;

    @Option(names = {"-e", "--evalset"}, required = true,  description = "Evaluation set (JSON)")
    File evalset;

    @Option(names = {"-o", "--output"}, required = true,  description = "Output path (JSON)")
    File out;

    @Override
    public Integer call() {
        try {
            Files.createDirectories(out.toPath());
            ContractGen.basicStats(RISCVContract.fromJSON(new FileReader(contract)), RISCVContract.fromJSON(new FileReader(evalset)).getTestResults(), "Statistics", out.getPath() + "/stats", null);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return 0;
    }
}

@Command(name = "falsify", description = "Falsify a contract and output false negatives.")
class Falsify implements Callable<Integer> {

    @Option(names = {"-v", "--verified-contract"}, required = true, description = "Verified contract (JSON)")
    File contract;

    // select the processor
    @Option(names = {"-p", "--processor"}, required = true, description = "The processor to use. Options: ${COMPLETION-CANDIDATES}")
    CONFIG.PROCESSOR processor;

    // select ISA
    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    // select contract template
    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    // select number of test cases
    @Option(names = {"-n"}, required = true, description = "Number of test cases")
    int number;

    // select number of threads
    @Option(names = {"-t"}, required = true, description = "Number of threads")
    int threads;

    // select seed
    @Option(names = {"-s"}, required = true, description = "Seed")
    long seed;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path")
    Path out;

    @Option(names = {"--sp"}, description = "Only consider identical programs (same program mode)")
    boolean isSP = false;

    @Option(names = {"--verilator"}, description = "Use Verilator for simulation. Applies to IBEX.")
    boolean useVerilator = false;

    @Override
    public Integer call() {
       try {
            RISCVContract ctr = RISCVContract.fromJSON(new FileReader(contract));
            // ctr.update(true); do not update the contract, use the one from the json.
            out.toFile().mkdirs();
            System.out.println(ctr.getCurrentContract());
            Files.write(out.resolve("contract.txt"), ctr.toString().getBytes());
            TestCases tc = new RISCVIterativeTests(isa, RISCV_OBSERVATION_TYPE.getGroups(template), seed, threads, number, isSP, processor != CONFIG.PROCESSOR.CVA6 || !useVerilator);
            Generator generator = 
            new Falsifier(
                switch (processor) {
                    case IBEX -> new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                    case IBEX_TEST -> new IBEXTest(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                    case IBEX_SMALL -> new IBEX(IBEX.VARIANT.SMALL, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                    case IBEX_CACHE -> new IBEX(IBEX.VARIANT.CACHE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                    case CVA6 -> new CVA6(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                    case SODOR_2 -> new SODOR_2(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                    case SODOR_5 -> new SODOR_5(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                    case DARKRISCV_2 -> new DARKRISCV_2(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                    case DARKRISCV_3 -> new DARKRISCV_3(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                    case HAZARD3 -> new contractgen.riscv.hazard3.HAZARD3(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                }, 
                threads, 
                ctr, 
                out);
            generator.generate();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return 0;
    }
}

@Command(name = "export_tests", description = "Generate, execute, and export only non-skipped testcases.")
class ExportTests implements Callable<Integer> {
    @Option(names = {"-p", "--processor"}, required = true, description = "The processor to use. Options: ${COMPLETION-CANDIDATES}")
    CONFIG.PROCESSOR processor;

    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    @Option(names = {"-n"}, required = true, description = "Number of test cases")
    int number;

    @Option(names = {"-t"}, required = true, description = "Number of threads")
    int threads;

    @Option(names = {"-s"}, required = true, description = "Seed")
    long seed;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--results-output"}, description = "Optional output path for execution results/contract JSON")
    File resultsOut;

    @Option(names = {"--sp"}, description = "Only consider identical programs (same program mode)")
    boolean isSP = false;

    @Option(names = {"--verilator"}, description = "Use Verilator for simulation. Applies to IBEX.")
    boolean useVerilator = false;

    @Option(names = {"--reps"}, description = "Number of times to test an atom in one test case.", defaultValue = "1")
    int reps = 1;

    @Option(names = {"--bit-dist"}, description = "Use bit length distribution for immediates", defaultValue = "false")
    boolean bitDist = false;

    @Option(names = {"--random-prefix"}, description = "Add random instructions before the target atom", defaultValue = "false")
    boolean randomPrefix = false;

    @Option(names = {"--random-suffix"}, description = "Add state-isolated non-memory, non-control random instructions after the target atom", defaultValue = "false")
    boolean randomSuffix = false;

    @Option(names = {"--reset-sequence"}, description = "Insert reset sequence between repetitions", defaultValue = "false")
    boolean resetSequence = false;

    @Override
    public Integer call() {
        try {
            TestCases tc = new RISCVIterativeTests(isa, RISCV_OBSERVATION_TYPE.getGroups(template), seed, threads, number, isSP, processor != CONFIG.PROCESSOR.CVA6 || !useVerilator, reps, bitDist, randomPrefix, randomSuffix, resetSequence);
            List<TestCase> tests = RISCVTestCaseIO.collect(tc::getIterator, threads);

            TestCases replay = new RISCVListTestCases(tests, threads);
            Generator generator = new ParallelIverilogGenerator(
                    switch (processor) {
                        case IBEX -> new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                        case IBEX_TEST -> new IBEXTest(new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                        case IBEX_CACHE -> new IBEX(IBEX.VARIANT.CACHE, new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                        case IBEX_SMALL -> new IBEX(IBEX.VARIANT.SMALL, new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                        case CVA6 -> new CVA6(new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                        case SODOR_2 -> new SODOR_2(new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                        case SODOR_5 -> new SODOR_5(new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                        case DARKRISCV_2 -> new DARKRISCV_2(new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                        case DARKRISCV_3 -> new DARKRISCV_3(new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                        case HAZARD3 -> new contractgen.riscv.hazard3.HAZARD3(new ILPUpdater(), replay, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                    },
                    threads, false, null, true);
            Contract replayResults = generator.generate();
            Set<Integer> executedIndices = replayResults.getTestResults().stream().map(TestResult::getIndex).collect(Collectors.toSet());
            List<TestCase> cleanTests = RISCVTestCaseIO.filterByIndices(tests, executedIndices);

            RISCVTestCaseIO.write(out.toPath(), cleanTests);
            if (resultsOut != null) {
                try (FileWriter writer = new FileWriter(resultsOut)) {
                    replayResults.toJSON(writer);
                }
            }
            System.out.println("Exported " + cleanTests.size() + " clean test cases out of " + tests.size() + " to " + out.getPath());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

@Command(name = "compact_tests", description = "Compact a clean testcase JSON into repeated-atom testcases.")
class CompactTests implements Callable<Integer> {
    @Option(names = {"-i", "--input"}, required = true, description = "Input testcase JSON")
    File in;

    @Option(names = {"-o", "--output"}, required = true, description = "Output testcase JSON")
    File out;

    @Option(names = {"--stats"}, description = "Optional output path for group-size stats (TXT)")
    File stats;

    @Option(names = {"--group-size"}, description = "Maximum repetitions per compacted testcase for one atom group", defaultValue = "2147483647")
    int groupSize;

    @Option(names = {"--reset-sequence"}, description = "Insert reset sequence between repetitions inside a compacted testcase", defaultValue = "true")
    boolean resetSequence = true;

    @Override
    public Integer call() {
        try {
            List<TestCase> tests = RISCVTestCaseIO.read(in.toPath());
            Map<String, Integer> groups = RISCVTestCaseIO.compactGroupSizes(tests);
            List<TestCase> compacted = RISCVTestCaseIO.compact(tests, groupSize, resetSequence);
            RISCVTestCaseIO.write(out.toPath(), compacted);
            if (stats != null) {
                StringBuilder sb = new StringBuilder();
                groups.forEach((k, v) -> sb.append(v).append("\t").append(k).append("\n"));
                Files.write(stats.toPath(), sb.toString().getBytes());
            }
            System.out.println("Compacted " + tests.size() + " -> " + compacted.size() + " test cases.");
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

@Command(name = "replay_synthesize", description = "Run synthesis from an exported testcase JSON file.")
class ReplaySynthesize implements Callable<Integer> {
    @Option(names = {"-p", "--processor"}, required = true, description = "The processor to use. Options: ${COMPLETION-CANDIDATES}")
    CONFIG.PROCESSOR processor;

    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    @Option(names = {"-t"}, required = true, description = "Number of threads")
    int threads;

    @Option(names = {"-e", "--testcases"}, required = true, description = "Input testcase JSON")
    File testcases;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--txt"}, description = "Output path for txt-summary")
    File txt;

    @Option(names = {"--skipILP"}, description = "Skip ILP after evaluating the test cases.")
    boolean skipILP = false;

    @Option(names = {"--instruction"}, description = "Always leak the instruction and the PC.")
    boolean leakInstruction = false;

    @Option(names = {"--verilator"}, description = "Use Verilator for simulation. Applies to IBEX.")
    boolean useVerilator = false;

    @Override
    public Integer call() {
        List<TestCase> tests;
        try {
            tests = RISCVTestCaseIO.read(testcases.toPath());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        TestCases tc = new RISCVListTestCases(tests, threads);
        Generator generator = new ParallelIverilogGenerator(
                switch (processor) {
                    case IBEX -> new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                    case IBEX_TEST -> new IBEXTest(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                    case IBEX_CACHE -> new IBEX(IBEX.VARIANT.CACHE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                    case IBEX_SMALL -> new IBEX(IBEX.VARIANT.SMALL, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                    case CVA6 -> new CVA6(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                    case SODOR_2 -> new SODOR_2(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                    case SODOR_5 -> new SODOR_5(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                    case DARKRISCV_2 -> new DARKRISCV_2(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                    case DARKRISCV_3 -> new DARKRISCV_3(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false);
                    case HAZARD3 -> new contractgen.riscv.hazard3.HAZARD3(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, false, useVerilator);
                },
                threads, false, null, skipILP);

        long start = System.currentTimeMillis();
        Contract contract;
        try {
            contract = generator.generate();
            if (leakInstruction) {
                int index = tests.size() + 1;
                for (RISCV_TYPE type : RISCV_TYPE.values()) {
                    if (isa.contains(type.getSubset())) {
                        if (Set.of(RISCV_TYPE.BEQ, RISCV_TYPE.BGE, RISCV_TYPE.BLT, RISCV_TYPE.BNE, RISCV_TYPE.BGEU, RISCV_TYPE.BLTU, RISCV_TYPE.JAL, RISCV_TYPE.JALR).contains(type)) {
                            contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.NEW_PC)), Set.of(), true, index++));
                        }
                        switch (type.getFormat()) {
                            case RTYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS2)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT7)), Set.of(), true, index++));
                                break;
                            case ITYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                                break;
                            case STYPE, BTYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS2)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                                break;
                            case UTYPE, JTYPE:
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                                contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                                break;
                        }
                    }
                }
                if (!skipILP) {
                    contract.update(true);
                }
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        long finish = System.currentTimeMillis();
        long timeElapsed = finish - start;
        System.out.println("\nGeneration time: " + timeElapsed);
        System.out.println(contract);
        if (txt != null) {
            try {
                StringBuilder sb = new StringBuilder();
                sb.append("Summary:\n");
                sb.append("\tGeneration Time: ").append(timeElapsed).append(" ms\n");
                sb.append("\tProcessor: ").append(processor).append("\n");
                sb.append("\tISA: ").append(isa).append("\n");
                sb.append("\tTemplate: ").append(template).append("\n");
                sb.append("\tCount: ").append(tests.size()).append("\n");
                sb.append("\tThreads: ").append(threads).append("\n");
                sb.append("\tSource: ").append(testcases.getPath()).append("\n");
                sb.append("\n");
                sb.append(contract.toString());
                Files.write(Path.of(txt.getPath()), sb.toString().getBytes());
            } catch (IOException e) {
            }
        }
        try (FileWriter writer = new FileWriter(out)) {
            contract.toJSON(writer);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }
}

enum ReplayAttackerHarness {
    IBEX_TEST,
    CVA6_TEST,
    HAZARD3_TEST,
    PROTEUS_TEST
}

@Command(name = "replay_synthesize_spike", description = "Run replay synthesis using Spike for atom distinguishability and an attacker-only RTL harness for attacker distinguishability.")
class ReplaySynthesizeSpike implements Callable<Integer> {
    private static final int MAX_FAILURE_INDICES = 10;

    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    @Option(names = {"-t"}, required = true, description = "Number of threads")
    int threads;

    @Option(names = {"-e", "--testcases"}, required = true, description = "Input testcase JSON")
    File testcases;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--txt"}, description = "Output path for txt-summary")
    File txt;

    @Option(names = {"--instruction"}, description = "Always leak the instruction and the PC.")
    boolean leakInstruction = false;

    @Option(names = {"--skipILP"}, description = "Skip ILP after evaluating the replay cases.")
    boolean skipILP = false;

    @Option(names = {"--spike-lib"}, description = "Path to libcontract_spike_atom.so. Defaults to CONTRACT_SPIKE_LIB or riscv-isa-sim/build/libcontract_spike_atom.so")
    File spikeLib;

    @Option(names = {"--ibex-test-lib"}, description = "Path to libcontract_ibex_test_attacker.so. Defaults to CONTRACT_IBEX_TEST_LIB or the IBEX_TEST compilation output.")
    File ibexTestLib;

    @Option(names = {"--cva6-test-lib"}, description = "Path to libcontract_cva6_test_attacker.so. Defaults to CONTRACT_CVA6_TEST_LIB or the CVA6_TEST compilation output.")
    File cva6TestLib;

    @Option(names = {"--hazard3-test-lib"}, description = "Path to libcontract_hazard3_test_attacker.so. Defaults to CONTRACT_HAZARD3_TEST_LIB or the HAZARD3_TEST compilation output.")
    File hazard3TestLib;

    @Option(names = {"--proteus-test-lib"}, description = "Path to libcontract_proteus_test_attacker.so. Defaults to CONTRACT_PROTEUS_TEST_LIB or the PROTEUS_TEST compilation output.")
    File proteusTestLib;

    @Option(names = {"-p", "--processor"}, defaultValue = "IBEX_TEST", description = "Attacker-only RTL harness: ${COMPLETION-CANDIDATES}. Default: ${DEFAULT-VALUE}")
    ReplayAttackerHarness processor;

    @Option(names = {"--spike-isa"}, description = "Spike ISA string", defaultValue = "RV32IM_Zicclsm")
    String spikeIsa;

    @Option(names = {"--negative-signature-threshold"}, description = "Maximum attacker-negative RTL executions for one exact Spike atom signature before skipping remaining cases. Use 0 to disable negative skipping.", defaultValue = "0")
    int negativeSignatureThreshold = 0;

    @Option(names = {"--use-skipped-evidence"}, description = "Add skipped cases to the contract as copied evidence.")
    boolean useSkippedEvidence = false;

    @Option(names = {"--skip-positive-supersets"}, description = "Skip a Spike signature as attacker-positive when it is a strict superset of a previously attacker-positive signature.")
    boolean skipPositiveSupersets = false;

    @Option(names = {"--skip-negative-subsets"}, description = "Skip a Spike signature as attacker-negative when it is a strict subset of a previously attacker-negative signature.")
    boolean skipNegativeSubsets = false;

    @Option(names = {"--disable-adaptive-skipping"}, description = "Execute the attacker RTL for every testcase; disables exact-signature, threshold, and signature-relation skipping.")
    boolean disableAdaptiveSkipping = false;

    private String sourceDescription;

    @Override
    public Integer call() {
        List<TestCase> tests;
        try {
            tests = RISCVTestCaseIO.read(testcases.toPath());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return runTests(tests, testcases.getPath());
    }

    Integer runTests(List<TestCase> tests, String sourceDescription) {
        if (negativeSignatureThreshold < 0) {
            throw new IllegalArgumentException("--negative-signature-threshold must be >= 0.");
        }
        this.sourceDescription = sourceDescription;
        Set<RISCV_OBSERVATION_TYPE> allowed = RISCV_OBSERVATION_TYPE.getGroups(template);

        long start = System.currentTimeMillis();
        Path spikeLibrary = resolveSpikeLibrary();
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal = runSpikeInChunks(spikeLibrary, tests, allowed);
        long spikeTime = System.currentTimeMillis() - start;

        List<String> failures = new ArrayList<>();
        int failureCount = validateSpikeResults(tests, spikeByOrdinal, failures);
        if (failureCount > 0) {
            throw new IllegalStateException("Cannot synthesize replay contract. Invalid Spike results: "
                    + failureCount + " issue(s). First issues: " + String.join("; ", failures));
        }

        List<TestCase> ordinalTests = new ArrayList<>(tests.size());
        for (int i = 0; i < tests.size(); i++) {
            TestCase tc = tests.get(i);
            ordinalTests.add(new RISCVTestCase(tc.getProgram1(), tc.getProgram2(), tc.getMaxInstructionCount(), tc.getLikelyCTX(), i));
        }

        String attackerHarnessName = processor.name();
        long attackerResolveStart = System.currentTimeMillis();
        AttackerHarnessSetup harness = setupAttackerHarness(ordinalTests, allowed);
        long attackerResolveTime = System.currentTimeMillis() - attackerResolveStart;
        long attackerStart = System.currentTimeMillis();
        AdaptiveAttackerRunner.Result adaptiveResult = new AdaptiveAttackerRunner(
                harness.library(), attackerHarnessName, harness.clientFactory(), harness.requireFailureCutoff(),
                threads, negativeSignatureThreshold, useSkippedEvidence, skipPositiveSupersets,
                skipNegativeSubsets, disableAdaptiveSkipping)
                .run(tests, ordinalTests, spikeByOrdinal);
        long attackerTime = System.currentTimeMillis() - attackerStart;
        synthesizeAndWrite(harness.contract(), tests, adaptiveResult, failures, spikeTime,
                attackerResolveTime, attackerTime, start, attackerHarnessName);
        return 0;
    }

    private AttackerHarnessSetup setupAttackerHarness(
            List<TestCase> ordinalTests,
            Set<RISCV_OBSERVATION_TYPE> allowed
    ) {
        RISCVListTestCases testCases = new RISCVListTestCases(ordinalTests, threads);
        return switch (processor) {
            case IBEX_TEST -> createHarnessSetup(
                    new IBEXTest(new ILPUpdater(), testCases, allowed, isa, false),
                    ibexTestLib, "CONTRACT_IBEX_TEST_LIB",
                    "/home/yosys/output/ibex-test/compiled/libcontract_ibex_test_attacker.so",
                    IBEXTestAttackerClient::new, true, false);
            case CVA6_TEST -> createHarnessSetup(
                    new CVA6Test(new ILPUpdater(), testCases, allowed, isa, false),
                    cva6TestLib, "CONTRACT_CVA6_TEST_LIB",
                    "/home/yosys/output/cva6-test/compiled/libcontract_cva6_test_attacker.so",
                    CVA6TestAttackerClient::new, false, true);
            case HAZARD3_TEST -> createHarnessSetup(
                    new Hazard3Test(new ILPUpdater(), testCases, allowed, isa, false),
                    hazard3TestLib, "CONTRACT_HAZARD3_TEST_LIB",
                    "/home/yosys/output/hazard3-test/compiled/libcontract_hazard3_test_attacker.so",
                    Hazard3TestAttackerClient::new, false, false);
            case PROTEUS_TEST -> createHarnessSetup(
                    new ProteusTest(new ILPUpdater(), testCases, allowed, isa, false),
                    proteusTestLib, "CONTRACT_PROTEUS_TEST_LIB",
                    "/home/yosys/output/proteus-test/compiled/libcontract_proteus_test_attacker.so",
                    ProteusTestAttackerClient::new, true, false);
        };
    }

    private AttackerHarnessSetup createHarnessSetup(
            MARCH march,
            File explicitLibrary,
            String environmentVariable,
            String defaultLibrary,
            Function<Path, AttackerHarnessClient> clientFactory,
            boolean requireFailureCutoff,
            boolean rebuildDefault
    ) {
        Path library = explicitLibrary == null ? null : explicitLibrary.toPath();
        boolean externallyProvided = library != null;
        if (library == null) {
            String environmentPath = System.getenv(environmentVariable);
            externallyProvided = environmentPath != null && !environmentPath.isBlank();
            library = externallyProvided ? Path.of(environmentPath) : Path.of(defaultLibrary);
        }
        if (!externallyProvided && (rebuildDefault || !Files.exists(library))) {
            if (rebuildDefault) {
                System.out.println("Rebuilding " + processor + " attacker shared library from the current harness sources.");
            }
            march.compile();
        }
        if (!Files.exists(library)) {
            throw new IllegalStateException(processor + " attacker shared library not found at " + library);
        }
        return new AttackerHarnessSetup(
                (RISCVContract) march.getISA().getContract(), library, clientFactory, requireFailureCutoff);
    }

    private record AttackerHarnessSetup(
            RISCVContract contract,
            Path library,
            Function<Path, AttackerHarnessClient> clientFactory,
            boolean requireFailureCutoff
    ) {
    }

    private void synthesizeAndWrite(
            RISCVContract contract,
            List<TestCase> tests,
            AdaptiveAttackerRunner.Result adaptiveResult,
            List<String> failures,
            long spikeTime,
            long attackerResolveTime,
            long attackerTime,
            long start,
            String attackerHarnessName
    ) {
        failures.addAll(adaptiveResult.failures());

        if (adaptiveResult.stats().failureCount() > 0) {
            throw new IllegalStateException("Cannot synthesize replay contract. Invalid testcase results: "
                    + adaptiveResult.stats().failureCount() + " issue(s). First issues: " + String.join("; ", failures));
        }

        for (RISCVTestResult result : adaptiveResult.results()) {
            if (result != null) {
                contract.add(result);
            }
        }

        if (leakInstruction) {
            addInstructionLeaks(contract, tests.size() + 1);
        }
        long ilpStart = System.currentTimeMillis();
        if (!skipILP) {
            contract.update(true);
        }
        long ilpTime = System.currentTimeMillis() - ilpStart;

        long timeElapsed = System.currentTimeMillis() - start;
        System.out.println("\nGeneration time: " + timeElapsed);
        System.out.printf("Adaptive signatures: unique=%d, rtlExecuted=%d, skippedPositive=%d, skippedNegative=%d, skippedPositiveSuperset=%d, skippedNegativeSubset=%d, relationConflicts=%d, useSkippedEvidence=%s, negativeThreshold=%d, skipPositiveSupersets=%s, skipNegativeSubsets=%s, disableAdaptiveSkipping=%s%n",
                adaptiveResult.uniqueSignatures(),
                adaptiveResult.stats().executed(),
                adaptiveResult.stats().skippedPositive(),
                adaptiveResult.stats().skippedNegative(),
                adaptiveResult.stats().skippedPositiveSuperset(),
                adaptiveResult.stats().skippedNegativeSubset(),
                adaptiveResult.stats().relationConflicts(),
                useSkippedEvidence,
                negativeSignatureThreshold,
                skipPositiveSupersets,
                skipNegativeSubsets,
                disableAdaptiveSkipping);
        System.out.println(contract);
        if (txt != null) {
            try {
                StringBuilder sb = new StringBuilder();
                sb.append("Summary:\n");
                sb.append("\tGeneration Time: ").append(timeElapsed).append(" ms\n");
                sb.append("\tProcessor: ").append(attackerHarnessName).append("\n");
                sb.append("\tAtom Source: Spike\n");
                sb.append("\tISA: ").append(isa).append("\n");
                sb.append("\tTemplate: ").append(template).append("\n");
                sb.append("\tCount: ").append(tests.size()).append("\n");
                sb.append("\tThreads: ").append(threads).append("\n");
                sb.append("\tSource: ").append(sourceDescription).append("\n");
                sb.append("\tSkip ILP: ").append(skipILP).append("\n");
                sb.append("\tSpike Time: ").append(spikeTime).append(" ms\n");
                sb.append("\t").append(attackerHarnessName).append(" Library Time: ").append(attackerResolveTime).append(" ms\n");
                sb.append("\tAdaptive Attacker Time: ").append(attackerTime).append(" ms\n");
                sb.append("\tILP Time: ").append(ilpTime).append(" ms\n");
                sb.append("\tUnique Signatures: ").append(adaptiveResult.uniqueSignatures()).append("\n");
                sb.append("\tRTL Executed: ").append(adaptiveResult.stats().executed()).append("\n");
                sb.append("\tSkipped Positive Signature: ").append(adaptiveResult.stats().skippedPositive()).append("\n");
                sb.append("\tSkipped Negative Threshold: ").append(adaptiveResult.stats().skippedNegative()).append("\n");
                sb.append("\tSkipped Positive Superset: ").append(adaptiveResult.stats().skippedPositiveSuperset()).append("\n");
                sb.append("\tSkipped Negative Subset: ").append(adaptiveResult.stats().skippedNegativeSubset()).append("\n");
                sb.append("\tRelation Conflicts: ").append(adaptiveResult.stats().relationConflicts()).append("\n");
                sb.append("\tUse Skipped Evidence: ").append(useSkippedEvidence).append("\n");
                sb.append("\tNegative Signature Threshold: ").append(negativeSignatureThreshold).append("\n");
                sb.append("\tSkip Positive Supersets: ").append(skipPositiveSupersets).append("\n");
                sb.append("\tSkip Negative Subsets: ").append(skipNegativeSubsets).append("\n");
                sb.append("\tDisable Adaptive Skipping: ").append(disableAdaptiveSkipping).append("\n");
                sb.append("\n");
                sb.append(contract);
                Files.write(Path.of(txt.getPath()), sb.toString().getBytes());
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }
        try (FileWriter writer = new FileWriter(out)) {
            contract.toJSON(writer);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private int validateSpikeResults(List<TestCase> tests, Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal, List<String> failures) {
        int failureCount = 0;
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            TestCase tc = tests.get(ordinal);
            SpikeAtomClient.SpikeCaseAtoms spikeCase = spikeByOrdinal.get(ordinal);
            if (spikeCase == null) {
                failureCount++;
                addFailure(failures, tc.getIndex() + ": missing Spike result");
            } else if (spikeCase.error() != null) {
                failureCount++;
                addFailure(failures, tc.getIndex() + ": Spike error: " + spikeCase.error());
            }
        }
        return failureCount;
    }

    private Map<Integer, SpikeAtomClient.SpikeCaseAtoms> runSpikeInChunks(Path spikeLibrary, List<TestCase> tests, Set<RISCV_OBSERVATION_TYPE> allowed) {
        return new SpikeAtomParallelRunner(spikeLibrary, spikeIsa, allowed, threads).run(tests);
    }

    private Path resolveSpikeLibrary() {
        if (spikeLib != null) {
            return spikeLib.toPath();
        }
        String env = System.getenv("CONTRACT_SPIKE_LIB");
        if (env != null && !env.isBlank()) {
            return Path.of(env);
        }
        return Path.of("riscv-isa-sim/build/libcontract_spike_atom.so");
    }

    private void addInstructionLeaks(RISCVContract contract, int startIndex) {
        int index = startIndex;
        for (RISCV_TYPE type : RISCV_TYPE.values()) {
            if (isa.contains(type.getSubset())) {
                if (Set.of(RISCV_TYPE.BEQ, RISCV_TYPE.BGE, RISCV_TYPE.BLT, RISCV_TYPE.BNE, RISCV_TYPE.BGEU, RISCV_TYPE.BLTU, RISCV_TYPE.JAL, RISCV_TYPE.JALR).contains(type)) {
                    contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.NEW_PC)), Set.of(), true, index++));
                }
                switch (type.getFormat()) {
                    case RTYPE:
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS2)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT7)), Set.of(), true, index++));
                        break;
                    case ITYPE:
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                        break;
                    case STYPE, BTYPE:
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FUNCT3)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS1)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RS2)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                        break;
                    case UTYPE, JTYPE:
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.FORMAT)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.OPCODE)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.RD)), Set.of(), true, index++));
                        contract.add(new RISCVTestResult(Set.of(new RISCVObservation(type, RISCV_OBSERVATION_TYPE.IMM)), Set.of(), true, index++));
                        break;
                }
            }
        }
    }

    private void addFailure(List<String> failures, String failure) {
        if (failures.size() < MAX_FAILURE_INDICES) {
            failures.add(failure);
        }
    }

}

@Command(name = "compare_spike_rvfi_atoms", description = "Compare adapted Spike atom extraction against the old IBEX RVFI extractor.")
class CompareSpikeRvfiAtoms implements Callable<Integer> {
    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    @Option(names = {"-c", "--contract"}, required = true, description = "The contract template to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> template;

    @Option(names = {"-t"}, required = true, description = "Number of threads for the RVFI/RTL run")
    int threads;

    @Option(names = {"-e", "--testcases"}, description = "Input testcase JSON. If omitted, tests are generated from -n and -s.")
    File testcases;

    @Option(names = {"-n"}, description = "Number of test cases to generate when --testcases is omitted")
    int number;

    @Option(names = {"-s"}, description = "Seed for testcase generation when --testcases is omitted")
    Long seed;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--sp"}, description = "Only consider identical programs (same program mode)")
    boolean isSP = false;

    @Option(names = {"--reps"}, description = "Number of times to test an atom in one test case.", defaultValue = "1")
    int reps = 1;

    @Option(names = {"--bit-dist"}, description = "Use bit length distribution for immediates", defaultValue = "false")
    boolean bitDist = false;

    @Option(names = {"--random-prefix"}, description = "Add random instructions before the target atom", defaultValue = "false")
    boolean randomPrefix = false;

    @Option(names = {"--random-suffix"}, description = "Add state-isolated non-memory, non-control random instructions after the target atom", defaultValue = "false")
    boolean randomSuffix = false;

    @Option(names = {"--reset-sequence"}, description = "Insert reset sequence between repetitions", defaultValue = "false")
    boolean resetSequence = false;

    @Option(names = {"--spike-lib"}, description = "Path to libcontract_spike_atom.so. Defaults to CONTRACT_SPIKE_LIB or riscv-isa-sim/build/libcontract_spike_atom.so")
    File spikeLib;

    @Option(names = {"--spike-isa"}, description = "Spike ISA string", defaultValue = "RV32IM_Zicclsm")
    String spikeIsa;

    @Override
    public Integer call() {
        Set<RISCV_OBSERVATION_TYPE> allowed = RISCV_OBSERVATION_TYPE.getGroups(template);
        List<TestCase> tests;
        if (testcases != null) {
            try {
                tests = RISCVTestCaseIO.read(testcases.toPath());
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        } else {
            if (number <= 0 || seed == null) {
                throw new IllegalArgumentException("Either --testcases or both -n and -s must be provided.");
            }
            TestCases generated = new RISCVIterativeTests(isa, allowed, seed, threads, number, isSP, true, reps, bitDist, randomPrefix, randomSuffix, resetSequence);
            tests = RISCVTestCaseIO.collect(generated::getIterator, threads);
        }

        Path spikeLibrary = resolveSpikeLibrary();
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal = runSpikeInChunks(spikeLibrary, tests, allowed);

        List<TestCase> ordinalTests = new ArrayList<>(tests.size());
        for (int i = 0; i < tests.size(); i++) {
            TestCase tc = tests.get(i);
            ordinalTests.add(new RISCVTestCase(tc.getProgram1(), tc.getProgram2(), tc.getMaxInstructionCount(), tc.getLikelyCTX(), i));
        }

        TestCases replay = new RISCVListTestCases(ordinalTests, threads);
        Generator generator = new ParallelIverilogGenerator(
                new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), replay, allowed, isa, false, true),
                threads, false, null, true);

        Contract rvfiContract;
        long start = System.currentTimeMillis();
        try {
            rvfiContract = generator.generate();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        long elapsed = System.currentTimeMillis() - start;

        Map<Integer, TestResult> rvfiByOrdinal = rvfiContract.getTestResults().stream()
                .collect(Collectors.toMap(TestResult::getIndex, r -> r, (first, ignored) -> first));

        List<AtomComparisonCase> cases = new ArrayList<>(tests.size());
        int spikeFailed = 0;
        int mismatches = 0;
        int attackerDistinguishable = 0;
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            TestCase tc = tests.get(ordinal);
            SpikeAtomClient.SpikeCaseAtoms spikeCase = spikeByOrdinal.get(ordinal);
            TestResult rvfi = rvfiByOrdinal.get(ordinal);

            Set<RISCVObservation> spikeAtoms = spikeCase == null ? Set.of() : spikeCase.atoms();
            Set<RISCVObservation> rvfiAtoms = observations(rvfi, allowed);
            Set<RISCVObservation> onlySpike = difference(spikeAtoms, rvfiAtoms);
            Set<RISCVObservation> onlyRvfi = difference(rvfiAtoms, spikeAtoms);
            String spikeError = spikeCase == null ? "Missing Spike result" : spikeCase.error();
            boolean missingRvfi = rvfi == null;
            boolean adversaryDistinguishable = rvfi != null && rvfi.isAdversaryDistinguishable();
            boolean mismatch = spikeError != null || missingRvfi || !onlySpike.isEmpty() || !onlyRvfi.isEmpty();

            if (spikeError != null) spikeFailed++;
            if (adversaryDistinguishable) attackerDistinguishable++;
            if (mismatch) mismatches++;

            cases.add(new AtomComparisonCase(
                    tc.getIndex(),
                    mismatch,
                    adversaryDistinguishable,
                    spikeAtoms,
                    rvfiAtoms,
                    onlySpike,
                    onlyRvfi,
                    spikeError
            ));
        }

        AtomComparisonReport report = new AtomComparisonReport(
                "IBEX",
                template.stream().map(Enum::name).sorted().toList(),
                isa.stream().map(Enum::name).sorted().toList(),
                spikeIsa,
                spikeLibrary.toString(),
                new AtomComparisonSummary(tests.size(), spikeFailed, mismatches, attackerDistinguishable, elapsed),
                cases
        );

        try {
            Files.writeString(out.toPath(), new GsonBuilder().setPrettyPrinting().create().toJson(report));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        System.out.printf(
                "Compared %d cases. atomMismatches=%d, spikeFailed=%d, attackerDistinguishable=%d. Output: %s%n",
                tests.size(), mismatches, spikeFailed, attackerDistinguishable, out.getPath());
        return mismatches == 0 ? 0 : 2;
    }

    private Map<Integer, SpikeAtomClient.SpikeCaseAtoms> runSpikeInChunks(Path spikeLibrary, List<TestCase> tests, Set<RISCV_OBSERVATION_TYPE> allowed) {
        return new SpikeAtomParallelRunner(spikeLibrary, spikeIsa, allowed, threads).run(tests);
    }

    private Path resolveSpikeLibrary() {
        if (spikeLib != null) {
            return spikeLib.toPath();
        }
        String env = System.getenv("CONTRACT_SPIKE_LIB");
        if (env != null && !env.isBlank()) {
            return Path.of(env);
        }
        return Path.of("riscv-isa-sim/build/libcontract_spike_atom.so");
    }

    private static Set<RISCVObservation> observations(TestResult result, Set<RISCV_OBSERVATION_TYPE> allowed) {
        if (result == null) {
            return Set.of();
        }
        return result.getDistinguishingObservations().stream()
                .map(o -> (RISCVObservation) o)
                .filter(o -> allowed.contains(o.observation()))
                .collect(Collectors.toCollection(CompareSpikeRvfiAtoms::observationSet));
    }

    private static Set<RISCVObservation> difference(Set<RISCVObservation> left, Set<RISCVObservation> right) {
        Set<RISCVObservation> out = observationSet();
        out.addAll(left);
        out.removeAll(right);
        return out;
    }

    private static Set<RISCVObservation> observationSet() {
        return new java.util.TreeSet<>(Comparator.comparing(RISCVObservation::type).thenComparing(RISCVObservation::observation));
    }

    private record AtomComparisonReport(
            String processor,
            List<String> template,
            List<String> isa,
            String spikeIsa,
            String spikeLibrary,
            AtomComparisonSummary summary,
            List<AtomComparisonCase> cases
    ) {
    }

    private record AtomComparisonSummary(
            int total,
            int spikeFailed,
            int atomMismatches,
            int attackerDistinguishable,
            long rvfiElapsedMillis
    ) {
    }

    private record AtomComparisonCase(
            int index,
            boolean mismatch,
            boolean attackerDistinguishable,
            Set<RISCVObservation> spikeAtoms,
            Set<RISCVObservation> rvfiAtoms,
            Set<RISCVObservation> onlySpike,
            Set<RISCVObservation> onlyRvfi,
            String spikeError
    ) {
    }
}

@Command(name = "compare_ibex_test_attacker", description = "Compare attacker distinguishability labels from old IBEX and attacker-only IBEX_TEST.")
class CompareIbexTestAttacker implements Callable<Integer> {
    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    @Option(names = {"-t"}, required = true, description = "Number of simulation threads")
    int threads;

    @Option(names = {"-e", "--testcases"}, required = true, description = "Input testcase JSON")
    File testcases;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--ibex-test-lib"}, description = "Path to libcontract_ibex_test_attacker.so. Defaults to CONTRACT_IBEX_TEST_LIB or the IBEX_TEST compilation output.")
    File ibexTestLib;

    @Override
    public Integer call() {
        List<TestCase> tests;
        try {
            tests = RISCVTestCaseIO.read(testcases.toPath());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        List<TestCase> ordinalTests = new ArrayList<>(tests.size());
        for (int i = 0; i < tests.size(); i++) {
            TestCase tc = tests.get(i);
            ordinalTests.add(new RISCVTestCase(tc.getProgram1(), tc.getProgram2(), tc.getMaxInstructionCount(), tc.getLikelyCTX(), i));
        }

        IBEXTest ibexTest = new IBEXTest(new ILPUpdater(), new RISCVListTestCases(ordinalTests, threads), Set.of(), isa, false);
        IBEXTestAttackerClient ibexTestAttackerClient = new IBEXTestAttackerClient(resolveIbexTestLibrary(ibexTest));
        AttackerRun oldRun = runAttackerLabels(
                new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), new RISCVListTestCases(ordinalTests, threads), Set.of(), isa, false, true),
                ordinalTests,
                "IBEX"
        );
        AttackerRun newRun = runNativeIbexTestAttackerLabels(
                ibexTestAttackerClient,
                ordinalTests
        );

        List<AttackerComparisonCase> cases = new ArrayList<>();
        int mismatches = 0;
        int executionIssues = 0;
        int attackerDistinguishable = 0;
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            Boolean oldLabel = oldRun.labels[ordinal];
            Boolean newLabel = newRun.labels[ordinal];
            SIMULATION_RESULT oldStatus = oldRun.statuses[ordinal];
            SIMULATION_RESULT newStatus = newRun.statuses[ordinal];
            boolean executionIssue = oldLabel == null || newLabel == null;
            boolean mismatch = executionIssue || !oldLabel.equals(newLabel);
            if (executionIssue) executionIssues++;
            if (mismatch) mismatches++;
            if (Boolean.TRUE.equals(newLabel)) attackerDistinguishable++;
            if (mismatch) {
                cases.add(new AttackerComparisonCase(
                        tests.get(ordinal).getIndex(),
                        oldLabel,
                        newLabel,
                        oldStatus,
                        newStatus
                ));
            }
        }

        AttackerComparisonReport report = new AttackerComparisonReport(
                testcases.getPath(),
                isa.stream().map(Enum::name).sorted().toList(),
                new AttackerComparisonSummary(tests.size(), mismatches, executionIssues, attackerDistinguishable),
                cases
        );

        try {
            Files.writeString(out.toPath(), new GsonBuilder().setPrettyPrinting().create().toJson(report));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        System.out.printf(
                "Compared %d cases. attackerMismatches=%d, executionIssues=%d, attackerDistinguishable=%d. Output: %s%n",
                tests.size(), mismatches, executionIssues, attackerDistinguishable, out.getPath());
        return mismatches == 0 ? 0 : 2;
    }

    private AttackerRun runAttackerLabels(MARCH march, List<TestCase> tests, String name) {
        System.out.printf("Running %s attacker labels for %d cases.%n", name, tests.size());
        march.compile();
        Boolean[] labels = new Boolean[tests.size()];
        SIMULATION_RESULT[] statuses = new SIMULATION_RESULT[tests.size()];
        AtomicInteger progress = new AtomicInteger();
        List<Thread> runners = new ArrayList<>();
        for (int id = 1; id <= threads; id++) {
            int runnerId = id;
            runners.add(new Thread(() -> march.getISA().getTestCases().getIterator(runnerId - 1).forEachRemaining(testCase -> {
                march.writeTestCase(runnerId, testCase);
                SIMULATION_RESULT result = march.simulate(runnerId);
                statuses[testCase.getIndex()] = result;
                labels[testCase.getIndex()] = switch (result) {
                    case FAIL -> true;
                    case SUCCESS, FALSE_POSITIVE -> false;
                    case ERROR, TIMEOUT, UNKNOWN -> null;
                };
                int done = progress.incrementAndGet();
                if (shouldReportProgress(done, tests.size())) {
                    System.out.printf("%s progress: %d of %d.%n", name, done, tests.size());
                }
            }), name + "_Runner_" + id));
        }
        runners.forEach(Thread::start);
        runners.forEach(t -> {
            try {
                t.join();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException(e);
            }
        });
        System.out.println();
        return new AttackerRun(labels, statuses);
    }

    private record AttackerRun(Boolean[] labels, SIMULATION_RESULT[] statuses) {
    }

    private AttackerRun runNativeIbexTestAttackerLabels(IBEXTestAttackerClient client, List<TestCase> tests) {
        System.out.printf("Running IBEX_TEST shared-library attacker labels for %d cases.%n", tests.size());
        Boolean[] labels = new Boolean[tests.size()];
        SIMULATION_RESULT[] statuses = new SIMULATION_RESULT[tests.size()];
        AtomicInteger progress = new AtomicInteger();
        int chunkSize = 1000;
        for (int start = 0; start < tests.size(); start += chunkSize) {
            int end = Math.min(start + chunkSize, tests.size());
            List<IBEXTestAttackerClient.IbexAttackerCase> chunk = client.runAll(tests.subList(start, end), 10000);
            for (IBEXTestAttackerClient.IbexAttackerCase result : chunk) {
                int ordinal = start + result.ordinal();
                statuses[ordinal] = result.status();
                labels[ordinal] = switch (result.status()) {
                    case FAIL -> true;
                    case SUCCESS, FALSE_POSITIVE -> false;
                    case ERROR, TIMEOUT, UNKNOWN -> null;
                };
                int done = progress.incrementAndGet();
                if (shouldReportProgress(done, tests.size())) {
                    System.out.printf("IBEX_TEST shared-library progress: %d of %d.%n", done, tests.size());
                }
            }
        }
        System.out.println();
        return new AttackerRun(labels, statuses);
    }

    private static boolean shouldReportProgress(int done, int total) {
        if (done == total) {
            return true;
        }
        int step = Math.max(1, total / 20);
        return done % step == 0;
    }

    private Path resolveIbexTestLibrary(IBEXTest ibexTest) {
        Path library;
        boolean explicitLibrary = false;
        if (ibexTestLib != null) {
            library = ibexTestLib.toPath();
            explicitLibrary = true;
        } else {
            String env = System.getenv("CONTRACT_IBEX_TEST_LIB");
            if (env != null && !env.isBlank()) {
                library = Path.of(env);
                explicitLibrary = true;
            } else {
                library = Path.of("/home/yosys/output/ibex-test/compiled/libcontract_ibex_test_attacker.so");
            }
        }
        if (!Files.exists(library) && !explicitLibrary) {
            ibexTest.compile();
        }
        if (!Files.exists(library)) {
            throw new IllegalStateException("IBEX_TEST attacker shared library not found at " + library);
        }
        return library;
    }

    private record AttackerComparisonReport(
            String testcases,
            List<String> isa,
            AttackerComparisonSummary summary,
            List<AttackerComparisonCase> mismatches
    ) {
    }

    private record AttackerComparisonSummary(
            int total,
            int attackerMismatches,
            int executionIssues,
            int attackerDistinguishable
    ) {
    }

    private record AttackerComparisonCase(
            int index,
            Boolean oldIbexAttackerDistinguishable,
            Boolean ibexTestAttackerDistinguishable,
            SIMULATION_RESULT oldIbexStatus,
            SIMULATION_RESULT ibexTestStatus
    ) {
    }
}

@Command(name = "compare_cva6_test_attacker", description = "Compare attacker distinguishability labels from old CVA6 Verilator and attacker-only CVA6_TEST.")
class CompareCva6TestAttacker implements Callable<Integer> {
    @Option(names = {"-i", "--isa"}, required = true, description = "The ISA to use. Options: ${COMPLETION-CANDIDATES}", split = ",")
    Set<RISCV_SUBSET> isa;

    @Option(names = {"-t"}, required = true, description = "Number of simulation threads")
    int threads;

    @Option(names = {"-e", "--testcases"}, required = true, description = "Input testcase JSON")
    File testcases;

    @Option(names = {"-o", "--output"}, required = true, description = "Output path (JSON)")
    File out;

    @Option(names = {"--cva6-test-lib"}, description = "Path to libcontract_cva6_test_attacker.so. Defaults to CONTRACT_CVA6_TEST_LIB or the CVA6_TEST compilation output.")
    File cva6TestLib;

    @Override
    public Integer call() {
        List<TestCase> tests;
        try {
            tests = RISCVTestCaseIO.read(testcases.toPath());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        List<TestCase> ordinalTests = new ArrayList<>(tests.size());
        for (int i = 0; i < tests.size(); i++) {
            TestCase tc = tests.get(i);
            ordinalTests.add(new RISCVTestCase(tc.getProgram1(), tc.getProgram2(), tc.getMaxInstructionCount(), tc.getLikelyCTX(), i));
        }

        CVA6Test cva6Test = new CVA6Test(new ILPUpdater(), new RISCVListTestCases(ordinalTests, threads), Set.of(), isa, false);
        CVA6TestAttackerClient cva6TestAttackerClient = new CVA6TestAttackerClient(resolveCva6TestLibrary(cva6Test));
        AttackerRun oldRun = runLegacyCva6AttackerLabels(
                new CVA6(new ILPUpdater(), new RISCVListTestCases(ordinalTests, threads), Set.of(), isa, false, true),
                ordinalTests,
                "CVA6"
        );
        AttackerRun newRun = runNativeCva6TestAttackerLabels(
                cva6TestAttackerClient,
                ordinalTests
        );

        List<AttackerComparisonCase> cases = new ArrayList<>();
        int mismatches = 0;
        int executionIssues = 0;
        int attackerDistinguishable = 0;
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            Boolean oldLabel = oldRun.labels[ordinal];
            Boolean newLabel = newRun.labels[ordinal];
            SIMULATION_RESULT oldStatus = oldRun.statuses[ordinal];
            SIMULATION_RESULT newStatus = newRun.statuses[ordinal];
            boolean executionIssue = oldLabel == null || newLabel == null;
            boolean mismatch = executionIssue || !oldLabel.equals(newLabel);
            if (executionIssue) executionIssues++;
            if (mismatch) mismatches++;
            if (Boolean.TRUE.equals(newLabel)) attackerDistinguishable++;
            if (mismatch) {
                cases.add(new AttackerComparisonCase(
                        tests.get(ordinal).getIndex(),
                        oldLabel,
                        newLabel,
                        oldStatus,
                        newStatus
                ));
            }
        }

        AttackerComparisonReport report = new AttackerComparisonReport(
                testcases.getPath(),
                isa.stream().map(Enum::name).sorted().toList(),
                new AttackerComparisonSummary(tests.size(), mismatches, executionIssues, attackerDistinguishable),
                cases
        );

        try {
            Files.writeString(out.toPath(), new GsonBuilder().setPrettyPrinting().create().toJson(report));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        System.out.printf(
                "Compared %d cases. attackerMismatches=%d, executionIssues=%d, attackerDistinguishable=%d. Output: %s%n",
                tests.size(), mismatches, executionIssues, attackerDistinguishable, out.getPath());
        return mismatches == 0 ? 0 : 2;
    }

    private AttackerRun runLegacyCva6AttackerLabels(MARCH march, List<TestCase> tests, String name) {
        System.out.printf("Running %s attacker labels for %d cases.%n", name, tests.size());
        march.compile();
        Boolean[] labels = new Boolean[tests.size()];
        SIMULATION_RESULT[] statuses = new SIMULATION_RESULT[tests.size()];
        AtomicInteger progress = new AtomicInteger();
        List<Thread> runners = new ArrayList<>();
        for (int id = 1; id <= threads; id++) {
            int runnerId = id;
            runners.add(new Thread(() -> march.getISA().getTestCases().getIterator(runnerId - 1).forEachRemaining(testCase -> {
                march.writeTestCase(runnerId, testCase);
                SIMULATION_RESULT result = march.simulate(runnerId);
                statuses[testCase.getIndex()] = result;
                labels[testCase.getIndex()] = switch (result) {
                    case FAIL -> true;
                    case SUCCESS, FALSE_POSITIVE -> false;
                    case ERROR, TIMEOUT, UNKNOWN -> null;
                };
                int done = progress.incrementAndGet();
                if (shouldReportProgress(done, tests.size())) {
                    System.out.printf("%s progress: %d of %d.%n", name, done, tests.size());
                }
            }), name + "_Runner_" + id));
        }
        runners.forEach(Thread::start);
        runners.forEach(t -> {
            try {
                t.join();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException(e);
            }
        });

        int retried = 0;
        int retryAttempts = 0;
        for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
            if (labels[ordinal] != null) continue;

            TestCase testCase = tests.get(ordinal);
            march.writeTestCase(1, testCase);
            retried++;
            for (int attempt = 0; attempt < 5 && labels[ordinal] == null; attempt++) {
                SIMULATION_RESULT result = march.simulate(1);
                statuses[ordinal] = result;
                labels[ordinal] = switch (result) {
                    case FAIL -> true;
                    case SUCCESS, FALSE_POSITIVE -> false;
                    case ERROR, TIMEOUT, UNKNOWN -> null;
                };
                retryAttempts++;
            }
        }
        if (retried > 0) {
            System.out.printf(
                    "%s retried %d inconclusive cases serially in %d attempts.%n",
                    name,
                    retried,
                    retryAttempts
            );
        }
        System.out.println();
        return new AttackerRun(labels, statuses);
    }

    private record AttackerRun(Boolean[] labels, SIMULATION_RESULT[] statuses) {
    }

    private AttackerRun runNativeCva6TestAttackerLabels(CVA6TestAttackerClient client, List<TestCase> tests) {
        System.out.printf("Running CVA6_TEST shared-library attacker labels for %d cases.%n", tests.size());
        Boolean[] labels = new Boolean[tests.size()];
        SIMULATION_RESULT[] statuses = new SIMULATION_RESULT[tests.size()];
        AtomicInteger progress = new AtomicInteger();
        int chunkSize = 1000;
        for (int start = 0; start < tests.size(); start += chunkSize) {
            int end = Math.min(start + chunkSize, tests.size());
            List<CVA6TestAttackerClient.Cva6AttackerCase> chunk = client.runAll(tests.subList(start, end), 10000);
            for (CVA6TestAttackerClient.Cva6AttackerCase result : chunk) {
                int ordinal = start + result.ordinal();
                statuses[ordinal] = result.status();
                labels[ordinal] = switch (result.status()) {
                    case FAIL -> true;
                    case SUCCESS, FALSE_POSITIVE -> false;
                    case ERROR, TIMEOUT, UNKNOWN -> null;
                };
                int done = progress.incrementAndGet();
                if (shouldReportProgress(done, tests.size())) {
                    System.out.printf("CVA6_TEST shared-library progress: %d of %d.%n", done, tests.size());
                }
            }
        }
        System.out.println();
        return new AttackerRun(labels, statuses);
    }

    private static boolean shouldReportProgress(int done, int total) {
        if (done == total) {
            return true;
        }
        int step = Math.max(1, total / 20);
        return done % step == 0;
    }

    private Path resolveCva6TestLibrary(CVA6Test cva6Test) {
        Path library;
        boolean explicitLibrary = false;
        if (cva6TestLib != null) {
            library = cva6TestLib.toPath();
            explicitLibrary = true;
        } else {
            String env = System.getenv("CONTRACT_CVA6_TEST_LIB");
            if (env != null && !env.isBlank()) {
                library = Path.of(env);
                explicitLibrary = true;
            } else {
                library = Path.of("/home/yosys/output/cva6-test/compiled/libcontract_cva6_test_attacker.so");
            }
        }
        if (!explicitLibrary) {
            System.out.println("Rebuilding CVA6_TEST attacker shared library from the current harness sources.");
            cva6Test.compile();
        }
        if (!Files.exists(library)) {
            throw new IllegalStateException("CVA6_TEST attacker shared library not found at " + library);
        }
        return library;
    }

    private record AttackerComparisonReport(
            String testcases,
            List<String> isa,
            AttackerComparisonSummary summary,
            List<AttackerComparisonCase> mismatches
    ) {
    }

    private record AttackerComparisonSummary(
            int total,
            int attackerMismatches,
            int executionIssues,
            int attackerDistinguishable
    ) {
    }

    private record AttackerComparisonCase(
            int index,
            Boolean oldCva6AttackerDistinguishable,
            Boolean cva6TestAttackerDistinguishable,
            SIMULATION_RESULT oldCva6Status,
            SIMULATION_RESULT cva6TestStatus
    ) {
    }
}

@Command(name = "compare_contracts", description = "Compare two synthesized contracts for equivalence.")
class CompareContracts implements Callable<Integer> {
    @Option(names = {"-a", "--first"}, required = true, description = "First contract JSON")
    File first;

    @Option(names = {"-b", "--second"}, required = true, description = "Second contract JSON")
    File second;

    @Override
    public Integer call() {
        try {
            RISCVContract a = RISCVContract.fromJSON(new FileReader(first));
            RISCVContract b = RISCVContract.fromJSON(new FileReader(second));
            Set<Observation> onlyA = a.getCurrentContract().stream().filter(obs -> !b.getCurrentContract().contains(obs)).collect(Collectors.toSet());
            Set<Observation> onlyB = b.getCurrentContract().stream().filter(obs -> !a.getCurrentContract().contains(obs)).collect(Collectors.toSet());
            if (onlyA.isEmpty() && onlyB.isEmpty()) {
                System.out.println("Contracts are equivalent.");
                return 0;
            }
            System.out.println("Contracts differ.");
            System.out.println("Only in first: " + onlyA.size());
            System.out.println("Only in second: " + onlyB.size());
            return 1;
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}

@Command(name = "statistics", mixinStandardHelpOptions = true, description = "Generate learning curve statistics")
class Stats implements Callable<Integer> {

    @Option(names = {"-t", "--training"}, required = true, description = "Training set (JSON)")
    File training;

    @Option(names = {"-e", "--eval"}, required = true, description = "Evaluation set (JSON)")
    File eval;

    @Option(names = {"-o", "--output"}, required = true, description = "Output CSV")
    File out;

    @Option(names = {"-n", "--threads"}, defaultValue = "1", description = "Number of threads")
    int threads;

    @Option(names = {"-i", "--isa"}, defaultValue = "BASE", description = "ISA subsets (BASE, M)")
    String isaString;

    @Option(names = {"-c", "--contract"}, defaultValue = "BASE", description = "Contract template (BASE, ALIGNED, BRANCH, DEPENDENCIES)")
    String templateString;

    @Override
    public Integer call() {
        Set<RISCV_SUBSET> isa = Arrays.stream(isaString.split(",")).map(RISCV_SUBSET::valueOf).collect(Collectors.toSet());
        Set<RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP> groups = Arrays.stream(templateString.split(",")).map(RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP::valueOf).collect(Collectors.toSet());
        Set<RISCV_OBSERVATION_TYPE> contract_template = RISCV_OBSERVATION_TYPE.getGroups(groups);

        try {
            Statistics.genStatsParallel(training.getPath(), eval.getPath(), out.getPath(), threads, 0, contract_template, isa);
        } catch (IOException e) {
            e.printStackTrace();
            return 1;
        }
        return 0;
    }
}
