#!/usr/bin/env bash
set -euo pipefail
SOURCE_DIR="$(realpath "$1")"
OUT_DIR="$(realpath -m "$2")"
CORE_ROOT="${CONTRACT_PICCOLO_CORE_ROOT:-$SOURCE_DIR/core}"
COMMON_ROOT="${CONTRACT_ATTACKER_COMMON_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/attacker-test-common}"
COMMON_ROOT="$(realpath "$COMMON_ROOT")"
[[ -f "$CORE_ROOT/LICENSE" && -f "$COMMON_ROOT/verif/simple_test_shared.cpp" ]] || { echo 'Missing Piccolo or shared resources' >&2; exit 1; }
mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/rtl" "$OUT_DIR/obj_dir"
python3 "$SOURCE_DIR/prepare.py" "$CORE_ROOT" "$OUT_DIR"
# The optimized 5.008 compiler crashes while linking this generated hierarchy.
# Use the debug compiler shipped by the same pinned package, without debug
# dumps; the resulting model is still compiled with the normal C++ flags.
export VERILATOR_BIN="${VERILATOR_BIN:-verilator_bin_dbg}"
verilator --cc --no-timing --top-module piccolo_test_top -Wno-fatal -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT \
  -y "$OUT_DIR/rtl" -y "$CORE_ROOT/src_bsc_lib_RTL" \
  --Mdir "$OUT_DIR/obj_dir" --exe "$SOURCE_DIR/verif/piccolo_runtime.cpp" "$COMMON_ROOT/verif/simple_test_shared.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I$COMMON_ROOT/verif -I$SOURCE_DIR/verif" -LDFLAGS '-shared -fPIC' \
  -o libcontract_piccolo_test_attacker.so "$OUT_DIR/piccolo_test_top.sv"
make -j "${CONTRACT_BUILD_JOBS:-4}" -C "$OUT_DIR/obj_dir" -f Vpiccolo_test_top.mk
cp "$OUT_DIR/obj_dir/libcontract_piccolo_test_attacker.so" "$OUT_DIR/"
