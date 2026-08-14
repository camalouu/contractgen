package contractgen.refinement;

import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCVTestCase;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Materializes a Z3 pre-state and produces semantics-preserving concrete variants. */
final class RefinementTestMutator {
    private static final int REGISTER_COUNT = 32;
    private static final int SUFFIX_NOPS = 5;

    private RefinementTestMutator() {
    }

    static List<Variant> variants(Seed seed, int maximum, int firstIndex) {
        if (maximum < 1) {
            return List.of();
        }
        Map<String, Variant> unique = new LinkedHashMap<>();
        int index = firstIndex;
        for (int shift = 0; shift < REGISTER_COUNT - 1 && unique.size() < maximum; shift++) {
            Renamed renamed = rename(seed, shift);
            String baseMutation = shift == 0 ? "identity" : "register-shift-" + shift;
            index = add(unique, baseMutation, renamed.program1(), renamed.registers1(),
                    renamed.program2(), renamed.registers2(), index, maximum);
            if (unique.size() < maximum) {
                index = add(unique, baseMutation + "-pair-swapped",
                        renamed.program2(), renamed.registers2(), renamed.program1(), renamed.registers1(),
                        index, maximum);
            }
        }
        return List.copyOf(unique.values());
    }

    private static int add(
            Map<String, Variant> unique,
            String mutation,
            List<RISCVInstruction> target1,
            Map<Integer, Integer> state1,
            List<RISCVInstruction> target2,
            Map<Integer, Integer> state2,
            int index,
            int maximum
    ) {
        if (unique.size() >= maximum) {
            return index;
        }
        Materialized materialized = materialize(target1, state1, target2, state2, index);
        String key = key(materialized.test());
        if (!unique.containsKey(key)) {
            unique.put(key, new Variant(mutation, materialized.test()));
            return index + 1;
        }
        return index;
    }

    /**
     * Uses one identical hidden initialization on both sides. Values that differ in
     * the Z3 pre-state are established by paired ADDIs in the visible program.
     */
    private static Materialized materialize(
            List<RISCVInstruction> target1,
            Map<Integer, Integer> state1,
            List<RISCVInstruction> target2,
            Map<Integer, Integer> state2,
            int index
    ) {
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
            int value1 = state1.getOrDefault(register, 0);
            int value2 = state2.getOrDefault(register, 0);
            requireSignedImmediate(register, value1);
            requireSignedImmediate(register, value2);
            if (value1 == value2) {
                // Missing entries become the ordinary harness NOP initialization
                // and leave the reset value zero, just like generated tests.
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
        RISCVTestCase test = new RISCVTestCase(
                new RISCVProgram(Map.copyOf(common), List.copyOf(program1)),
                new RISCVProgram(Map.copyOf(common), List.copyOf(program2)),
                // The test harness retires one padding NOP between its 31 hidden
                // initialization slots and the visible program at 0x100.
                program1.size() + 1,
                index);
        return new Materialized(test);
    }

    private static void requireSignedImmediate(int register, int value) {
        if (value < -2048 || value > 2047) {
            throw new IllegalArgumentException("x" + register + " pre-state value cannot be materialized by ADDI: " + value);
        }
    }

    private static Renamed rename(Seed seed, int shift) {
        return new Renamed(
                renameProgram(seed.program1(), shift), renameRegisters(seed.registers1(), shift),
                renameProgram(seed.program2(), shift), renameRegisters(seed.registers2(), shift));
    }

    private static List<RISCVInstruction> renameProgram(List<RISCVInstruction> program, int shift) {
        return program.stream().map(instruction -> new RISCVInstruction(
                instruction.type(),
                renameRegister(instruction.rd(), shift),
                renameRegister(instruction.rs1(), shift),
                renameRegister(instruction.rs2(), shift),
                instruction.imm())).toList();
    }

    private static Map<Integer, Integer> renameRegisters(Map<Integer, Integer> registers, int shift) {
        Map<Integer, Integer> renamed = new HashMap<>();
        registers.forEach((register, value) -> renamed.put(renameRegister(register, shift), value));
        return renamed;
    }

    private static Integer renameRegister(Integer register, int shift) {
        if (register == null || register == 0 || shift == 0) {
            return register;
        }
        return ((register - 1 + shift) % (REGISTER_COUNT - 1)) + 1;
    }

    private static String key(RISCVTestCase test) {
        RISCVProgram program1 = (RISCVProgram) test.getProgram1();
        RISCVProgram program2 = (RISCVProgram) test.getProgram2();
        return program1.getRegisters() + ":" + words(program1) + "|" + program2.getRegisters() + ":" + words(program2);
    }

    private static String words(RISCVProgram program) {
        return program.getProgram().stream().map(RISCVInstruction::toHexEncoding).reduce("", (a, b) -> a + b);
    }

    record Seed(
            List<RISCVInstruction> program1,
            Map<Integer, Integer> registers1,
            List<RISCVInstruction> program2,
            Map<Integer, Integer> registers2
    ) {
    }

    record Variant(String mutation, RISCVTestCase test) {
    }

    private record Renamed(
            List<RISCVInstruction> program1,
            Map<Integer, Integer> registers1,
            List<RISCVInstruction> program2,
            Map<Integer, Integer> registers2
    ) {
    }

    private record Materialized(RISCVTestCase test) {
    }
}
