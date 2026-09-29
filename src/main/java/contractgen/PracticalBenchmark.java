package contractgen;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.ptr.IntByReference;
import com.google.gson.Gson;
import contractgen.riscv.ibex.IBEXTestAttackerClient;
import contractgen.riscv.cva6_test.CVA6TestAttackerClient;
import contractgen.riscv.AttackerProgramImages;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.extractor.RVFIExtractor;
import contractgen.riscv.isa.tests.RISCVIterativeTests;
import contractgen.riscv.isa.tests.RISCVTestCaseIO;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import contractgen.riscv.isa.spike.SpikeAtomParallelRunner;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.Callable;

/** Benchmarks transport with identical generated Verilator models and testcases. */
@Command(name = "practical_benchmark", mixinStandardHelpOptions = true,
        subcommands = {PracticalBenchmark.Generate.class, PracticalBenchmark.Transport.class,
                PracticalBenchmark.Trace.class, PracticalBenchmark.Spike.class,
                PracticalBenchmark.SpikeWorkers.class,
                PracticalBenchmark.Workers.class})
public final class PracticalBenchmark implements Callable<Integer> {
    @Override public Integer call() { return 0; }

    @Command(name = "generate", mixinStandardHelpOptions = true)
    static final class Generate implements Callable<Integer> {
        @Option(names = "--count", required = true) int count;
        @Option(names = "--seed", required = true) long seed;
        @Option(names = "--output", required = true) Path output;
        @Override public Integer call() throws IOException {
            if (count < 1) throw new IllegalArgumentException("count must be positive");
            var template = RISCV_OBSERVATION_TYPE.getGroups(Set.of(
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BASE,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.ALIGNED,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BRANCH,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.DEPENDENCIES,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.VALUE));
            var generated = new RISCVIterativeTests(Set.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                    template, seed, 1, count, false, false, 1, false, false, false, false);
            RISCVTestCaseIO.write(output, RISCVTestCaseIO.collect(generated::getIterator, 1));
            return 0;
        }
    }

    @Command(name = "spike", mixinStandardHelpOptions = true)
    static final class Spike implements Callable<Integer> {
        @Option(names = "--testcases", required = true) Path testcases;
        @Option(names = "--library", required = true) Path library;
        @Option(names = "--output", required = true) Path output;
        @Option(names = "--limit", defaultValue = "32") int limit;
        @Option(names = "--isa", defaultValue = "RV32IM_Zicclsm") String isa;

        @Override public Integer call() throws Exception {
            if (limit < 1) throw new IllegalArgumentException("limit must be positive");
            var tests = RISCVTestCaseIO.read(testcases);
            tests = tests.subList(0, Math.min(limit, tests.size()));
            var allowed = RISCV_OBSERVATION_TYPE.getGroups(Set.of(
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BASE,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.ALIGNED,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BRANCH,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.DEPENDENCIES,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.VALUE));
            String encoded = RISCVTestCaseIO.toJSON(tests);
            var client = new SpikeAtomClient(library);
            long start = System.nanoTime();
            String response = client.runAllJson(encoded, isa);
            long nativeNs = System.nanoTime() - start;
            start = System.nanoTime();
            var cases = SpikeAtomClient.parseResponse(response, allowed);
            long parseNs = System.nanoTime() - start;
            if (cases.size() != tests.size())
                throw new IllegalStateException("Spike returned " + cases.size() + " cases for " + tests.size());
            var rows = new ArrayList<java.util.Map<String, Object>>();
            for (var result : cases) {
                if (result.error() != null) throw new IllegalStateException("Spike case " + result.ordinal() + ": " + result.error());
                rows.add(java.util.Map.of("ordinal", result.ordinal(), "caseIndex", result.caseIndex(),
                        "atoms", result.atoms().stream().map(Object::toString).sorted().toList(),
                        "instructionPairs", result.instructionPairs().stream().map(Object::toString).sorted().toList(),
                        "firstRetire", result.firstRetire().entrySet().stream()
                                .collect(java.util.stream.Collectors.toMap(e -> e.getKey().toString(),
                                        java.util.Map.Entry::getValue)),
                        "pairFirstRetire", result.pairFirstRetire().entrySet().stream()
                                .collect(java.util.stream.Collectors.toMap(e -> e.getKey().toString(),
                                        java.util.Map.Entry::getValue))));
            }
            Files.writeString(output, new Gson().toJson(java.util.Map.of("cases", rows,
                    "nativeNs", nativeNs, "parseNs", parseNs, "inputBytes", encoded.length(),
                    "outputBytes", response.length(), "isa", isa)) + "\n");
            System.out.printf("SPIKE_NATIVE_NS=%d SPIKE_PARSE_NS=%d CASES=%d%n", nativeNs, parseNs, cases.size());
            return 0;
        }
    }

    @Command(name = "spike_workers", mixinStandardHelpOptions = true)
    static final class SpikeWorkers implements Callable<Integer> {
        @Option(names = "--testcases", required = true) Path testcases;
        @Option(names = "--library", required = true) Path library;
        @Option(names = "--output", required = true) Path output;
        @Option(names = "--work-dir", required = true) Path workDir;
        @Option(names = "--limit", defaultValue = "1024") int limit;
        @Option(names = "--workers", defaultValue = "1") int workers;
        @Option(names = "--isa", defaultValue = "RV32IM_Zicclsm") String isa;

        @Override public Integer call() throws Exception {
            if (limit < 1 || workers < 1) throw new IllegalArgumentException("limit and workers must be positive");
            var tests = RISCVTestCaseIO.read(testcases);
            tests = tests.subList(0, Math.min(limit, tests.size()));
            var allowed = RISCV_OBSERVATION_TYPE.getGroups(Set.of(
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BASE,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.ALIGNED,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BRANCH,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.DEPENDENCIES,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.VALUE));
            long start = System.nanoTime();
            var results = new SpikeAtomParallelRunner(library, isa, allowed, workers, workDir).run(tests);
            long elapsed = System.nanoTime() - start;
            if (results.size() != tests.size()) throw new IllegalStateException("Missing Spike results");
            var rows = new ArrayList<java.util.Map<String, Object>>();
            for (int ordinal = 0; ordinal < tests.size(); ordinal++) {
                var result = results.get(ordinal);
                if (result.error() != null) throw new IllegalStateException("Spike case " + ordinal + ": " + result.error());
                rows.add(java.util.Map.of("ordinal", ordinal, "caseIndex", result.caseIndex(),
                        "atoms", result.atoms().stream().map(Object::toString).sorted().toList(),
                        "instructionPairs", result.instructionPairs().stream().map(Object::toString).sorted().toList()));
            }
            Files.writeString(output, new Gson().toJson(java.util.Map.of(
                    "workers", workers, "elapsedNs", elapsed, "cases", rows)) + "\n");
            System.out.printf("SPIKE_WORKERS_NS=%d CASES=%d%n", elapsed, rows.size());
            return 0;
        }
    }

    private interface IbexLibrary extends Library {
        int contract_ibex_test_attacker_file_v1(String directory, int maxCycles,
                IntByReference status, IntByReference failureCutoff, IntByReference executionCutoff);
        int contract_ibex_test_attacker_batch_v4(int count, int maxCycles, int[] indices,
                int[] bounds, int[] program1, int[] program2, int[] statuses,
                int[] failureCutoffs, int[] executionCutoffs);
    }

    private interface Cva6Library extends Library {
        int contract_cva6_test_attacker_file_v1(String directory, int maxCycles,
                IntByReference status);
        int contract_cva6_test_attacker_batch(int count, int maxCycles, int[] indices,
                int[] bounds, int[] program1, int[] program2, int[] statuses);
    }

    @Command(name = "trace", mixinStandardHelpOptions = true)
    static final class Trace implements Callable<Integer> {
        @Option(names = "--directory", required = true) Path directory;
        @Option(names = "--index", required = true) int index;
        @Option(names = "--attacker-label", required = true) boolean attackerLabel;

        @Override public Integer call() {
            var allowed = RISCV_OBSERVATION_TYPE.getGroups(Set.of(
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BASE,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.ALIGNED,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.BRANCH,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.DEPENDENCIES,
                    RISCV_OBSERVATION_TYPE.RISCV_OBSERVATION_TYPE_GROUP.VALUE));
            long start = System.nanoTime();
            var result = new RVFIExtractor(allowed, false)
                    .extractResults(directory.toString(), attackerLabel, index);
            long extractNs = System.nanoTime() - start;
            var atoms = result.getDistinguishingObservations().stream()
                    .map(Object::toString).sorted().toList();
            var pairs = result.getDistinguishingInstructions().stream()
                    .map(Object::toString).sorted().toList();
            System.out.println(new Gson().toJson(java.util.Map.of("atoms", atoms,
                    "instructionPairs", pairs, "attackerLabel", attackerLabel, "index", index,
                    "extractNs", extractNs)));
            return 0;
        }
    }

    @Command(name = "workers", mixinStandardHelpOptions = true)
    static final class Workers implements Callable<Integer> {
        @Option(names = "--core", required = true) Transport.Core core;
        @Option(names = "--testcases", required = true) Path testcases;
        @Option(names = "--library", required = true) Path library;
        @Option(names = "--output", required = true) Path output;
        @Option(names = "--limit", defaultValue = "1024") int limit;
        @Option(names = "--workers", defaultValue = "1") int workers;
        @Option(names = "--batch-size", defaultValue = "1") int batchSize;

        @Override public Integer call() throws Exception {
            if (limit < 1 || workers < 1 || batchSize < 1)
                throw new IllegalArgumentException("limit, workers and batch-size must be positive");
            var allTests = RISCVTestCaseIO.read(testcases);
            var tests = allTests.subList(0, Math.min(limit, allTests.size()));
            var ibex = core == Transport.Core.ibex ? new IBEXTestAttackerClient(library) : null;
            var cva6 = core == Transport.Core.cva6 ? new CVA6TestAttackerClient(library) : null;
            var pool = java.util.concurrent.Executors.newFixedThreadPool(workers);
            var futures = new ArrayList<java.util.concurrent.Future<List<String>>>();
            long start = System.nanoTime();
            try {
                for (int from = 0; from < tests.size(); from += batchSize) {
                    var chunk = List.copyOf(tests.subList(from, Math.min(from + batchSize, tests.size())));
                    futures.add(pool.submit(() -> {
                        var rows = new ArrayList<String>();
                        if (ibex != null) {
                            for (var result : ibex.runAll(chunk, 10000)) {
                                rows.add(result.caseIndex() + "," + result.status() + ","
                                        + result.failureCutoff() + "," + result.executionCutoff());
                            }
                        } else {
                            for (var result : cva6.runAll(chunk, 10000)) {
                                rows.add(result.caseIndex() + "," + result.status() + ",null,null");
                            }
                        }
                        return rows;
                    }));
                }
                try (var writer = Files.newBufferedWriter(output)) {
                    writer.write("case_index,status,failure_cutoff,execution_cutoff\n");
                    for (var future : futures) {
                        for (String row : future.get()) writer.write(row + "\n");
                    }
                }
            } finally {
                pool.shutdownNow();
            }
            System.out.printf("BENCHMARK_TOTAL_NS=%d%n", System.nanoTime() - start);
            return 0;
        }
    }

    @Command(name = "transport", mixinStandardHelpOptions = true)
    static final class Transport implements Callable<Integer> {
        enum Core { ibex, cva6 }
        enum Mode { process_file, library_file, library_arrays }
        @Option(names = "--core", required = true) Core core;
        @Option(names = "--mode", required = true) Mode mode;
        @Option(names = "--testcases", required = true) Path testcases;
        @Option(names = "--library", required = true) Path library;
        @Option(names = "--process-driver") Path processDriver;
        @Option(names = "--work-dir", required = true) Path workDir;
        @Option(names = "--output", required = true) Path output;
        @Option(names = "--limit", defaultValue = "32") int limit;
        @Option(names = "--batch-size", defaultValue = "1") int batchSize;
        @Option(names = "--max-cycles", defaultValue = "10000") int maxCycles;

        @Override public Integer call() throws Exception {
            if (limit < 1 || batchSize < 1 || maxCycles < 1)
                throw new IllegalArgumentException("limit, batch-size and max-cycles must be positive");
            if (mode == Mode.process_file && (processDriver == null || !Files.isExecutable(processDriver)))
                throw new IllegalArgumentException("process_file needs an executable --process-driver");
            if (mode != Mode.library_arrays && batchSize != 1)
                throw new IllegalArgumentException("file modes need batch-size 1");
            List<TestCase> tests = RISCVTestCaseIO.read(testcases);
            tests = tests.subList(0, Math.min(limit, tests.size()));
            Files.createDirectories(workDir);
            IbexLibrary ibex = mode == Mode.process_file || core != Core.ibex ? null
                    : Native.load(library.toAbsolutePath().toString(), IbexLibrary.class);
            Cva6Library cva6 = mode == Mode.process_file || core != Core.cva6 ? null
                    : Native.load(library.toAbsolutePath().toString(), Cva6Library.class);
            try (BufferedWriter out = Files.newBufferedWriter(output)) {
                out.write("ordinal,case_index,status,failure_cutoff,execution_cutoff,elapsed_ns,mode,batch_size\n");
                for (int start = 0; start < tests.size(); start += batchSize) {
                    List<TestCase> group = tests.subList(start, Math.min(start + batchSize, tests.size()));
                    long before = System.nanoTime();
                    int[] statuses = new int[group.size()];
                    int[] failures = new int[group.size()];
                    int[] executions = new int[group.size()];
                    java.util.Arrays.fill(failures, -1);
                    java.util.Arrays.fill(executions, -1);
                    if (mode == Mode.library_arrays) {
                        var encoded = AttackerProgramImages.encode(group, core.name());
                        int rc = core == Core.ibex
                                ? ibex.contract_ibex_test_attacker_batch_v4(group.size(), maxCycles,
                                    encoded.caseIndices(), encoded.maxInstructionCounts(), encoded.program1(),
                                    encoded.program2(), statuses, failures, executions)
                                : cva6.contract_cva6_test_attacker_batch(group.size(), maxCycles,
                                    encoded.caseIndices(), encoded.maxInstructionCounts(), encoded.program1(),
                                    encoded.program2(), statuses);
                        if (rc != 0) throw new IllegalStateException("native batch failed at " + start);
                    } else {
                        Path directory = workDir.resolve("case-" + start);
                        Files.createDirectories(directory);
                        writeFiles(group.get(0), directory);
                        if (mode == Mode.library_file) {
                            var status = new IntByReference();
                            var failure = new IntByReference(-1);
                            var execution = new IntByReference(-1);
                            int rc = core == Core.ibex
                                    ? ibex.contract_ibex_test_attacker_file_v1(directory.toString(), maxCycles,
                                        status, failure, execution)
                                    : cva6.contract_cva6_test_attacker_file_v1(directory.toString(), maxCycles, status);
                            if (rc != 0) throw new IllegalStateException("native file call failed at " + start);
                            statuses[0] = status.getValue();
                            failures[0] = failure.getValue();
                            executions[0] = execution.getValue();
                        } else {
                            var process = new ProcessBuilder(processDriver.toString(), core.name(),
                                    library.toString(), directory.toString(), Integer.toString(maxCycles))
                                    .redirectErrorStream(true).start();
                            boolean done = process.waitFor(Duration.ofMinutes(3).toMillis(),
                                    java.util.concurrent.TimeUnit.MILLISECONDS);
                            if (!done) { process.destroyForcibly(); throw new IllegalStateException("driver timeout at " + start); }
                            String response = new String(process.getInputStream().readAllBytes()).trim();
                            if (process.exitValue() != 0) throw new IllegalStateException("driver: " + response);
                            String[] values = response.split(",");
                            if (values.length != 3) throw new IllegalStateException("bad driver response: " + response);
                            statuses[0] = Integer.parseInt(values[0]);
                            failures[0] = Integer.parseInt(values[1]);
                            executions[0] = Integer.parseInt(values[2]);
                        }
                    }
                    long elapsed = System.nanoTime() - before;
                    for (int i = 0; i < group.size(); i++) {
                        out.write((start+i) + "," + group.get(i).getIndex() + "," + statuses[i] + ","
                                + failures[i] + "," + executions[i] + "," + elapsed / group.size()
                                + "," + mode + "," + group.size() + "\n");
                    }
                    out.flush();
                }
            }
            return 0;
        }

        private static void writeFiles(TestCase test, Path directory) throws IOException {
            ((RISCVProgram) test.getProgram1()).printInit(directory.resolve("init_1.dat").toString());
            ((RISCVProgram) test.getProgram1()).printInstr(directory.resolve("memory_1.dat").toString());
            ((RISCVProgram) test.getProgram2()).printInit(directory.resolve("init_2.dat").toString());
            ((RISCVProgram) test.getProgram2()).printInstr(directory.resolve("memory_2.dat").toString());
            Files.writeString(directory.resolve("count.dat"),
                    Integer.toHexString(test.getMaxInstructionCount() + 31) + "\n");
        }
    }
}
