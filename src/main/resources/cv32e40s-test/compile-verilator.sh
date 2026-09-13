#!/usr/bin/env bash
set -euo pipefail
SOURCE_DIR="$(realpath "$1")"
mkdir -p "$2"
OUT_DIR="$(realpath "$2")"
CORE_ROOT="${CONTRACT_CV32E40S_CORE_ROOT:-$SOURCE_DIR/core}"
COMMON_ROOT="${CONTRACT_ATTACKER_COMMON_ROOT:-$SOURCE_DIR/../attacker-test-common}"
if [[ ! -d "$COMMON_ROOT/verif" ]]; then
  COMMON_ROOT=/home/yosys/resources/attacker-test-common
fi
test -f "$CORE_ROOT/rtl/cv32e40s_core.sv"
test -f "$COMMON_ROOT/verif/clk_sync.sv"
# Compile only the core and simulation primitives, not the upstream RVFI/UVM wrappers.
RTL_SOURCES=("$CORE_ROOT/rtl/include/cv32e40s_pkg.sv" "$CORE_ROOT/rtl/cv32e40s_if_c_obi.sv")
for source in "$CORE_ROOT"/rtl/*.sv; do
  [[ "$source" == */cv32e40s_if_c_obi.sv ]] || RTL_SOURCES+=("$source")
done
RTL_SOURCES+=("$CORE_ROOT/bhv/cv32e40s_sim_sffr.sv" "$CORE_ROOT/bhv/cv32e40s_sim_sffs.sv" "$CORE_ROOT/bhv/cv32e40s_sim_clock_gate.sv")
verilator --cc --top-module cv32e40s_test_top -I"$CORE_ROOT/rtl/include" \
  -Wno-fatal -Wno-WIDTH -Wno-LITENDIAN --threads-dpi none -O3 \
  "$SOURCE_DIR/verif/upstream.vlt" \
  --Mdir "$OUT_DIR/obj_dir" \
  --exe "$SOURCE_DIR/verif/cv32e40s_test_runtime.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I$SOURCE_DIR/verif" -LDFLAGS "-shared -fPIC" \
  -o libcontract_cv32e40s_test_attacker.so \
  "${RTL_SOURCES[@]}" "$COMMON_ROOT/verif/clk_sync.sv" \
  "$SOURCE_DIR/verif/cv32e40s_mem.sv" "$SOURCE_DIR/verif/cv32e40s_test_top.sv"
make -j "${CONTRACT_BUILD_JOBS:-4}" -C "$OUT_DIR/obj_dir" -f Vcv32e40s_test_top.mk
cp "$OUT_DIR/obj_dir/libcontract_cv32e40s_test_attacker.so" "$OUT_DIR/libcontract_cv32e40s_test_attacker.so"
