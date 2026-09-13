package contractgen.riscv.cv32e40s_test;

import contractgen.TestCase;
import contractgen.SIMULATION_RESULT;
import contractgen.riscv.isa.RISCVInstruction;
import contractgen.riscv.isa.RISCVProgram;
import contractgen.riscv.isa.RISCVTestCase;
import org.junit.jupiter.api.Test;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;
import static contractgen.riscv.cv32e40s_test.CV32E40STestAttackerClient.TimingMode.*;

class CV32E40STestAttackerClientTest {
    @Test
    void missingLibraryFailsClearly() {
        assertThrows(UnsatisfiedLinkError.class,
                () -> new CV32E40STestAttackerClient(Path.of("/nonexistent/contract_cv32e40s_test_attacker.so"), off));
    }

    private CV32E40STestAttackerClient client(CV32E40STestAttackerClient.TimingMode mode) {
        String configured = System.getProperty("contract.cv32e40s.lib", "");
        assumeTrue(!configured.isEmpty() && Files.isRegularFile(Path.of(configured)), "CV32E40S native library not configured");
        return new CV32E40STestAttackerClient(Path.of(configured), mode);
    }

    private TestCase division() {
        var program = List.of(RISCVInstruction.DIVU(3, 1, 2), RISCVInstruction.NOP());
        return new RISCVTestCase(new RISCVProgram(Map.of(1, 100, 2, 1), program),
                new RISCVProgram(Map.of(1, 100, 2, 100), program), 8, 72);
    }

    @Test
    void isolatesModesAcrossBatchesAndThreads() throws Exception {
        var baseline = client(off);
        var protectedCore = client(on);
        TestCase division = division();
        assertEquals(List.of(SIMULATION_RESULT.FAIL, SIMULATION_RESULT.FAIL), baseline.runAll(List.of(division, division), 10000));
        assertEquals(SIMULATION_RESULT.SUCCESS, protectedCore.run(division, 10000));
        assertEquals(SIMULATION_RESULT.FAIL, baseline.run(division, 10000));
        var pool = Executors.newFixedThreadPool(2);
        try {
            var a = pool.submit(() -> baseline.run(division, 10000));
            var b = pool.submit(() -> protectedCore.run(division, 10000));
            assertEquals(SIMULATION_RESULT.FAIL, a.get());
            assertEquals(SIMULATION_RESULT.SUCCESS, b.get());
        } finally { pool.shutdownNow(); }
        assertTrue(baseline.runDetailed(division, 10000).failureCutoff().isEmpty());
    }

    @Test
    void handlesIdenticalPairsTimeoutAndImageBounds() {
        var baseline = client(off);
        var program = new RISCVProgram(Map.of(1, 17), List.of(RISCVInstruction.ADD(2, 1, 1)));
        var identical = new RISCVTestCase(program, program, 4, 0);
        assertEquals(SIMULATION_RESULT.SUCCESS, baseline.run(identical, 10000));
        assertEquals(SIMULATION_RESULT.TIMEOUT, baseline.run(identical, 1));
        assertEquals(List.of(), baseline.runAll(List.of(), 10000));
        var oversized = new RISCVProgram(Map.of(), Collections.nCopies(2048, RISCVInstruction.NOP()));
        assertThrows(IllegalArgumentException.class,
                () -> baseline.run(new RISCVTestCase(oversized, oversized, 2048, 0), 10000));
    }
}
