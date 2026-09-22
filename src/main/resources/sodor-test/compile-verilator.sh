#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$1"
OUT_DIR="$2"
LEGACY_DIR="${CONTRACT_SODOR_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/sodor-2}"
PROJECT_LEGACY_DIR="${CONTRACT_SODOR_PROJECT_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/sodor-2}"
COMMON_DIR="${CONTRACT_ATTACKER_COMMON_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/attacker-test-common}"
PROJECT_COMMON_DIR="${CONTRACT_ATTACKER_PROJECT_COMMON_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/attacker-test-common}"

if [[ -d "$LEGACY_DIR/core" ]]; then CORE_ROOT="$LEGACY_DIR"; else CORE_ROOT="$PROJECT_LEGACY_DIR"; fi
if [[ -d "$COMMON_DIR/verif" ]]; then COMMON_ROOT="$COMMON_DIR"; else COMMON_ROOT="$PROJECT_COMMON_DIR"; fi
if [[ ! -d "$CORE_ROOT/core" || ! -d "$COMMON_ROOT/verif" ]]; then
  echo "Cannot find Sodor-2 or shared attacker-harness resources." >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/verif" "$OUT_DIR/core"

for file in "$CORE_ROOT"/core/*.v; do
  perl -0pe 's/,\s*\)/\n)/g' "$file" > "$OUT_DIR/core/$(basename "$file")"
done
# The checked-in legacy Sodor RTL was accepted after sv2v normalization. Make
# the same ANSI-port normalization directly for the handful of redeclarations
# that Verilator rejects when sv2v is not installed.
perl -0pi -e 's/^\s*wire\s+\[4:0\]\s+io_ctl_alu_fun_ctr;\n//m; s/^\s*wire\s+\[1:0\]\s+io_ctl_op1_sel_ctr;\n//m; s/^\s*wire\s+\[2:0\]\s+io_ctl_op2_sel_ctr;\n//m; s/(wire branch_inst =[^\n]+;\n)\s*wire\s+_csignals_T_63_ctr[^\n]+;\n\s*wire\s+_csignals_T_65_ctr[^\n]+;\n\s*wire\s+_csignals_T_67_ctr[^\n]+;\n\s*wire\s+_csignals_T_69_ctr[^\n]+;\n\s*wire\s+_csignals_T_71_ctr[^\n]+;\n\s*wire\s+_csignals_T_73_ctr[^\n]+;\n/$1/' "$OUT_DIR/core/CtlPath_2stage.v"
perl -0pi -e 's/output \[31:0\] pc_retire/output reg [31:0] pc_retire/; s/output \[31:0\] exe_reg_pc/output reg [31:0] exe_reg_pc/; s/^\s*wire\s+\[31:0\]\s+instr_ctr;\n//m; s/^\s*wire\s+\[31:0\]\s+io_dat_inst_ctr;\n//m; s/^\s*wire\s+\[31:0\]\s+io_dmem_req_bits_addr_ctr;\n//m; s/^\s*wire\s+\[31:0\]\s+exe_rs2_data_ctr[^\n]*\n//m; s/^\s*reg\s+\[31:0\]\s+exe_reg_pc;[^\n]*\n//m; s/^\s*reg\s+\[31:0\]\s+pc_retire;\n//m' "$OUT_DIR/core/DatPath_2stage.v"
perl -0pi -e 's/reg \[31:0\] regfile \[0:31\] = 0;/reg [31:0] regfile [0:31];\n  initial begin for (integer cg_i = 0; cg_i < 32; cg_i = cg_i + 1) regfile[cg_i] = 0; end/' "$OUT_DIR/core/DatPath_2stage.v"
perl -0pi -e 's/old_regfile <= 0;/for (integer cg_i = 0; cg_i < 32; cg_i = cg_i + 1) old_regfile[cg_i] <= 0;/; s/old_regfile <= rvfi_regfile;/for (integer cg_i = 0; cg_i < 32; cg_i = cg_i + 1) old_regfile[cg_i] <= rvfi_regfile[cg_i];/' "$OUT_DIR/core/Core_2stage.v"

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
  "$SOURCE_DIR"/verif/sodor_test_top.sv
)

verilator --cc --top-module sodor_test_top --timing \
  -DSYNTHESIS -DRISCV_FORMAL -I"$OUT_DIR/core" \
  -Wno-fatal -Wno-WIDTH -Wno-INITIALDLY -Wno-LATCH -Wno-UNOPTFLAT \
  --threads-dpi none -O3 --Mdir "$OUT_DIR/obj_dir_shared" \
  --exe "$SOURCE_DIR/verif/sodor_test_runtime.cpp" "$COMMON_ROOT/verif/simple_test_shared.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I$COMMON_ROOT/verif" -LDFLAGS "-shared -fPIC" \
  -o libcontract_sodor_2_test_attacker.so "${CORE_SOURCES[@]}" "${VERIF_SOURCES[@]}"
make -j "${CONTRACT_BUILD_JOBS:-4}" -C "$OUT_DIR/obj_dir_shared" -f Vsodor_test_top.mk libcontract_sodor_2_test_attacker.so
cp "$OUT_DIR/obj_dir_shared/libcontract_sodor_2_test_attacker.so" "$OUT_DIR/libcontract_sodor_2_test_attacker.so"
test -f "$OUT_DIR/libcontract_sodor_2_test_attacker.so"
