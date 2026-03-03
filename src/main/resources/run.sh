#!/usr/bin/env bash
set -euo pipefail

cd /home/yosys/project
mvn -q package

platform="IBEX"
# platform="CVA6"
count=1000
reps=12
suffix="test"

json_out="/home/yosys/project/${platform,,}-${count}-${reps}rep-${suffix}.json"
txt_out="/home/yosys/project/${platform,,}-${count}-${reps}rep-${suffix}.txt"

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synthesize \
  -p "$platform" \
  -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
  -n "$count" \
  -t 8 \
  -s 88 \
  -o "$json_out" \
  --txt "$txt_out" \
  --reps "$reps" \
  --verilator \
  # --bit-dist \
  # --random-prefix \
