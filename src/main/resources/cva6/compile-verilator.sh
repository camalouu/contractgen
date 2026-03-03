set -ax
cd "$1" || exit
export LR_VERIF_OUT_DIR=$2
rm -rf "$LR_VERIF_OUT_DIR"
mkdir -p "$LR_VERIF_OUT_DIR"


#-------------------------------------------------------------------------
# use sv2v to convert all SystemVerilog files to Verilog
#-------------------------------------------------------------------------
export directories=( \
      "verif/*.sv" \
    );

cp -r cva6 "$LR_VERIF_OUT_DIR"/cva6
cp verif/*.sv "$LR_VERIF_OUT_DIR"/
cp -r include "$LR_VERIF_OUT_DIR"/include
cp cva6-verilator.patch "$LR_VERIF_OUT_DIR"/cva6-vverilator.patch
cp verif/sim_main.cpp "$LR_VERIF_OUT_DIR"/sim_main.cpp
cd "$LR_VERIF_OUT_DIR"/cva6 || exit
patch -p1 < ../cva6-vverilator.patch
cd "$LR_VERIF_OUT_DIR" || exit

# Insert content from formal.prop into generated top.v as sv2v would remove it
sed -i '/endmodule/i MARKER' "$LR_VERIF_OUT_DIR"/top.sv
sed -i -e '/MARKER/e cat verif\/vcd.prop' -e '/MARKER/d' "$LR_VERIF_OUT_DIR"/top.sv

# Read initial memory content from files
# shellcheck disable=SC2016
sed -i '/\/\/ Trace: verif\/mem.sv:45:9/i $readmemh({"init_", $sformatf("%0d", ID), ".dat"}, instr_mem, 0, 31);' "$LR_VERIF_OUT_DIR"/mem.sv
# shellcheck disable=SC2016
sed -i '/\/\/ Trace: verif\/mem.sv:45:9/i $readmemh({"memory_", $sformatf("%0d", ID), ".dat"}, instr_mem, 32, (2048 - 1));' "$LR_VERIF_OUT_DIR"/mem.sv


# shellcheck disable=SC2016
sed -i '/\/\/ Trace: verif\/control.sv:22:9/i $readmemh({"count.dat"}, counters, 0, 0);' "$LR_VERIF_OUT_DIR"/control.sv

#cp verif/sim_main.cpp "$LR_VERIF_OUT_DIR"/sim_main.cpp

cd "$LR_VERIF_OUT_DIR"/ || exit

# shellcheck disable=SC2035
# iverilog -o ariane *.v

export CVA6_REPO_DIR="$LR_VERIF_OUT_DIR"/cva6
export HPDCACHE_DIR="$CVA6_REPO_DIR"/core/cache_subsystem/hpdcache
export TARGET_CFG=cv32a6_imac_sv0

mkdir obj_dir

verilator --no-timing -DUSEVERILATOR "$LR_VERIF_OUT_DIR"/cva6/verilator_config.vlt -f "$LR_VERIF_OUT_DIR"/cva6/core/Flist.cva6 "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/ariane_axi_pkg.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/axi_intf.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/register_interface/src/reg_intf.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/ariane_soc_pkg.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_pkg.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/ariane_axi_soc_pkg.sv  "$LR_VERIF_OUT_DIR"/cva6/core/cva6_rvfi.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/ariane.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/bootrom/bootrom.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/clint/axi_lite_interface.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/clint/clint.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi2apb/src/axi2apb_64_32.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi2apb/src/axi2apb.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi2apb/src/axi2apb_wrap.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/apb_timer/apb_timer.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/apb_timer/timer.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_ar_buffer.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_aw_buffer.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_b_buffer.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_r_buffer.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_single_slice.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_slice.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_slice_wrap.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_w_buffer.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_res_tbl.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_amos_alu.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_amos.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_atomics.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_atomics_wrap.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_lrsc.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_lrsc_wrap.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/axi_mem_if/src/axi2mem.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_csrs.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dmi_cdc.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dmi_jtag.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dmi_jtag_tap.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_mem.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_sba.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_top.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/rv_plic_target.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/rv_plic_gateway.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/plic_regmap.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/plic_top.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/debug_rom/debug_rom.sv  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/register_interface/src/apb_to_reg.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_multicut.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/rstgen_bypass.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/rstgen.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/addr_decode.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/stream_register.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_cut.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_join.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_delayer.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_to_axi_lite.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_id_prepend.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_atop_filter.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_err_slv.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_mux.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_demux.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_xbar.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/cdc_2phase.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/spill_register_flushable.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/spill_register.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/stream_delay.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/lfsr_16bit.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/tech_cells_generic/src/deprecated/cluster_clk_cells.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/tech_cells_generic/src/deprecated/pulp_clk_cells.sv  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/tech_cells_generic/src/rtl/tc_clk.sv "$LR_VERIF_OUT_DIR"/atk.sv "$LR_VERIF_OUT_DIR"/clk_sync.sv "$LR_VERIF_OUT_DIR"/control.sv "$LR_VERIF_OUT_DIR"/ctr.sv "$LR_VERIF_OUT_DIR"/mem.sv "$LR_VERIF_OUT_DIR"/riscv_decoder.sv "$LR_VERIF_OUT_DIR"/rvfi_unwrap.sv "$LR_VERIF_OUT_DIR"/top.sv --top-module top --exe "$LR_VERIF_OUT_DIR"/sim_main.cpp --trace +define+corev_apu/tb/common/mock_uart.sv +incdir+corev_apu/axi_node --unroll-count 256 -Wall -Werror-PINMISSING -Werror-IMPLICIT -Wno-fatal -Wno-PINCONNECTEMPTY -Wno-ASSIGNDLY -Wno-DECLFILENAME -Wno-UNUSED -Wno-UNOPTFLAT -Wno-BLKANDNBLK -Wno-style -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -DPRELOAD=1 -LDFLAGS "-lpthread" -CFLAGS "-I/include -I/share/verilator/include/vltstd -std=c++17 -O3 -DVL_DEBUG" --cc --vpi +incdir+"$LR_VERIF_OUT_DIR"/Cva6/vendor/pulp-platform/common_cells/include/ +incdir+"$LR_VERIF_OUT_DIR"cva6/vendor/pulp-platform/axi/include/ +incdir+"$LR_VERIF_OUT_DIR"cva6/corev_apu/register_interface/include/ +incdir+"$LR_VERIF_OUT_DIR"cva6/corev_apu/tb/common/ +incdir+"$LR_VERIF_OUT_DIR"cva6/vendor/pulp-platform/axi/include/ +incdir+"$LR_VERIF_OUT_DIR"cva6/verif/core-v-verif/lib/uvm_agents/uvma_rvfi/ +incdir+"$LR_VERIF_OUT_DIR"/Cva6/verif/core-v-verif/lib/uvm_components/uvmc_rvfi_reference_model/ +incdir+"$LR_VERIF_OUT_DIR"cva6/verif/core-v-verif/lib/uvm_components/uvmc_rvfi_scoreboard/ +incdir+"$LR_VERIF_OUT_DIR"cva6/verif/core-v-verif/lib/uvm_agents/uvma_core_cntrl/ +incdir+"$LR_VERIF_OUT_DIR"cva6/verif/tb/core/ +incdir+"$LR_VERIF_OUT_DIR"cva6/core/include/ +incdir+"$LR_VERIF_OUT_DIR"include/ --threads-dpi none --Mdir obj_dir -O3 &> "$LR_VERIF_OUT_DIR"compile.log
make -j -C obj_dir/ -f Vtop.mk Vtop
cp obj_dir/Vtop ariane
