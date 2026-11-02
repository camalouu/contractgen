package contractgen.updater;

import contractgen.Observation;
import contractgen.TestResult;
import contractgen.Type;
import contractgen.util.Pair;
import java.util.*;

/** Explicit rewrite-style explanations lowered from the unchanged Spike/TestResult format. */
record ExplanationTerms(Set<Observation> stronglyDistinguishing, Set<Xor> xorDistinguishing) {
    ExplanationTerms {
        stronglyDistinguishing = Set.copyOf(stronglyDistinguishing);
        xorDistinguishing = Set.copyOf(xorDistinguishing);
    }

    /** Selection on exactly one side exposes observation presence. The pair is symmetric. */
    record Xor(Set<Observation> left, Set<Observation> right) {
        Xor { left = Set.copyOf(left); right = Set.copyOf(right); }
        @Override public boolean equals(Object o) {
            return o instanceof Xor x && ((left.equals(x.left) && right.equals(x.right))
                    || (left.equals(x.right) && right.equals(x.left)));
        }
        @Override public int hashCode() { return left.hashCode() + right.hashCode(); }
    }

    static final class Adapter {
        private final Set<Observation> universe;
        private final Map<Type, Set<Observation>> byType = new HashMap<>();
        private final Map<Pair<Type, Type>, ExplanationTerms> pairs = new HashMap<>();
        Adapter(Set<Observation> universe) {
            this.universe = Set.copyOf(universe);
            // Producer-attributed dependencies describe history, not current-instruction presence.
            for (Observation a : universe) if (a.isTypeScoped())
                byType.computeIfAbsent(a.getType(), k -> new HashSet<>()).add(a);
        }
        ExplanationTerms of(TestResult t) {
            Set<Observation> strong = new HashSet<>(t.getDistinguishingObservations());
            strong.retainAll(universe);
            Set<Xor> xor = new HashSet<>();
            for (Pair<Type, Type> pair : t.getDistinguishingInstructions()) {
                ExplanationTerms e = pairs.computeIfAbsent(pair, this::expand);
                strong.addAll(e.stronglyDistinguishing()); xor.addAll(e.xorDistinguishing());
            }
            return new ExplanationTerms(strong, xor);
        }
        private ExplanationTerms expand(Pair<Type, Type> pair) {
            Set<Observation> left = byType.getOrDefault(pair.left(), Set.of());
            Set<Observation> right = byType.getOrDefault(pair.right(), Set.of());
            Set<Observation> strong = new HashSet<>();
            Set<Xor> xor = new HashSet<>();
            for (Observation a : left) {
                Set<Observation> matches = new HashSet<>();
                for (Observation b : right) if (a.matchExceptType(b)) matches.add(b);
                if (matches.isEmpty()) strong.add(a);
                else xor.add(new Xor(Set.of(a), matches));
            }
            for (Observation b : right)
                if (left.stream().noneMatch(a -> a.matchExceptType(b))) strong.add(b);
            return new ExplanationTerms(strong, xor);
        }
    }
}
