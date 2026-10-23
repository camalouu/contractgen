package contractgen.riscv.isa.spike;

import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.util.Pair;
import org.junit.jupiter.api.Test;

import java.util.EnumSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SpikeAtomClientTest {
    @Test
    void preservesDistinctProducersAndRetirementTimes() {
        String json = """
                {"atom_schema":"producer-attributed-dependencies-v1","cases":[{"ordinal":0,"case_index":0,"atoms":[
                  {"type":"LW","observation":"RAW_RS1_1","first_retire":34},
                  {"type":"ADD","observation":"RAW_RS1_1","first_retire":40}
                ]}]}
                """;
        var result = SpikeAtomClient.parseResponse(json, EnumSet.allOf(RISCV_OBSERVATION_TYPE.class)).get(0);
        var load = new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.RAW_RS1_1, true);
        var add = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.RAW_RS1_1, true);
        assertEquals(Set.of(load, add), result.atoms());
        assertEquals(34, result.firstRetire(load).orElseThrow());
        assertEquals(40, result.firstRetire(add).orElseThrow());
        assertThrows(IllegalStateException.class, () -> SpikeAtomClient.parseResponse(
                json.replace("producer-attributed-dependencies-v1", "producer-dependencies-v1"), EnumSet.allOf(RISCV_OBSERVATION_TYPE.class)));
        assertThrows(IllegalStateException.class, () -> SpikeAtomClient.parseResponse(
                json.replace("producer-attributed-dependencies-v1", "unknown"), EnumSet.allOf(RISCV_OBSERVATION_TYPE.class)));
        assertThrows(IllegalStateException.class, () -> SpikeAtomClient.parseResponse(
                json.replace("\"atom_schema\":\"producer-attributed-dependencies-v1\",", ""),
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class)));
        assertThrows(IllegalStateException.class, () -> SpikeAtomClient.parseResponse(
                json.replace("\"type\":\"LW\"", "\"type\":\"MUL\",\"producer\":\"LW\""),
                EnumSet.allOf(RISCV_OBSERVATION_TYPE.class)));
    }
    @Test
    void retainsEarliestRetirementForRepeatedAtom() {
        String json = """
                {"cases":[{"ordinal":0,"case_index":7,"atoms":[
                  {"type":"ADDI","observation":"OPCODE","first_retire":40},
                  {"type":"ADDI","observation":"OPCODE","first_retire":34}
                ],"instruction_pairs":[
                  {"left":"JALR","right":"ADDI","first_retire":40},
                  {"left":"JALR","right":"ADDI","first_retire":35}
                ]}]}
                """;

        List<SpikeAtomClient.SpikeCaseAtoms> cases = SpikeAtomClient.parseResponse(
                json, EnumSet.allOf(RISCV_OBSERVATION_TYPE.class));
        RISCVObservation atom = new RISCVObservation(RISCV_TYPE.ADDI, RISCV_OBSERVATION_TYPE.OPCODE);
        Pair<RISCV_TYPE, RISCV_TYPE> pair = new Pair<>(RISCV_TYPE.JALR, RISCV_TYPE.ADDI);

        assertEquals(1, cases.get(0).atoms().size());
        assertEquals(34, cases.get(0).firstRetire(atom).orElseThrow());
        assertEquals(Set.of(pair), cases.get(0).instructionPairs());
        assertEquals(35, cases.get(0).firstRetire(pair).orElseThrow());
    }

    @Test
    void parsesRs2LowFiveAtom() {
        String json = """
                {"cases":[{"ordinal":0,"case_index":9,"atoms":[
                  {"type":"SLL","observation":"REG_RS2_LOW5","first_retire":33}
                ]}]}
                """;

        SpikeAtomClient.SpikeCaseAtoms result = SpikeAtomClient.parseResponse(
                json, EnumSet.allOf(RISCV_OBSERVATION_TYPE.class)).get(0);
        RISCVObservation atom = new RISCVObservation(RISCV_TYPE.SLL, RISCV_OBSERVATION_TYPE.REG_RS2_LOW5);

        assertEquals(Set.of(atom), result.atoms());
        assertEquals(33, result.firstRetire(atom).orElseThrow());
    }

    @Test
    void parsesAndFiltersStructuralPredicates() {
        String json = """
                {"cases":[{"ordinal":0,"case_index":9,"atoms":[
                  {"type":"LW","observation":"RD_IS_ZERO","first_retire":33},
                  {"type":"ADD","observation":"RS1_IS_ZERO","first_retire":34},
                  {"type":"ADD","observation":"RS2_IS_ZERO","first_retire":34},
                  {"type":"BEQ","observation":"IMM_IS_NEGATIVE","first_retire":35}
                ]}]}
                """;
        var all = SpikeAtomClient.parseResponse(json, EnumSet.allOf(RISCV_OBSERVATION_TYPE.class)).get(0);
        assertEquals(4, all.atoms().size());
        var sign = new RISCVObservation(RISCV_TYPE.BEQ, RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE);
        assertEquals(35, all.firstRetire(sign).orElseThrow());
        var filtered = SpikeAtomClient.parseResponse(json, Set.of(RISCV_OBSERVATION_TYPE.IMM_IS_NEGATIVE)).get(0);
        assertEquals(Set.of(sign), filtered.atoms());
    }
}
