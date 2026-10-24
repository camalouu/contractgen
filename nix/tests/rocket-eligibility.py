"""A reached misaligned access is unsupported; an unreachable one is eligible."""
import json
import pathlib
import subprocess
import sys

application, directory = sys.argv[1:3]
processor = sys.argv[3] if len(sys.argv) > 3 else "ROCKET_TEST"
supports_misaligned = processor in {"IBEX_TEST", "IBEX_SMALL_TEST", "IBEX_MULT_DIV_TEST", "IBEX_CACHE_TEST", "CV32E40P_TEST", "CV32E40S_TEST"}
isa = "BASE" if processor in {"SODOR_2_TEST", "SODOR_5_TEST", "DARKRISCV_2_TEST", "DARKRISCV_3_TEST"} else "BASE,M"
root = pathlib.Path(directory)
root.mkdir(parents=True, exist_ok=True)
nop = {"type": "ADDI", "rd": 0, "rs1": 0, "imm": 0}
misaligned = {"type": "LH", "rd": 1, "rs1": 0, "imm": 1}
cases = []
for index, program in [(901, [misaligned, nop]), (907, [nop]),
                       (909, [{"type": "JAL", "rd": 0, "imm": 8}, misaligned, nop])]:
    cases.append(dict(index=index, registers1={}, registers2={}, program1=program,
                      program2=program, maxInstructionCount=3))
source = root / "cases.json"
source.write_text(json.dumps(cases))
output = root / "contract.json"
summary = root / "summary.txt"
subprocess.run([application, "replay_synthesize_spike", "-p", processor,
                "-i", isa, "-c", "BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE",
                "-t", "2", "-e", str(source),
                "-o", str(output), "--txt", str(summary), "--disable-adaptive-skipping"], check=True)
results = json.loads(output.read_text())["testResults"]
assert {result["index"] for result in results} == ({901, 907, 909} if supports_misaligned else {907, 909})
assert all(not result["adversaryDistinguishable"] for result in results)
unsupported = json.loads(pathlib.Path(str(output) + ".unsupported.json").read_text())
assert len(unsupported) == (0 if supports_misaligned else 1)
if not supports_misaligned:
    assert unsupported[0]["ordinal"] == 0 and unsupported[0]["caseIndex"] == 901
assert f"Unsupported For Core: {0 if supports_misaligned else 1}" in summary.read_text()
assert f"RTL Executed: {3 if supports_misaligned else 2}" in summary.read_text()
print(f"{processor} applies alignment eligibility without changing indices or inferring negatives")
