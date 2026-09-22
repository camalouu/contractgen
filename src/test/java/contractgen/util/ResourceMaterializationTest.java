package contractgen.util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

class ResourceMaterializationTest {
    @TempDir Path directory;

    @Test void materializesReadonlySymlinkWithoutChangingOriginal() throws Exception {
        Path original = directory.resolve("original");
        Files.writeString(original, "immutable");
        original.toFile().setWritable(false);
        Path source = Files.createDirectory(directory.resolve("resources"));
        Files.createSymbolicLink(source.resolve("linked"), original);
        Path copy = directory.resolve("work with spaces");
        FileUtils.copyFileOrFolder(source.toFile(), copy.toFile());
        assertFalse(Files.isSymbolicLink(copy.resolve("linked")));
        Files.writeString(copy.resolve("linked"), "modified");
        assertEquals("immutable", Files.readString(original));
    }

    @Test void preservesArgumentsAndWorkingDirectoryWithSpaces() throws Exception {
        Path work = Files.createDirectory(directory.resolve("work with spaces"));
        String output = ScriptUtils.runScript(List.of("bash", "-c",
                "printf '%s\\n' \"$PWD\" \"$1\"", "test", "argument with spaces"), work, true, 5);
        assertEquals(work + System.lineSeparator() + "argument with spaces" + System.lineSeparator(), output);
    }
}
