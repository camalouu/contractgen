#!/usr/bin/env bash
set -euo pipefail

cd /home/yosys/project
mvn clean package

# platform="PROTEUS_TEST"
# platform="HAZARD3_TEST"
# platform="SODOR_2_TEST"
# platform="CVA6_TEST"
# platform="DARKRISCV_2_TEST"
# platform="FWRISC_TEST"
platform="CV32E40P_TEST"
count=100000

output_dir="/home/yosys/project/results/${platform,,}-${count}-seed31"

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synth_new \
  -p "$platform" \
  -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
  -n "$count" \
  -t 8 \
  -s 31 \
  --output-dir "$output_dir" \
  --disable-adaptive-skipping

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main export_tests \
#   -p "$platform" \
#   -c BASE,ALIGNED,BRANCH \
#   -i BASE,M \
#   -n "$count" \
#   -t 8 \
#   -s 58 \
#   -o "${count}-${platform}-full.json" \
#   --verilator \
#   --random-suffix \
#   --results-output "${count}-${platform}-fullvalue-results.json" \
#   --reps 3
#
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
# -p "$platform" \
# -i BASE,M \
# -c BASE,ALIGNED,BRANCH \
# -t 8 \
# -e "${count}-${platform}-full.json" \
# -o "${count}-${platform}-full-replay-results.json" \
# --txt "${count}-${platform}-full-replay-results.txt" \
# --verilator
#
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize_spike \
# -i BASE,M \
# -c BASE,ALIGNED,BRANCH \
# -t 8 \
# -e "${count}-${platform}-full.json" \
# -o "${count}-${platform}-full-replayspike-results.json" \
# --txt "${count}-${platform}-full-replayspike-results.txt" \
# --disable-adaptive-skipping
# --skip-negative-subsets \
# --skip-positive-supersets \
# --use-skipped-evidence \

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main compare_spike_rvfi_atoms \
# -i BASE,M \
# -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
# -t 8 \
# -e "10000-IBEX-full-testcases.json" \
# -o "spike-rvfi-compare.json" \
#
#
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main compare_ibex_test_attacker \
# -i BASE,M \
# -t 8 \
# -e "10000-IBEX-base-testcases.json" \
# -o "ibex-test-attacker-harness-compare.json" \
#
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main compare_cva6_test_attacker \
# -i BASE,M \
# -t 8 \
# -e "2235-CVA6-full-testcases.json" \
# -o "cva6-test-attacker-harness-compare.json" \


# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize_spike \
# -p IBEX_TEST \
# -i BASE,M \
# -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
# -t 8 \
# -e "25000-IBEX-fullvalue-testcases-nosuffix.json" \
# -o "25000-IBEX-fullvalue-testcases-nosuffix-results.json" \
# --txt "25k-ibex-fullvalue.txt" \
# --negative-signature-threshold 10 \
# --skip-negative-subsets \
# --skip-positive-supersets \
# --use-skipped-evidence \

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
# -p "CVA6" \
# -i BASE,M \
# -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
# -t 8 \
# -e "887-CVA6-testcases.json" \
# -o "887-CVA6-full-replay-result.json" \
# --txt "887-CVA6-full-replay-result.txt" \
# --verilator \

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main evaluate \
# -c "ibex-10000-full-results.json" \
# -e "ibex-fulltemplate-100k-replay-result.json" \
# -o "original-stats-10k-100k" 
#
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main evaluate \
# -c "ibex-10k-refuned-results.json" \
# -e "ibex-fulltemplate-100k-replay-result.json" \
# -o "refined-stats-10k-100k" 

# if [[ ! -x "$refinement_python" ]]; then
#     echo "Missing Z3 Python environment: $refinement_python" >&2
#     echo "Rebuild the Compose image with: docker compose build yosys" >&2
#     exit 1
# fi
# if ! "$refinement_python" -c 'import z3' >/dev/null 2>&1; then
#     echo "Python environment cannot import z3: $refinement_python" >&2
#     echo "Rebuild the Compose image with: docker compose build yosys" >&2
#     exit 1
# fi

# refinement_python="${CONTRACTGEN_PYTHON:-/opt/contractgen-python/bin/python}"
# java --enable-native-access=ALL-UNNAMED \
#     -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main refine_z3 \
#     --results "filtered-nodep-500k.json" \
#     --output "refined-results-500k.json" \
#     --artifacts "refined-artifacts-500k" \
#     --threads 8 \
#     --max-tests 1000 \
#     --solver-timeout-ms 300000 \
#     --python "$refinement_python" \
#     --generator-dir /home/yosys/project/abstraction-guided-test-case-generation \
#     --spike-lib /home/yosys/project/riscv-isa-sim/build/libcontract_spike_atom.so
