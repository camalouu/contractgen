#!/usr/bin/env bash
set -euo pipefail

# platform="FWRISC_TEST"
# platform="CV32E40S_TEST"
# platform="CV32E40P_TEST"
# platform="PROTEUS_TEST"
platform="CVA6_TEST"
# platform="ROCKET_TEST"
# platform="IBEX_SMALL_TEST"
# platform="DARKRISCV_3_TEST"
# platform="SODOR_5_TEST"
count=100000
threads=8
seed=2
# isa="BASE,M"
isa="BASE"
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
  --disable-adaptive-skipping 
  # --random-suffix \
  # --cv32e40s-data-independent-timing=on \
