#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR=$(cd "$1" && pwd)
OUTPUT_DIR=$2
PROJECT_RESOURCE_DIR=${CONTRACT_PROTEUS_TEST_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/proteus-test}

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

copy_required() {
  local relative=$1
  if [[ -f "$SOURCE_DIR/$relative" ]]; then
    cp "$SOURCE_DIR/$relative" "$OUTPUT_DIR/$(basename "$relative")"
  elif [[ -f "$PROJECT_RESOURCE_DIR/$relative" ]]; then
    cp "$PROJECT_RESOURCE_DIR/$relative" "$OUTPUT_DIR/$(basename "$relative")"
  else
    echo "Missing required proteus-test resource: $relative" >&2
    exit 1
  fi
}

copy_required generated/ProteusContractCore.v
copy_required verif/top.sv
copy_required verif/clk_sync.sv
copy_required verif/atk.sv
copy_required verif/control.sv
copy_required verif/instr_mem.sv
copy_required verif/data_mem.sv
copy_required verif/proteus_test_runtime.hpp
copy_required verif/proteus_test_runtime.cpp
copy_required verif/proteus_test_shared.cpp

cd "$OUTPUT_DIR"
SOURCES="ProteusContractCore.v top.sv clk_sync.sv atk.sv control.sv instr_mem.sv data_mem.sv"
FLAGS="--top-module top -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -Wno-LATCH -Wno-INITIALDLY"

verilator --cc $FLAGS --Mdir obj_dir_shared --exe \
  proteus_test_runtime.cpp proteus_test_shared.cpp \
  -CFLAGS "-std=c++17 -fPIC" -LDFLAGS "-shared -fPIC" \
  -o libcontract_proteus_test_attacker.so $SOURCES
make -j "${CONTRACT_BUILD_JOBS:-4}" -C obj_dir_shared -f Vtop.mk libcontract_proteus_test_attacker.so
cp obj_dir_shared/libcontract_proteus_test_attacker.so .
test -f libcontract_proteus_test_attacker.so
