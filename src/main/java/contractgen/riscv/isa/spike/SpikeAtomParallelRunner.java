package contractgen.riscv.isa.spike;

import contractgen.TestCase;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.tests.RISCVTestCaseIO;

import java.io.IOException;
import java.nio.channels.FileChannel;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

public final class SpikeAtomParallelRunner {
    private static final int MAX_CHUNK_SIZE = 1000;
    private static final int MIN_CHUNK_SIZE = 100;

    private final Path spikeLibrary;
    private final String spikeIsa;
    private final Set<RISCV_OBSERVATION_TYPE> allowed;
    private final int threads;
    private final Path temporaryRoot;
    private final ExecutionModel executionModel;

    public SpikeAtomParallelRunner(Path spikeLibrary, String spikeIsa, Set<RISCV_OBSERVATION_TYPE> allowed, int threads) {
        this(spikeLibrary, spikeIsa, allowed, threads, null);
    }

    public SpikeAtomParallelRunner(Path spikeLibrary, String spikeIsa, Set<RISCV_OBSERVATION_TYPE> allowed,
                                   int threads, Path temporaryRoot) {
        this(spikeLibrary, spikeIsa, allowed, threads, temporaryRoot, ExecutionModel.RV32_V1);
    }

    public SpikeAtomParallelRunner(Path spikeLibrary, String spikeIsa, Set<RISCV_OBSERVATION_TYPE> allowed,
                                   int threads, Path temporaryRoot, ExecutionModel executionModel) {
        this.executionModel = java.util.Objects.requireNonNull(executionModel);
        this.spikeLibrary = spikeLibrary;
        this.spikeIsa = spikeIsa;
        this.allowed = allowed;
        this.threads = Math.max(1, threads);
        this.temporaryRoot = temporaryRoot;
    }

    public Map<Integer, SpikeAtomClient.SpikeCaseAtoms> run(List<TestCase> tests) {
        int chunkSize = chunkSize(tests.size());
        List<SpikeChunk> chunks = chunks(tests.size(), chunkSize);
        if (threads == 1) {
            return runSequential(tests, chunks);
        }

        SpikeAtomClient.SpikeCaseAtoms[] results = new SpikeAtomClient.SpikeCaseAtoms[tests.size()];
        AtomicInteger cursor = new AtomicInteger();
        AtomicInteger completed = new AtomicInteger();
        AtomicReference<RuntimeException> failure = new AtomicReference<>();
        List<Thread> runners = new ArrayList<>();
        System.out.printf("Running Spike atom extraction for %d cases across %d JVM process chunk(s) with %d worker(s).%n", tests.size(), chunks.size(), threads);
        for (int id = 1; id <= threads; id++) {
            runners.add(new Thread(() -> {
                int chunkIndex;
                while (failure.get() == null && (chunkIndex = cursor.getAndIncrement()) < chunks.size()) {
                    SpikeChunk chunk = chunks.get(chunkIndex);
                    try {
                        storeChunkResults(results, tests, chunk, runProcessChunk(tests, chunk));
                    } catch (RuntimeException e) {
                        failure.compareAndSet(null, e);
                    }
                    int done = completed.incrementAndGet();
                    if (shouldReportProgress(done, chunks.size())) {
                        System.out.printf("Spike progress: %d of %d chunks.%n", done, chunks.size());
                    }
                }
            }, "Spike_Atom_Runner_" + id));
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
        if (failure.get() != null) {
            throw new IllegalStateException("Spike atom extraction failed", failure.get());
        }
        return toMap(results);
    }

    private Map<Integer, SpikeAtomClient.SpikeCaseAtoms> runSequential(List<TestCase> tests, List<SpikeChunk> chunks) {
        System.out.printf("Running Spike atom extraction for %d cases across %d chunk(s) with the shared library.%n", tests.size(), chunks.size());
        SpikeAtomClient spike = new SpikeAtomClient(spikeLibrary, executionModel);
        SpikeAtomClient.SpikeCaseAtoms[] results = new SpikeAtomClient.SpikeCaseAtoms[tests.size()];
        int completed = 0;
        for (SpikeChunk chunk : chunks) {
            String json = RISCVTestCaseIO.toJSON(tests.subList(chunk.start(), chunk.end()));
            storeChunkResults(results, tests, chunk, spike.runAll(json, spikeIsa, allowed));
            completed++;
            if (shouldReportProgress(completed, chunks.size())) {
                System.out.printf("Spike progress: %d of %d chunks.%n", completed, chunks.size());
            }
        }
        return toMap(results);
    }

    private List<SpikeAtomClient.SpikeCaseAtoms> runProcessChunk(List<TestCase> tests, SpikeChunk chunk) {
        Path directory = null;
        try {
            if (temporaryRoot != null) Files.createDirectories(temporaryRoot);
            directory = temporaryRoot == null
                    ? Files.createTempDirectory("contract-spike-chunk-")
                    : Files.createTempDirectory(temporaryRoot, "contract-spike-chunk-");
            Path input = directory.resolve("testcases.json");
            Path output = directory.resolve("atoms.json");
            Path log = directory.resolve("worker.log");
            Files.writeString(input, RISCVTestCaseIO.toJSON(tests.subList(chunk.start(), chunk.end())));
            List<String> command = new ArrayList<>();
            command.add(javaExecutable());
            for (String property : List.of("jna.boot.library.path", "jna.library.path", "java.library.path")) {
                String value = System.getProperty(property);
                if (value != null) command.add("-D" + property + "=" + value);
            }
            command.addAll(List.of(
                    "-cp", System.getProperty("java.class.path"),
                    "contractgen.Main",
                    "spike_atoms_worker",
                    "--testcases", input.toString(),
                    "--output", output.toString(),
                    "--spike-lib", spikeLibrary.toString(),
                    "--spike-isa", spikeIsa,
                    "--execution-model", executionModel.toString()
            ));
            runWorker(command, log, 10, TimeUnit.MINUTES);
            if (!Files.exists(output))
                throw new IllegalStateException("Spike worker did not produce output: " + logTail(log));
            return SpikeAtomClient.parseResponse(Files.readString(output), allowed);
        } catch (IOException e) {
            throw new RuntimeException(e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException(e);
        } finally {
            if (directory != null) {
                try {
                    Files.deleteIfExists(directory.resolve("testcases.json"));
                    Files.deleteIfExists(directory.resolve("atoms.json"));
                    Files.deleteIfExists(directory.resolve("worker.log"));
                    Files.deleteIfExists(directory);
                } catch (IOException ignored) {
                }
            }
        }
    }

    // Redirect to a file before waiting: a full stdout pipe can otherwise prevent
    // exit, and reading a live worker's pipe after a timeout can block forever.
    static void runWorker(List<String> command, Path log, long timeout, TimeUnit unit)
            throws IOException, InterruptedException {
        Process process = new ProcessBuilder(command).redirectErrorStream(true).redirectOutput(log.toFile()).start();
        try {
            if (!process.waitFor(timeout, unit))
                throw new IllegalStateException("Spike worker process timed out: " + logTail(log));
            if (process.exitValue() != 0)
                throw new IllegalStateException("Spike worker process failed with exit code "
                        + process.exitValue() + ": " + logTail(log));
        } finally {
            if (process.isAlive()) {
                process.destroyForcibly();
                process.waitFor(5, TimeUnit.SECONDS);
            }
        }
    }

    private static String logTail(Path log) throws IOException {
        try (FileChannel channel = FileChannel.open(log)) {
            int size = (int) Math.min(channel.size(), 8192);
            channel.position(channel.size() - size);
            ByteBuffer buffer = ByteBuffer.allocate(size);
            while (buffer.hasRemaining() && channel.read(buffer) > 0) { }
            return new String(buffer.array(), 0, buffer.position(), StandardCharsets.UTF_8);
        }
    }

    private static void storeChunkResults(SpikeAtomClient.SpikeCaseAtoms[] results, List<TestCase> tests,
                                          SpikeChunk chunk, List<SpikeAtomClient.SpikeCaseAtoms> chunkResults) {
        if (chunkResults.size() != chunk.end() - chunk.start())
            throw new IllegalStateException("Spike returned an incomplete chunk [" + chunk.start() + ", " + chunk.end() + ")");
        for (SpikeAtomClient.SpikeCaseAtoms result : chunkResults) {
            if (result.ordinal() < 0 || result.ordinal() >= chunk.end() - chunk.start()) {
                throw new IllegalStateException("Spike returned out-of-range ordinal " + result.ordinal()
                        + " for chunk [" + chunk.start() + ", " + chunk.end() + ")");
            }
            int ordinal = chunk.start() + result.ordinal();
            if (results[ordinal] != null)
                throw new IllegalStateException("Spike returned duplicate ordinal " + result.ordinal());
            if (result.caseIndex() != tests.get(ordinal).getIndex())
                throw new IllegalStateException("Spike returned mismatched case index for ordinal " + ordinal);
            results[ordinal] = new SpikeAtomClient.SpikeCaseAtoms(
                    ordinal,
                    result.caseIndex(),
                    result.atoms(),
                    result.firstRetire(),
                    result.instructionPairs(),
                    result.pairFirstRetire(),
                    result.error(),
                    result.requiresMisalignedDataAccess()
            );
        }
    }

    private static Map<Integer, SpikeAtomClient.SpikeCaseAtoms> toMap(SpikeAtomClient.SpikeCaseAtoms[] results) {
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> out = new HashMap<>();
        for (int ordinal = 0; ordinal < results.length; ordinal++) {
            if (results[ordinal] != null) {
                out.put(ordinal, results[ordinal]);
            }
        }
        return out;
    }

    private int chunkSize(int total) {
        if (total <= 0) {
            return MAX_CHUNK_SIZE;
        }
        int target = (total + threads * 4 - 1) / (threads * 4);
        return Math.max(MIN_CHUNK_SIZE, Math.min(MAX_CHUNK_SIZE, target));
    }

    private static List<SpikeChunk> chunks(int total, int chunkSize) {
        List<SpikeChunk> chunks = new ArrayList<>();
        for (int start = 0; start < total; start += chunkSize) {
            chunks.add(new SpikeChunk(start, Math.min(start + chunkSize, total)));
        }
        return chunks;
    }

    private static boolean shouldReportProgress(int done, int total) {
        if (done == total) {
            return true;
        }
        int step = Math.max(1, total / 20);
        return done % step == 0;
    }

    private static String javaExecutable() {
        return Path.of(System.getProperty("java.home"), "bin", "java").toString();
    }

    private record SpikeChunk(int start, int end) {
    }
}
