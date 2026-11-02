package contractgen.riscv.isa.tests.imported.contract;

import contractgen.riscv.isa.tests.imported.isa.Instruction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;
import org.junit.jupiter.api.Test;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class ModifiersTest {

    private static Instruction random(Mnemonic m, Random r) {
        return new Instruction(m, m.hasRD() ? r.nextInt(32) : null, m.hasRS1() ? r.nextInt(32) : null,
                m.hasRS2() ? r.nextInt(32) : null, m.hasIMM() ? (long) r.nextInt(4096) / 4 * 4 + (m.isBranch() ? 0 : r.nextInt(4)) : null);
    }

    /**
     * The register values (unsigned 32-bit) before the last instruction of a prefix, as far as lui and addi set them;
     * registers written otherwise are absent.
     */
    private static Map<Integer, Long> registers(List<Instruction> prefix) {
        Map<Integer, Long> regs = new HashMap<>();
        regs.put(0, 0L);
        for (Instruction i : prefix.subList(0, prefix.size() - 1)) {
            if (i.rd() == null || i.rd() == 0) continue;
            if (i.mnemonic() == Mnemonic.LUI) regs.put(i.rd(), i.imm());
            else if (i.mnemonic() == Mnemonic.ADDI && regs.containsKey(i.rs1())) {
                regs.put(i.rd(), (regs.get(i.rs1()) + Instruction.signExtend12(i.imm())) & 0xffffffffL);
            } else regs.remove(i.rd());
        }
        return regs;
    }

    /** Every modifier applies to some instruction of its domain, and (almost always) changes the program. */
    @Test
    void everyModifierProducesDifferentPrograms() {
        Random r = new Random(1);
        for (RegisterValues values : RegisterValues.values()) {
            for (LeakageFunction f : LeakageFunction.recipes()) {
                if (f.modifier().isEmpty()) continue;
                int produced = 0, different = 0;
                for (Mnemonic m : Mnemonic.values()) {
                    if (!f.isDefinedFor(m)) continue;
                    for (int k = 0; k < 50; k++) {
                        Optional<Modifier.Modification> mod = f.modifier().get().modify(random(m, r), r, values);
                        if (mod.isEmpty()) continue;
                        produced++;
                        if (!mod.get().first().equals(mod.get().second())) different++;
                    }
                }
                assertTrue(produced > 0, f.id() + " never produced a test case");
                // the ported modifiers draw two values independently, which may coincide
                assertTrue(different >= 0.9 * produced, values + " " + f.id() + ": " + different + " of " + produced + " differ");
            }
        }
    }

    /** With LEGACY, a single addi from x0 sets each register; with FULL, lui + addi, and the values use all 32 bits. */
    @Test
    void registerValuesDecideHowRegistersAreSet() {
        Random r = new Random(7);
        Instruction add = new Instruction(Mnemonic.ADD, 3, 5, 6, null);
        Modifier modifier = LeakageFunction.recipes().stream().filter(recipe -> recipe.id().equals("REG_RS1")).findFirst().orElseThrow().modifier().orElseThrow();
        long high = 0;
        for (int k = 0; k < 200; k++) {
            List<Instruction> legacy = modifier.modify(add, r, RegisterValues.LEGACY).orElseThrow().first();
            assertEquals(List.of(Mnemonic.ADDI, Mnemonic.ADD), legacy.stream().map(Instruction::mnemonic).toList());
            assertEquals(0, legacy.get(0).rs1());
            List<Instruction> full = modifier.modify(add, r, RegisterValues.FULL).orElseThrow().first();
            assertEquals(List.of(Mnemonic.LUI, Mnemonic.ADDI, Mnemonic.ADD), full.stream().map(Instruction::mnemonic).toList());
            long value = registers(full).get(5);
            if (value >> 12 != 0 && value >> 12 != 0xfffff) high++;
        }
        assertTrue(high > 50, "only " + high + " of 200 values use bits 12 to 31");
    }

    @Test
    void branchOutcomeTakesTheBranchInTheFirstProgramOnly() {
        Random r = new Random(2);
        for (RegisterValues values : RegisterValues.values()) {
            for (Mnemonic m : Mnemonic.values()) {
                if (!m.isBranch()) continue;
                for (int k = 0; k < 200; k++) {
                    Instruction i = random(m, r);
                    Optional<Modifier.Modification> mod = LeakageFunction.recipes().stream().filter(recipe -> recipe.id().equals("BRANCH_TAKEN")).findFirst().orElseThrow().modifier().orElseThrow().modify(i, r, values);
                    if (mod.isEmpty()) {
                        // impossible only for the same register twice, and for unsigned comparisons with x0 on the right
                        boolean unsignedAgainstZero = (m == Mnemonic.BLTU || m == Mnemonic.BGEU) && i.rs2() == 0;
                        assertTrue(i.rs1().equals(i.rs2()) || unsignedAgainstZero, i.toString());
                        continue;
                    }
                    Map<Integer, Long> first = registers(mod.get().first()), second = registers(mod.get().second());
                    assertTrue(Modifiers.taken(m, first.get(i.rs1()), first.get(i.rs2())), values + " " + i);
                    assertFalse(Modifiers.taken(m, second.get(i.rs1()), second.get(i.rs2())), values + " " + i);
                }
            }
        }
    }

    @Test
    void alignmentModifiersCrossTheAlignment() {
        Random r = new Random(3);
        for (RegisterValues values : RegisterValues.values()) {
            for (boolean half : new boolean[]{false, true}) {
                LeakageFunction f = half ? LeakageFunction.recipes().stream().filter(recipe -> recipe.id().equals("IS_HALF_ALIGNED")).findFirst().orElseThrow() : LeakageFunction.recipes().stream().filter(recipe -> recipe.id().equals("IS_ALIGNED")).findFirst().orElseThrow();
                assertTrue(f.modifier().orElseThrow().needsMisalignedMemory());
                for (Mnemonic m : Mnemonic.values()) {
                    if (!m.isMemory()) continue;
                    for (int k = 0; k < 100; k++) {
                        Modifier.Modification mod = f.modifier().get().modify(random(m, r), r, values).orElseThrow();
                        long a1 = address(mod.first()), a2 = address(mod.second());
                        if (half) {
                            assertNotEquals(3, a1 & 3);
                            assertEquals(3, a2 & 3);
                        } else {
                            assertEquals(0, a1 & 3);
                            assertNotEquals(0, a2 & 3);
                        }
                    }
                }
            }
        }
    }

    private static long address(List<Instruction> prefix) {
        Instruction i = prefix.get(prefix.size() - 1);
        return registers(prefix).get(i.rs1()) + Instruction.signExtend12(i.imm());
    }

    @Test
    void dependencyModifiersWriteAtTheDistance() {
        Random r = new Random(4);
        for (int d = 1; d <= 4; d++) {
            Instruction i = new Instruction(Mnemonic.ADD, 3, 5, 6, null);
            Modifier.Modification mod = Modifiers.dependency(Instruction::rs1, d).modify(i, r, RegisterValues.FULL).orElseThrow();
            assertEquals(d + 1, mod.first().size());
            assertEquals(5, mod.first().get(0).rd());
            assertEquals(0, mod.second().get(0).rd());
            for (int k = 1; k < d; k++) assertEquals(Instruction.nop(), mod.first().get(k));
        }
    }

    @Test
    void valueModifiers() {
        Random r = new Random(5);
        Instruction div = new Instruction(Mnemonic.DIV, 3, 5, 6, null);
        for (RegisterValues values : RegisterValues.values()) {
            for (int k = 0; k < 100; k++) {
                Modifier.Modification zero = Modifiers.zero(Instruction::rs2).modify(div, r, values).orElseThrow();
                assertEquals(0, registers(zero.first()).get(6));
                assertNotEquals(0, registers(zero.second()).get(6));
                Modifier.Modification log2 = Modifiers.log2(Instruction::rs1).modify(div, r, values).orElseThrow();
                long a = registers(log2.first()).get(5), b = registers(log2.second()).get(5);
                assertEquals(1, Long.bitCount(a));
                assertEquals(1, Long.bitCount(b));
                assertNotEquals(a, b);
            }
            assertTrue(Modifiers.zero(Instruction::rs1).modify(div.withRS1(0), r, values).isEmpty());
        }
    }

    @Test
    void programCounterRunsTheInstructionAtAnotherAddressAtTheSameStep() {
        Instruction i = new Instruction(Mnemonic.ADD, 3, 5, 6, null);
        Modifier.Modification mod = Modifiers.programCounter().modify(i, new Random(6), RegisterValues.FULL).orElseThrow();
        assertEquals(List.of(new Instruction(Mnemonic.JAL, 0, null, null, 8L), Instruction.nop(), i), mod.first());
        assertEquals(List.of(new Instruction(Mnemonic.JAL, 0, null, null, 4L), i), mod.second());
    }
}
