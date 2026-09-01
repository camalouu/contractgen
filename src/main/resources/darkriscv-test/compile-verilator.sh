#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$1"
OUT_DIR="$2"
LEGACY_DIR="${CONTRACT_DARKRISCV_RESOURCE_ROOT:-/home/yosys/resources/darkriscv-2}"
PROJECT_LEGACY_DIR="${CONTRACT_DARKRISCV_PROJECT_RESOURCE_ROOT:-/home/yosys/project/src/main/resources/darkriscv-2}"
COMMON_DIR="${CONTRACT_ATTACKER_COMMON_ROOT:-/home/yosys/resources/attacker-test-common}"
PROJECT_COMMON_DIR="${CONTRACT_ATTACKER_PROJECT_COMMON_ROOT:-/home/yosys/project/src/main/resources/attacker-test-common}"

if [[ -d "$LEGACY_DIR/core" ]]; then CORE_ROOT="$LEGACY_DIR"; else CORE_ROOT="$PROJECT_LEGACY_DIR"; fi
if [[ -d "$COMMON_DIR/verif" ]]; then COMMON_ROOT="$COMMON_DIR"; else COMMON_ROOT="$PROJECT_COMMON_DIR"; fi
if [[ ! -d "$CORE_ROOT/core" || ! -d "$COMMON_ROOT/verif" ]]; then
  echo "Cannot find DarkRISCV-2 or shared attacker-harness resources." >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/verif" "$OUT_DIR/core"

for file in "$CORE_ROOT"/core/*.v; do
  perl -0pe 's/,\s*\)/\n)/g' "$file" > "$OUT_DIR/core/$(basename "$file")"
done
perl -0pi -e 's/output FLUSH,/output reg FLUSH,/; s/^\s*reg FLUSH\s*;[^\n]*\n//m; s/^\s*wire \[31:0\] mem_addr;\n\s*assign mem_addr = rvfi_mem_addr;\n//m; s/old_regfile <= 0;/for (integer cg_i = 0; cg_i < 32; cg_i = cg_i + 1) old_regfile[cg_i] <= 0;/; s/old_regfile <= REG1;/for (integer cg_i = 0; cg_i < 32; cg_i = cg_i + 1) old_regfile[cg_i] <= REG1[cg_i];/' "$OUT_DIR/core/darkriscv_2stages.v"

for name in atk clk_sync riscv_decoder; do
  perl -0pe 's/,\s*\)/\n)/g' "$CORE_ROOT/verif/$name.sv" > "$OUT_DIR/verif/$name.sv"
done
perl -0pe 's/module\s+top\s*\(\s*\);/module top (input logic clk, input logic reset);/; s/\(\*\s*gclk\s*\*\)\s*reg\s+clk\s*;//; s/logic reset_1;\s*logic reset_2;\s*initial begin.*?\n\s*end/logic reset_1;\n    logic reset_2;\n    assign reset_1 = reset;\n    assign reset_2 = reset;/s; s/(control control \(\s*\.clk_i\s*\(clock\),)/$1\n        .reset_i                (reset),/; s/,\s*\)/\n)/g' \
  "$CORE_ROOT/verif/top.sv" > "$OUT_DIR/verif/top.sv"

CORE_SOURCES=("$OUT_DIR"/core/*.v)
VERIF_SOURCES=(
  "$OUT_DIR"/verif/atk.sv "$OUT_DIR"/verif/clk_sync.sv
  "$COMMON_ROOT"/verif/data_mem.sv "$OUT_DIR"/verif/riscv_decoder.sv
  "$COMMON_ROOT"/verif/instr_mem.sv "$COMMON_ROOT"/verif/control.sv
  "$COMMON_ROOT"/verif/ctr.sv "$OUT_DIR"/verif/top.sv
  "$SOURCE_DIR"/verif/darkriscv_test_top.sv
)

verilator --cc --top-module darkriscv_test_top --timing \
  -DSYNTHESIS -DRISCV_FORMAL -DVERIFICATION -I"$OUT_DIR/core" -I"$CORE_ROOT/core" \
  -Wno-fatal -Wno-WIDTH -Wno-INITIALDLY -Wno-LATCH -Wno-UNOPTFLAT \
  --threads-dpi none -O3 --Mdir "$OUT_DIR/obj_dir_shared" \
  --exe "$SOURCE_DIR/verif/darkriscv_test_runtime.cpp" "$COMMON_ROOT/verif/simple_test_shared.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I$COMMON_ROOT/verif" -LDFLAGS "-shared -fPIC" \
  -o libcontract_darkriscv_2_test_attacker.so "${CORE_SOURCES[@]}" "${VERIF_SOURCES[@]}"
make -j -C "$OUT_DIR/obj_dir_shared" -f Vdarkriscv_test_top.mk libcontract_darkriscv_2_test_attacker.so
cp "$OUT_DIR/obj_dir_shared/libcontract_darkriscv_2_test_attacker.so" "$OUT_DIR/libcontract_darkriscv_2_test_attacker.so"
test -f "$OUT_DIR/libcontract_darkriscv_2_test_attacker.so"
