set -ax

cd "$1" || exit
export LR_VERIF_OUT_DIR=$2
rm -rf "$LR_VERIF_OUT_DIR"
mkdir -p "$LR_VERIF_OUT_DIR"

# Convert verif SystemVerilog files to Verilog
export directories=( "verif/*.sv" );

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
    --define=HAZARD3_RVFI_STANDALONE \
    -I./core/hdl \
    "$file" \
    > "$LR_VERIF_OUT_DIR"/"${module}".v
done

# Copy Hazard3 core hdl files directly
find core/hdl -type f -name "*.v" -exec cp {} "$LR_VERIF_OUT_DIR"/ \;
find core/hdl -type f -name "*.vh" -exec cp {} "$LR_VERIF_OUT_DIR"/ \;

# Read initial memory content from files
sed -i '/\/\/ Trace: verif\/instr_mem.sv:31:9/i $readmemh({"init_", $sformatf("%0d", ID), ".dat"}, mem, 0, 31);' "$LR_VERIF_OUT_DIR"/instr_mem.v
sed -i '/\/\/ Trace: verif\/instr_mem.sv:31:9/i $readmemh({"memory_", $sformatf("%0d", ID), ".dat"}, mem, 32, (2048 - 1));' "$LR_VERIF_OUT_DIR"/instr_mem.v
sed -i '/\/\/ Trace: verif\/control.sv:22:9/i $readmemh({"count.dat"}, counters, 0, 0);' "$LR_VERIF_OUT_DIR"/control.v

cp verif/sim_main.cpp "$LR_VERIF_OUT_DIR"/sim_main.cpp

cd "$LR_VERIF_OUT_DIR"/ || exit

rm -f hazard3_ecp5_jtag_dtm.v hazard3_xilinx7_jtag_dtm.v

iverilog -DHAZARD3_RVFI_STANDALONE -DRISCV_FORMAL -o hazard3 *.v
