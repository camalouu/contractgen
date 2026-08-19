package contractgen.refinement;

import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCVTestCase;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Materializes one symbolic pre-state as one concrete paired testcase. */
final class RefinementTestMaterializer {
    private static final int REGISTER_COUNT = 32;
    private static final int SUFFIX_NOPS = 5;

    private RefinementTestMaterializer() {
    }

    static RISCVTestCase materialize(Seed seed, int index) {
        List<RISCVInstruction> target1 = seed.program1();
        List<RISCVInstruction> target2 = seed.program2();
        if (target1.size() != target2.size()) {
            throw new IllegalArgumentException("Z3 target programs have different lengths");
        }
        for (int i = 0; i < target1.size(); i++) {
            if (target1.get(i).type() != target2.get(i).type()) {
                throw new IllegalArgumentException("Z3 changed instruction type at target slot " + i);
            }
        }

        Map<Integer, Integer> common = new HashMap<>();
        List<RISCVInstruction> program1 = new ArrayList<>();
        List<RISCVInstruction> program2 = new ArrayList<>();
        for (int register = 1; register < REGISTER_COUNT; register++) {
            int value1 = seed.registers1().getOrDefault(register, 0);
            int value2 = seed.registers2().getOrDefault(register, 0);
            requireSignedImmediate(register, value1);
            requireSignedImmediate(register, value2);
            if (value1 == value2) {
                if (value1 != 0) {
                    common.put(register, value1);
                }
            } else {
                program1.add(RISCVInstruction.ADDI(register, 0, value1));
                program2.add(RISCVInstruction.ADDI(register, 0, value2));
            }
        }
        program1.addAll(target1);
        program2.addAll(target2);
        for (int i = 0; i < SUFFIX_NOPS; i++) {
            program1.add(RISCVInstruction.NOP());
            program2.add(RISCVInstruction.NOP());
        }
        return new RISCVTestCase(
                new RISCVProgram(Map.copyOf(common), List.copyOf(program1)),
                new RISCVProgram(Map.copyOf(common), List.copyOf(program2)),
                program1.size() + 1,
                index);
    }

    private static void requireSignedImmediate(int register, int value) {
        if (value < -2048 || value > 2047) {
            throw new IllegalArgumentException("x" + register + " pre-state value cannot be materialized by ADDI: " + value);
        }
    }

    record Seed(
            List<RISCVInstruction> program1,
            Map<Integer, Integer> registers1,
            List<RISCVInstruction> program2,
            Map<Integer, Integer> registers2
    ) {
    }
}
