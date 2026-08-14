package contractgen.riscv.isa.spike;

import com.google.gson.Gson;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import contractgen.riscv.isa.RISCV_TYPE;
import contractgen.riscv.isa.contract.RISCVObservation;
import contractgen.riscv.isa.contract.RISCV_OBSERVATION_TYPE;
import contractgen.util.Pair;

import java.nio.file.Path;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.OptionalInt;
import java.util.Set;

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
                .map(c -> atoms(c, allowed))
                .toList();
    }

    private static SpikeCaseAtoms atoms(SpikeCase spikeCase, Set<RISCV_OBSERVATION_TYPE> allowed) {
        Set<RISCVObservation> observations = new java.util.TreeSet<>(Comparator.comparing(RISCVObservation::type).thenComparing(RISCVObservation::observation));
        Map<RISCVObservation, Integer> firstRetire = new LinkedHashMap<>();
        Set<Pair<RISCV_TYPE, RISCV_TYPE>> instructionPairs = new java.util.TreeSet<>(instructionPairComparator());
        Map<Pair<RISCV_TYPE, RISCV_TYPE>, Integer> pairFirstRetire = new LinkedHashMap<>();
        if (spikeCase.atoms != null) {
            for (SpikeAtom atom : spikeCase.atoms) {
                RISCVObservation observation = new RISCVObservation(
                        RISCV_TYPE.valueOf(atom.type),
                        RISCV_OBSERVATION_TYPE.valueOf(atom.observation));
                if (!allowed.contains(observation.observation())) {
                    continue;
                }
                observations.add(observation);
                if (atom.first_retire != null) {
                    firstRetire.merge(observation, atom.first_retire, Math::min);
                }
            }
        }
        if (spikeCase.instruction_pairs != null) {
            for (SpikeInstructionPair rawPair : spikeCase.instruction_pairs) {
                Pair<RISCV_TYPE, RISCV_TYPE> pair = new Pair<>(
                        RISCV_TYPE.valueOf(rawPair.left), RISCV_TYPE.valueOf(rawPair.right));
                instructionPairs.add(pair);
                if (rawPair.first_retire != null) {
                    pairFirstRetire.merge(pair, rawPair.first_retire, Math::min);
                }
            }
        }
        return new SpikeCaseAtoms(spikeCase.ordinal, spikeCase.case_index, observations, firstRetire,
                instructionPairs, pairFirstRetire, spikeCase.error);
    }

    public record SpikeCaseAtoms(
            int ordinal,
            int caseIndex,
            Set<RISCVObservation> atoms,
            Map<RISCVObservation, Integer> firstRetire,
            Set<Pair<RISCV_TYPE, RISCV_TYPE>> instructionPairs,
            Map<Pair<RISCV_TYPE, RISCV_TYPE>, Integer> pairFirstRetire,
            String error
    ) {
        public SpikeCaseAtoms {
            Set<RISCVObservation> sortedAtoms = new java.util.TreeSet<>(
                    Comparator.comparing(RISCVObservation::type).thenComparing(RISCVObservation::observation));
            sortedAtoms.addAll(atoms);
            atoms = Collections.unmodifiableSet(sortedAtoms);
            firstRetire = Collections.unmodifiableMap(new LinkedHashMap<>(firstRetire));
            Set<Pair<RISCV_TYPE, RISCV_TYPE>> sortedPairs = new java.util.TreeSet<>(instructionPairComparator());
            sortedPairs.addAll(instructionPairs);
            instructionPairs = Collections.unmodifiableSet(sortedPairs);
            pairFirstRetire = Collections.unmodifiableMap(new LinkedHashMap<>(pairFirstRetire));
        }

        /** Compatibility constructor for callers that only need the ordinary atom set. */
        public SpikeCaseAtoms(int ordinal, int caseIndex, Set<RISCVObservation> atoms, String error) {
            this(ordinal, caseIndex, atoms, Map.of(), Set.of(), Map.of(), error);
        }

        /** Compatibility constructor for callers with timed atoms but no instruction-pair metadata. */
        public SpikeCaseAtoms(int ordinal, int caseIndex, Set<RISCVObservation> atoms,
                              Map<RISCVObservation, Integer> firstRetire, String error) {
            this(ordinal, caseIndex, atoms, firstRetire, Set.of(), Map.of(), error);
        }

        public OptionalInt firstRetire(RISCVObservation atom) {
            Integer value = firstRetire.get(atom);
            return value == null ? OptionalInt.empty() : OptionalInt.of(value);
        }

        public OptionalInt firstRetire(Pair<RISCV_TYPE, RISCV_TYPE> pair) {
            Integer value = pairFirstRetire.get(pair);
            return value == null ? OptionalInt.empty() : OptionalInt.of(value);
        }
    }

    private static Comparator<Pair<RISCV_TYPE, RISCV_TYPE>> instructionPairComparator() {
        return Comparator.comparing((Pair<RISCV_TYPE, RISCV_TYPE> pair) -> pair.left().name())
                .thenComparing(pair -> pair.right().name());
    }

    private static final class SpikeResponse {
        List<SpikeCase> cases;
        String error;
    }

    private static final class SpikeCase {
        int ordinal;
        int case_index;
        List<SpikeAtom> atoms;
        List<SpikeInstructionPair> instruction_pairs;
        String error;
    }

    private static final class SpikeAtom {
        String type;
        String observation;
        Integer first_retire;
    }

    private static final class SpikeInstructionPair {
        String left;
        String right;
        Integer first_retire;
    }
}
