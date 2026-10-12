#!/usr/bin/env bash
set -euo pipefail

# platform="FWRISC_TEST"
# platform="CV32E40S_TEST"
# platform="CV32E40P_TEST"
# platform="PROTEUS_TEST"
platform="CVA6_TEST"
# platform="IBEX_TEST"
# platform="ROCKET_TEST"
count=1000
threads=8
seed=43
isa="BASE,M"
contract="BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE"

platform_lower=$(echo "$platform" | tr '[:upper:]' '[:lower:]')
output_dir="results/${platform_lower}-${count}-seed${seed}"

./run-nix.sh synth_new \
  -p "$platform" \
  -i "$isa" \
  -c "$contract" \
  -n "$count" \
  -t "$threads" \
  -s "$seed" \
  --output-dir "$output_dir" \
  --random-suffix \
  --disable-adaptive-skipping 
  # --cv32e40s-data-independent-timing=on \
