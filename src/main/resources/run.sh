#!/usr/bin/env bash
set -euo pipefail

cd /home/yosys/project
mvn clean package

platform="IBEX"
# platform="CVA6"
count=10000
reps=1

json_out="/home/yosys/project/${platform,,}-${count}-base-results.json"
txt_out="/home/yosys/project/${platform,,}-${count}-base-results.txt"

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synthesize \
#   -p "$platform" \
#   -i BASE,M \
#   -c BASE \
#   -n "$count" \
#   -t 8 \
#   -s 51 \
#   -o "$json_out" \
#   --txt "$txt_out" \
#   --verilator \
  # --random-suffix \
  # --reps "$reps" \
  # --reset-sequence \
  # --random-prefix \
  # --bit-dist \
  # -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
  #
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main export_tests \
#   -p "$platform" \
#   -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
#   -i BASE,M \
#   -n "$count" \
#   -t 8 \
#   -s 58 \
#   -o "${count}-${platform}-full-testcases.json" \
#   --verilator \
  # --random-suffix \
  # --results-output "${json_out}" \
  # --reps 3
#
# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
# -p "$platform" \
# -i BASE,M \
# -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
# -t 8 \
# -e "${count}-${platform}-full-testcases.json" \
# -o "ibex-fulltemplate-10k-replay-result.json" \
# --txt "ibex-fulltemplate-10k-replay-result.txt" \
# --verilator 


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
# -e "887-CVA6-testcases.json" \
# -o "cva6-test-attacker-harness-compare.json" \

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize_spike \
-i BASE,M \
-c BASE,ALIGNED,BRANCH,DEPENDENCIES \
-t 8 \
-e "${count}-${platform}-full-testcases.json" \
-o "${count}-${platform}-full-adaptive-result.json" \
--txt "${count}-${platform}-full-adaptive-result.txt" \
--negative-signature-threshold 10 \
# --skip-negative-subsets \
# --skip-positive-supersets \
# --use-skipped-evidence \

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
-p "IBEX" \
-i BASE,M \
-c BASE,ALIGNED,BRANCH,DEPENDENCIES \
-t 8 \
-e "${count}-${platform}-full-testcases.json" \
-o "${count}-${platform}-full-replay-result.json" \
--txt "${count}-${platform}-full-replay-result.txt" \
--verilator \

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main evaluate \
# -c "150000-IBEX-base-replay-result.json" \
# -e "ibex-500000-base-results.json" \
# -o "original-stats-150k-500k" 

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main evaluate \
# -c "150000-IBEX-base-adaptive-result.json" \
# -e "ibex-500000-base-results.json" \
# -o "adaptive-stats-150k-500k" 
