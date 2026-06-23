set -ax

cd "$1" || exit
export LR_VERIF_OUT_DIR=$2
rm -rf "$LR_VERIF_OUT_DIR"
mkdir -p "$LR_VERIF_OUT_DIR"

case "$3" in
  BASE)
    VARIANT="$3"
    ;;
  *)
    echo "IBEX_TEST supports only BASE, got: $3"
    exit 1
    ;;
esac


cd core
patch -p1 < ../ibex.patch
cd ..

#-------------------------------------------------------------------------
# use sv2v to convert all SystemVerilog files to Verilog
#-------------------------------------------------------------------------
export directories=( \
      "core/rtl/*.sv" \
      "verif/*.sv" \
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
    --define=RISCV_FORMAL \
    --define=USEVERILATOR \
    --define=$VARIANT \
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

# Insert content from formal.prop into generated top.v as sv2v would remove it
sed -i '/endmodule/i MARKER' "$LR_VERIF_OUT_DIR"/top.v
sed -i -e '/MARKER/e cat verif\/formal-verilator.prop' -e '/MARKER/d' "$LR_VERIF_OUT_DIR"/top.v

# Read initial memory content from files
# shellcheck disable=SC2016
sed -i '/\/\/ Trace: verif\/instr_mem.sv:31:9/i $readmemh({"init_", $sformatf("%0d", ID), ".dat"}, mem, 0, 31);' "$LR_VERIF_OUT_DIR"/instr_mem.v
# shellcheck disable=SC2016
sed -i '/\/\/ Trace: verif\/instr_mem.sv:31:9/i $readmemh({"memory_", $sformatf("%0d", ID), ".dat"}, mem, 32, (2048 - 1));' "$LR_VERIF_OUT_DIR"/instr_mem.v

# shellcheck disable=SC2016
sed -i '/\/\/ Trace: verif\/control.sv:22:9/i $readmemh({"count.dat"}, counters);' "$LR_VERIF_OUT_DIR"/control.v

cp verif/sim_main.cpp "$LR_VERIF_OUT_DIR"/sim_main.cpp

cd "$LR_VERIF_OUT_DIR"/ || exit

# shellcheck disable=SC2035
# iverilog -o ibex *.v

verilator --cc -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-LATCH -Wno-COMBDLY -Wno-STMTDLY -Wno-WIDTH -Wno-PINMISSING -Wno-LITENDIAN --top-module top --exe sim_main.cpp --trace atk.v cached_data_mem.v clk_sync.v control.v ctr.v data_mem.v ibex_alu.v ibex_branch_predict.v ibex_compressed_decoder.v ibex_controller.v ibex_core.v ibex_counter.v ibex_cs_registers.v ibex_csr.v ibex_decoder.v ibex_dummy_instr.v ibex_ex_block.v ibex_fetch_fifo.v ibex_icache.v ibex_id_stage.v ibex_if_stage.v ibex_load_store_unit.v ibex_multdiv_fast.v ibex_multdiv_slow.v ibex_pmp.v ibex_prefetch_buffer.v ibex_register_file_ff.v ibex_wb_stage.v instr_mem.v riscv_decoder.v tc_clk_gating.v top.v
make -j -C obj_dir/ -f Vtop.mk Vtop
cp obj_dir/Vtop ibex
