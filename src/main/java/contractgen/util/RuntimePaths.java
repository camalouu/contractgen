package contractgen.util;

import java.nio.file.Path;

/** Immutable input resources and writable experiment build directories. */
public final class RuntimePaths {
    private RuntimePaths() {}

    public static Path resource(String relative) {
        return root("CONTRACTGEN_RESOURCE_ROOT", "./src/main/resources").resolve(relative).normalize();
    }

    public static Path work(String relative) {
        return root("CONTRACTGEN_WORK_ROOT", "./results/.work").resolve(relative).normalize();
    }

    private static Path root(String variable, String fallback) {
        String value = System.getenv(variable);
        return Path.of(value == null || value.isBlank() ? fallback : value).toAbsolutePath().normalize();
    }
}
