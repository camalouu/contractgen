package contractgen.riscv.isa.contract;

import com.google.gson.Gson;
import contractgen.Contract;
import contractgen.Observation;
import contractgen.riscv.isa.RISCV;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.updater.ILPUpdater;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;
import java.util.TreeSet;

import static org.junit.jupiter.api.Assertions.*;

class ProducerDependencyTest {
    private static final RISCVObservation LOAD_RAW = new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.RAW_RS1_1, true);
    private static final RISCVObservation ADD_RAW = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.RAW_RS1_1, true);
    private static final RISCVObservation LOAD_RD = new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.RD);

    @Test
    void atomIdentityAndOrderingRetainProducer() {
        assertNotEquals(LOAD_RAW, ADD_RAW);
        assertEquals(2, Set.of(LOAD_RAW, ADD_RAW).size());
        var sorted = new TreeSet<>(RISCVObservation.ORDER);
        sorted.addAll(Set.of(LOAD_RAW, ADD_RAW));
        assertEquals(2, sorted.size());
        assertTrue(LOAD_RAW.matchExceptType(ADD_RAW));
        assertTrue(LOAD_RAW.toString().contains("LW: RAW_RS1_1"));
        assertEquals(LOAD_RAW, new Gson().fromJson(new Gson().toJson(LOAD_RAW), RISCVObservation.class));
    }

    @Test
    void universeUsesEnabledWritersWithoutConsumerCrossProduct() {
        var types = Set.of(RISCV_TYPE.LW, RISCV_TYPE.MUL, RISCV_TYPE.SW, RISCV_TYPE.SLLI);
        var atoms = RISCV.atoms(types, Set.of(RISCV_OBSERVATION_TYPE.RAW_RS1_1,
                RISCV_OBSERVATION_TYPE.RAW_RS2_4, RISCV_OBSERVATION_TYPE.WAW_2), true);
        assertTrue(atoms.contains(LOAD_RAW));
        assertEquals(9, atoms.size()); // Three writer types × three relations, without a consumer cross product.
        assertTrue(atoms.contains(new RISCVObservation(RISCV_TYPE.SLLI, RISCV_OBSERVATION_TYPE.RAW_RS2_4, true)));
        for (Observation atom : atoms) {
            var r = (RISCVObservation) atom;
            assertTrue(r.producerDependency());
            assertNotEquals(RISCV_TYPE.SW, r.type());
        }
    }

    @Test
    void solverCanSelectLoadDependencyWithoutCoveringEqualValueAddCase() {
        var positive = new RISCVTestResult(Set.of(LOAD_RAW, LOAD_RD), Set.of(), true, 0);
        var addRd = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.RD);
        var negative = new RISCVTestResult(Set.of(ADD_RAW, addRd), Set.of(), false, 1);
        var unlinked = new RISCVTestResult(Set.of(LOAD_RD), Set.of(), false, 2);
        var solution = new ILPUpdater().solve(Set.of(LOAD_RAW, ADD_RAW, LOAD_RD, addRd),
                List.of(positive, negative, unlinked), Set.of(), Set.of(), Set.of());
        assertTrue(solution.isOptimal());
        assertEquals(Set.of(LOAD_RAW), solution.contract());
        assertEquals(0, solution.falsePositives());
        assertTrue(Contract.covers(solution.contract(), positive));
        assertFalse(Contract.covers(solution.contract(), negative));
    }

    @Test
    void producerPredicateDoesNotExposeInstructionPresenceWhenFalse() {
        var unrelatedTypeChange = new RISCVTestResult(Set.of(),
                Set.of(new Pair<>(RISCV_TYPE.LW, RISCV_TYPE.ADD)), false, 1);
        var positive = new RISCVTestResult(Set.of(LOAD_RAW), Set.of(), true, 0);
        var solution = new ILPUpdater().solve(Set.of(LOAD_RAW), List.of(positive, unrelatedTypeChange),
                Set.of(), Set.of(), Set.of());
        assertEquals(Set.of(LOAD_RAW), solution.contract());
        assertEquals(0, solution.falsePositives());
        assertFalse(Contract.covers(solution.contract(), unrelatedTypeChange));
        assertTrue(Contract.whyCovers(solution.contract(), unrelatedTypeChange).right().isEmpty());
    }

    @Test
    void contractsRoundTripWithSchemaAndRejectLegacyMixing() {
        var contract = new RISCVContract(Set.of(LOAD_RAW, ADD_RAW), new ILPUpdater());
        contract.add(new RISCVTestResult(Set.of(LOAD_RAW), Set.of(), true, 0));
        contract.update(true);
        var restored = RISCVContract.fromJSON(new Gson().toJson(contract));
        assertEquals(RISCVObservation.DEPENDENCY_SCHEMA, restored.atomSchema());
        assertEquals(contract.getAllAtoms(), restored.getAllAtoms());
        assertEquals(Set.of(LOAD_RAW), restored.getCurrentContract());
        assertEquals(Set.of(LOAD_RAW), restored.getTestResults().get(0).getDistinguishingObservations());
        var legacy = new RISCVContract(Set.of(new RISCVObservation(RISCV_TYPE.MUL,
                RISCV_OBSERVATION_TYPE.RAW_RS1_1)), new ILPUpdater());
        assertThrows(IllegalArgumentException.class, () -> restored.requireCompatible(legacy));
        assertThrows(com.google.gson.JsonParseException.class, () -> RISCVContract.fromJSON(
                new Gson().toJson(contract).replace(RISCVObservation.DEPENDENCY_SCHEMA, RISCVObservation.LEGACY_SCHEMA)));
        assertThrows(com.google.gson.JsonParseException.class, () -> RISCVContract.fromJSON(
                new Gson().toJson(contract).replace(RISCVObservation.DEPENDENCY_SCHEMA, "producer-dependencies-v1")));
        assertThrows(UnsupportedOperationException.class, restored::printContract);
        var oldJson = com.google.gson.JsonParser.parseString(new Gson().toJson(legacy)).getAsJsonObject();
        oldJson.remove("atomSchema");
        assertEquals(RISCVObservation.LEGACY_SCHEMA, RISCVContract.fromJSON(oldJson.toString()).atomSchema());
    }
}
