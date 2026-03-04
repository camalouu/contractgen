#!/usr/bin/env bash
set -euo pipefail

cd /home/yosys/project
mvn -q package

platform="IBEX"
# platform="CVA6"
count=10
reps=1
suffix="test"

json_out="/home/yosys/project/${platform,,}-${count}-${reps}rep-${suffix}.json"
txt_out="/home/yosys/project/${platform,,}-${count}-${reps}rep-${suffix}.txt"

# java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synthesize \
#   -p "$platform" \
#   -i BASE,M \
#   -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
#   -n "$count" \
#   -t 8 \
#   -s 88 \
#   -o "$json_out" \
#   --txt "$txt_out" \
#   --reps "$reps" \
#   --verilator \
# --bit-dist \
# --random-prefix \

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main export_tests \
  -p "$platform" \
  -i BASE,M \
  -c BASE \
  -n "$count" \
  -t 8 \
  -s 88 \
  -o "${count}-${platform}-clean-original-set.json" \
  --verilator \
# --results-output "${json_out}" \

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
-p "$platform" \
-i BASE,M \
-c BASE \
-t 8 \
-e "${count}-${platform}-clean-original-set.json" \
-o "${count}-${platform}-replay-result.json" \
--txt "${txt_out}-replay-result.txt" \
--verilator \

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main compact_tests \
    -i "${count}-${platform}-clean-original-set.json" \
    -o "/home/yosys/project/${count}-${platform}-compacted.json" \
    --group-size 2
    # --stats "/home/yosys/project/stats.txt"

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main replay_synthesize \
-p "$platform" \
-i BASE,M \
-c BASE \
-t 8 \
-e "${count}-${platform}-compacted.json" \
-o "${count}-${platform}-replay-compacted-result.json" \
--txt "${txt_out}-replay-compacted-result.txt" \
--verilator \
