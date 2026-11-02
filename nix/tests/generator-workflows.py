"""Small native generator/replay acceptance matrix; no research datasets."""
import json
import subprocess
import sys
from pathlib import Path

app, destination = sys.argv[1:3]
root = Path(destination).resolve()
root.mkdir(parents=True, exist_ok=True)
compare = Path(sys.argv[3]) if len(sys.argv) > 3 else Path(__file__).with_name("compare-replay.py")
for processor in ("IBEX_TEST", "CVA6_TEST"):
    common = ["--processor", processor, "--isa", "BASE", "--contract", "BASE,DEPENDENCIES,VALUE",
              "--disable-adaptive-skipping"]
    for strategy in ("current", "different_programs", "same_programs", "coverage_guided", "random"):
        outputs = []
        for threads in ((1,) if strategy == "current" else (1, 8)):
            output = root / f"{processor}-{strategy}-{threads}"
            options = [] if strategy == "current" else ["--generation-batch-size", "2"]
            subprocess.run([app, "synth_new", *common, "--strategy", strategy, "-n", "8", "-s", "42",
                            "-t", str(threads), "--output-dir", str(output), *options], check=True)
            outputs.append(output)
        if len(outputs) == 2:
            assert (outputs[0] / "testcases.json").read_bytes() == (outputs[1] / "testcases.json").read_bytes()
            subprocess.run([sys.executable, str(compare), str(outputs[0] / "contract.json"),
                            str(outputs[1] / "contract.json")], check=True)
        original = outputs[0]
        replay = root / f"{processor}-{strategy}-replay"
        subprocess.run([app, "synth_new", *common, "--strategy", "replay", "--testcases",
                        str(original / "testcases.json"), "-t", "2", "--output-dir", str(replay)], check=True)
        subprocess.run([sys.executable, str(compare), str(original / "contract.json"),
                        str(replay / "contract.json")], check=True)
        assert json.loads((replay / "testcases.json").read_text()) == json.loads((original / "testcases.json").read_text())
print("All generator strategies synthesize and reproduce on Ibex and CVA6")
