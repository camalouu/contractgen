#!/usr/bin/env bash
set -euo pipefail

cd "$1" || exit
SOURCE_DIR="$PWD"
PROJECT_RESOURCE_DIR="${CONTRACT_IBEX_TEST_RESOURCE_ROOT:-/home/yosys/project/src/main/resources/ibex-test}"
export LR_VERIF_OUT_DIR=$2
rm -rf "$LR_VERIF_OUT_DIR"
mkdir -p "$LR_VERIF_OUT_DIR"

cd core
patch -N -p1 < ../ibex.patch || true
cd ..

#-------------------------------------------------------------------------
# use sv2v to convert all SystemVerilog files to Verilog
#-------------------------------------------------------------------------
export directories=( \
      "core/rtl/*.sv" \
    );

# Print array values in  lines
for file in ${directories[*]}; do
  module=$(basename -s .sv "$file")
  if [[ "$module" == *_pkg ]]; then
    continue
  fi
  if [[ "$module" == *_intf ]]; then
    continue
  fi
  sv2v -v \
    --define=SYNTHESIS \
    --define=CONTRACT \
    --define=USEVERILATOR \
    --define=RVFI \
    ./core/rtl/*_pkg.sv \
    -I./core/vendor/lowrisc_ip/ip/prim/rtl \
    "$file" \
    > "$LR_VERIF_OUT_DIR"/"${module}".v
done

# remove generated *pkg.v files (they are empty files and not needed)
rm -f "$LR_VERIF_OUT_DIR"/*_pkg.v

# remove tracer (not needed for synthesis)
rm -f "$LR_VERIF_OUT_DIR"/ibex_tracer.v
rm -f "$LR_VERIF_OUT_DIR"/ibex_core_tracing.v

# remove the FPGA & latch-based register file (because we will use the
# flipflop-based one instead)
rm -f "$LR_VERIF_OUT_DIR"/ibex_register_file_latch.v
rm -f "$LR_VERIF_OUT_DIR"/ibex_register_file_fpga.v

copy_required() {
  local rel="$1"
  local dest="$2"
  if [[ -f "$SOURCE_DIR/$rel" ]]; then
    cp "$SOURCE_DIR/$rel" "$dest"
  elif [[ -f "$PROJECT_RESOURCE_DIR/$rel" ]]; then
    cp "$PROJECT_RESOURCE_DIR/$rel" "$dest"
  else
    echo "Missing required ibex-test resource: $rel" >&2
    echo "Checked: $SOURCE_DIR/$rel" >&2
    echo "Checked: $PROJECT_RESOURCE_DIR/$rel" >&2
    exit 1
  fi
}

copy_required verif/sim_main.cpp "$LR_VERIF_OUT_DIR"/sim_main.cpp
copy_required verif/ibex_test_runtime.hpp "$LR_VERIF_OUT_DIR"/ibex_test_runtime.hpp
copy_required verif/ibex_test_runtime.cpp "$LR_VERIF_OUT_DIR"/ibex_test_runtime.cpp
copy_required verif/ibex_test_shared.cpp "$LR_VERIF_OUT_DIR"/ibex_test_shared.cpp
copy_required verif/atk.sv "$LR_VERIF_OUT_DIR"/atk.sv
copy_required verif/clk_sync.sv "$LR_VERIF_OUT_DIR"/clk_sync.sv
copy_required verif/control.sv "$LR_VERIF_OUT_DIR"/control.sv
copy_required verif/data_mem.sv "$LR_VERIF_OUT_DIR"/data_mem.sv
copy_required verif/instr_mem.sv "$LR_VERIF_OUT_DIR"/instr_mem.sv
copy_required verif/tc_clk_gating.sv "$LR_VERIF_OUT_DIR"/tc_clk_gating.sv
copy_required verif/top.sv "$LR_VERIF_OUT_DIR"/top.sv

cd "$LR_VERIF_OUT_DIR"/ || exit

# shellcheck disable=SC2035
# iverilog -o ibex *.v

VERILOG_SOURCES="atk.sv clk_sync.sv control.sv data_mem.sv ibex_alu.v ibex_branch_predict.v ibex_compressed_decoder.v ibex_controller.v ibex_core.v ibex_counter.v ibex_cs_registers.v ibex_csr.v ibex_decoder.v ibex_dummy_instr.v ibex_ex_block.v ibex_fetch_fifo.v ibex_icache.v ibex_id_stage.v ibex_if_stage.v ibex_load_store_unit.v ibex_multdiv_fast.v ibex_multdiv_slow.v ibex_pmp.v ibex_prefetch_buffer.v ibex_register_file_ff.v ibex_wb_stage.v instr_mem.sv tc_clk_gating.sv top.sv"
VERILATOR_FLAGS="-DUSEVERILATOR -DRVFI -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-LATCH -Wno-COMBDLY -Wno-STMTDLY -Wno-WIDTH -Wno-PINMISSING -Wno-LITENDIAN --top-module top"

# Compatibility executable used by the existing file-based Java harness.
# It reads init_*.dat/memory_*.dat/count.dat in C++ instead of using $readmemh.
verilator --cc $VERILATOR_FLAGS --exe sim_main.cpp ibex_test_runtime.cpp $VERILOG_SOURCES
make -j -C obj_dir/ -f Vtop.mk Vtop
cp obj_dir/Vtop ibex

# Batched shared library used by the new Java fast path.
verilator --cc $VERILATOR_FLAGS --Mdir obj_dir_shared --exe ibex_test_runtime.cpp ibex_test_shared.cpp \
  -CFLAGS "-fPIC" -LDFLAGS "-shared -fPIC" -o libcontract_ibex_test_attacker.so $VERILOG_SOURCES
make -j -C obj_dir_shared/ -f Vtop.mk libcontract_ibex_test_attacker.so
cp obj_dir_shared/libcontract_ibex_test_attacker.so libcontract_ibex_test_attacker.so
test -f libcontract_ibex_test_attacker.so
