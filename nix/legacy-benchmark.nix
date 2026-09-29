{ pkgs, resources, tools }:
core: pkgs.stdenv.mkDerivation {
  pname = "contractgen-legacy-engine-${core}";
  version = "1";
  src = resources.assemble [ core ];
  nativeBuildInputs = tools.simulation ++ [ tools.iverilog ];
  dontUnpack = true;
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    mkdir resources
    cp -rL $src/${core} resources/${core}
    chmod -R u+w resources
    export CONTRACTGEN_RESOURCE_ROOT="$PWD/resources"
    export CONTRACT_BUILD_JOBS="''${NIX_BUILD_CORES:-2}"
    if ! bash resources/${core}/compile.sh "$PWD/resources/${core}" "$PWD/translated" ${if core == "ibex" then "BASE" else ""} > compile-icarus.log 2>&1; then
      tail -n 60 compile-icarus.log
      exit 1
    fi
    cd translated
    ${pkgs.lib.optionalString (core == "cva6") ''
      # The checked-in Yosys netlist puts source-location attributes inside
      # expressions. Icarus accepts them; Verilator 5.008 does not. Attributes
      # carry no logic, and the Icarus binary was already built from the same
      # unmodified translated netlist.
      sed -i -E 's/\(\* src = "[^"]*" \*\)//g' cva6.v
      # Verilator 5.008 misidentifies some long escaped Yosys function-result
      # names containing punctuation. Rename each complete escaped token to a
      # stable internal identifier; declarations and references change together.
      python3 - <<'PY'
import hashlib
import re
from pathlib import Path
path = Path("cva6.v")
source = path.read_text()
def rename(match):
    token = match.group(1)
    if "$func$" not in token:
        return match.group(0)
    digest = hashlib.sha256(token.encode()).hexdigest()[:24]
    return "\\benchfn_" + digest
updated, count = re.subn(r"\\([^\s]+)", rename, source)
path.write_text(updated)
print(f"Canonicalized {count} escaped function-result occurrences")
PY
    ''}
    if ! verilator --binary --timing --trace --top-module top \
      -Wno-fatal -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-LATCH \
      -Wno-COMBDLY -Wno-STMTDLY -Wno-WIDTH -Wno-PINMISSING \
      --Mdir obj_dir_benchmark -j "''${NIX_BUILD_CORES:-2}" *.v > ../compile-verilator.log 2>&1; then
      grep -m 20 -E '^%Error' ../compile-verilator.log || true
      tail -n 60 ../compile-verilator.log
      exit 1
    fi
    # Keep the same translated RTL and full testbench, but remove only VCD
    # system tasks for a separate waveform-cost comparison.
    sed -i -E '/^[[:space:]]*\$dump(file|vars)[[:space:]]*\(/d' top.v
    if ! verilator --binary --timing --top-module top \
      -Wno-fatal -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-LATCH \
      -Wno-COMBDLY -Wno-STMTDLY -Wno-WIDTH -Wno-PINMISSING \
      --Mdir obj_dir_no_trace -j "''${NIX_BUILD_CORES:-2}" *.v > ../compile-no-trace.log 2>&1; then
      grep -m 20 -E '^%Error' ../compile-no-trace.log || true
      tail -n 60 ../compile-no-trace.log
      exit 1
    fi
    # The contract observer is a single top-level instance in each legacy
    # bench. Remove exactly that instance; keep cores, memories, control and
    # attacker wiring unchanged. Verilator will prune unused RVFI logic.
    python3 - <<'PY'
import re
from pathlib import Path
path = Path("top.v")
source = path.read_text()
updated, count = re.subn(r"\bctr\s+ctr\s*\(.*?\);", "", source, flags=re.S)
if count != 1:
    raise SystemExit(f"expected one contract observer, found {count}")
# The legacy testbench classifies both contract and attacker outcomes. Once
# Spike supplies contract evidence, its attacker-only form treats the contract
# side as satisfied and reports the raw attacker divergence.
updated += "\n"
updated, module_count = re.subn(r"\bendmodule\b", "assign ctr_equiv = 1'b1;\nendmodule", updated, count=1)
if module_count != 1:
    raise SystemExit("could not locate benchmark top module")
path.write_text(updated)
PY
    if ! verilator --binary --timing --top-module top \
      -Wno-fatal -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-LATCH \
      -Wno-COMBDLY -Wno-STMTDLY -Wno-WIDTH -Wno-PINMISSING \
      --Mdir obj_dir_attacker_only -j "''${NIX_BUILD_CORES:-2}" *.v > ../compile-attacker-only.log 2>&1; then
      grep -m 20 -E '^%Error' ../compile-attacker-only.log || true
      tail -n 60 ../compile-attacker-only.log
      exit 1
    fi
    runHook postBuild
  '';
  installPhase = ''
    mkdir -p $out/bin $out/share/contractgen-benchmark
    cp ${if core == "ibex" then "ibex" else "ariane"} $out/bin/${core}-icarus
    cp obj_dir_benchmark/Vtop $out/bin/${core}-verilator
    cp obj_dir_no_trace/Vtop $out/bin/${core}-verilator-no-trace
    cp obj_dir_attacker_only/Vtop $out/bin/${core}-verilator-attacker-only
    cp ../compile-icarus.log ../compile-verilator.log ../compile-no-trace.log ../compile-attacker-only.log $out/share/contractgen-benchmark/
  '';
}
