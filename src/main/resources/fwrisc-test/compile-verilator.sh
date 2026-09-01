#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$1"
OUT_DIR="$2"
CORE_ROOT="${CONTRACT_FWRISC_CORE_ROOT:-$SOURCE_DIR/core}"
COMMON_DIR="${CONTRACT_ATTACKER_COMMON_ROOT:-/home/yosys/resources/attacker-test-common}"
PROJECT_COMMON_DIR="${CONTRACT_ATTACKER_PROJECT_COMMON_ROOT:-/home/yosys/project/src/main/resources/attacker-test-common}"
if [[ -d "$COMMON_DIR/verif" ]]; then COMMON_ROOT="$COMMON_DIR"; else COMMON_ROOT="$PROJECT_COMMON_DIR"; fi
if [[ ! -f "$CORE_ROOT/rtl/fwrisc.sv" || ! -d "$COMMON_ROOT/verif" ]]; then
  echo "Cannot find FWRISC RTL or shared attacker-harness resources." >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

RTL_SOURCES=(
  "$CORE_ROOT"/rtl/fwrisc_regfile.sv "$CORE_ROOT"/rtl/fwrisc_mul_div_shift.sv
  "$CORE_ROOT"/rtl/fwrisc_tracer.sv "$CORE_ROOT"/rtl/fwrisc_fetch.sv
  "$CORE_ROOT"/rtl/fwrisc_c_decode.sv "$CORE_ROOT"/rtl/fwrisc_decode.sv
  "$CORE_ROOT"/rtl/fwrisc_alu.sv "$CORE_ROOT"/rtl/fwrisc_mem.sv
  "$CORE_ROOT"/rtl/fwrisc_exec.sv "$CORE_ROOT"/rtl/fwrisc.sv
)
VERIF_SOURCES=(
  "$COMMON_ROOT"/verif/data_mem.sv "$COMMON_ROOT"/verif/clk_sync.sv
  "$COMMON_ROOT"/verif/atk.sv "$COMMON_ROOT"/verif/control.sv
  "$SOURCE_DIR"/verif/fwrisc_test_top.sv
)

verilator --cc --top-module fwrisc_test_top -I"$CORE_ROOT/rtl" \
  -Wno-fatal -Wno-WIDTH -Wno-LATCH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE \
  --threads-dpi none -O3 --Mdir "$OUT_DIR/obj_dir_shared" \
  --exe "$SOURCE_DIR/verif/fwrisc_test_runtime.cpp" "$COMMON_ROOT/verif/simple_test_shared.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I$COMMON_ROOT/verif" -LDFLAGS "-shared -fPIC" \
  -o libcontract_fwrisc_test_attacker.so "${RTL_SOURCES[@]}" "${VERIF_SOURCES[@]}"
make -j -C "$OUT_DIR/obj_dir_shared" -f Vfwrisc_test_top.mk libcontract_fwrisc_test_attacker.so
cp "$OUT_DIR/obj_dir_shared/libcontract_fwrisc_test_attacker.so" "$OUT_DIR/libcontract_fwrisc_test_attacker.so"
test -f "$OUT_DIR/libcontract_fwrisc_test_attacker.so"
