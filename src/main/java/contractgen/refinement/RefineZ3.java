package contractgen.refinement;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import contractgen.Contract;
import contractgen.Observation;
import contractgen.SIMULATION_RESULT;
import contractgen.TestCase;
import contractgen.riscv.ibex.IBEXTest;
import contractgen.riscv.ibex.IBEXTestAttackerClient;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCVTestCase;
import contractgen.riscv.isa.RISCV_SUBSET;
import contractgen.riscv.isa.contract.RISCVContract;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import contractgen.riscv.isa.spike.SpikeAtomParallelRunner;
import contractgen.riscv.isa.tests.RISCVListTestCases;
import contractgen.riscv.isa.tests.RISCVTestCaseIO;
import contractgen.updater.ILPUpdater;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.TimeUnit;

/** Refines an existing result with Z3-generated ambiguity-separating evidence. */
@Command(name = "refine_z3", description = "Generate ambiguity-separating tests with Z3, validate atoms with Spike, execute Ibex RTL, and update the contract.")
public final class RefineZ3 implements Callable<Integer> {
    private static final int PROTOCOL_VERSION = 4;
    private static final int PROGRAM_LENGTH = 1;
    private static final int TRACE_LENGTH = 1;
    private static final int CODE_BASE = 0x100;
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    @Option(names = {"-r", "--results"}, required = true, description = "Input synthesis result JSON")
    File results;

    @Option(names = {"-o", "--output"}, required = true, description = "Updated result JSON")
    File output;

    @Option(names = {"-t", "--threads"}, defaultValue = "1", description = "Spike extraction worker count")
    int threads;

    @Option(names = "--artifacts", description = "Refinement artifact directory (default: <output-base>-refinement)")
    File artifacts;

    @Option(names = "--max-tests", defaultValue = "50", description = "Maximum number of Spike-validated tests executed on RTL")
    int maxTests;

    @Option(names = "--solver-timeout-ms", defaultValue = "300000", description = "Z3 timeout per ambiguity query")
    int solverTimeoutMs;

    @Option(names = "--max-cycles", defaultValue = "10000", description = "Ibex RTL cycle limit per testcase")
    int maxCycles;

    @Option(names = "--python", defaultValue = "python3", description = "Python executable")
    String python;

    @Option(names = "--generator-dir", defaultValue = "abstraction-guided-test-case-generation", description = "Vendored Z3 generator directory")
    File generatorDir;

    @Option(names = "--spike-lib", description = "Path to libcontract_spike_atom.so")
    File spikeLib;

    @Option(names = "--ibex-test-lib", description = "Path to libcontract_ibex_test_attacker.so")
    File ibexTestLib;

    @Option(names = "--spike-isa", defaultValue = "RV32IM_Zicclsm", description = "Spike ISA string")
    String spikeIsa;

    @Override
    public Integer call() throws Exception {
        validateOptions();
        Path artifactDirectory = artifacts == null ? defaultArtifactDirectory() : artifacts.toPath();
        Files.createDirectories(artifactDirectory);

        RISCVContract contract;
        try (FileReader reader = new FileReader(results)) {
            contract = RISCVContract.fromJSON(reader);
        }
        Set<RISCV_OBSERVATION_TYPE> allowed = allowedObservations(contract);

        long started = System.currentTimeMillis();
        ContractAmbiguityAnalyzer.Analysis analysis = new ContractAmbiguityAnalyzer().analyze(
                contract.getAllAtoms(), contract.getTestResults(), contract.getCurrentContract());
        writeJson(artifactDirectory.resolve("ambiguities.json"), analysis);

        List<Query> queries = buildQueries(analysis);
        Request request = new Request(
                PROTOCOL_VERSION,
                PROGRAM_LENGTH,
                TRACE_LENGTH,
                CODE_BASE,
                solverTimeoutMs,
                Math.min(maxTests, queries.size()),
                queries
        );
        Path requestPath = artifactDirectory.resolve("z3-queries.json");
        Path responsePath = artifactDirectory.resolve("z3-response.json");
        writeJson(requestPath, request);

        Response response;
        if (queries.isEmpty() || maxTests == 0) {
            response = new Response(PROTOCOL_VERSION, List.of(), List.of());
            writeJson(responsePath, response);
            Files.writeString(artifactDirectory.resolve("z3-bridge.log"), "Z3 bridge skipped: no queries or --max-tests=0.\n");
        } else {
            response = runBridge(requestPath, responsePath, artifactDirectory.resolve("z3-bridge.log"), queries.size());
        }
        if (response.protocolVersion() != PROTOCOL_VERSION) {
            throw new IllegalStateException("Unsupported Z3 bridge response version " + response.protocolVersion());
        }
        if (!response.queryResults().isEmpty()
                && response.queryResults().stream().allMatch(result -> "ERROR".equals(result.status()))) {
            throw new IllegalStateException("Every Z3 query failed; see " + responsePath);
        }

        int firstIndex = contract.getTestResults().stream().mapToInt(result -> result.getIndex()).max().orElse(-1) + 1;
        List<CandidateTest> generated = decodeCandidates(response.candidates(), firstIndex);
        List<TestCase> generatedTests = generated.stream().map(CandidateTest::test).map(test -> (TestCase) test).toList();
        RISCVTestCaseIO.write(artifactDirectory.resolve("generated-testcases.json"), generatedTests);
        writeJson(artifactDirectory.resolve("generated-candidates.json"), generated.stream()
                .map(candidate -> new CandidateManifest(candidate.test().getIndex(), provenance(candidate.candidate())))
                .toList());

        Validation validation = validateWithSpike(generated, analysis, allowed);
        List<Accepted> accepted = validation.accepted().stream().limit(maxTests).toList();
        RISCVTestCaseIO.write(
                artifactDirectory.resolve("accepted-testcases.json"),
                accepted.stream().map(Accepted::test).map(test -> (TestCase) test).toList());

        List<RtlEvidence> rtlEvidence = runIbex(accepted, allowed);
        int evidenceAdded = 0;
        for (RtlEvidence evidence : rtlEvidence) {
            if (evidence.status() != SIMULATION_RESULT.SUCCESS && evidence.status() != SIMULATION_RESULT.FAIL) {
                continue;
            }
            contract.add(new RISCVTestResult(
                    evidence.atoms(),
                    Set.of(),
                    evidence.status() == SIMULATION_RESULT.FAIL,
                    evidence.test().getIndex()));
            evidenceAdded++;
        }
        Set<Observation> before = Set.copyOf(contract.getCurrentContract());
        if (evidenceAdded > 0) {
            contract.update(true);
        }
        contract.sort();

        Path outputPath = output.toPath();
        if (outputPath.getParent() != null) {
            Files.createDirectories(outputPath.getParent());
        }
        Files.writeString(outputPath, contract.toJSON());

        Map<String, Object> report = new LinkedHashMap<>();
        report.put("input", results.getPath());
        report.put("output", output.getPath());
        report.put("baselineObjective", Map.of(
                "falsePositives", analysis.baseline().falsePositives(),
                "size", analysis.baseline().size()));
        report.put("ambiguities", analysis.alternatives().size());
        report.put("queries", queries.size());
        report.put("z3Candidates", generated.size());
        report.put("spikeAccepted", validation.accepted().size());
        report.put("spikeRejected", validation.rejected());
        report.put("rtlBudget", maxTests);
        report.put("rtlExecuted", accepted.size());
        report.put("evidenceAdded", evidenceAdded);
        report.put("rtlEvidence", rtlEvidence);
        report.put("contractBefore", before);
        report.put("contractAfter", contract.getCurrentContract());
        report.put("contractChanged", !before.equals(contract.getCurrentContract()));
        report.put("durationMs", System.currentTimeMillis() - started);
        report.put("queryResults", response.queryResults());
        writeJson(artifactDirectory.resolve("refinement-report.json"), report);
        writeSummary(artifactDirectory.resolve("summary.txt"), report, contract);

        System.out.printf("Z3 refinement complete: alternatives=%d, generated=%d, Spike accepted=%d, RTL evidence=%d, contract changed=%s%n",
                analysis.alternatives().size(), generated.size(), validation.accepted().size(), evidenceAdded,
                !before.equals(contract.getCurrentContract()));
        return 0;
    }

    private void validateOptions() {
        if (threads < 1 || maxTests < 0 || solverTimeoutMs < 1 || maxCycles < 1) {
            throw new IllegalArgumentException("threads/timeout/cycles must be positive and max-tests must be non-negative");
        }
        if (!results.isFile()) {
            throw new IllegalArgumentException("Results file does not exist: " + results);
        }
    }

    private Path defaultArtifactDirectory() {
        String name = output.getName();
        int suffix = name.toLowerCase().endsWith(".json") ? name.length() - 5 : name.length();
        String artifactName = name.substring(0, suffix) + "-refinement";
        Path parent = output.toPath().toAbsolutePath().getParent();
        return parent.resolve(artifactName);
    }

    private static Set<RISCV_OBSERVATION_TYPE> allowedObservations(RISCVContract contract) {
        Set<RISCV_OBSERVATION_TYPE> allowed = new HashSet<>();
        for (Observation atom : contract.getAllAtoms()) {
            allowed.add((RISCV_OBSERVATION_TYPE) atom.getObservation());
        }
        return Set.copyOf(allowed);
    }

    private List<Query> buildQueries(ContractAmbiguityAnalyzer.Analysis analysis) {
        List<Query> out = new ArrayList<>();
        for (ContractAmbiguityAnalyzer.Alternative alternative : analysis.alternatives()) {
            List<RISCVObservation> removed = alternative.removed().stream()
                    .map(atom -> (RISCVObservation) atom)
                    .filter(RISCVObservation::isApplicable)
                    .filter(atom -> !isStructural(atom.observation()))
                    .filter(atom -> !isDependency(atom.observation()))
                    .sorted(Comparator.comparing(RISCVObservation::type)
                            .thenComparing(RISCVObservation::observation))
                    .toList();
            List<RISCVObservation> added = alternative.added().stream()
                    .map(atom -> (RISCVObservation) atom)
                    .filter(RISCVObservation::isApplicable)
                    .filter(atom -> !isStructural(atom.observation()))
                    .filter(atom -> !isDependency(atom.observation()))
                    .sorted(Comparator.comparing(RISCVObservation::type)
                            .thenComparing(RISCVObservation::observation))
                    .toList();
            for (RISCVObservation oldAtom : removed) {
                for (RISCVObservation newAtom : added) {
                    if (oldAtom.type() != newAtom.type()) {
                        continue;
                    }
                    String id = alternative.id() + "-" + oldAtom.type().name() + "-"
                            + oldAtom.observation().name() + "-xor-" + newAtom.observation().name();
                    out.add(new Query(id, alternative.id(), oldAtom.type().name(),
                            oldAtom.observation().name(), newAtom.observation().name(), 0));
                }
            }
        }
        return out;
    }

    private static boolean isDependency(RISCV_OBSERVATION_TYPE observation) {
        return observation.name().startsWith("RAW_") || observation.name().startsWith("WAW_");
    }

    private static boolean isStructural(RISCV_OBSERVATION_TYPE observation) {
        return Set.of(
                RISCV_OBSERVATION_TYPE.FORMAT,
                RISCV_OBSERVATION_TYPE.OPCODE,
                RISCV_OBSERVATION_TYPE.FUNCT3,
                RISCV_OBSERVATION_TYPE.FUNCT7,
                RISCV_OBSERVATION_TYPE.IS_BRANCH
        ).contains(observation);
    }

    private Response runBridge(Path request, Path response, Path log, int queryCount) throws Exception {
        Path bridge = generatorDir.toPath().resolve("refinement_bridge.py");
        if (!Files.isRegularFile(bridge)) {
            throw new IllegalStateException("Z3 refinement bridge not found: " + bridge);
        }
        Process process = new ProcessBuilder(
                python,
                bridge.toAbsolutePath().toString(),
                "--request", request.toAbsolutePath().toString(),
                "--response", response.toAbsolutePath().toString())
                .directory(generatorDir)
                .redirectErrorStream(true)
                .redirectOutput(log.toFile())
                .start();
        long totalSeconds = Math.max(60L,
                (long) Math.ceil(queryCount * solverTimeoutMs / 1000.0) + 60L);
        if (!process.waitFor(totalSeconds, TimeUnit.SECONDS)) {
            process.destroyForcibly();
            throw new IllegalStateException("Z3 bridge timed out after " + Duration.ofSeconds(totalSeconds));
        }
        if (process.exitValue() != 0 || !Files.isRegularFile(response)) {
            throw new IllegalStateException("Z3 bridge failed with exit code " + process.exitValue() + "; see " + log);
        }
        return GSON.fromJson(Files.readString(response), Response.class);
    }

    private List<CandidateTest> decodeCandidates(List<Candidate> candidates, int firstIndex) {
        List<CandidateTest> out = new ArrayList<>(candidates.size());
        int index = firstIndex;
        for (Candidate candidate : candidates) {
            List<RISCVInstruction> program1 = parseProgram(candidate.program1(), candidate.queryId());
            List<RISCVInstruction> program2 = parseProgram(candidate.program2(), candidate.queryId());
            if (program1.size() != 1 || program2.size() != 1) {
                throw new IllegalArgumentException("Query " + candidate.queryId() + " did not return one target instruction per side");
            }
            if (program1.get(0).type() != program2.get(0).type()
                    || !program1.get(0).type().name().equals(candidate.targetType())) {
                throw new IllegalArgumentException("Query " + candidate.queryId() + " changed the target instruction type");
            }
            RefinementTestMaterializer.Seed seed = new RefinementTestMaterializer.Seed(
                    program1, integerRegisters(candidate.registers1()),
                    program2, integerRegisters(candidate.registers2()));
            RISCVTestCase test = RefinementTestMaterializer.materialize(seed, index++);
            out.add(new CandidateTest(candidate, test));
        }
        return out;
    }

    private static List<RISCVInstruction> parseProgram(List<String> words, String queryId) {
        List<RISCVInstruction> out = new ArrayList<>(words.size());
        for (String word : words) {
            RISCVInstruction instruction = RISCVInstruction.parseHexString(word);
            if (instruction == null) {
                throw new IllegalArgumentException("Query " + queryId + " returned invalid instruction " + word);
            }
            out.add(instruction);
        }
        return out;
    }

    private static Map<Integer, Integer> integerRegisters(Map<String, Integer> registers) {
        Map<Integer, Integer> out = new HashMap<>();
        registers.forEach((register, value) -> out.put(Integer.parseInt(register), value));
        return out;
    }

    private Validation validateWithSpike(
            List<CandidateTest> candidates,
            ContractAmbiguityAnalyzer.Analysis analysis,
            Set<RISCV_OBSERVATION_TYPE> allowed
    ) {
        if (candidates.isEmpty()) {
            return new Validation(List.of(), 0);
        }
        Path library = resolveSpikeLibrary();
        Set<RISCV_OBSERVATION_TYPE> validationObservations = EnumSet.allOf(RISCV_OBSERVATION_TYPE.class);
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> byOrdinal = new SpikeAtomParallelRunner(
                library, spikeIsa, validationObservations, threads).run(candidates.stream().map(CandidateTest::test).map(test -> (TestCase) test).toList());
        Map<String, ContractAmbiguityAnalyzer.Alternative> alternatives = new HashMap<>();
        analysis.alternatives().forEach(alternative -> alternatives.put(alternative.id(), alternative));
        List<Accepted> accepted = new ArrayList<>();
        int rejected = 0;
        for (int ordinal = 0; ordinal < candidates.size(); ordinal++) {
            CandidateTest candidate = candidates.get(ordinal);
            SpikeAtomClient.SpikeCaseAtoms spike = byOrdinal.get(ordinal);
            ContractAmbiguityAnalyzer.Alternative alternative = alternatives.get(candidate.candidate().alternativeId());
            if (spike == null || spike.error() != null || alternative == null) {
                rejected++;
                continue;
            }
            if (spike.atoms().stream().anyMatch(atom -> isStructural(atom.observation()))) {
                rejected++;
                continue;
            }
            Set<RISCVObservation> evidenceAtoms = spike.atoms().stream()
                    .filter(atom -> allowed.contains(atom.observation()))
                    .collect(java.util.stream.Collectors.toUnmodifiableSet());
            RISCVTestResult provisional = new RISCVTestResult(evidenceAtoms, Set.of(), true, candidate.test().getIndex());
            boolean baselineCovered = Contract.covers(analysis.baseline().contract(), provisional);
            boolean alternativeCovered = Contract.covers(alternative.contract(), provisional);
            if (baselineCovered == alternativeCovered) {
                rejected++;
                continue;
            }
            accepted.add(new Accepted(candidate.candidate(), candidate.test(), evidenceAtoms, baselineCovered, alternativeCovered));
        }
        return new Validation(List.copyOf(accepted), rejected);
    }

    private static CandidateProvenance provenance(Candidate candidate) {
        return new CandidateProvenance(
                candidate.queryId(), candidate.alternativeId(), candidate.targetType(),
                candidate.removedObservation(), candidate.addedObservation());
    }

    private List<RtlEvidence> runIbex(List<Accepted> accepted, Set<RISCV_OBSERVATION_TYPE> allowed) {
        if (accepted.isEmpty()) {
            return List.of();
        }
        List<TestCase> tests = accepted.stream().map(Accepted::test).map(test -> (TestCase) test).toList();
        IBEXTest ibex = new IBEXTest(
                new ILPUpdater(),
                new RISCVListTestCases(tests, threads),
                allowed,
                Set.of(RISCV_SUBSET.BASE, RISCV_SUBSET.M),
                false);
        Path library = resolveIbexLibrary(ibex);
        List<IBEXTestAttackerClient.IbexAttackerCase> results = new IBEXTestAttackerClient(library).runAll(tests, maxCycles);
        List<RtlEvidence> evidence = new ArrayList<>(results.size());
        for (IBEXTestAttackerClient.IbexAttackerCase result : results) {
            Accepted candidate = accepted.get(result.ordinal());
            evidence.add(new RtlEvidence(
                    provenance(candidate.candidate()), candidate.test(), candidate.atoms(), result.status(), result.error()));
        }
        return List.copyOf(evidence);
    }

    private Path resolveSpikeLibrary() {
        Path library = spikeLib != null ? spikeLib.toPath() : environmentOrDefault(
                "CONTRACT_SPIKE_LIB", Path.of("riscv-isa-sim/build/libcontract_spike_atom.so"));
        if (!Files.isRegularFile(library)) {
            throw new IllegalStateException("Spike atom library not found: " + library);
        }
        return library;
    }

    private Path resolveIbexLibrary(IBEXTest ibex) {
        boolean explicit = ibexTestLib != null || nonBlankEnvironment("CONTRACT_IBEX_TEST_LIB") != null;
        Path library = ibexTestLib != null ? ibexTestLib.toPath() : environmentOrDefault(
                "CONTRACT_IBEX_TEST_LIB", Path.of("/home/yosys/output/ibex-test/compiled/libcontract_ibex_test_attacker.so"));
        if (!Files.isRegularFile(library) && !explicit) {
            ibex.compile();
        }
        if (!Files.isRegularFile(library)) {
            throw new IllegalStateException("Ibex attacker library not found: " + library);
        }
        return library;
    }

    private static Path environmentOrDefault(String name, Path fallback) {
        String value = nonBlankEnvironment(name);
        return value == null ? fallback : Path.of(value);
    }

    private static String nonBlankEnvironment(String name) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? null : value;
    }

    private static void writeJson(Path output, Object value) throws IOException {
        Files.writeString(output, GSON.toJson(value) + System.lineSeparator());
    }

    private static void writeSummary(Path output, Map<String, Object> report, RISCVContract contract) throws IOException {
        String summary = "Z3 refinement\n"
                + "==============\n"
                + "Alternatives: " + report.get("ambiguities") + "\n"
                + "Queries: " + report.get("queries") + "\n"
                + "Z3 candidates: " + report.get("z3Candidates") + "\n"
                + "Spike accepted: " + report.get("spikeAccepted") + "\n"
                + "RTL evidence added: " + report.get("evidenceAdded") + "\n"
                + "Contract changed: " + report.get("contractChanged") + "\n\n"
                + contract;
        Files.writeString(output, summary);
    }

    private record Request(
            int protocolVersion,
            int programLength,
            int traceLength,
            int codeBase,
            int solverTimeoutMs,
            int maxCandidates,
            List<Query> queries
    ) {}

    private record Query(
            String id,
            String alternativeId,
            String targetType,
            String removedObservation,
            String addedObservation,
            int targetStep
    ) {}

    private record Response(int protocolVersion, List<Candidate> candidates, List<QueryResult> queryResults) {
        private Response {
            candidates = candidates == null ? List.of() : List.copyOf(candidates);
            queryResults = queryResults == null ? List.of() : List.copyOf(queryResults);
        }
    }

    private record Candidate(
            String queryId,
            String alternativeId,
            String targetType,
            String removedObservation,
            String addedObservation,
            Map<String, Integer> registers1,
            List<String> program1,
            Map<String, Integer> registers2,
            List<String> program2,
            int maxInstructionCount
    ) {}

    private record QueryResult(
            String queryId,
            String status,
            int models,
            String check,
            String reasonUnknown,
            long durationMs,
            String error
    ) {}
    private record CandidateProvenance(
            String queryId,
            String alternativeId,
            String targetType,
            String removedObservation,
            String addedObservation
    ) {}
    private record CandidateManifest(int testIndex, CandidateProvenance provenance) {}
    private record CandidateTest(Candidate candidate, RISCVTestCase test) {}
    private record Accepted(Candidate candidate, RISCVTestCase test, Set<RISCVObservation> atoms, boolean baselineCovered, boolean alternativeCovered) {}
    private record Validation(List<Accepted> accepted, int rejected) {}
    private record RtlEvidence(
            CandidateProvenance provenance,
            RISCVTestCase test,
            Set<RISCVObservation> atoms,
            SIMULATION_RESULT status,
            String error
    ) {}
}
