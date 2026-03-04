package contractgen.riscv.isa.tests;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;
import contractgen.Observation;
import contractgen.TestCase;
import contractgen.TestResult;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCVTestCase;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCVTestResult;
import contractgen.util.Pair;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

public final class RISCVTestCaseIO {
    private RISCVTestCaseIO() {
    }

    private record SerializedTestCase(
            Map<Integer, Integer> registers1,
            List<RISCVInstruction> program1,
            Map<Integer, Integer> registers2,
            List<RISCVInstruction> program2,
            int maxInstructionCount,
            int index,
            Set<RISCVObservation> observations,
            Set<Pair<RISCV_TYPE, RISCV_TYPE>> distinguishingInstructions,
            boolean adversaryDistinguishable
    ) {
    }

    public static List<TestCase> collect(TestCasesSource source, int threadCount) {
        List<TestCase> tests = new ArrayList<>();
        for (int i = 0; i < threadCount; i++) {
            source.iterator(i).forEachRemaining(tests::add);
        }
        return tests;
    }

    public static void write(Path output, List<TestCase> tests) throws IOException {
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        List<SerializedTestCase> serialized = tests.stream().map(RISCVTestCaseIO::serialize).toList();
        Files.writeString(output, gson.toJson(serialized));
    }

    public static List<TestCase> read(Path input) throws IOException {
        Gson gson = new GsonBuilder().create();
        List<SerializedTestCase> data = gson.fromJson(
                Files.readString(input),
                new TypeToken<List<SerializedTestCase>>() {
                }.getType()
        );
        if (data == null) {
            return List.of();
        }
        List<TestCase> tests = new ArrayList<>(data.size());
        for (SerializedTestCase s : data) {
            tests.add(deserialize(s));
        }
        return tests;
    }

    public static List<TestCase> compact(List<TestCase> tests) {
        return compact(tests, Integer.MAX_VALUE);
    }

    public static List<TestCase> compact(List<TestCase> tests, int maxGroupSize) {
        if (maxGroupSize < 1) {
            throw new IllegalArgumentException("maxGroupSize must be >= 1");
        }
        // if (maxGroupSize == 1) {
        //     return new ArrayList<>(tests);
        // }
        Map<CompactionKey, List<TestCase>> groups = new LinkedHashMap<>();
        for (TestCase tc : tests) {
            RISCVTestResult result = (RISCVTestResult) tc.getLikelyCTX();
            if (result == null) {
                continue;
            }
            CompactionKey key = CompactionKey.from(result);
            groups.computeIfAbsent(key, ignored -> new ArrayList<>()).add(tc);
        }
        List<TestCase> compacted = new ArrayList<>(groups.size());
        int index = 0;
        for (Map.Entry<CompactionKey, List<TestCase>> entry : groups.entrySet()) {
            if (entry.getValue().isEmpty()) {
                continue;
            }
            List<TestCase> groupTests = entry.getValue();
            for (int start = 0; start < groupTests.size(); start += maxGroupSize) {
                int end = Math.min(start + maxGroupSize, groupTests.size());
                List<TestCase> chunk = groupTests.subList(start, end);
                List<RISCVInstruction> p1 = new ArrayList<>();
                List<RISCVInstruction> p2 = new ArrayList<>();
                Map<Integer, Integer> registers1 = new HashMap<>(((RISCVProgram) chunk.get(0).getProgram1()).getRegisters());
                Map<Integer, Integer> registers2 = new HashMap<>(((RISCVProgram) chunk.get(0).getProgram2()).getRegisters());
                for (int repetition = 0; repetition < chunk.size(); repetition++) {
                    TestCase tc = chunk.get(repetition);
                    RISCVProgram rp1 = (RISCVProgram) tc.getProgram1();
                    RISCVProgram rp2 = (RISCVProgram) tc.getProgram2();
                    if (repetition > 0) {
                        p1.addAll(resetInstructions(rp1.getRegisters()));
                        p2.addAll(resetInstructions(rp2.getRegisters()));
                    }
                    p1.addAll(rp1.getProgram());
                    p2.addAll(rp2.getProgram());
                }
                RISCVTestResult mergedResult = new RISCVTestResult(entry.getKey().observations, entry.getKey().distinguishingInstructions, entry.getKey().adversaryDistinguishable, index);
                compacted.add(new RISCVTestCase(
                        new RISCVProgram(registers1, p1),
                        new RISCVProgram(registers2, p2),
                        Math.max(p1.size(), p2.size()),
                        mergedResult,
                        index
                ));
                index++;
            }
        }
        return compacted;
    }

    public static List<TestCase> filterByIndices(List<TestCase> tests, Set<Integer> indices) {
        if (indices == null || indices.isEmpty()) {
            return List.of();
        }
        return tests.stream().filter(tc -> indices.contains(tc.getIndex())).toList();
    }

    public static Map<String, Integer> compactGroupSizes(List<TestCase> tests) {
        Map<CompactionKey, Integer> groups = new LinkedHashMap<>();
        for (TestCase tc : tests) {
            RISCVTestResult result = (RISCVTestResult) tc.getLikelyCTX();
            if (result == null) continue;
            CompactionKey key = CompactionKey.from(result);
            groups.put(key, groups.getOrDefault(key, 0) + 1);
        }
        Map<String, Integer> out = new LinkedHashMap<>();
        groups.forEach((k, v) -> out.put(k.toString(), v));
        return out;
    }

    private static List<RISCVInstruction> resetInstructions(Map<Integer, Integer> registers) {
        List<RISCVInstruction> reset = new ArrayList<>(31);
        for (int i = 1; i < 32; i++) {
            Integer value = registers.get(i);
            reset.add(RISCVInstruction.ADDI(i, 0, value == null ? 0 : value));
        }
        return reset;
    }

    private static SerializedTestCase serialize(TestCase tc) {
        RISCVProgram p1 = (RISCVProgram) tc.getProgram1();
        RISCVProgram p2 = (RISCVProgram) tc.getProgram2();
        RISCVTestResult likely = (RISCVTestResult) tc.getLikelyCTX();
        Set<RISCVObservation> observations = new HashSet<>();
        Set<Pair<RISCV_TYPE, RISCV_TYPE>> distinguishingInstructions = new HashSet<>();
        boolean adversaryDistinguishable = true;
        if (likely != null) {
            likely.getDistinguishingObservations().forEach(o -> observations.add((RISCVObservation) o));
            likely.getDistinguishingInstructions().forEach(p -> distinguishingInstructions.add(new Pair<>((RISCV_TYPE) p.left(), (RISCV_TYPE) p.right())));
            adversaryDistinguishable = likely.isAdversaryDistinguishable();
        }
        return new SerializedTestCase(
                p1.getRegisters(),
                p1.getProgram(),
                p2.getRegisters(),
                p2.getProgram(),
                tc.getMaxInstructionCount(),
                tc.getIndex(),
                observations,
                distinguishingInstructions,
                adversaryDistinguishable
        );
    }

    private static TestCase deserialize(SerializedTestCase s) {
        RISCVTestResult result = new RISCVTestResult(
                s.observations == null ? Set.of() : s.observations,
                s.distinguishingInstructions == null ? Set.of() : s.distinguishingInstructions,
                s.adversaryDistinguishable,
                s.index
        );
        return new RISCVTestCase(
                new RISCVProgram(s.registers1 == null ? new HashMap<>() : s.registers1, s.program1 == null ? List.of() : s.program1),
                new RISCVProgram(s.registers2 == null ? new HashMap<>() : s.registers2, s.program2 == null ? List.of() : s.program2),
                s.maxInstructionCount,
                result,
                s.index
        );
    }

    private record CompactionKey(
            Set<RISCVObservation> observations,
            Set<Pair<RISCV_TYPE, RISCV_TYPE>> distinguishingInstructions,
            boolean adversaryDistinguishable
    ) {
        static CompactionKey from(TestResult result) {
            Set<RISCVObservation> observations = new HashSet<>();
            for (Observation observation : result.getDistinguishingObservations()) {
                observations.add((RISCVObservation) observation);
            }
            Set<Pair<RISCV_TYPE, RISCV_TYPE>> distinguishingInstructions = new HashSet<>();
            result.getDistinguishingInstructions().forEach(p -> distinguishingInstructions.add(new Pair<>((RISCV_TYPE) p.left(), (RISCV_TYPE) p.right())));
            return new CompactionKey(observations, distinguishingInstructions, result.isAdversaryDistinguishable());
        }
    }

    public interface TestCasesSource {
        Iterator<TestCase> iterator(int idx);
    }
}
