#!/usr/bin/env bash
set -euo pipefail

platform="CVA6"       # Options: IBEX, CVA6
count=24
threads=8
seed=35
isa="BASE,M"
contract="BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE"
use_verilator=false   # Set to false for Icarus Verilog (iverilog), true for Verilator

platform_lower=$(echo "$platform" | tr '[:upper:]' '[:lower:]')
sim_mode=$( [ "$use_verilator" = true ] && echo "verilator" || echo "iverilog" )
output_file="results/${platform_lower}-${sim_mode}-${count}-seed${seed}.json"
txt_file="results/${platform_lower}-${sim_mode}-${count}-seed${seed}.txt"

mkdir -p results

extra_args=()
if [ "$use_verilator" = true ]; then
  extra_args+=(--verilator)
fi

./run-nix.sh synthesize \
  -p "$platform" \
  -i "$isa" \
  -c "$contract" \
  -n "$count" \
  -t "$threads" \
  -s "$seed" \
  -o "$output_file" \
  --txt "$txt_file" \
  "${extra_args[@]}"
