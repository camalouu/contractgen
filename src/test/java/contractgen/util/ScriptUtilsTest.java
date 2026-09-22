package contractgen.util;

import org.junit.jupiter.api.Test;
import java.nio.file.Path;
import static org.junit.jupiter.api.Assertions.*;

class ScriptUtilsTest {
    private java.util.List<String> command(String mode) throws Exception {
        String classes = Path.of(Child.class.getProtectionDomain().getCodeSource().getLocation().toURI()).toString();
        return java.util.List.of(Path.of(System.getProperty("java.home"), "bin", "java").toString(),
                "-cp", classes, Child.class.getName(), mode);
    }

    @Test
    void drainsMoreThanAPipeBufferBeforeWaitingForExit() throws Exception {
        String output = ScriptUtils.runScript(command("verbose"), Path.of("."), true, 5);
        assertNotNull(output);
        assertTrue(output.contains("OUTPUT_COMPLETE"));
        assertFalse(output.contains("Process exited with code"));
    }

    @Test
    void preservesOutputAndFailureMarkerOnTimeout() throws Exception {
        String output = ScriptUtils.runScript(command("timeout"), Path.of("."), true, 1);
        assertNotNull(output);
        assertTrue(output.contains("STARTED"));
        assertTrue(output.contains("timed out"));
        assertTrue(output.contains("Process exited with code"));
    }

    @Test
    void preservesNonzeroExitAndMergedStderr() throws Exception {
        String output = ScriptUtils.runScript(command("failure"), Path.of("."), true, 5);
        assertTrue(output.contains("COMPILER_DIAGNOSTIC"));
        assertTrue(output.contains("Process exited with code 7"));
    }

    public static class Child {
        public static void main(String[] args) throws Exception {
            switch (args[0]) {
                case "verbose" -> {
                    for (int i = 0; i < 20000; i++) System.out.println("compiler output line " + i);
                    System.err.println("OUTPUT_COMPLETE");
                }
                case "timeout" -> {
                    System.out.println("STARTED");
                    System.out.flush();
                    Thread.sleep(30000);
                }
                case "failure" -> {
                    System.err.println("COMPILER_DIAGNOSTIC");
                    System.exit(7);
                }
            }
        }
    }
}
