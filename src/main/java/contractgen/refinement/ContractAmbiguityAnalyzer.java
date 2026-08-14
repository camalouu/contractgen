package contractgen.refinement;

import contractgen.Observation;
import contractgen.TestResult;
import contractgen.updater.ILPUpdater;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/** Finds equal-objective contracts that are still consistent with the collected evidence. */
public final class ContractAmbiguityAnalyzer {
    private static final Comparator<Observation> OBSERVATION_ORDER = Comparator.comparing(Observation::toString);

    public Analysis analyze(
            Set<Observation> allAtoms,
            List<TestResult> results,
            Set<Observation> currentContract
    ) {
        ILPUpdater updater = new ILPUpdater();
        ILPUpdater.Solution baseline = updater.solve(allAtoms, results, currentContract, Set.of(), Set.of());
        if (!baseline.isOptimal()) {
            throw new IllegalStateException("Baseline contract optimization was not optimal: " + baseline.status());
        }

        Map<String, Alternative> unique = new LinkedHashMap<>();
        for (Observation selected : baseline.contract().stream().sorted(OBSERVATION_ORDER).toList()) {
            ILPUpdater.Solution candidate = updater.solve(
                    allAtoms,
                    results,
                    baseline.contract(),
                    Set.of(),
                    Set.of(selected)
            );
            if (!candidate.isOptimal()
                    || candidate.falsePositives() != baseline.falsePositives()
                    || candidate.size() != baseline.size()) {
                continue;
            }

            Set<Observation> removed = difference(baseline.contract(), candidate.contract());
            Set<Observation> added = difference(candidate.contract(), baseline.contract());
            if (removed.isEmpty() || added.isEmpty()) {
                continue;
            }
            String key = canonical(candidate.contract());
            unique.putIfAbsent(key, new Alternative(
                    "alternative-" + (unique.size() + 1),
                    candidate.contract(),
                    removed,
                    added,
                    coOccurrence(results, removed, added),
                    exclusiveSupport(results, baseline.contract(), removed)
            ));
        }

        List<Alternative> alternatives = new ArrayList<>(unique.values());
        alternatives.sort(Comparator
                .comparingInt((Alternative a) -> a.removed().size() + a.added().size())
                .thenComparing(Comparator.comparingInt(Alternative::exclusiveSupport).reversed())
                .thenComparing(Comparator.comparingInt(Alternative::coOccurrence).reversed())
                .thenComparing(a -> canonical(a.contract())));
        List<Alternative> numbered = new ArrayList<>(alternatives.size());
        for (int i = 0; i < alternatives.size(); i++) {
            Alternative a = alternatives.get(i);
            numbered.add(new Alternative("alternative-" + (i + 1), a.contract(), a.removed(), a.added(), a.coOccurrence(), a.exclusiveSupport()));
        }
        return new Analysis(baseline, numbered);
    }

    private static int coOccurrence(List<TestResult> results, Set<Observation> left, Set<Observation> right) {
        return (int) results.stream().filter(result ->
                result.getDistinguishingObservations().containsAll(left)
                        && result.getDistinguishingObservations().containsAll(right)).count();
    }

    private static int exclusiveSupport(List<TestResult> results, Set<Observation> baseline, Set<Observation> removed) {
        return (int) results.stream()
                .filter(TestResult::isAdversaryDistinguishable)
                .filter(result -> removed.stream().anyMatch(result.getDistinguishingObservations()::contains))
                .filter(result -> baseline.stream()
                        .filter(atom -> !removed.contains(atom))
                        .noneMatch(result.getDistinguishingObservations()::contains))
                .count();
    }

    private static Set<Observation> difference(Set<Observation> left, Set<Observation> right) {
        Set<Observation> out = new HashSet<>(left);
        out.removeAll(right);
        return Set.copyOf(out);
    }

    private static String canonical(Set<Observation> contract) {
        return contract.stream().sorted(OBSERVATION_ORDER).map(Observation::toString).collect(Collectors.joining("|"));
    }

    public record Analysis(ILPUpdater.Solution baseline, List<Alternative> alternatives) {
        public Analysis {
            alternatives = List.copyOf(alternatives);
        }
    }

    public record Alternative(
            String id,
            Set<Observation> contract,
            Set<Observation> removed,
            Set<Observation> added,
            int coOccurrence,
            int exclusiveSupport
    ) {
        public Alternative {
            contract = Set.copyOf(contract);
            removed = Set.copyOf(removed);
            added = Set.copyOf(added);
        }
    }
}
