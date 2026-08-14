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
import java.util.stream.Collectors;

/**
 * Updates the contract using integer linear programming.
 */
public class ILPUpdater implements Updater {

    /** Result of the lexicographic contract optimization. */
    public record Solution(Set<Observation> contract, long falsePositives, int size, Status status) {
        public Solution {
            contract = Set.copyOf(contract);
        }

        public boolean isOptimal() {
            return status == Status.OPTIMAL;
        }
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
        if (!solution.isOptimal()) {
            throw new IllegalStateException("Contract ILP did not finish optimally: " + solution.status());
        }
        return solution.contract();
    }

    /**
     * Solves the normal two-stage objective with optional atom requirements.
     * This is also used by refinement analysis to ask counterfactual questions
     * such as "what is the best contract when this selected atom is absent?".
     */
    public Solution solve(
            Set<Observation> allObservations,
            List<TestResult> testResults,
            Set<Observation> oldContract,
            Set<Observation> required,
            Set<Observation> forbidden
    ) {
        if (!allObservations.containsAll(required) || !allObservations.containsAll(forbidden)) {
            throw new IllegalArgumentException("Required/forbidden atoms must belong to ALL_ATOMS.");
        }
        Set<Observation> overlap = new HashSet<>(required);
        overlap.retainAll(forbidden);
        if (!overlap.isEmpty()) {
            throw new IllegalArgumentException("Atoms cannot be both required and forbidden: " + overlap);
        }

        Map<MPVariable, Double> hint = new HashMap<>();
        List<TestResult> indistinguishable =
                testResults.stream().filter(TestResult::isAdversaryIndistinguishable).toList();
        List<TestResult> distinguishable =
                testResults.stream().filter(TestResult::isAdversaryDistinguishable).toList();

        Loader.loadNativeLibraries();
        MPSolver solver = MPSolver.createSolver("CP_SAT");

        // variables representing whether obs is chosen or not
        HashMap<Observation, MPVariable> selected_observations = new HashMap<>(allObservations.size());
        for (Observation obs : allObservations) {
            MPVariable var = solver.makeIntVar(0, 1, "S_" + obs.getType().toString() + "_" + obs.getObservation().toString());
            selected_observations.put(obs, var);
            double hinted = oldContract.contains(obs) ? 1.0 : 0.0;
            if (required.contains(obs)) hinted = 1.0;
            if (forbidden.contains(obs)) hinted = 0.0;
            hint.put(var, hinted);
        }
        for (Observation obs : required) {
            MPConstraint constraint = solver.makeConstraint(1.0, 1.0, "REQ_" + selected_observations.get(obs).name());
            constraint.setCoefficient(selected_observations.get(obs), 1.0);
        }
        for (Observation obs : forbidden) {
            MPConstraint constraint = solver.makeConstraint(0.0, 0.0, "FORBID_" + selected_observations.get(obs).name());
            constraint.setCoefficient(selected_observations.get(obs), 1.0);
        }

        Map<Type, Set<Observation>> grouped_observations = new HashMap<>();
        for (Observation obs : allObservations) {
            grouped_observations.computeIfAbsent(obs.getType(), k -> new HashSet<>()).add(obs);
        }

        Map<Pair<Type, Type>, Set<MPVariable>> type_pairs = new HashMap<>();
        type_pairs = testResults.stream().map(res -> res.getDistinguishingInstructions()).flatMap(Collection::stream)
        .distinct()
        .collect(Collectors.toMap(
            pair -> pair,
            pair -> new HashSet<>()
        ));

        for ( Map.Entry<Pair<Type, Type>, Set<MPVariable>> entry : type_pairs.entrySet()) {
            Set<Observation> obs1 = grouped_observations.get(entry.getKey().left());
            Set<Observation> obs2 = grouped_observations.get(entry.getKey().right());
            Set<Pair<Observation, Observation>> intersection = new HashSet<>();
            for (Observation o1 : obs1) {
                for (Observation o2 : obs2) {
                    if (o1.matchExceptType(o2)) {
                        intersection.add(new Pair<>(o1, o2));
                    }
                }
            }
            Set<Observation> singular = new HashSet<>(obs1);
            singular.addAll(obs2);
            singular.removeAll(intersection.stream().map(Pair::left).collect(Collectors.toSet()));
            singular.removeAll(intersection.stream().map(Pair::right).collect(Collectors.toSet()));
            for (Pair<Observation, Observation> pair : intersection) {
                String name = "P_" + pair.left().getType().toString() + "_" + pair.left().getObservation().toString() + "_-_" + pair.right().getType().toString() + "_" + pair.right().getObservation().toString();
                MPVariable var = solver.makeBoolVar(name);
                MPConstraint constraint1 = solver.makeConstraint(-2.0, 0.0, "C1_" + name);
                constraint1.setCoefficient(selected_observations.get(pair.left()), 1);
                constraint1.setCoefficient(selected_observations.get(pair.right()), -1);
                constraint1.setCoefficient(var, -1);
                MPConstraint constraint2 = solver.makeConstraint(-2.0, 0.0, "C2_" + name);
                constraint2.setCoefficient(selected_observations.get(pair.left()), -1);
                constraint2.setCoefficient(selected_observations.get(pair.right()), 1);
                constraint2.setCoefficient(var, -1);
                MPConstraint constraint3 = solver.makeConstraint(0.0, 2.0, "C3_" + name);
                constraint3.setCoefficient(selected_observations.get(pair.left()), 1);
                constraint3.setCoefficient(selected_observations.get(pair.right()), 1);
                constraint3.setCoefficient(var, -1);
                MPConstraint constraint4 = solver.makeConstraint(-2.0, 0.0, "C4_" + name);
                constraint4.setCoefficient(selected_observations.get(pair.left()), -1);
                constraint4.setCoefficient(selected_observations.get(pair.right()), -1);
                constraint4.setCoefficient(var, -1);

                entry.getValue().add(var);
            }
            for (Observation obs : singular) {
                entry.getValue().add(selected_observations.get(obs));
            }
        }

        // for every distinguishable test case, at least one observation must be chosen
        for (TestResult ctx : distinguishable) {
            MPConstraint constraint = solver.makeConstraint(1.0, MPSolver.infinity(), "D_" + ctx.getIndex());
            for (Observation obs : ctx.getDistinguishingObservations()) {
                constraint.setCoefficient(selected_observations.get(obs), 1);
            }
            for (Pair<Type, Type> pair : ctx.getDistinguishingInstructions()) {
                for (MPVariable var : type_pairs.get(pair)) {
                    constraint.setCoefficient(var, 1);
                }
            }
        }

        
        HashMap<TestResult, MPVariable> indistinguishable_covered = new HashMap<>(indistinguishable.size());
        for (TestResult pe : indistinguishable) {
            MPVariable var = solver.makeBoolVar("C_" + pe.getIndex());
            indistinguishable_covered.put(pe, var);
            hint.put(var, oldContract.stream().anyMatch(o -> pe.getDistinguishingObservations().contains(o)) ? 1.0 : 0.0);



            MPConstraint lower_constraint = solver.makeConstraint(0.0, MPSolver.infinity(), "L_" + pe.getIndex());
            lower_constraint.setCoefficient(var, -1);
            for (Observation obs : pe.getDistinguishingObservations()) {
                lower_constraint.setCoefficient(selected_observations.get(obs), 1);
            }
            for (Pair<Type, Type> pair : pe.getDistinguishingInstructions()) {
                for (MPVariable var2 : type_pairs.get(pair)) {
                    lower_constraint.setCoefficient(var2, 1);
                }
            }
            for (Observation obs: pe.getDistinguishingObservations()) {
                MPConstraint constraint = solver.makeConstraint(-MPSolver.infinity(), 0.0, "U_" + pe.getIndex() + "_" + selected_observations.get(obs).name());
                constraint.setCoefficient(selected_observations.get(obs), 1);
                constraint.setCoefficient(var, -1);
            }
            for (Pair<Type, Type> pair : pe.getDistinguishingInstructions()) {
                for (MPVariable var2 : type_pairs.get(pair)) {
                    MPConstraint constraint = solver.makeConstraint(-MPSolver.infinity(), 0.0, "U_" + pe.getIndex() + "_" + var2.name());
                    constraint.setCoefficient(var2, 1);
                    constraint.setCoefficient(var, -1);
                }
            }
        }

        // Minimize number of tests without violation covered
        MPObjective objective = solver.objective();
        for (MPVariable var : indistinguishable_covered.values()) {
            objective.setCoefficient(var, 1);
        }
        objective.setMinimization();

        List<Map.Entry<MPVariable, Double>> entries = hint.entrySet().stream().toList();

        MPVariable[] hint_var = new MPVariable[hint.size()];
        double[] hint_val;
        entries.stream().map(Map.Entry::getKey).toList().toArray(hint_var);
        hint_val = entries.stream().map(Map.Entry::getValue).mapToDouble(Double::doubleValue).toArray();
        solver.setHint(hint_var, hint_val);
        MPSolver.ResultStatus primaryStatus = solver.solve();
        if (primaryStatus != MPSolver.ResultStatus.OPTIMAL && primaryStatus != MPSolver.ResultStatus.FEASIBLE) {
            return new Solution(Set.of(), 0, 0, mapStatus(primaryStatus));
        }

        hint.clear();
        for (MPVariable var : hint_var) {
            hint.put(var, var.solutionValue());
        }

        double goal = objective.value();
        objective.clear();

        MPConstraint primaryGoal = solver.makeConstraint(goal, goal);
        for (MPVariable var : indistinguishable_covered.values()) {
            primaryGoal.setCoefficient(var, 1);
        }

        // Minimize overall size of the contract
        for (MPVariable var : selected_observations.values()) {
            objective.setCoefficient(var, 1);
        }
        objective.setMinimization();

        entries = hint.entrySet().stream().toList();
        entries.stream().map(Map.Entry::getKey).toList().toArray(hint_var);
        hint_val = entries.stream().map(Map.Entry::getValue).mapToDouble(Double::doubleValue).toArray();
        solver.setHint(hint_var, hint_val);
        MPSolver.ResultStatus secondaryStatus = solver.solve();
        if (secondaryStatus != MPSolver.ResultStatus.OPTIMAL && secondaryStatus != MPSolver.ResultStatus.FEASIBLE) {
            return new Solution(Set.of(), Math.round(goal), 0, mapStatus(secondaryStatus));
        }

        Set<Observation> new_contract = new HashSet<>();
        for (Map.Entry<Observation, MPVariable> entry : selected_observations.entrySet()) {
            if (entry.getValue().solutionValue() > 0.0) {
                new_contract.add(entry.getKey());
            }
        }
        Status status = primaryStatus == MPSolver.ResultStatus.OPTIMAL && secondaryStatus == MPSolver.ResultStatus.OPTIMAL
                ? Status.OPTIMAL
                : Status.FEASIBLE;
        return new Solution(new_contract, Math.round(goal), new_contract.size(), status);
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
