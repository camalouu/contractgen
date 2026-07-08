package contractgen.riscv.isa.spike;

import com.google.gson.Gson;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;

import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

public final class SpikeAtomClient {
    private final ContractSpikeLibrary library;
    private static final Gson GSON = new Gson();

    private interface ContractSpikeLibrary extends Library {
        Pointer contract_spike_atoms_json(String testcasesJson, String isa, int ordinal);

        void contract_spike_free(Pointer pointer);
    }

    public SpikeAtomClient(Path libraryPath) {
        this.library = Native.load(libraryPath.toAbsolutePath().toString(), ContractSpikeLibrary.class);
    }

    public List<SpikeCaseAtoms> runAll(String testcasesJson, String isa, Set<RISCV_OBSERVATION_TYPE> allowed) {
        return parseResponse(runAllJson(testcasesJson, isa), allowed);
    }

    public String runAllJson(String testcasesJson, String isa) {
        Pointer pointer = library.contract_spike_atoms_json(testcasesJson, isa, -1);
        if (pointer == null) {
            throw new IllegalStateException("Spike atom library returned null");
        }
        try {
            return pointer.getString(0);
        } finally {
            library.contract_spike_free(pointer);
        }
    }

    public static List<SpikeCaseAtoms> parseResponse(String json, Set<RISCV_OBSERVATION_TYPE> allowed) {
        SpikeResponse response = GSON.fromJson(json, SpikeResponse.class);
        if (response == null) {
            throw new IllegalStateException("Spike atom library returned empty JSON");
        }
        if (response.error != null) {
            throw new IllegalStateException("Spike atom library failed: " + response.error);
        }
        if (response.cases == null) {
            return List.of();
        }
        return response.cases.stream()
                .map(c -> new SpikeCaseAtoms(c.ordinal, c.case_index, atoms(c.atoms, allowed), c.error))
                .toList();
    }

    private static Set<RISCVObservation> atoms(List<SpikeAtom> atoms, Set<RISCV_OBSERVATION_TYPE> allowed) {
        if (atoms == null) {
            return Set.of();
        }
        return atoms.stream()
                .map(a -> new RISCVObservation(RISCV_TYPE.valueOf(a.type), RISCV_OBSERVATION_TYPE.valueOf(a.observation)))
                .filter(a -> allowed.contains(a.observation()))
                .collect(Collectors.toCollection(() -> new java.util.TreeSet<>(Comparator.comparing(RISCVObservation::type).thenComparing(RISCVObservation::observation))));
    }

    public record SpikeCaseAtoms(int ordinal, int caseIndex, Set<RISCVObservation> atoms, String error) {
    }

    private static final class SpikeResponse {
        List<SpikeCase> cases;
        String error;
    }

    private static final class SpikeCase {
        int ordinal;
        int case_index;
        List<SpikeAtom> atoms;
        String error;
    }

    private static final class SpikeAtom {
        String type;
        String observation;
    }
}
