#!/usr/bin/env bash
set -euo pipefail
SOURCE_DIR="$1"
OUT_DIR="$2"
CORE_ROOT="${CONTRACT_CV32E40P_CORE_ROOT:-$SOURCE_DIR/core}"
COMMON_DIR="${CONTRACT_ATTACKER_COMMON_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/attacker-test-common}"
PROJECT_COMMON_DIR="${CONTRACT_ATTACKER_PROJECT_COMMON_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/attacker-test-common}"
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
# Verilator 5.008 cannot resolve a class method's implicit enclosing-module
# variable references. Pass the same pipeline snapshot explicitly, in a
# disposable copy of the upstream diagnostic monitor (not the processor RTL).
mkdir -p "$OUT_DIR/rvfi"
cp "$CORE_ROOT"/bhv/{cv32e40p_rvfi,pipe_freeze_trace,insn_trace}.sv "$OUT_DIR/rvfi/"
python3 - "$OUT_DIR/rvfi" <<'PYRVFI'
from pathlib import Path
import sys,re
root=Path(sys.argv[1]);p=root/'insn_trace.sv';s=p.read_text()
s=s.replace('if(!is_compressed_id_i)',"if(this.m_insn[1:0] == 2'b11)")
s=s.replace('if (is_compressed_id_i)',"if (m_source.m_insn[1:0] != 2'b11)")
s=re.sub(r'function void init\(\s*insn_trace_t m_source\)', 'function void init(insn_trace_t m_source, pipe_trace_t captured, int sampled_cycle)',s)
s=s.replace('this.m_start_cycle      = cycles;', 'this.m_start_cycle      = sampled_cycle;')
s=s.replace('r_pipe_freeze_trace.', 'captured.')
p.write_text(s)
p=root/'cv32e40p_rvfi.sv';s=p.read_text();old='trace_id.init(trace_if);'
assert s.count(old)==1, 'Pinned RVFI initialization layout changed'
p.write_text(s.replace(old,'trace_id.init(trace_if,r_pipe_freeze_trace,cycles);'))
p=root/'pipe_freeze_trace.sv';s=p.read_text()
for field,source in [('pmpcfg_n','csr_pmpcfg_n_i'),('pmpcfg_q','csr_pmpcfg_q_i'),('pmpaddr_q','csr_pmpaddr_q_i')]:
 old='r_pipe_freeze_trace.csr.'+field+' = '+source+';'
 new='for(int cg_index=0;cg_index<16;cg_index++) r_pipe_freeze_trace.csr.'+field+'[cg_index] = '+source+'[cg_index];'
 assert old in s, 'Pinned RVFI array snapshot layout changed'
 s=s.replace(old,new)
p.write_text(s)
freeze=s
end=freeze.index('} pipe_trace_t;')+len('} pipe_trace_t;')
start=freeze.index('typedef struct')
class_text=(root/'insn_trace.sv').read_text()
class_text,copies=re.subn(r'this\.m_mem\s*=\s*m_source\.m_mem;', ''.join('this.m_mem.'+field+' = m_source.m_mem.'+field+';\n' for field in ('addr','rmask','wmask','rdata','wdata')),class_text)
assert copies==1, 'Pinned RVFI memory snapshot layout changed'
# Retain the class's CSR macros and imports as well as its declaration.
package='package contract_cv32e40p_trace_pkg;\nimport cv32e40p_pkg::*;\nimport cv32e40p_rvfi_pkg::*;\n'+freeze[start:end]+'\n'+class_text+'\nendpackage\n'
(root/'trace_types_pkg.sv').write_text(package)
p=root/'pipe_freeze_trace.sv';p.write_text(freeze[:start]+'import contract_cv32e40p_trace_pkg::*;\n'+freeze[end:])
p=root/'cv32e40p_rvfi.sv';s=p.read_text().replace('`include "insn_trace.sv"','import contract_cv32e40p_trace_pkg::*;').replace('`include "cv32e40p_rvfi_pkg.sv"','')
# Equivalent whole-field updates avoid the pinned emitter's masked lvalue bug.
def update_valid(match):
 obj,bit,value=match.groups();mask=1<<int(bit)
 return obj+'.m_mem_req_id_valid = '+obj+".m_mem_req_id_valid "+('|' if value=='1' else '&')+" 2'd"+str(mask if value=='1' else 3^mask)+';'
s=re.sub(r"(\w+)\.m_mem_req_id_valid\[([01])\] = 1'b([01]);",update_valid,s)
# Suppress unconditional monitor startup messages during batched experiments.
s=re.sub(r'\$display\("\*+Starting[^;]+;', '', s)
p.write_text(s)
PYRVFI
RTL_SOURCES+=("$CORE_ROOT/bhv/include/cv32e40p_tracer_pkg.sv" "$CORE_ROOT/bhv/include/cv32e40p_rvfi_pkg.sv" "$OUT_DIR/rvfi/trace_types_pkg.sv" "$OUT_DIR/rvfi/cv32e40p_rvfi.sv")
VERIF_SOURCES=(
  "$COMMON_ROOT"/verif/clk_sync.sv "$COMMON_ROOT"/verif/atk.sv
  "$SOURCE_DIR"/verif/cv32e40p_obi_instr_mem.sv
  "$SOURCE_DIR"/verif/cv32e40p_obi_data_mem.sv
  "$SOURCE_DIR"/verif/cv32e40p_retire_control.sv
  "$SOURCE_DIR"/verif/cv32e40p_test_top.sv
)
verilator --cc --timing --top-module cv32e40p_test_top -I"$CORE_ROOT/rtl/include" -I"$CORE_ROOT/bhv/include" -I"$OUT_DIR/rvfi" -I"$CORE_ROOT/bhv" \
  -Wno-fatal -Wno-BLKANDNBLK -Wno-COMBDLY -Wno-WIDTH -Wno-LATCH -Wno-UNOPTFLAT \
  -Wno-CASEINCOMPLETE -Wno-PINMISSING --threads-dpi none -O3 \
  --Mdir "$OUT_DIR/obj_dir_shared" \
  --exe "$SOURCE_DIR/verif/cv32e40p_test_runtime.cpp" "$COMMON_ROOT/verif/simple_test_shared.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I${CONTRACTGEN_RESOURCE_ROOT:-$SOURCE_DIR/..}/attacker-test-common/verif -I$COMMON_ROOT/verif" -LDFLAGS "-shared -fPIC" \
  -o libcontract_cv32e40p_test_attacker.so "${RTL_SOURCES[@]}" "${VERIF_SOURCES[@]}"
# Verilator 5.008 declares a class in its __Vclpkg header but emits includes
# for the absent class-only header. Supply a forwarding header, with no type
# or behavioral changes, only when that exact class package exists.
python3 - "$OUT_DIR/obj_dir_shared" <<'PYHEADERS'
from pathlib import Path
import re,sys
root=Path(sys.argv[1])
for p in list(root.glob('*.h')):
 for name in re.findall(r'#include "([^"\n]+\.h)"',p.read_text()):
  missing=root/name
  if missing.exists() or '__03a__03a' not in name:continue
  package=root/(name[:-2]+'__Vclpkg.h')
  if not package.exists():
   raise RuntimeError('Missing class header '+name+'; candidates: '+str([p.name for p in root.glob('*insn_trace*')]))
  missing.write_text('#pragma once\n#include "'+package.name+'"\n')
PYHEADERS
make -j "${CONTRACT_BUILD_JOBS:-4}" -C "$OUT_DIR/obj_dir_shared" -f Vcv32e40p_test_top.mk libcontract_cv32e40p_test_attacker.so
cp "$OUT_DIR/obj_dir_shared/libcontract_cv32e40p_test_attacker.so" "$OUT_DIR/libcontract_cv32e40p_test_attacker.so"
test -f "$OUT_DIR/libcontract_cv32e40p_test_attacker.so"
