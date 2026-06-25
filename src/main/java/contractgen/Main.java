package contractgen;

import com.google.gson.GsonBuilder;
import contractgen.generator.iverilog.Falsifier;
import contractgen.generator.iverilog.ParallelIverilogGenerator;
import contractgen.riscv.cva6.CVA6;
import contractgen.riscv.darkriscv.DARKRISCV_2;
import contractgen.riscv.darkriscv.DARKRISCV_3;
import contractgen.riscv.ibex.IBEX;
import contractgen.riscv.ibex.IBEXTest;
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
import contractgen.riscv.isa.tests.RISCVIterativeTests;
import contractgen.riscv.isa.tests.RISCVListTestCases;
import contractgen.riscv.isa.tests.RISCVTestCaseIO;
import contractgen.riscv.sodor.SODOR_2;
import contractgen.riscv.sodor.SODOR_5;
import contractgen.updater.ILPUpdater;
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
import java.util.stream.Collectors;

@Command(name = "main", subcommands = {Synthesize.class, ExportTests.class, CompactTests.class, ReplaySynthesize.class, CompareSpikeRvfiAtoms.class, CompareContracts.class, ILP.class, Analyze.class, Update.class, Evaluate.class, Falsify.class, PrintAtoms.class, UnsafeInstructions.class, Stats.class}, description = "Main application command.")
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

@Command(name = "synthesize", description = "Synthesize one contract.")
class Synthesize implements Callable<Integer> {
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

    @Option(names = {"--random-suffix"}, description = "Add random instructions after the target atom", defaultValue = "false")
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
        TestCases tc = new RISCVIterativeTests(isa, RISCV_OBSERVATION_TYPE.getGroups(template), seed, threads, number, isSP, processor != CONFIG.PROCESSOR.CVA6 || !useVerilator, reps, bitDist, randomPrefix, randomSuffix, resetSequence);
        Generator generator = new 
        ParallelIverilogGenerator(
            switch (processor) {
                case IBEX -> new IBEX(IBEX.VARIANT.BASE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                case IBEX_TEST -> new IBEXTest(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                case IBEX_CACHE -> new IBEX(IBEX.VARIANT.CACHE, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                case IBEX_SMALL -> new IBEX(IBEX.VARIANT.SMALL, new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                case CVA6 -> new CVA6(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
                case SODOR_2 -> new SODOR_2(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                case SODOR_5 -> new SODOR_5(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                case DARKRISCV_2 -> new DARKRISCV_2(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                case DARKRISCV_3 -> new DARKRISCV_3(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP);
                case HAZARD3 -> new contractgen.riscv.hazard3.HAZARD3(new ILPUpdater(), tc, RISCV_OBSERVATION_TYPE.getGroups(template), isa, isSP, useVerilator);
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

    @Option(names = {"--random-suffix"}, description = "Add random instructions after the target atom", defaultValue = "false")
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

@Command(name = "compare_spike_rvfi_atoms", description = "Compare adapted Spike atom extraction against the current IBEX_TEST RVFI extractor.")
class CompareSpikeRvfiAtoms implements Callable<Integer> {
    private static final int SPIKE_INTERNAL_CHUNK_SIZE = 1000;

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

    @Option(names = {"--random-suffix"}, description = "Add random instructions after the target atom", defaultValue = "false")
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
        SpikeAtomClient spike = new SpikeAtomClient(spikeLibrary);
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spikeByOrdinal = runSpikeInChunks(spike, tests, allowed);

        List<TestCase> ordinalTests = new ArrayList<>(tests.size());
        for (int i = 0; i < tests.size(); i++) {
            TestCase tc = tests.get(i);
            ordinalTests.add(new RISCVTestCase(tc.getProgram1(), tc.getProgram2(), tc.getMaxInstructionCount(), tc.getLikelyCTX(), i));
        }

        TestCases replay = new RISCVListTestCases(ordinalTests, threads);
        Generator generator = new ParallelIverilogGenerator(
                new IBEXTest(new ILPUpdater(), replay, allowed, isa, false),
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
                "IBEX_TEST",
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

    private Map<Integer, SpikeAtomClient.SpikeCaseAtoms> runSpikeInChunks(SpikeAtomClient spike, List<TestCase> tests, Set<RISCV_OBSERVATION_TYPE> allowed) {
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> out = new HashMap<>();
        for (int start = 0; start < tests.size(); start += SPIKE_INTERNAL_CHUNK_SIZE) {
            int end = Math.min(start + SPIKE_INTERNAL_CHUNK_SIZE, tests.size());
            String json = RISCVTestCaseIO.toJSON(tests.subList(start, end));
            List<SpikeAtomClient.SpikeCaseAtoms> chunk = spike.runAll(json, spikeIsa, allowed);
            for (SpikeAtomClient.SpikeCaseAtoms result : chunk) {
                out.put(start + result.ordinal(), new SpikeAtomClient.SpikeCaseAtoms(
                        start + result.ordinal(),
                        result.caseIndex(),
                        result.atoms(),
                        result.error()
                ));
            }
        }
        return out;
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
