package contractgen.riscv.isa.spike;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;
import java.util.HashSet;

/** Sidecar provenance preserves existing testcase and contract JSON formats. */
public final class ExecutionMetadata {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private record Metadata(int version, String executionModel, String spikeIsa, String sha256) {}
    private ExecutionMetadata() {}

    public static Path path(Path artifact) {
        return artifact.resolveSibling(artifact.getFileName() + ".execution.json");
    }

    /** Reject collisions before an output can overwrite an artifact or sidecar. */
    public static void requireDistinctPaths(Path... paths) {
        var seen = new HashSet<Path>();
        for (Path path : paths) {
            if (path != null && !seen.add(path.toAbsolutePath().normalize()))
                throw new IllegalArgumentException("Artifact, metadata and summary paths must be distinct: " + path);
        }
    }

    public static void write(Path artifact, ExecutionModel model, String isa) throws IOException {
        Files.writeString(path(artifact), GSON.toJson(new Metadata(1, model.toString(), normalize(isa), digest(artifact))) + "\n");
    }

    public static void validate(Path artifact, ExecutionModel model, String isa) throws IOException {
        Path metadataPath = path(artifact);
        // Historical and explicitly imported testcase files have no sidecar.
        // The caller's explicit/default model governs those inputs.
        if (!Files.exists(metadataPath)) return;
        Metadata metadata = GSON.fromJson(Files.readString(metadataPath), Metadata.class);
        if (metadata == null || metadata.version != 1
                || !model.toString().equals(metadata.executionModel)
                || !normalize(isa).equals(metadata.spikeIsa)
                || !digest(artifact).equals(metadata.sha256)) {
            throw new IllegalArgumentException("Execution metadata mismatch for " + artifact
                    + "; use the recorded execution model and ISA, and the original artifact.");
        }
    }

    private static String normalize(String isa) { return isa.toUpperCase(Locale.ROOT); }
    private static String digest(Path artifact) throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (InputStream input = Files.newInputStream(artifact)) {
                byte[] buffer = new byte[65536];
                int size;
                while ((size = input.read(buffer)) != -1) digest.update(buffer, 0, size);
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
}
