package contractgen.riscv.isa.spike;

import contractgen.TestCase;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.tests.RISCVTestCaseIO;

import java.io.IOException;
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

    public SpikeAtomParallelRunner(Path spikeLibrary, String spikeIsa, Set<RISCV_OBSERVATION_TYPE> allowed, int threads) {
        this.spikeLibrary = spikeLibrary;
        this.spikeIsa = spikeIsa;
        this.allowed = allowed;
        this.threads = Math.max(1, threads);
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
                        storeChunkResults(results, chunk, runProcessChunk(tests, chunk));
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
        SpikeAtomClient spike = new SpikeAtomClient(spikeLibrary);
        SpikeAtomClient.SpikeCaseAtoms[] results = new SpikeAtomClient.SpikeCaseAtoms[tests.size()];
        int completed = 0;
        for (SpikeChunk chunk : chunks) {
            String json = RISCVTestCaseIO.toJSON(tests.subList(chunk.start(), chunk.end()));
            storeChunkResults(results, chunk, spike.runAll(json, spikeIsa, allowed));
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
            directory = Files.createTempDirectory("contract-spike-chunk-");
            Path input = directory.resolve("testcases.json");
            Path output = directory.resolve("atoms.json");
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
                    "--spike-isa", spikeIsa
            ));
            Process process = new ProcessBuilder(command).redirectErrorStream(true).start();
            boolean finished = process.waitFor(10, TimeUnit.MINUTES);
            String processOutput = new String(process.getInputStream().readAllBytes());
            if (!finished) {
                process.destroyForcibly();
                throw new IllegalStateException("Spike process timed out for chunk [" + chunk.start() + ", " + chunk.end() + ")");
            }
            int exit = process.exitValue();
            if (exit != 0 || !Files.exists(output)) {
                throw new IllegalStateException("Spike worker process failed with exit code " + exit + ": " + processOutput);
            }
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
                    Files.deleteIfExists(directory);
                } catch (IOException ignored) {
                }
            }
        }
    }

    private static void storeChunkResults(SpikeAtomClient.SpikeCaseAtoms[] results, SpikeChunk chunk, List<SpikeAtomClient.SpikeCaseAtoms> chunkResults) {
        for (SpikeAtomClient.SpikeCaseAtoms result : chunkResults) {
            int ordinal = chunk.start() + result.ordinal();
            if (ordinal < chunk.start() || ordinal >= chunk.end()) {
                throw new IllegalStateException("Spike returned out-of-range ordinal " + result.ordinal()
                        + " for chunk [" + chunk.start() + ", " + chunk.end() + ")");
            }
            results[ordinal] = new SpikeAtomClient.SpikeCaseAtoms(
                    ordinal,
                    result.caseIndex(),
                    result.atoms(),
                    result.firstRetire(),
                    result.instructionPairs(),
                    result.pairFirstRetire(),
                    result.error()
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
