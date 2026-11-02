package contractgen;
import org.junit.jupiter.api.Test;
import picocli.CommandLine;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
class GeneratorOptionsTest {
 private SynthesizeNew parse(String... options) {
  var command=new SynthesizeNew();var args=new ArrayList<>(List.of("-p","IBEX_TEST","-i","BASE","-c","BASE","-t","1","-o","/tmp/unused.json"));
  args.addAll(List.of(options));new CommandLine(command).parseArgs(args.toArray(String[]::new));return command;
 }
 @Test void requiresCountAndSeedOnlyForGeneratedSources() {
  assertThrows(IllegalArgumentException.class,()->parse().validateGenerationOptions());
  parse("--strategy","replay","--testcases","cases.json").validateGenerationOptions();
  parse("--strategy","random","-n","5","-s","0").validateGenerationOptions();
 }
 @Test void replayInputCannotBeOverwrittenByOutputMetadata() {
  var command=parse("--strategy","replay","--testcases","/tmp/unused.json.execution.json");
  assertThrows(IllegalArgumentException.class,command::call);
 }
 @Test void explicitCurrentOptionsAreRejectedEvenAtDefaultValues() {
  assertThrows(IllegalArgumentException.class,()->parse("--strategy","random","-n","5","-s","0","--reps","1").validateGenerationOptions());
  assertThrows(IllegalArgumentException.class,()->parse("--strategy","current","-n","5","-s","0","--register-values","full").validateGenerationOptions());
  assertThrows(IllegalArgumentException.class,()->parse("--strategy","same_programs","-n","5","-s","0","--program-length","3").validateGenerationOptions());
  assertFalse(parse("--strategy","random","-n","5","-s","0","--no-skip-init").skipInit);
 }
}
