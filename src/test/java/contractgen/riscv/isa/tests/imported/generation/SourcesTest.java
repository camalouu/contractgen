package contractgen.riscv.isa.tests.imported.generation;

import contractgen.riscv.isa.tests.imported.contract.LeakageFunction;
import contractgen.riscv.isa.tests.imported.isa.Mnemonic;
import contractgen.riscv.isa.tests.imported.isa.RegisterValues;
import contractgen.riscv.isa.tests.imported.isa.Subset;
import contractgen.riscv.isa.tests.imported.testcase.TestCase;
import org.junit.jupiter.api.Test;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Properties of the test-case sources. (Until the switch-over, both sources were also checked to reproduce the
 * original generators test case by test case.)
 */
class SourcesTest {

    private static List<TestCase> all(TestCaseSource source) {
        List<TestCase> result = new ArrayList<>();
        GenerationContext ctx = new GenerationContext();
        for (List<TestCase> b = source.nextBatch(ctx); !b.isEmpty(); b = source.nextBatch(ctx)) {
            result.addAll(b);
            ctx.startNextBatch();
        }
        return result;
    }

    private static List<String> fingerprint(List<TestCase> tcs) {
        return tcs.stream().map(tc -> tc.id() + ":" + tc.first().registers() + tc.first().programWords()
                + tc.second().registers() + tc.second().programWords() + tc.intent()).toList();
    }

    @Test
    void differentProgramsIsDeterministicWithSequentialIds() {
        var functions = LeakageFunction.recipes();
        List<TestCase> a = all(new DifferentProgramsSource(EnumSet.allOf(Subset.class), functions, 42, 777, false, RegisterValues.FULL));
        List<TestCase> b = all(new DifferentProgramsSource(EnumSet.allOf(Subset.class), functions, 42, 777, false, RegisterValues.FULL));
        assertEquals(777, a.size());
        assertEquals(fingerprint(a), fingerprint(b));
        for (int i = 0; i < a.size(); i++) assertEquals(i, a.get(i).id());
        assertNotEquals(fingerprint(a), fingerprint(all(new DifferentProgramsSource(EnumSet.allOf(Subset.class), functions, 43, 777, false, RegisterValues.FULL))));
    }

    @Test
    void differentProgramsShareRegistersAndSuffix() {
        for (TestCase tc : all(new DifferentProgramsSource(EnumSet.of(Subset.I), LeakageFunction.recipes(), 1, 300, false, RegisterValues.FULL))) {
            assertEquals(tc.first().registers(), tc.second().registers());
            List<String> p1 = tc.first().programWords(), p2 = tc.second().programWords();
            int shared = 0;
            while (shared < Math.min(p1.size(), p2.size()) && p1.get(p1.size() - 1 - shared).equals(p2.get(p2.size() - 1 - shared))) shared++;
            assertTrue(shared >= 5, "suffix of at least 5 instructions");
            assertTrue(tc.intent().isPresent());
        }
    }


    @Test
    void alignedMemoryAccesses() {
        Set<Mnemonic> aligned = EnumSet.of(Mnemonic.SH, Mnemonic.SW, Mnemonic.LH, Mnemonic.LHU, Mnemonic.LW);
        for (TestCase tc : all(new DifferentProgramsSource(EnumSet.allOf(Subset.class), LeakageFunction.recipes(), 3, 500, true, RegisterValues.FULL))) {
            for (var p : List.of(tc.first(), tc.second())) {
                for (int i = 0; i < p.instructions().size(); i++) {
                    var ins = p.instructions().get(i);
                    if (!aligned.contains(ins.mnemonic()) || ins.rs1() != 0) continue;
                    assertEquals(0, ins.imm() % 4, ins.toString());
                }
            }
        }
    }

    @Test
    void suffixesDrawEveryMnemonic() {
        Set<Mnemonic> seen = EnumSet.noneOf(Mnemonic.class);
        for (TestCase tc : all(new SameProgramsSource(EnumSet.allOf(Subset.class), 5, 2000, false, RegisterValues.FULL))) {
            var instructions = tc.first().instructions();
            instructions.subList(1, instructions.size()).forEach(i -> seen.add(i.mnemonic()));  // after the target
        }
        assertEquals(EnumSet.allOf(Mnemonic.class), seen);
    }

    @Test
    void sameProgramsRunTheSameProgram() {
        for (TestCase tc : all(new SameProgramsSource(EnumSet.allOf(Subset.class), 7, 200, false, RegisterValues.FULL))) {
            assertEquals(tc.first().programWords(), tc.second().programWords());
        }
    }

    /**
     * A jalr follows an andi that aligns its base register; with alignMemory, every half- or word-sized access is
     * aligned, by an andi/ori of its base register or (base x0) by its immediate.
     */
    @Test
    void sameProgramsAlignJumpsAndMemoryAccesses() {
        Set<Mnemonic> alignmentSensitive = EnumSet.of(Mnemonic.SH, Mnemonic.SW, Mnemonic.LH, Mnemonic.LHU, Mnemonic.LW);
        for (boolean align : new boolean[]{false, true}) {
            int jumps = 0, accesses = 0;
            for (TestCase tc : all(new SameProgramsSource(EnumSet.of(Subset.I), 19, 500, align, RegisterValues.FULL))) {
                var p = tc.first().instructions();
                for (int i = 0; i < p.size(); i++) {
                    var ins = p.get(i);
                    if (ins.mnemonic() == Mnemonic.JALR) {
                        jumps++;
                        assertEquals(contractgen.riscv.isa.tests.imported.isa.Instruction.andi(ins.rs1(), ins.rs1(), 4092), p.get(i - 1), tc.toString());
                    }
                    if (align && alignmentSensitive.contains(ins.mnemonic())) {
                        accesses++;
                        if (ins.rs1() == 0) assertEquals(0, ins.imm() % 4, ins.toString());
                        else {
                            var before = p.get(i - 1);
                            assertTrue(before.mnemonic() == Mnemonic.ANDI || before.mnemonic() == Mnemonic.ORI, tc.toString());
                            assertEquals(ins.rs1(), before.rd());
                        }
                    }
                }
            }
            assertTrue(jumps > 10, jumps + " jalr");
            if (align) assertTrue(accesses > 50, accesses + " aligned accesses");
        }
    }

    @Test
    void truncatedLastBatchIsNotBiasedTowardsEarlyMnemonics() {
        // a full batch has a test case per mnemonic; keep 10 of the second one
        GenerationContext ctx = new GenerationContext();
        var source = new SameProgramsSource(EnumSet.allOf(Subset.class), 13, Mnemonic.values().length + 10, false, RegisterValues.FULL);
        assertEquals(Mnemonic.values().length, source.nextBatch(ctx).size());
        List<TestCase> last = source.nextBatch(ctx);
        assertEquals(10, last.size());
        assertTrue(last.stream().anyMatch(tc -> tc.first().instructions().get(0).mnemonic().ordinal() >= 10), "a late mnemonic");
        assertTrue(source.nextBatch(ctx).isEmpty());
    }



    @Test
    void registerValues() {
        for (RegisterValues values : RegisterValues.values()) {
            long free = 0, all = 0;
            for (TestCase tc : all(new SameProgramsSource(EnumSet.allOf(Subset.class), 17, 200, false, values))) {
                for (long v : tc.first().registers().values()) {
                    all++;
                    if (v >> 11 != 0 && v >> 11 != 0x1fffff) free++;
                }
            }
            if (values == RegisterValues.LEGACY) assertEquals(0, free);
            else assertTrue(free > all / 3, free + " of " + all + " values use the upper bits");
        }
    }

    @Test
    void sameProgramsHasNoDuplicates() {
        List<TestCase> tcs = all(new SameProgramsSource(EnumSet.allOf(Subset.class), 11, 500, false, RegisterValues.FULL));
        assertEquals(500, tcs.size());
        assertEquals(500, tcs.stream().map(tc -> List.of(tc.first(), tc.second())).distinct().count());
    }

    private static RandomSource random(Set<Subset> subsets, long seed, long total, boolean align, String length,
                                       String registerDifferences, String instructionModifications) {
        return new RandomSource(subsets, seed, total, align, RegisterValues.FULL,
                RandomSource.Distributions.parse(length, registerDifferences, instructionModifications));
    }

    @Test
    void randomIsDeterministicWithSequentialIds() {
        List<TestCase> a = all(random(EnumSet.allOf(Subset.class), 42, 700, false, null, null, null));
        List<TestCase> b = all(random(EnumSet.allOf(Subset.class), 42, 700, false, null, null, null));
        assertEquals(700, a.size());
        assertEquals(fingerprint(a), fingerprint(b));
        for (int i = 0; i < a.size(); i++) assertEquals(i, a.get(i).id());
        assertTrue(a.stream().allMatch(tc -> tc.intent().isEmpty()));
        assertNotEquals(fingerprint(a), fingerprint(all(random(EnumSet.allOf(Subset.class), 43, 700, false, null, null, null))));
    }

    /**
     * The second program differs from the first in exactly the drawn number of registers and instructions, each
     * modified instruction in its mnemonic or in a single operand field, and the two programs always differ.
     */
    @Test
    void randomProgramsDifferAsDrawn() {
        RandomSource source = random(EnumSet.of(Subset.I), 3, 0, false, "mean=10,sd=5,min=2,max=30", "mean=2,sd=2,min=0,max=31",
                "mean=2,sd=2,min=0,max=8");
        Set<Integer> differences = new HashSet<>(), modifications = new HashSet<>();
        int mnemonicChanges = 0;
        for (int k = 0; k < 3000; k++) {
            RandomSource.Draw d = source.draw();
            assertTrue(d.first().size() >= 2 && d.first().size() <= 30, "length " + d.first().size());
            assertEquals(d.first().size(), d.second().size());
            assertTrue(d.registerDifferences() + d.instructionModifications() > 0);
            assertTrue(d.instructionModifications() <= Math.min(8, d.first().size()));
            differences.add(d.registerDifferences());
            modifications.add(d.instructionModifications());

            int registers = 0;
            for (int r = 1; r < 32; r++) {
                if (!d.firstRegisters().getOrDefault(r, 0L).equals(d.secondRegisters().getOrDefault(r, 0L))) registers++;
            }
            assertEquals(d.registerDifferences(), registers);

            int instructions = 0;
            for (int i = 0; i < d.first().size(); i++) {
                var x = d.first().get(i);
                var y = d.second().get(i);
                assertEquals(Subset.I, y.mnemonic().subset());
                assertNotEquals(0, y.hasRD() ? y.rd() : 1, y.toString());
                if (x.equals(y)) continue;
                instructions++;
                assertNotEquals(x.encode(), y.encode());
                if (x.mnemonic() != y.mnemonic()) {
                    mnemonicChanges++;
                    if (x.hasRS1() && y.hasRS1()) assertEquals(x.rs1(), y.rs1());
                    if (x.hasRD() && y.hasRD()) assertEquals(x.rd(), y.rd());
                } else {
                    int fields = (Objects.equals(x.rd(), y.rd()) ? 0 : 1) + (Objects.equals(x.rs1(), y.rs1()) ? 0 : 1)
                            + (Objects.equals(x.rs2(), y.rs2()) ? 0 : 1) + (Objects.equals(x.imm(), y.imm()) ? 0 : 1);
                    assertEquals(1, fields, x + " -> " + y);
                }
            }
            assertEquals(d.instructionModifications(), instructions);
        }
        assertTrue(differences.containsAll(Set.of(0, 1, 2, 3, 4, 5)), differences.toString());
        assertEquals(Set.of(0, 1, 2, 3, 4, 5, 6, 7, 8), modifications);
        assertTrue(mnemonicChanges > 500, mnemonicChanges + " mnemonic changes");
    }

    @Test
    void randomFixedNumbers() {
        RandomSource source = random(EnumSet.allOf(Subset.class), 5, 0, false, "12", "0", "3");
        for (int k = 0; k < 200; k++) {
            RandomSource.Draw d = source.draw();
            assertEquals(12, d.first().size());
            assertEquals(d.firstRegisters(), d.secondRegisters());
            assertEquals(3, d.instructionModifications());
        }
    }

    /** As in the other sources, a jalr follows an andi of its base register, and with alignMemory accesses are aligned. */
    @Test
    void randomProgramsAreAligned() {
        Set<Mnemonic> alignmentSensitive = EnumSet.of(Mnemonic.SH, Mnemonic.SW, Mnemonic.LH, Mnemonic.LHU, Mnemonic.LW);
        int jumps = 0, accesses = 0;
        for (TestCase tc : all(random(EnumSet.allOf(Subset.class), 11, 1000, true, "mean=40,sd=20,min=1,max=63", null, "mean=5,sd=3,min=0,max=63"))) {
            for (var program : List.of(tc.first(), tc.second())) {
                var p = program.instructions();
                for (int i = 0; i < p.size(); i++) {
                    var ins = p.get(i);
                    if (ins.mnemonic() == Mnemonic.JALR) {
                        jumps++;
                        assertEquals(contractgen.riscv.isa.tests.imported.isa.Instruction.andi(ins.rs1(), ins.rs1(), 4092), p.get(i - 1));
                    }
                    if (alignmentSensitive.contains(ins.mnemonic())) {
                        accesses++;
                        if (ins.rs1() == 0) assertEquals(0, ins.imm() % 4, ins.toString());
                        else assertEquals(ins.rs1(), p.get(i - 1).rd());
                    }
                }
            }
        }
        assertTrue(jumps > 100, jumps + " jalr");
        assertTrue(accesses > 1000, accesses + " accesses");
    }

    @Test
    void randomRejectsDistributionsThatCannotWork() {
        Set<Subset> all = EnumSet.allOf(Subset.class);
        // aligned programs must fit into the instruction memory: up to 3 instructions per random one with aligned memory
        assertDoesNotThrow(() -> random(all, 0, 1, true, "max=651", null, null));
        assertThrows(IllegalArgumentException.class, () -> random(all, 0, 1, true, "max=652", null, null));
        assertDoesNotThrow(() -> random(all, 0, 1, false, "max=976", null, null));
        assertThrows(IllegalArgumentException.class, () -> random(all, 0, 1, false, "max=977", null, null));
        assertThrows(IllegalArgumentException.class, () -> random(all, 0, 1, false, "min=0", null, null));
        assertThrows(IllegalArgumentException.class, () -> random(all, 0, 1, false, null, "max=32", null));
        assertThrows(IllegalArgumentException.class, () -> random(all, 0, 1, false, null, "0", "0"));
        var e = assertThrows(IllegalArgumentException.class, () -> random(all, 0, 1, false, null, null, "min=60"));
        assertTrue(e.getMessage().startsWith("instruction modifications: "), e.getMessage());
    }
}
