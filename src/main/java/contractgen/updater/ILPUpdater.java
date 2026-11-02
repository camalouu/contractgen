package contractgen.updater;

import com.google.ortools.Loader;
import com.google.ortools.linearsolver.MPConstraint;
import com.google.ortools.linearsolver.MPObjective;
import com.google.ortools.linearsolver.MPSolver;
import com.google.ortools.linearsolver.MPVariable;
import contractgen.Observation;
import contractgen.TestResult;
import contractgen.Type;
import contractgen.Updater;
import contractgen.util.Pair;

import java.util.*;


/**
 * Updates the contract using integer linear programming.
 */
public class ILPUpdater implements Updater {

    /** Result of the lexicographic contract optimization. */
    public record Solution(Set<Observation> contract, long falsePositives, int size, Status status,
                           List<Integer> unexplainedPositiveIds) {
        public Solution {
            contract = Set.copyOf(contract);
            unexplainedPositiveIds = List.copyOf(unexplainedPositiveIds);
        }

        public boolean isOptimal() {
            return status == Status.OPTIMAL;
        }
    }

    /** Persisted synthesis diagnostics; old saved contracts did not contain these fields. */
    private String objective;
    private List<Integer> unexplainedPositiveIds = List.of();

    public String objective() { return objective; }

    public List<Integer> unexplainedPositiveIds() {
        return unexplainedPositiveIds == null ? List.of() : List.copyOf(unexplainedPositiveIds);
    }

    /** Solver status kept independent of the OR-Tools API. */
    public enum Status {
        OPTIMAL,
        FEASIBLE,
        INFEASIBLE,
        ERROR
    }

    @Override
    public Set<Observation> update(Set<Observation> allObservations, List<TestResult> testResults, Set<Observation> oldContract) {
        Solution solution = solve(allObservations, testResults, oldContract, Set.of(), Set.of());
        if (!solution.isOptimal())
            throw new IllegalStateException("Contract ILP did not finish optimally: " + solution.status());
        unexplainedPositiveIds = solution.unexplainedPositiveIds();
        objective = "occurrence-weighted-false-positives-then-size-v1";
        if (!unexplainedPositiveIds.isEmpty())
            System.err.println("Contract template cannot explain " + unexplainedPositiveIds.size()
                    + " attacker-positive testcase(s); IDs are saved in updater.unexplainedPositiveIds.");
        return solution.contract();
    }

    /** Rewrite's lexicographic objective, retaining optional refinement requirements. */
    public Solution solve(Set<Observation> allObservations, List<TestResult> testResults,
                          Set<Observation> oldContract, Set<Observation> required, Set<Observation> forbidden) {
        if (!allObservations.containsAll(required) || !allObservations.containsAll(forbidden))
            throw new IllegalArgumentException("Required/forbidden atoms must belong to ALL_ATOMS.");
        if (!Collections.disjoint(required, forbidden))
            throw new IllegalArgumentException("Atoms cannot be both required and forbidden.");
        Loader.loadNativeLibraries();
        MPSolver solver = MPSolver.createSolver("CP_SAT");
        if (solver == null) throw new IllegalStateException("CP-SAT solver not available");
        try {
            solver.setSolverSpecificParametersAsString("random_seed: 0");
            Map<Observation, MPVariable> selected = new LinkedHashMap<>();
            // Stable construction also makes saved-evidence comparisons reproducible.
            List<Observation> ordered = allObservations.stream().sorted(Comparator.comparing(Observation::toString)
                    .thenComparing(o -> o.isTypeScoped() ? 0 : 1)).toList();
            for (Observation a : ordered) {
                MPVariable v = solver.makeBoolVar("s_" + selected.size());
                selected.put(a, v);
                if (required.contains(a)) v.setBounds(1, 1);
                if (forbidden.contains(a)) v.setBounds(0, 0);
            }
            Model model = new Model(solver, selected);
            ExplanationTerms.Adapter adapter = new ExplanationTerms.Adapter(allObservations);
            Map<Set<MPVariable>, Long> negatives = new LinkedHashMap<>();
            Set<Set<MPVariable>> positives = new LinkedHashSet<>();
            List<Integer> unexplained = new ArrayList<>();
            for (TestResult t : testResults) {
                Set<MPVariable> terms = model.terms(adapter.of(t));
                if (t.isAdversaryDistinguishable()) {
                    if (terms.isEmpty()) unexplained.add(t.getIndex());
                    else positives.add(terms);
                } else if (!terms.isEmpty()) negatives.merge(terms, 1L, Long::sum);
            }
            int i = 0;
            for (Set<MPVariable> terms : positives) {
                MPConstraint c = solver.makeConstraint(1, MPSolver.infinity(), "D_" + i++);
                terms.forEach(v -> c.setCoefficient(v, 1));
            }
            Map<MPVariable, Long> falsePositive = new LinkedHashMap<>();
            for (var e : negatives.entrySet()) {
                MPVariable fp = solver.makeBoolVar("fp_" + falsePositive.size());
                falsePositive.put(fp, e.getValue());
                model.or(fp, e.getKey(), "FP_" + falsePositive.size());
            }
            MPVariable[] hintVars = selected.values().toArray(MPVariable[]::new);
            solver.setHint(hintVars, selected.keySet().stream()
                    .mapToDouble(a -> required.contains(a) || (!forbidden.contains(a) && oldContract.contains(a)) ? 1 : 0).toArray());
            MPObjective objective = solver.objective();
            falsePositive.forEach(objective::setCoefficient);
            objective.setMinimization();
            MPSolver.ResultStatus first = solver.solve();
            if (first != MPSolver.ResultStatus.OPTIMAL)
                return new Solution(Set.of(), 0, 0, mapStatus(first), unexplained);
            long fpCount = Math.round(objective.value());
            double[] firstSolution = Arrays.stream(hintVars).mapToDouble(MPVariable::solutionValue).toArray();
            MPConstraint primary = solver.makeConstraint(fpCount, fpCount, "primary_goal");
            falsePositive.forEach(primary::setCoefficient);
            objective.clear();
            selected.values().forEach(v -> objective.setCoefficient(v, 1));
            objective.setMinimization();
            solver.setHint(hintVars, firstSolution);
            MPSolver.ResultStatus second = solver.solve();
            if (second != MPSolver.ResultStatus.OPTIMAL)
                return new Solution(Set.of(), fpCount, 0, mapStatus(second), unexplained);
            Set<Observation> contract = new LinkedHashSet<>();
            selected.forEach((a, v) -> { if (v.solutionValue() > .5) contract.add(a); });
            return new Solution(contract, fpCount, contract.size(), Status.OPTIMAL, unexplained);
        } finally {
            solver.delete();
        }
    }

    /**
     * Shared OR and XOR variables of the terms of all test cases.
     */
    private static final class Model {
        private final MPSolver solver;
        private final Map<Observation, MPVariable> selected;
        private final Map<Set<Observation>, MPVariable> ors = new HashMap<>();
        private final Map<ExplanationTerms.Xor, MPVariable> xors = new HashMap<>();

        Model(MPSolver solver, Map<Observation, MPVariable> selected) {
            this.solver = solver;
            this.selected = selected;
        }

        /** @return the variables whose disjunction says that the contract distinguishes the test case. */
        Set<MPVariable> terms(ExplanationTerms t) {
            Set<MPVariable> terms = new LinkedHashSet<>();
            for (Observation a : t.stronglyDistinguishing()) {
                MPVariable s = selected.get(a);
                if (s != null) terms.add(s);
            }
            for (ExplanationTerms.Xor p : t.xorDistinguishing()) {
                MPVariable x = xor(p);
                if (x != null) terms.add(x);
            }
            return terms;
        }

        private MPVariable xor(ExplanationTerms.Xor p) {
            if (xors.containsKey(p)) return xors.get(p);
            MPVariable a = any(p.left());
            MPVariable b = any(p.right());
            MPVariable x;
            if (a == b) {
                x = null;  // both sides are the same (or both empty): never distinguishing
            } else if (a == null || b == null) {
                x = a == null ? b : a;  // the other side can never be selected
            } else {
                int i = xors.size();
                x = solver.makeBoolVar("x_" + i);
                // x = a XOR b
                constraint(-MPSolver.infinity(), 0, "X1_" + i, x, 1, a, -1, b, -1);
                constraint(-MPSolver.infinity(), 0, "X2_" + i, x, -1, a, 1, b, -1);
                constraint(-MPSolver.infinity(), 0, "X3_" + i, x, -1, a, -1, b, 1);
                constraint(-MPSolver.infinity(), 2, "X4_" + i, x, 1, a, 1, b, 1);
            }
            xors.put(p, x);
            return x;
        }

        /** @return a variable that is 1 iff some atom of the set (within the universe) is selected, or null. */
        private MPVariable any(Set<Observation> atoms) {
            Set<Observation> known = new HashSet<>();
            for (Observation a : atoms) if (selected.containsKey(a)) known.add(a);
            if (known.isEmpty()) return null;
            if (known.size() == 1) return selected.get(known.iterator().next());
            return ors.computeIfAbsent(known, k -> {
                MPVariable o = solver.makeBoolVar("o_" + ors.size());
                or(o, k.stream().map(selected::get).toList(), "O_" + ors.size());
                return o;
            });
        }

        /** Constrains {@code result} to be the disjunction of the variables. */
        void or(MPVariable result, Collection<MPVariable> vars, String name) {
            MPConstraint lower = solver.makeConstraint(-MPSolver.infinity(), 0, name + "_LB");
            lower.setCoefficient(result, 1);
            int i = 0;
            for (MPVariable v : vars) {
                lower.setCoefficient(v, -1);
                MPConstraint upper = solver.makeConstraint(-MPSolver.infinity(), 0, name + "_UB_" + i++);
                upper.setCoefficient(v, 1);
                upper.setCoefficient(result, -1);
            }
        }

        private void constraint(double lb, double ub, String name, Object... coefficients) {
            MPConstraint c = solver.makeConstraint(lb, ub, name);
            for (int i = 0; i < coefficients.length; i += 2) {
                c.setCoefficient((MPVariable) coefficients[i], ((Number) coefficients[i + 1]).doubleValue());
            }
        }
    }

    private static Status mapStatus(MPSolver.ResultStatus status) {
        return switch (status) {
            case OPTIMAL -> Status.OPTIMAL;
            case FEASIBLE -> Status.FEASIBLE;
            case INFEASIBLE -> Status.INFEASIBLE;
            default -> Status.ERROR;
        };
    }
}
