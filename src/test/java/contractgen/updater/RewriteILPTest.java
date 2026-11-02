package contractgen.updater;

import com.google.gson.Gson;
import contractgen.Contract;
import contractgen.Observation;
import contractgen.TestResult;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.*;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class RewriteILPTest {
    private static final RISCVObservation A = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.REG_RS1);
    private static final RISCVObservation B = new RISCVObservation(RISCV_TYPE.SUB, RISCV_OBSERVATION_TYPE.REG_RS1);
    private static final RISCVObservation C = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.RD);
    private static final RISCVObservation D = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.RAW_RS1_1, true);
    private static RISCVTestResult row(Set<RISCVObservation> a, boolean positive, int id) {
        return new RISCVTestResult(a, Set.of(), positive, id);
    }

    @Test void frequencyMattersAndFalsePositivesPrecedeSize() {
        List<TestResult> rows = new ArrayList<>(List.of(row(Set.of(A,B),true,0),row(Set.of(A,C),true,1)));
        for (int i=0;i<100;i++) rows.add(row(Set.of(A),false,i+2));
        rows.add(row(Set.of(B),false,102));rows.add(row(Set.of(C),false,103));
        var solution = new ILPUpdater().solve(Set.of(A,B,C),rows,Set.of(A),Set.of(),Set.of());
        assertTrue(solution.isOptimal());assertEquals(Set.of(B,C),solution.contract());
        assertEquals(2,solution.falsePositives());assertEquals(2,solution.size());
    }

    @Test void instructionPresenceXorHasCorrectTruthTable() {
        var pair = new RISCVTestResult(Set.of(),Set.of(new Pair<>(RISCV_TYPE.ADD,RISCV_TYPE.SUB)),false,0);
        for (Set<Observation> chosen : List.of(Set.<Observation>of(),Set.<Observation>of(A),Set.<Observation>of(B),Set.<Observation>of(A,B))) {
            Set<Observation> forbidden = new HashSet<>(Set.of(A,B));forbidden.removeAll(chosen);
            var s = new ILPUpdater().solve(Set.of(A,B),List.of(pair),Set.of(),chosen,forbidden);
            assertTrue(s.isOptimal());assertEquals(chosen,s.contract());
            assertEquals(chosen.size()==1 ? 1 : 0,s.falsePositives());
        }
    }

    @Test void unexplainedPositivesAreExplicitAndDiagnosticsRoundTrip() {
        var updater = new ILPUpdater();
        var missing = row(Set.of(B),true,37); // No usable atom in this universe.
        var solution = updater.solve(Set.of(A),List.of(missing,row(Set.of(A),true,38)),Set.of(),Set.of(),Set.of());
        assertTrue(solution.isOptimal());assertEquals(List.of(37),solution.unexplainedPositiveIds());
        var contract = new RISCVContract(Set.of(A),updater);contract.add(missing);contract.add(row(Set.of(A),true,38));contract.update(true);
        assertEquals(List.of(37),updater.unexplainedPositiveIds());
        String json = new Gson().toJson(contract);
        var restored = RISCVContract.fromJSON(json);
        assertTrue(restored.getContractStats().contains("Unexplained Positive Cases: 1"));
        assertTrue(new Gson().toJson(restored).contains("37"));
        updater.update(Set.of(A),List.of(row(Set.of(A),true,38)),Set.of());
        assertTrue(updater.unexplainedPositiveIds().isEmpty());
    }

    @Test void matchesExhaustiveContractEvaluationIncludingProducerDependencies() {
        List<Observation> atoms = List.of(A,B,C,D);Set<Observation> universe = Set.copyOf(atoms);
        Random rng = new Random(19);
        for(int trial=0;trial<12;trial++) {
            List<TestResult> rows = new ArrayList<>();
            for(int i=0;i<25;i++) {
                Set<RISCVObservation> obs = new HashSet<>();
                for(Observation a:atoms) if(rng.nextInt(5)==0)obs.add((RISCVObservation)a);
                var pairs = rng.nextBoolean() ? Set.of(new Pair<>(RISCV_TYPE.ADD,RISCV_TYPE.SUB))
                        : Set.<Pair<RISCV_TYPE,RISCV_TYPE>>of();
                var probe = new RISCVTestResult(obs,pairs,false,i);
                rows.add(new RISCVTestResult(obs,pairs,rng.nextInt(4)==0 && Contract.covers(Set.of(A,C),probe),i));
            }
            long bestFp=Long.MAX_VALUE;int bestSize=Integer.MAX_VALUE;
            for(int mask=0;mask<16;mask++) {
                Set<Observation> candidate = new HashSet<>();
                for(int bit=0;bit<4;bit++)if((mask&(1<<bit))!=0)candidate.add(atoms.get(bit));
                if(rows.stream().anyMatch(t -> t.isAdversaryDistinguishable() && !Contract.covers(candidate,t)))continue;
                long fp=rows.stream().filter(TestResult::isAdversaryIndistinguishable).filter(t -> Contract.covers(candidate,t)).count();
                if(fp<bestFp || fp==bestFp && candidate.size()<bestSize){bestFp=fp;bestSize=candidate.size();}
            }
            var s = new ILPUpdater().solve(universe,rows,Set.of(),Set.of(),Set.of());
            assertTrue(s.isOptimal());
            if(bestFp!=Long.MAX_VALUE) {assertEquals(bestFp,s.falsePositives());assertEquals(bestSize,s.size());}
            // Empty positives are reported, not converted into negative evidence.
            assertEquals(rows.stream().filter(TestResult::isAdversaryDistinguishable)
                    .filter(t -> t.getDistinguishingObservations().isEmpty() && t.getDistinguishingInstructions().isEmpty())
                    .map(TestResult::getIndex).toList(),s.unexplainedPositiveIds());
        }
    }
}
