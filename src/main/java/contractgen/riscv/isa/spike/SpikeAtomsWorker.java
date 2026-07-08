package contractgen.riscv.isa.spike;

import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.concurrent.Callable;

@Command(name = "spike_atoms_worker", hidden = true, description = "Internal worker for process-isolated Spike atom extraction.")
public class SpikeAtomsWorker implements Callable<Integer> {
    @Option(names = {"--testcases"}, required = true)
    File testcases;

    @Option(names = {"--output"}, required = true)
    File output;

    @Option(names = {"--spike-lib"}, required = true)
    File spikeLib;

    @Option(names = {"--spike-isa"}, defaultValue = "RV32IM_Zicclsm")
    String spikeIsa;

    @Override
    public Integer call() {
        try {
            SpikeAtomClient spike = new SpikeAtomClient(spikeLib.toPath());
            String json = spike.runAllJson(Files.readString(testcases.toPath()), spikeIsa);
            Files.writeString(output.toPath(), json);
            return 0;
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}
