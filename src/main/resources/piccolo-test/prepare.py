"""Prepare an asserted disposable copy of the pinned generated RTL."""
from pathlib import Path
import hashlib, re, shutil, sys
source, out = map(Path, sys.argv[1:])
rtl = source / 'builds/RV32ACIMU_Piccolo_verilator/Verilog_RTL'
manifest = {name: digest for digest, name in (line.split() for line in (Path(__file__).parent / 'source-hashes.sha256').read_text().splitlines())}
for name, digest in manifest.items():
    assert hashlib.sha256((source / name).read_bytes()).hexdigest() == digest, name
shutil.copytree(rtl, out / 'rtl')
# Silence simulation-only startup/verbosity messages in the disposable copy.
# Preserve assertions and $finish, which the runtime treats as failures.
for generated in (out / 'rtl').glob('*.v'):
    text = generated.read_text()
    text = re.sub(r'\$(?:display|write)\s*\([^;]*\);', 'begin end', text)
    generated.write_text(text)
# rv32-v1 starts unspecified GPRs at zero; upstream simulation initializes
# RegFile to an alternating pattern and its reset handshake leaves GPRs intact.
# Specialize only the GPR simulation initializer, preserving the write ports.
gpr = out / 'rtl/mkGPR_RegFile.v'
text = gpr.read_text()
assert text.count('  RegFile #(') == 1
text = text.replace('  RegFile #(', '  contract_piccolo_gpr_regfile #(')
gpr.write_text(text)
text = (source / 'src_bsc_lib_RTL/RegFile.v').read_text()
assert text.count("arr[i] = {((data_width + 1)/2){2'b10}} ;") == 1
text = text.replace("arr[i] = {((data_width + 1)/2){2'b10}} ;", "arr[i] = 0 ;")
text, count = re.subn(r'module RegFile\b', 'module contract_piccolo_gpr_regfile', text)
assert count == 1
(out / 'rtl/contract_piccolo_gpr_regfile.v').write_text(text)
p = out / 'rtl/mkSoC_Map.v'
s = p.read_text()
for name, value in [('m_pc_reset_value', "64'h80"), ('m_is_mem_addr', "1'b1"), ('m_is_IO_addr', "1'b0"), ('m_is_near_mem_IO_addr', "1'b0"), ('m_near_mem_io_addr_lim', "64'h2000000"), ('m_plic_addr_lim', "64'hc000000")]:
    s, count = re.subn(r'(assign ' + name + r' =)[^;]+;', r'\g<1> ' + value + ';', s)
    assert count == 1, name
p.write_text(s)
# Export only real stage-three dequeue and trap-rule signals. No fetch probes.
core = (rtl / 'mkCore.v').read_text()
ports = re.findall(r'^  (input|output)\s*(\[[^\]]+\])?\s*(\w+)\s*;', core, re.M)
assert len(ports) == 107, len(ports)
declarations = ['input logic clk, rst_n, reset_request, reset_response', 'output logic reset_ready, reset_done, retire, trap', 'output logic [31:0] pc, instruction, value', 'output logic [4:0] rd']
connections = ['.CLK(clk)', '.RST_N(rst_n)']
for direction, width, name in ports:
    if name in ('CLK', 'RST_N'): continue
    if name.startswith('cpu_imem_master_') or name.startswith('cpu_dmem_master_'):
        short = ('i_' if name.startswith('cpu_imem') else 'd_') + name.split('_master_')[1]
        declarations.append(f'{direction} logic {width} {short}')
        connections.append(f'.{name}({short})')
    else:
        signal = {'EN_cpu_reset_server_request_put': 'reset_request', 'cpu_reset_server_request_put': "1'b1", 'EN_cpu_reset_server_response_get': 'reset_response', 'RDY_cpu_reset_server_request_put': 'reset_ready', 'RDY_cpu_reset_server_response_get': 'reset_done'}.get(name, "'0" if direction == 'input' else '')
        connections.append(f'.{name}({signal})')
s = 'module piccolo_test_top(\n' + ',\n'.join(declarations) + ');\nmkCore core(\n' + ',\n'.join(connections) + ');\n'
s += '''assign retire = core.cpu.WILL_FIRE_RL_rl_pipe && core.cpu.stage3_rg_full;
assign pc = core.cpu.stage3_rg_stage3[103:72];
assign instruction = core.cpu.stage3_rg_stage3[71:40];
assign rd = core.cpu.stage3_rg_stage3[37] ? core.cpu.stage3_rg_stage3[36:32] : 0;
assign value = core.cpu.stage3_rg_stage3[31:0];
assign trap = core.cpu.WILL_FIRE_RL_rl_trap || core.cpu.WILL_FIRE_RL_rl_trap_fetch || core.cpu.WILL_FIRE_RL_rl_stage1_interrupt;
endmodule
'''
(out / 'piccolo_test_top.sv').write_text(s)
