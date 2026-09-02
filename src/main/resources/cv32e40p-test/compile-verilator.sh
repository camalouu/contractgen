#!/usr/bin/env bash
set -euo pipefail
SOURCE_DIR="$1"
OUT_DIR="$2"
CORE_ROOT="${CONTRACT_CV32E40P_CORE_ROOT:-$SOURCE_DIR/core}"
COMMON_DIR="${CONTRACT_ATTACKER_COMMON_ROOT:-/home/yosys/resources/attacker-test-common}"
PROJECT_COMMON_DIR="${CONTRACT_ATTACKER_PROJECT_COMMON_ROOT:-/home/yosys/project/src/main/resources/attacker-test-common}"
if [[ -d "$COMMON_DIR/verif" ]]; then COMMON_ROOT="$COMMON_DIR"; else COMMON_ROOT="$PROJECT_COMMON_DIR"; fi
if [[ ! -f "$CORE_ROOT/rtl/cv32e40p_top.sv" || ! -d "$COMMON_ROOT/verif" ]]; then
  echo "Cannot find CV32E40P RTL or shared attacker-harness resources." >&2; exit 1
fi
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
RTL_SOURCES=(
  "$CORE_ROOT"/rtl/include/cv32e40p_apu_core_pkg.sv
  "$CORE_ROOT"/rtl/include/cv32e40p_fpu_pkg.sv
  "$CORE_ROOT"/rtl/include/cv32e40p_pkg.sv
  "$CORE_ROOT"/bhv/cv32e40p_sim_clock_gate.sv
  "$CORE_ROOT"/rtl/cv32e40p_alu.sv "$CORE_ROOT"/rtl/cv32e40p_alu_div.sv
  "$CORE_ROOT"/rtl/cv32e40p_ff_one.sv "$CORE_ROOT"/rtl/cv32e40p_popcnt.sv
  "$CORE_ROOT"/rtl/cv32e40p_compressed_decoder.sv "$CORE_ROOT"/rtl/cv32e40p_controller.sv
  "$CORE_ROOT"/rtl/cv32e40p_cs_registers.sv "$CORE_ROOT"/rtl/cv32e40p_decoder.sv
  "$CORE_ROOT"/rtl/cv32e40p_int_controller.sv "$CORE_ROOT"/rtl/cv32e40p_ex_stage.sv
  "$CORE_ROOT"/rtl/cv32e40p_hwloop_regs.sv "$CORE_ROOT"/rtl/cv32e40p_id_stage.sv
  "$CORE_ROOT"/rtl/cv32e40p_if_stage.sv "$CORE_ROOT"/rtl/cv32e40p_load_store_unit.sv
  "$CORE_ROOT"/rtl/cv32e40p_mult.sv "$CORE_ROOT"/rtl/cv32e40p_prefetch_buffer.sv
  "$CORE_ROOT"/rtl/cv32e40p_prefetch_controller.sv "$CORE_ROOT"/rtl/cv32e40p_obi_interface.sv
  "$CORE_ROOT"/rtl/cv32e40p_aligner.sv "$CORE_ROOT"/rtl/cv32e40p_sleep_unit.sv
  "$CORE_ROOT"/rtl/cv32e40p_apu_disp.sv "$CORE_ROOT"/rtl/cv32e40p_fifo.sv
  "$CORE_ROOT"/rtl/cv32e40p_register_file_ff.sv "$CORE_ROOT"/rtl/cv32e40p_core.sv
  "$CORE_ROOT"/rtl/cv32e40p_top.sv
)
VERIF_SOURCES=(
  "$COMMON_ROOT"/verif/clk_sync.sv "$COMMON_ROOT"/verif/atk.sv
  "$SOURCE_DIR"/verif/cv32e40p_obi_instr_mem.sv
  "$SOURCE_DIR"/verif/cv32e40p_obi_data_mem.sv
  "$SOURCE_DIR"/verif/cv32e40p_retire_control.sv
  "$SOURCE_DIR"/verif/cv32e40p_test_top.sv
)
verilator --cc --top-module cv32e40p_test_top -I"$CORE_ROOT/rtl/include" \
  -Wno-fatal -Wno-BLKANDNBLK -Wno-COMBDLY -Wno-WIDTH -Wno-LATCH -Wno-UNOPTFLAT \
  -Wno-CASEINCOMPLETE -Wno-PINMISSING --threads-dpi none -O3 \
  --Mdir "$OUT_DIR/obj_dir_shared" \
  --exe "$SOURCE_DIR/verif/cv32e40p_test_runtime.cpp" "$COMMON_ROOT/verif/simple_test_shared.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I$COMMON_ROOT/verif" -LDFLAGS "-shared -fPIC" \
  -o libcontract_cv32e40p_test_attacker.so "${RTL_SOURCES[@]}" "${VERIF_SOURCES[@]}"
make -j -C "$OUT_DIR/obj_dir_shared" -f Vcv32e40p_test_top.mk libcontract_cv32e40p_test_attacker.so
cp "$OUT_DIR/obj_dir_shared/libcontract_cv32e40p_test_attacker.so" "$OUT_DIR/libcontract_cv32e40p_test_attacker.so"
test -f "$OUT_DIR/libcontract_cv32e40p_test_attacker.so"
