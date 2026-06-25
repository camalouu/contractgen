#!/usr/bin/env bash
set -euo pipefail

cd /home/yosys/project
mvn clean package

platform="IBEX"
# platform="CVA6"
count=20000
reps=1
suffix="test"

json_out="/home/yosys/project/${platform,,}-${count}-results.json"
txt_out="/home/yosys/project/${platform,,}-${count}-${reps}rep-${suffix}.txt"

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synthesize \
#   -p "$platform" \
#   -i BASE,M \
#   -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
#   -n "$count" \
#   -t 8 \
#   -s 51 \
#   -o "$json_out" \
#   --txt "$txt_out" \
#   --reps "$reps" \
#   --random-suffix \
#   --verilator \
  # --reset-sequence \
  # --random-prefix \
  # --bit-dist \

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main export_tests \
#   -p "$platform" \
#   -i BASE,M \
#   -c BASE \
#   -n "$count" \
#   -t 8 \
#   -s 58 \
#   -o "${count}-${platform}-testcases.json" \
#   --results-output "${json_out}" \
#   --verilator \
  # --random-suffix \
  # --reps 3
  # -c BASE,ALIGNED,BRANCH,DEPENDENCIES \

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
# -p "IBEX" \
# -i BASE,M \
# -c BASE \
# -t 8 \
# -e "20000-IBEX-testcases.json" \
# -o "ibex-20k-replay-result.json" \
# --verilator \
# --txt "${txt_out}-replay-result.txt" \


java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main compare_spike_rvfi_atoms \
-i BASE,M \
-c BASE,ALIGNED,BRANCH,DEPENDENCIES \
-t 8 \
-o "spike-rvfi-compare.json" \
-e "12000-IBEX-testcases.json" \
#
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main compare_ibex_test_attacker \
# -i BASE,M \
# -t 8 \
# -e "12000-IBEX-testcases.json" \
# -o "ibex-test-attacker-harness-compare.json" \

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize_spike \
# -i BASE,M \
# -c BASE \
# -t 8 \
# -e "20000-IBEX-testcases.json" \
# -o "adaptive-spike-20k-replay-results-skippedevidence.json" \
# --txt adaptive-spike-20k-replay-results-skippedevidence.txt \
# --use-skipped-evidence


# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main compact_tests \
#     -i "${count}-${platform}-clean-original-set.json" \
#     -o "/home/yosys/project/${count}-${platform}-compacted.json" \
    # --group-size 1
#     # --stats "/home/yosys/project/stats.txt"

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
# -p "$platform" \
# -i BASE,M \
# -c BASE \
# -t 8 \
# -e "${count}-${platform}-compacted.json" \
# -o "${count}-${platform}-replay-compacted-result.json" \
# --txt "${txt_out}-replay-compacted-result.txt" \
# --verilator \
