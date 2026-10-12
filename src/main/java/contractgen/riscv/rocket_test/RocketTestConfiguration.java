package contractgen.riscv.rocket_test;

import contractgen.riscv.isa.spike.ExecutionModel;
import contractgen.riscv.isa.spike.SpikeAtomClient;

/** Fixed experiment identity; external libraries must be built from these sources. */
public final class RocketTestConfiguration {
    public static final String SOURCE_REVISION = "55bcad0f59436de98ea510334121de8546b9e9d7";
    private RocketTestConfiguration() {}

    public static String unsupportedReason(SpikeAtomClient.SpikeCaseAtoms evidence) {
        return evidence.requiresMisalignedDataAccess()
                ? "Rocket configuration does not support misaligned scalar data accesses" : null;
    }

    public static String description() {
        return "Rocket: RV32IM M-mode, I/D L1=64 sets x 4 ways x 64 bytes, blocking D-cache, "
                + "BTB enabled, mulUnroll=8, mul/div early-out; separate persistent data memory; "
                + "source=" + SOURCE_REVISION + "; execution model=" + ExecutionModel.RV32_V1;
    }
}
