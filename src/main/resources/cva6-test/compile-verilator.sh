#!/usr/bin/env bash
set -euo pipefail

cd "$1" || exit
SOURCE_DIR="$PWD"
ORIGINAL_CVA6_RESOURCE_DIR="${CONTRACT_CVA6_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/cva6}"
PROJECT_CVA6_RESOURCE_DIR="${CONTRACT_CVA6_PROJECT_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/cva6}"
export LR_VERIF_OUT_DIR=$2
rm -rf "$LR_VERIF_OUT_DIR"
mkdir -p "$LR_VERIF_OUT_DIR"

copy_required() {
  local rel="$1"
  local dest="$2"
  if [[ -e "$SOURCE_DIR/$rel" ]]; then
    cp -rL --no-preserve=mode "$SOURCE_DIR/$rel" "$dest"
  elif [[ -e "$ORIGINAL_CVA6_RESOURCE_DIR/$rel" ]]; then
    cp -rL --no-preserve=mode "$ORIGINAL_CVA6_RESOURCE_DIR/$rel" "$dest"
  elif [[ -e "$PROJECT_CVA6_RESOURCE_DIR/$rel" ]]; then
    cp -rL --no-preserve=mode "$PROJECT_CVA6_RESOURCE_DIR/$rel" "$dest"
  else
    echo "Missing required cva6-test resource: $rel" >&2
    echo "Checked: $SOURCE_DIR/$rel" >&2
    echo "Checked: $ORIGINAL_CVA6_RESOURCE_DIR/$rel" >&2
    echo "Checked: $PROJECT_CVA6_RESOURCE_DIR/$rel" >&2
    exit 1
  fi
}

copy_required cva6 "$LR_VERIF_OUT_DIR"/cva6
copy_required include "$LR_VERIF_OUT_DIR"/include
copy_required cva6-test.patch "$LR_VERIF_OUT_DIR"/cva6-test.patch
copy_required cva6-test-ariane.patch "$LR_VERIF_OUT_DIR"/cva6-test-ariane.patch
copy_required verif "$LR_VERIF_OUT_DIR"/verif

cd "$LR_VERIF_OUT_DIR"/cva6 || exit
patch -N -p1 < ../cva6-test.patch
patch -N -p1 < ../cva6-test-ariane.patch
cd "$LR_VERIF_OUT_DIR" || exit

cp verif/*.sv "$LR_VERIF_OUT_DIR"/
cp verif/sim_main.cpp "$LR_VERIF_OUT_DIR"/sim_main.cpp
cp verif/cva6_test_runtime.hpp "$LR_VERIF_OUT_DIR"/cva6_test_runtime.hpp
cp verif/cva6_test_runtime.cpp "$LR_VERIF_OUT_DIR"/cva6_test_runtime.cpp
cp verif/cva6_test_shared.cpp "$LR_VERIF_OUT_DIR"/cva6_test_shared.cpp

export CVA6_REPO_DIR="$LR_VERIF_OUT_DIR"/cva6
export HPDCACHE_DIR="$CVA6_REPO_DIR"/core/cache_subsystem/hpdcache
export TARGET_CFG=cv32a6_imac_sv0

VERILATOR_COMMON=(
  --no-timing
  -DUSEVERILATOR
  "$LR_VERIF_OUT_DIR"/cva6/verilator_config.vlt
  -f "$LR_VERIF_OUT_DIR"/cva6/core/Flist.cva6
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/ariane_axi_pkg.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/axi_intf.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/register_interface/src/reg_intf.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/ariane_soc_pkg.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_pkg.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/ariane_axi_soc_pkg.sv
  "$LR_VERIF_OUT_DIR"/cva6/core/cva6_rvfi.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/ariane.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/bootrom/bootrom.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/clint/axi_lite_interface.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/clint/clint.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi2apb/src/axi2apb_64_32.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi2apb/src/axi2apb.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi2apb/src/axi2apb_wrap.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/apb_timer/apb_timer.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/apb_timer/timer.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_ar_buffer.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_aw_buffer.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_b_buffer.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_r_buffer.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_single_slice.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_slice.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_slice_wrap.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/fpga/src/axi_slice/src/axi_w_buffer.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_res_tbl.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_amos_alu.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_amos.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_atomics.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_atomics_wrap.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_lrsc.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/src/axi_riscv_atomics/src/axi_riscv_lrsc_wrap.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/axi_mem_if/src/axi2mem.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_csrs.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dmi_cdc.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dmi_jtag.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dmi_jtag_tap.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_mem.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_sba.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/src/dm_top.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/rv_plic_target.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/rv_plic_gateway.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/plic_regmap.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/rv_plic/rtl/plic_top.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/riscv-dbg/debug_rom/debug_rom.sv
  "$LR_VERIF_OUT_DIR"/cva6/corev_apu/register_interface/src/apb_to_reg.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_multicut.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/rstgen_bypass.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/rstgen.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/addr_decode.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/stream_register.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_cut.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_join.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_delayer.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_to_axi_lite.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_id_prepend.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_atop_filter.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_err_slv.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_mux.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_demux.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/src/axi_xbar.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/cdc_2phase.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/spill_register_flushable.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/spill_register.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/stream_delay.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/src/lfsr_16bit.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/tech_cells_generic/src/deprecated/cluster_clk_cells.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/tech_cells_generic/src/deprecated/pulp_clk_cells.sv
  "$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/tech_cells_generic/src/rtl/tc_clk.sv
  "$LR_VERIF_OUT_DIR"/atk.sv
  "$LR_VERIF_OUT_DIR"/clk_sync.sv
  "$LR_VERIF_OUT_DIR"/control.sv
  "$LR_VERIF_OUT_DIR"/mem.sv
  "$LR_VERIF_OUT_DIR"/top.sv
  --top-module top
  +define+corev_apu/tb/common/mock_uart.sv
  +incdir+corev_apu/axi_node
  --unroll-count 256
  -Wall
  -Werror-PINMISSING
  -Werror-IMPLICIT
  -Wno-fatal
  -Wno-PINCONNECTEMPTY
  -Wno-ASSIGNDLY
  -Wno-DECLFILENAME
  -Wno-UNUSED
  -Wno-UNOPTFLAT
  -Wno-BLKANDNBLK
  -Wno-style
  -Wno-WIDTHEXPAND
  -Wno-WIDTHTRUNC
  -DPRELOAD=1
  -CFLAGS "-I/include -I/share/verilator/include/vltstd -std=c++17 -O3 -DVL_DEBUG"
  --cc
  --vpi
  +incdir+"$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/common_cells/include/
  +incdir+"$LR_VERIF_OUT_DIR"/cva6/vendor/pulp-platform/axi/include/
  +incdir+"$LR_VERIF_OUT_DIR"/cva6/corev_apu/register_interface/include/
  +incdir+"$LR_VERIF_OUT_DIR"/cva6/corev_apu/tb/common/
  +incdir+"$LR_VERIF_OUT_DIR"/cva6/core/include/
  +incdir+"$LR_VERIF_OUT_DIR"/include/
  --threads-dpi none
  -O3
)

verilator "${VERILATOR_COMMON[@]}" --Mdir obj_dir --exe "$LR_VERIF_OUT_DIR"/sim_main.cpp "$LR_VERIF_OUT_DIR"/cva6_test_runtime.cpp -LDFLAGS "-lpthread" &> "$LR_VERIF_OUT_DIR"/compile.log
make -j "${CONTRACT_BUILD_JOBS:-4}" -C obj_dir/ -f Vtop.mk Vtop
cp obj_dir/Vtop cva6-test

verilator "${VERILATOR_COMMON[@]}" --Mdir obj_dir_shared --exe "$LR_VERIF_OUT_DIR"/cva6_test_runtime.cpp "$LR_VERIF_OUT_DIR"/cva6_test_shared.cpp \
  -CFLAGS "-fPIC -I/include -I/share/verilator/include/vltstd -std=c++17 -O3 -DVL_DEBUG" -LDFLAGS "-shared -fPIC -lpthread" -o libcontract_cva6_test_attacker.so &> "$LR_VERIF_OUT_DIR"/compile-shared.log
make -j "${CONTRACT_BUILD_JOBS:-4}" -C obj_dir_shared/ -f Vtop.mk libcontract_cva6_test_attacker.so
cp obj_dir_shared/libcontract_cva6_test_attacker.so libcontract_cva6_test_attacker.so
test -f libcontract_cva6_test_attacker.so
