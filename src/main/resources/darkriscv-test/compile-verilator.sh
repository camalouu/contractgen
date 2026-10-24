#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$1"
STAGES="${3:-2}"
STAGES="${STAGES:-2}"
[[ "$STAGES" = 2 || "$STAGES" = 3 ]] || { echo "Expected DarkRISCV stage count 2 or 3" >&2; exit 1; }
OUT_DIR="$2"
LEGACY_DIR="${CONTRACT_DARKRISCV_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/darkriscv-${STAGES}}"
PROJECT_LEGACY_DIR="${CONTRACT_DARKRISCV_PROJECT_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/darkriscv-${STAGES}}"
COMMON_DIR="${CONTRACT_ATTACKER_COMMON_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/attacker-test-common}"
PROJECT_COMMON_DIR="${CONTRACT_ATTACKER_PROJECT_COMMON_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/attacker-test-common}"

if [[ -d "$LEGACY_DIR/core" ]]; then CORE_ROOT="$LEGACY_DIR"; else CORE_ROOT="$PROJECT_LEGACY_DIR"; fi
if [[ -d "$COMMON_DIR/verif" ]]; then COMMON_ROOT="$COMMON_DIR"; else COMMON_ROOT="$PROJECT_COMMON_DIR"; fi
if [[ ! -d "$CORE_ROOT/core" || ! -d "$COMMON_ROOT/verif" ]]; then
  echo "Cannot find DarkRISCV-$STAGES or shared attacker-harness resources." >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/verif" "$OUT_DIR/core"

for file in "$CORE_ROOT"/core/*.v; do
  perl -0pe 's/,\s*\)/\n)/g' "$file" > "$OUT_DIR/core/$(basename "$file")"
done
cp "$CORE_ROOT"/core/*.vh "$OUT_DIR/core/"
python3 - "$OUT_DIR/core/config_${STAGES}stages.vh" <<'PYBOOT'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();old="`define __RESETPC__ 32'd0"
assert s.count(old)==1, "Pinned DarkRISCV reset-vector layout changed"
p.write_text(s.replace(old,"`define __RESETPC__ 32'h80"))
PYBOOT
perl -0pi -e 's/output FLUSH,/output reg FLUSH,/; s/^\s*reg FLUSH\s*;[^\n]*\n//m; s/^\s*wire \[31:0\] mem_addr;\n\s*assign mem_addr = rvfi_mem_addr;\n//m; s/old_regfile <= 0;/for (integer cg_i = 0; cg_i < 32; cg_i = cg_i + 1) old_regfile[cg_i] <= 0;/; s/old_regfile <= REG1;/for (integer cg_i = 0; cg_i < 32; cg_i = cg_i + 1) old_regfile[cg_i] <= REG1[cg_i];/' "$OUT_DIR/core/darkriscv_${STAGES}stages.v"

# Correct the imported RTL's SLTIU immediate operand. RISC-V sign-extends
# the immediate before the unsigned comparison. Preserve the classic resource.
python3 - "$OUT_DIR/core/darkriscv_${STAGES}stages.v" "$STAGES" <<'PYSLTIU'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='wire        [31:0] U2REGX = XMCC ? UIMM : U2REG;'
assert s.count(old)==1, 'Pinned DarkRISCV immediate operand changed'
s=s.replace(old,'wire        [31:0] U2REGX = XMCC ? SIMM : U2REG;')
# The imported fork registers decode even in its two-stage configuration.
# Keep the target fetch address through the flush bubble; otherwise the first
# target instruction (and the reset instruction) is skipped.
old='NXPC <= XRES ? `__RESETPC__ : HLT ? NXPC :'
if sys.argv[2] == '2':
    assert s.count(old)==1, 'Pinned DarkRISCV two-stage PC update changed'
    s=s.replace(old,'NXPC <= XRES ? `__RESETPC__ : HLT || FLUSH ? NXPC :')
else:
    # The three-stage core expects registered instruction memory. Keep its
    # next-PC pipeline aligned through reset and branch flush bubbles.
    old='NXPC <= /*XRES ? `__RESETPC__ :*/ HLT ? NXPC : FLUSH ? NXPC : NXPC2;'
    assert s.count(old)==1, 'Pinned DarkRISCV three-stage PC pipeline changed'
    s=s.replace(old,'NXPC <= XRES ? `__RESETPC__ : HLT || (FLUSH > 1) ? NXPC : NXPC2;')
    old='NXPC2 <=  XRES ? `__RESETPC__ : HLT ? NXPC2 :'
    assert s.count(old)==1, 'Pinned DarkRISCV three-stage fetch pipeline changed'
    s=s.replace(old,'NXPC2 <= XRES ? `__RESETPC__ : HLT || (FLUSH > 1) ? NXPC2 :')
# JALR clears bit zero of its computed target, independently of alignment.
old='wire [31:0] JVAL = SIMM + (JALR ? U1REG : PC);'
assert s.count(old)==1, 'Pinned DarkRISCV jump target changed'
s=s.replace(old,"wire [31:0] JVAL = (SIMM + (JALR ? U1REG : PC)) & (JALR ? 32'hfffffffe : 32'hffffffff);")
p.write_text(s)
PYSLTIU

for name in atk clk_sync riscv_decoder; do
  perl -0pe 's/,\s*\)/\n)/g' "$CORE_ROOT/verif/$name.sv" > "$OUT_DIR/verif/$name.sv"
done
perl -0pe 's/module\s+top\s*\(\s*\);/module top (input logic clk, input logic reset);/; s/\(\*\s*gclk\s*\*\)\s*reg\s+clk\s*;//; s/logic reset_1;\s*logic reset_2;\s*initial begin.*?\n\s*end/logic reset_1;\n    logic reset_2;\n    assign reset_1 = reset;\n    assign reset_2 = reset;/s; s/(control control \(\s*\.clk_i\s*\(clock\),)/$1\n        .reset_i                (reset),/; s/,\s*\)/\n)/g' \
  "$CORE_ROOT/verif/top.sv" > "$OUT_DIR/verif/top.sv"

CORE_SOURCES=("$OUT_DIR"/core/*.v)
STAGE_FLAGS=()
INSTR_MEMORY="$COMMON_ROOT/verif/instr_mem.sv"
if [[ "$STAGES" = 3 ]]; then
    STAGE_FLAGS=(-DDARKRISCV_THREE_STAGE)
    python3 - "$OUT_DIR/core/RVFI_3stage.v" <<'PYRVFI'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);s=p.read_text()
core=p.with_name('darkriscv_3stages.v')
core.write_text(core.read_text().replace('output [1:0] FLUSH,', 'output reg [1:0] FLUSH,'))
for name in ('old_regfile','new_regfile'):
    s=s.replace('input [31:0] '+name+' [0:31]', 'input [1023:0] '+name)
    s=re.sub(name+r'\[(rs1|rs2|rd)\]',lambda m: name+'[(31-'+m[1]+')*32 +: 32]',s)
p.write_text(s)
PYRVFI
    python3 - "$COMMON_ROOT/verif/instr_mem.sv" "$OUT_DIR/verif/instr_mem.sv" <<'PYIMEM'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('    always_comb begin','    initial instr_o = `NO_OP;\n    always @(posedge clk_i) begin').replace('instr_o = enable_i', 'instr_o <= enable_i')
Path(sys.argv[2]).write_text(s)
PYIMEM
    INSTR_MEMORY="$OUT_DIR/verif/instr_mem.sv"
fi
# Wire diagnostics in the verification top, leaving pinned core sources intact.
python3 - "$OUT_DIR/verif/top.sv" <<'PYTRACE'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text()
s=s.replace('    logic clock;', '    logic [31:0] trace_pc_1, trace_pc_2;\n    logic clock;',1)
s=s.replace('(retire_trap_1)', '(rvfi_trap_1)').replace('(retire_trap_2)', '(rvfi_trap_2)')
for n in (1,2):
    s=re.sub(r'\.rvfi_valid\s*\(retire_'+str(n)+r'\)', '.rvfi_valid()',s)
    s=re.sub(r'\.rvfi_pc_rdata\s*\(\s*\)', '.rvfi_pc_rdata()',s,count=1)
    s+=f"""
// Actual commit metadata; sample the hardware register file after its write edge.
"""
    block=f"""
    always @(posedge clock_{n}) begin
        retire_{n} <= !reset && !core_{n}.XRES && !core_{n}.HLT && !core_{n}.FLUSH && core_{n}.decode_reg;
        trace_pc_{n} <= core_{n}.PC;
    end
"""
    s=s.replace('endmodule',block+'endmodule',1)

for n in (1,2): s=s.replace('data_mem data_mem_'+str(n), 'data_mem #(.ASYNC(1)) data_mem_'+str(n))
p.write_text(s)
PYTRACE

VERIF_SOURCES=(
  "$OUT_DIR"/verif/atk.sv "$OUT_DIR"/verif/clk_sync.sv
  "$COMMON_ROOT"/verif/data_mem.sv "$OUT_DIR"/verif/riscv_decoder.sv
  "$INSTR_MEMORY" "$COMMON_ROOT"/verif/control.sv
  "$COMMON_ROOT"/verif/ctr.sv "$OUT_DIR"/verif/top.sv
  "$SOURCE_DIR"/verif/darkriscv_test_top.sv
)

verilator --cc --top-module darkriscv_test_top --timing \
  -DSYNTHESIS -DRISCV_FORMAL -DVERIFICATION "${STAGE_FLAGS[@]}" -I"$OUT_DIR/core" -I"$CORE_ROOT/core" \
  -Wno-fatal -Wno-WIDTH -Wno-INITIALDLY -Wno-LATCH -Wno-UNOPTFLAT \
  --threads-dpi none -O3 --Mdir "$OUT_DIR/obj_dir_shared" \
  --exe "$SOURCE_DIR/verif/darkriscv_test_runtime.cpp" "$COMMON_ROOT/verif/simple_test_shared.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I${CONTRACTGEN_RESOURCE_ROOT:-$SOURCE_DIR/..}/attacker-test-common/verif -I$COMMON_ROOT/verif" -LDFLAGS "-shared -fPIC" \
  -o libcontract_darkriscv_${STAGES}_test_attacker.so "${CORE_SOURCES[@]}" "${VERIF_SOURCES[@]}"
make -j "${CONTRACT_BUILD_JOBS:-4}" -C "$OUT_DIR/obj_dir_shared" -f Vdarkriscv_test_top.mk libcontract_darkriscv_${STAGES}_test_attacker.so
cp "$OUT_DIR/obj_dir_shared/libcontract_darkriscv_${STAGES}_test_attacker.so" "$OUT_DIR/libcontract_darkriscv_${STAGES}_test_attacker.so"
test -f "$OUT_DIR/libcontract_darkriscv_${STAGES}_test_attacker.so"
