package contractgen.util;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Util methods related to running scripts.
 */
public class ScriptUtils {

    /**
     * @param path       The path of the script.
     * @param silent     Whether the output should be printed to the console.
     * @param maxSeconds The timeout in seconds.
     * @return The console output.
     */
    public static String runScript(String path, boolean silent, int maxSeconds) {
        java.nio.file.Path executable = java.nio.file.Path.of(path).toAbsolutePath();
        return runScript(List.of(executable.toString()), executable.getParent(), silent, maxSeconds);
    }

    /** Execute arguments without shell splitting, in an explicit working directory. */
    public static String runScript(List<String> command, java.nio.file.Path directory,
                                   boolean silent, int maxSeconds) {
        Process p = null;
        StringBuffer output = new StringBuffer();
        try {
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.directory(directory.toFile());
            pb.environment().putIfAbsent("CONTRACTGEN_RESOURCE_ROOT", RuntimePaths.resource("").toString());
            pb.environment().putIfAbsent("CONTRACTGEN_WORK_ROOT", RuntimePaths.work("").toString());
            pb.redirectErrorStream(true);
            // A newly written executable can briefly be busy. Bound retries so
            // a missing executable or permission failure cannot loop forever.
            for (int attempt = 0; ; attempt++) {
                try {
                    p = pb.start();
                    break;
                } catch (IOException e) {
                    if (attempt == 2) throw e;
                    Thread.sleep(50);
                }
            }
            Process process = p;
            AtomicReference<IOException> readFailure = new AtomicReference<>();
            Thread drainer = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) output.append(line).append(System.lineSeparator());
                } catch (IOException e) {
                    readFailure.set(e);
                }
            }, "contract-script-output");
            drainer.setDaemon(true);
            drainer.start();
            boolean completed = p.waitFor(maxSeconds, TimeUnit.SECONDS);
            if (!completed) terminateTree(p);
            drainer.join(2000);
            if (!completed) {
                output.append("Process exited with code TIMEOUT: process timed out after ")
                        .append(maxSeconds).append(" seconds.").append(System.lineSeparator());
            } else if (drainer.isAlive() || readFailure.get() != null) {
                output.append("Process exited with code OUTPUT_ERROR: could not finish reading output.")
                        .append(System.lineSeparator());
            } else if (p.exitValue() != 0) {
                output.append("Process exited with code ").append(p.exitValue()).append(System.lineSeparator());
            }
        } catch (IOException e) {
            output.append("Process exited with code START_ERROR: ").append(e).append(System.lineSeparator());
        } catch (InterruptedException e) {
            if (p != null) terminateTree(p);
            Thread.currentThread().interrupt();
            output.append("Process exited with code INTERRUPTED.").append(System.lineSeparator());
        }
        if (!silent) System.out.println(output);
        return output.toString();
    }

    private static void terminateTree(Process process) {
        // Retain handles before killing the parent, which can reparent make's
        // compiler children. Those children can also keep the output pipe open.
        List<ProcessHandle> descendants = process.descendants().toList();
        for (int i = descendants.size() - 1; i >= 0; i--) descendants.get(i).destroyForcibly();
        process.destroyForcibly();
    }
}
