package contractgen.riscv;

import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.riscv.isa.spike.SpikeAtomClient;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class SignatureReportTest {
    @Test
    void reportsProducerSpecificSignaturesSeparately() throws Exception {
        var load = new RISCVObservation(RISCV_TYPE.MUL, RISCV_OBSERVATION_TYPE.RAW_RS1_1, RISCV_TYPE.LW);
        var add = new RISCVObservation(RISCV_TYPE.MUL, RISCV_OBSERVATION_TYPE.RAW_RS1_1, RISCV_TYPE.ADD);
        var spike = Map.of(0, new SpikeAtomClient.SpikeCaseAtoms(0, 0, Set.of(load), null),
                1, new SpikeAtomClient.SpikeCaseAtoms(1, 1, Set.of(add), null));
        var report = SignatureReport.collect(2, spike, i -> true, new SignatureReport.Outcome[]{
                SignatureReport.Outcome.LEAKING, SignatureReport.Outcome.NON_LEAKING});
        assertEquals(2, report.size());
        var path = Files.createTempFile("dependency-signatures-", ".txt");
        try {
            SignatureReport.write(path, report);
            String text = Files.readString(path);
            assertTrue(text.contains("LW -> MUL.RAW_RS1_1"));
            assertTrue(text.contains("ADD -> MUL.RAW_RS1_1"));
            assertTrue(text.contains("Mixed: 0"));
        } finally { Files.delete(path); }
    }
    @Test
    void countsMeasuredOutcomesSeparatelyAndSortsAllSignatures() throws Exception {
        var a = new RISCVObservation(RISCV_TYPE.LW, RISCV_OBSERVATION_TYPE.RD);
        var b = new RISCVObservation(RISCV_TYPE.ADD, RISCV_OBSERVATION_TYPE.RAW_RS1_1);
        var c = new RISCVObservation(RISCV_TYPE.DIV, RISCV_OBSERVATION_TYPE.REG_RS1);
        Map<Integer, SpikeAtomClient.SpikeCaseAtoms> spike = new HashMap<>();
        List<Set<RISCVObservation>> atoms = List.of(Set.of(a), Set.of(a), Set.of(a), Set.of(a),
                Set.of(b), Set.of(b), Set.of(), Set.of(c));
        for (int i = 0; i < atoms.size(); i++)
            spike.put(i, new SpikeAtomClient.SpikeCaseAtoms(i, i, atoms.get(i), null));
        var outcomes = new SignatureReport.Outcome[]{SignatureReport.Outcome.LEAKING,
                SignatureReport.Outcome.NON_LEAKING, null, null, SignatureReport.Outcome.FAILURE,
                null, SignatureReport.Outcome.NON_LEAKING, null};
        var report = SignatureReport.collect(8, spike, i -> i != 3 && i != 7, outcomes);
        assertEquals(4, report.size());
        var mixed = report.get(0);
        assertEquals(Set.of(a), mixed.atoms());
        assertEquals(4, mixed.occurrences());
        assertEquals(2, mixed.executions());
        assertEquals(1, mixed.leaking());
        assertEquals(1, mixed.nonLeaking());
        assertEquals(1, mixed.skipped());
        assertEquals(1, mixed.unsupported());
        assertEquals("MIXED", mixed.result());
        var failed = report.get(1);
        assertEquals(1, failed.failures());
        assertEquals(0, failed.nonLeaking());
        assertEquals("UNTESTED", failed.result());
        assertTrue(report.get(2).atoms().isEmpty());
        assertEquals("NON-LEAKING", report.get(2).result());
        assertEquals("UNTESTED", report.get(3).result());
        for (var entry : report) assertEquals(entry.occurrences(),
                entry.executions() + entry.skipped() + entry.unsupported());
        var path = Files.createTempFile("signature-report-", ".txt");
        try {
            SignatureReport.write(path, report);
            String text = Files.readString(path);
            assertTrue(text.startsWith("Total signatures: 4\n"
                    + "  Leaking only: 0\n"
                    + "  Non-leaking only: 1\n"
                    + "  Mixed: 1\n"
                    + "  Untested: 2\n"
                    + "Cases in mixed signatures: 4\n"
                    + "Total testcases: 8\n"
                    + "RTL executions: 4\n"
                    + "  Leaking: 1\n"
                    + "  Non-leaking: 2\n"
                    + "Skipped: 2\n"
                    + "Unsupported: 2\n"
                    + "Failures: 1\n\nSignature 1\n"));
            assertTrue(text.contains("Occurrences: 4\nRTL executions: 2\n  Leaking: 1\n  Non-leaking: 1"));
            assertTrue(text.contains("Result: MIXED\n\nAtoms:\n  LW.RD"));
            assertTrue(text.contains("Failures: 1\nResult: UNTESTED"));
            assertTrue(text.contains("Atoms:\n  (empty)"));
        } finally { Files.delete(path); }
    }
}
