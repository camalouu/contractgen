#!/usr/bin/env bash
set -euo pipefail

cd /home/yosys/project
mvn -q package

platform="IBEX"
count=1000
suffix="test"

json_out="/home/yosys/project/${platform,,}-${count}-${suffix}.json"
txt_out="/home/yosys/project/${platform,,}-${count}-${suffix}.txt"

java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synthesize \
  -p "$platform" \
  -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
  -n "$count" \
  -t 8 \
  -s 88 \
  -o "$json_out" \
  --txt "$txt_out" \
  --verilator \
  --reps 1 \
  --bit-dist \
