package contractgen.riscv;

import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.spike.SpikeAtomClient;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.function.IntPredicate;

/** Counts original Spike signatures, independently of filtered or inferred synthesis evidence. */
public final class SignatureReport {
    private SignatureReport() {}

    enum Outcome { LEAKING, NON_LEAKING, FAILURE }

    public record Entry(Set<RISCVObservation> atoms, int occurrences, int leaking, int nonLeaking,
                        int skipped, int unsupported, int failures) {
        public Entry { atoms = Set.copyOf(atoms); }
        public int executions() { return leaking + nonLeaking + failures; }
        public String result() {
            if (leaking > 0 && nonLeaking > 0) return "MIXED";
            if (leaking > 0) return "LEAKING";
            if (nonLeaking > 0) return "NON-LEAKING";
            return "UNTESTED";
        }
        private List<String> atomNames() {
            return atoms.stream().map(RISCVObservation::name).sorted().toList();
        }
    }

    static List<Entry> collect(int total, Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spike,
                               IntPredicate eligible, Outcome[] outcomes) {
        Map<Set<RISCVObservation>, int[]> groups = new HashMap<>();
        for (int ordinal = 0; ordinal < total; ordinal++) {
            Set<RISCVObservation> atoms = Set.copyOf(spike.get(ordinal).atoms());
            int[] counts = groups.computeIfAbsent(atoms, ignored -> new int[6]);
            counts[0]++;
            if (!eligible.test(ordinal)) counts[4]++;
            else if (outcomes[ordinal] == null) counts[3]++;
            else switch (outcomes[ordinal]) {
                case LEAKING -> counts[1]++;
                case NON_LEAKING -> counts[2]++;
                case FAILURE -> counts[5]++;
            }
        }
        return groups.entrySet().stream().map(group -> {
            int[] n = group.getValue();
            return new Entry(group.getKey(), n[0], n[1], n[2], n[3], n[4], n[5]);
        }).sorted(Comparator.comparingInt(Entry::occurrences).reversed()
                .thenComparing(entry -> String.join(",", entry.atomNames()))).toList();
    }

    public static void write(Path path, List<Entry> entries) throws IOException {
        try (var writer = Files.newBufferedWriter(path)) {
            long leakingSignatures = 0, nonLeakingSignatures = 0, mixedSignatures = 0, untestedSignatures = 0;
            long occurrences = 0, executions = 0, leaking = 0, nonLeaking = 0;
            long skipped = 0, unsupported = 0, failures = 0, mixedOccurrences = 0;
            for (Entry entry : entries) {
                switch (entry.result()) {
                    case "LEAKING" -> leakingSignatures++;
                    case "NON-LEAKING" -> nonLeakingSignatures++;
                    case "MIXED" -> { mixedSignatures++; mixedOccurrences += entry.occurrences(); }
                    case "UNTESTED" -> untestedSignatures++;
                }
                occurrences += entry.occurrences();
                executions += entry.executions();
                leaking += entry.leaking();
                nonLeaking += entry.nonLeaking();
                skipped += entry.skipped();
                unsupported += entry.unsupported();
                failures += entry.failures();
            }
            writer.write("Total signatures: " + entries.size() + "\n"
                    + "  Leaking only: " + leakingSignatures + "\n"
                    + "  Non-leaking only: " + nonLeakingSignatures + "\n"
                    + "  Mixed: " + mixedSignatures + "\n"
                    + "  Untested: " + untestedSignatures + "\n"
                    + "Cases in mixed signatures: " + mixedOccurrences + "\n"
                    + "Total testcases: " + occurrences + "\n"
                    + "RTL executions: " + executions + "\n"
                    + "  Leaking: " + leaking + "\n"
                    + "  Non-leaking: " + nonLeaking + "\n"
                    + "Skipped: " + skipped + "\n"
                    + "Unsupported: " + unsupported + "\n"
                    + "Failures: " + failures + "\n\n");
            int rank = 0;
            for (Entry entry : entries) {
                writer.write("Signature " + (++rank) + "\n"
                        + "Occurrences: " + entry.occurrences() + "\n"
                        + "RTL executions: " + entry.executions() + "\n"
                        + "  Leaking: " + entry.leaking() + "\n"
                        + "  Non-leaking: " + entry.nonLeaking() + "\n"
                        + "Skipped: " + entry.skipped() + "\n"
                        + "Unsupported: " + entry.unsupported() + "\n"
                        + "Failures: " + entry.failures() + "\n"
                        + "Result: " + entry.result() + "\n\nAtoms:\n");
                if (entry.atoms().isEmpty()) writer.write("  (empty)\n");
                else for (String atom : entry.atomNames()) writer.write("  " + atom + "\n");
                writer.write("\n");
            }
        }
    }
}
