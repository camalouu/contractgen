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

class SpikeAtomClientTest {
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
}
