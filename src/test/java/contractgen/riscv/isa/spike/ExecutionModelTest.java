package contractgen.riscv.isa.spike;

import contractgen.TestCase;
import contractgen.riscv.isa.*;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import static org.junit.jupiter.api.Assertions.*;

class ExecutionModelTest {
    @TempDir Path temp;

    private Path library(String model) throws Exception {
        return library(model, "{\"ordinal\":0,\"case_index\":7,\"atoms\":[],\"requires_misaligned_data_access\":true}");
    }

    private Path library(String model, String cases) throws Exception {
        Path source = temp.resolve("spike.c");
        String legacy = "{\"cases\":[]}";
        var array = com.google.gson.JsonParser.parseString("[" + cases + "]").getAsJsonArray();
        for (var raw : array) if (!raw.getAsJsonObject().has("requires_misaligned_data_access"))
            raw.getAsJsonObject().addProperty("requires_misaligned_data_access", false);
        String canonical = "{\"execution_model\":\"" + model + "\",\"cases\":" + array + "}";
        String code = "#include <stdlib.h>\n#include <string.h>\n"
                + "char* contract_spike_atoms_json(const char*j,const char*i,int o){return strdup(\""
                + legacy.replace("\"", "\\\"") + "\");}\n"
                + "void contract_spike_free(char*p){free(p);}\n";
        if (model != null) code += "char* contract_spike_atoms_json_v2(const char*j,const char*i,int o,const char*m){"
                + "if(strcmp(m,\"rv32-v1\")) return strdup(\"{\\\"error\\\":\\\"wrong model\\\"}\");"
                + "return strdup(\"" + canonical.replace("\"", "\\\"") + "\");}\n";
        Files.writeString(source, code);
        Path lib = temp.resolve("lib-" + UUID.randomUUID() + ".so");
        Process compiler = new ProcessBuilder("cc", "-shared", "-fPIC", source.toString(), "-o", lib.toString())
                .redirectErrorStream(true).start();
        String output = new String(compiler.getInputStream().readAllBytes());
        assertEquals(0, compiler.waitFor(), output);
        return lib;
    }

    @Test void oldAbiCannotSilentlySupplySharedReferenceEvidence() throws Exception {
        Path lib = library(null);
        assertThrows(IllegalStateException.class, () -> new SpikeAtomClient(lib).runAllJson("[]", "RV32IM"));
        var error = assertThrows(IllegalStateException.class,
                () -> new SpikeAtomClient(lib, ExecutionModel.RV32_V1).runAllJson("[]", "RV32IM"));
        assertTrue(error.getMessage().contains("contract_spike_atoms_json_v2"));
        assertThrows(IllegalArgumentException.class, () -> ExecutionModel.parse("rocket-rv32-v1"));
    }

    @Test void modelAndTemporaryRootReachBothExecutionPaths() throws Exception {
        Path lib = library("rv32-v1");
        var program = new RISCVProgram(Map.of(), List.of(RISCVInstruction.NOP()));
        var tests = List.<TestCase>of(new RISCVTestCase(program, program, 2, 7));
        Path scratch = Files.createDirectory(temp.resolve("scratch with spaces"));
        for (int threads : new int[]{1, 2}) {
            var results = new SpikeAtomParallelRunner(lib, "RV32IM",
                    EnumSet.allOf(RISCV_OBSERVATION_TYPE.class), threads, scratch, ExecutionModel.RV32_V1).run(tests);
            assertEquals(7, results.get(0).caseIndex());
            assertTrue(results.get(0).requiresMisalignedDataAccess());
            assertNotNull(contractgen.riscv.rocket_test.RocketTestConfiguration.unsupportedReason(results.get(0)));
            try (var files = Files.list(scratch)) { assertEquals(0, files.count()); }
        }
    }

    @Test void incompatibleNativeModelIsRejected() throws Exception {
        Path lib = library("other-model");
        assertThrows(IllegalStateException.class,
                () -> new SpikeAtomClient(lib, ExecutionModel.RV32_V1).runAllJson("[]", "RV32IM"));
    }

    @Test void incompleteDuplicateAndMismatchedEvidenceIsRejected() throws Exception {
        var program = new RISCVProgram(Map.of(), List.of(RISCVInstruction.NOP()));
        var tests = List.<TestCase>of(new RISCVTestCase(program, program, 2, 7),
                new RISCVTestCase(program, program, 2, 8));
        String first = "{\"ordinal\":0,\"case_index\":7}";
        for (String cases : List.of(first, first + "," + first,
                first + ",{\"ordinal\":1,\"case_index\":99}",
                first + ",{\"ordinal\":2,\"case_index\":8}")) {
            Path lib = library("rv32-v1", cases);
            for (int threads : new int[]{1, 2}) {
                assertThrows(IllegalStateException.class, () -> new SpikeAtomParallelRunner(lib, "RV32IM",
                        EnumSet.allOf(RISCV_OBSERVATION_TYPE.class), threads, temp,
                        ExecutionModel.RV32_V1).run(tests));
            }
        }
    }

    public static class NoisyWorker {
        public static void main(String[] args) throws Exception {
            System.out.println("noise".repeat(100000));
            if (args.length > 0) {
                Files.writeString(Path.of(args[0]), Long.toString(ProcessHandle.current().pid()));
                Thread.sleep(60000);
            }
        }
    }

    @Test void noisyAndTimedOutWorkersCannotBlockExtraction() throws Exception {
        List<String> command = new ArrayList<>(List.of(Path.of(System.getProperty("java.home"), "bin", "java").toString(),
                "-cp", System.getProperty("java.class.path"), NoisyWorker.class.getName()));
        Path log = temp.resolve("worker.log");
        SpikeAtomParallelRunner.runWorker(command, log, 5, TimeUnit.SECONDS);
        assertTrue(Files.size(log) > 65536);
        Path pid = temp.resolve("worker.pid");
        command.add(pid.toString());
        var error = assertThrows(IllegalStateException.class,
                () -> SpikeAtomParallelRunner.runWorker(command, log, 2, TimeUnit.SECONDS));
        assertTrue(error.getMessage().contains("timed out"));
        assertTrue(error.getMessage().length() < 9000);
        assertFalse(ProcessHandle.of(Long.parseLong(Files.readString(pid)))
                .map(ProcessHandle::isAlive).orElse(false));
    }

    @Test void metadataPreventsMixingModelsIsaAndChangedArtifacts() throws Exception {
        Path artifact = temp.resolve("testcases.json");
        Files.writeString(artifact, "[]");
        ExecutionMetadata.validate(artifact, ExecutionModel.RV32_V1, "RV32IM");
        ExecutionMetadata.write(artifact, ExecutionModel.RV32_V1, "RV32IM");
        ExecutionMetadata.validate(artifact, ExecutionModel.RV32_V1, "rv32im");
        String originalMetadata = Files.readString(ExecutionMetadata.path(artifact));
        Files.writeString(ExecutionMetadata.path(artifact), originalMetadata.replace("rv32-v1", "legacy-v1"));
        assertThrows(IllegalArgumentException.class,
                () -> ExecutionMetadata.validate(artifact, ExecutionModel.RV32_V1, "RV32IM"));
        Files.writeString(ExecutionMetadata.path(artifact), originalMetadata);
        assertThrows(IllegalArgumentException.class,
                () -> ExecutionMetadata.validate(artifact, ExecutionModel.RV32_V1, "RV32I"));
        Files.writeString(artifact, "[{}]");
        assertThrows(IllegalArgumentException.class,
                () -> ExecutionMetadata.validate(artifact, ExecutionModel.RV32_V1, "RV32IM"));
    }
}
