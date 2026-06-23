#!/usr/bin/env python3
import sys
import os
import random
import argparse
import json

# Add useful-scripts to path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), "."))
from infer_atoms import (
    infer_atoms_for_testcase, 
    OBSERVATION_GROUPS, 
    TYPE_META
)
from format_testcases_side_by_side import build_pair_table

# Constants from Java code
NUMBER_REGISTERS = 32
MAX_IMM_I = 2047
MAX_IMM_B = 4095
MAX_IMM_U = 1048575 
MAX_IMM_J = 1048575

def random_immediate(bound):
    return random.randint(-bound, bound)

def random_registers(required_regs=None):
    result = {}
    for i in range(1, NUMBER_REGISTERS):
        if random.choice([True, False]) or (required_regs and i in required_regs):
            result[str(i)] = random_immediate(MAX_IMM_I)
    return result

def get_bound(instr_type):
    fmt = TYPE_META[instr_type]["format"]
    if fmt == "RTYPE": return 0
    if fmt in ["ITYPE", "STYPE"]: return MAX_IMM_I
    if fmt == "BTYPE": return MAX_IMM_B
    if fmt == "UTYPE": return MAX_IMM_U
    if fmt == "JTYPE": return MAX_IMM_J
    return 0

def random_instruction(instr_type):
    fmt = TYPE_META[instr_type]["format"]
    rd = random.randint(0, 31) if fmt in ["RTYPE", "ITYPE", "UTYPE", "JTYPE"] else None
    rs1 = random.randint(0, 31) if fmt in ["RTYPE", "ITYPE", "STYPE", "BTYPE"] else None
    rs2 = random.randint(0, 31) if fmt in ["RTYPE", "STYPE", "BTYPE"] else None
    imm = random_immediate(get_bound(instr_type)) if fmt != "RTYPE" else None
    
    if instr_type in ["SLLI", "SRLI", "SRAI"]:
        rs2 = random.randint(0, 31) # shamt
        imm = None
        
    return {
        "type": instr_type,
        "rd": rd,
        "rs1": rs1,
        "rs2": rs2,
        "imm": imm
    }

def alter_observation(obs_type, base_instr):
    t = base_instr["type"]
    fmt = TYPE_META[t]["format"]
    
    def clone(changes):
        new = base_instr.copy()
        new.update(changes)
        return new

    if obs_type == "RD":
        if base_instr["rd"] is None: return None
        r1, r2 = random.sample(range(1, 31), 2)
        return ([clone({"rd": r1})], [clone({"rd": r2})])
    
    if obs_type == "RS1":
        if base_instr["rs1"] is None: return None
        r1, r2 = random.sample(range(31), 2)
        return ([clone({"rs1": r1})], [clone({"rs1": r2})])

    if obs_type == "RS2":
        if base_instr["rs2"] is None: return None
        r1, r2 = random.sample(range(31), 2)
        return ([clone({"rs2": r1})], [clone({"rs2": r2})])

    if obs_type == "IMM":
        if base_instr["imm"] is None: return None
        imm1 = random_immediate(get_bound(t))
        imm2 = random_immediate(get_bound(t))
        while imm1 == imm2:
            imm2 = random_immediate(get_bound(t))
        if fmt == "BTYPE" or t in ["JAL", "JALR"]:
            imm1 = (imm1 // 4) * 4
            imm2 = (imm2 // 4) * 4
        return ([clone({"imm": imm1})], [clone({"imm": imm2})])

    if obs_type == "REG_RS1":
        if base_instr["rs1"] is None: return None
        rs1 = base_instr["rs1"]
        v1, v2 = random.sample(range(-MAX_IMM_I, MAX_IMM_I), 2)
        ins1 = {"type": "ADDI", "rd": rs1, "rs1": 0, "imm": v1}
        ins2 = {"type": "ADDI", "rd": rs1, "rs1": 0, "imm": v2}
        return ([ins1, base_instr], [ins2, base_instr])

    if obs_type == "REG_RS2":
        if base_instr["rs2"] is None: return None
        rs2 = base_instr["rs2"]
        v1, v2 = random.sample(range(-MAX_IMM_I, MAX_IMM_I), 2)
        ins1 = {"type": "ADDI", "rd": rs2, "rs1": 0, "imm": v1}
        ins2 = {"type": "ADDI", "rd": rs2, "rs1": 0, "imm": v2}
        return ([ins1, base_instr], [ins2, base_instr])

    if obs_type == "MEM_ADDR":
        if base_instr["rs1"] is None: return None
        rs1 = base_instr["rs1"]
        addr = random_immediate(MAX_IMM_I)
        v1, v2 = random.sample(range(-MAX_IMM_I, MAX_IMM_I), 2)
        val1 = {"type": "ADDI", "rd": 31, "rs1": 0, "imm": v1}
        val2 = {"type": "ADDI", "rd": 30, "rs1": 0, "imm": v2}
        instr_addr = {"type": "ADDI", "rd": rs1, "rs1": 0, "imm": addr}
        ins1 = {"type": "SW", "rs1": rs1, "rs2": 31, "imm": 0}
        ins2 = {"type": "SW", "rs1": rs1, "rs2": 30, "imm": 0}
        return ([val1, val2, instr_addr, ins1, base_instr], 
                [val1, val2, instr_addr, ins2, base_instr])

    if obs_type == "MEM_W_DATA":
        if base_instr["rs2"] is None: return None
        rs2 = base_instr["rs2"]
        addr = random_immediate(MAX_IMM_I)
        v1, v2 = random.sample(range(-MAX_IMM_I, MAX_IMM_I), 2)
        val1 = {"type": "ADDI", "rd": 31, "rs1": 0, "imm": v1}
        val2 = {"type": "ADDI", "rd": 30, "rs1": 0, "imm": v2}
        instr_addr = {"type": "ADDI", "rd": rs2, "rs1": 0, "imm": addr}
        ins1 = {"type": "SW", "rs1": rs2, "rs2": 31, "imm": 0}
        ins2 = {"type": "SW", "rs1": rs2, "rs2": 30, "imm": 0}
        return ([val1, val2, instr_addr, ins1, base_instr], 
                [val1, val2, instr_addr, ins2, base_instr])

    if obs_type == "REG_RD":
        if base_instr["rd"] is None: return None
        r1, r2 = random.sample(range(31), 2)
        return ([clone({"rd": r1})], [clone({"rd": r2})])

    if obs_type == "MEM_R_DATA":
        if base_instr["imm"] is None or base_instr["rs1"] is None: return None
        rs1 = base_instr["rs1"]
        addr = random_immediate(MAX_IMM_I)
        v1, v2 = random.sample(range(-MAX_IMM_I, MAX_IMM_I), 2)
        val1 = {"type": "ADDI", "rd": 31, "rs1": 0, "imm": v1}
        val2 = {"type": "ADDI", "rd": 30, "rs1": 0, "imm": v2}
        instr_addr1 = {"type": "ADDI", "rd": rs1, "rs1": 0, "imm": addr}
        ins1 = {"type": "SW", "rs1": rs1, "rs2": 31, "imm": 0}
        ins2 = {"type": "SW", "rs1": rs1, "rs2": 30, "imm": 0}
        instr_addr2 = {"type": "ADDI", "rd": rs1, "rs1": rs1, "imm": base_instr["imm"]}
        return ([val1, val2, instr_addr1, ins1, instr_addr2, base_instr], 
                [val1, val2, instr_addr1, ins2, instr_addr2, base_instr])

    if obs_type == "RAW_RS1_1":
        if base_instr["rs1"] is None: return None
        rs1 = base_instr["rs1"]
        add1 = {"type": "ADD", "rd": rs1, "rs1": 0, "rs2": 0}
        add2 = {"type": "ADD", "rd": 0, "rs1": 0, "rs2": 0}
        return ([add1, base_instr], [add2, base_instr])

    if obs_type == "RAW_RS2_1":
        if base_instr["rs2"] is None: return None
        rs2 = base_instr["rs2"]
        add1 = {"type": "ADD", "rd": rs2, "rs1": 0, "rs2": 0}
        add2 = {"type": "ADD", "rd": 0, "rs1": 0, "rs2": 0}
        return ([add1, base_instr], [add2, base_instr])

    if obs_type == "WAW_1":
        if base_instr["rd"] is None: return None
        rd = base_instr["rd"]
        add1 = {"type": "ADD", "rd": rd, "rs1": 0, "rs2": 0}
        add2 = {"type": "ADD", "rd": 0, "rs1": 0, "rs2": 0}
        return ([add1, base_instr], [add2, base_instr])

    return None

def main():
    parser = argparse.ArgumentParser(description="Reproduce testcase atoms for a specific type and observation.")
    parser.add_argument("--type", required=True, help="Instruction type (e.g. BEQ)")
    parser.add_argument("--obs", required=True, help="Observation type (e.g. RS2)")
    parser.add_argument("--random-prefix", action="store_true", help="Add random prefix instructions")
    parser.add_argument("--random-suffix", action="store_true", help="Add random suffix instructions")
    parser.add_argument("--side-by-side", action="store_true", help="Print pair of programs in readable format, side by side")
    parser.add_argument("--show-init", action="store_true", help="Show 31 ADDI initialization instructions in side-by-side view")
    parser.add_argument("--regs", action="store_true", help="Print initial register values")
    parser.add_argument("--groups", default="BASE,ALIGNED,BRANCH,DEPENDENCY", help="Observation groups to consider")
    args = parser.parse_args()

    allowed_obs = set()
    for g in args.groups.split(","):
        g = g.upper()
        if g == "DEPENDENCIES": g = "DEPENDENCY" # normalization
        if g in OBSERVATION_GROUPS:
            allowed_obs.update(OBSERVATION_GROUPS[g])

    base_instr = random_instruction(args.type)
    
    altered = alter_observation(args.obs, base_instr)
    if not altered:
        print(f"Error: Could not generate testcase for {args.type}:{args.obs}")
        return

    p1_core, p2_core = altered
    
    def get_random_sequence():
        size = random.randint(5, 25)
        seq = []
        types = list(TYPE_META.keys())
        for _ in range(size):
            t = random.choice(types)
            seq.append(random_instruction(t))
        return seq

    prefix = get_random_sequence() if args.random_prefix else []
    suffix = get_random_sequence() if args.random_suffix else []

    program1 = prefix + p1_core + suffix
    program2 = prefix + p2_core + suffix
    
    required_regs = set()
    for p in [program1, program2]:
        for i in p:
            if i.get("rs1") is not None: required_regs.add(i["rs1"])
            if i.get("rs2") is not None: required_regs.add(i["rs2"])
            if i.get("rd") is not None: required_regs.add(i["rd"])

    registers = random_registers(required_regs)

    tc = {
        "program1": program1,
        "program2": program2,
        "registers1": registers,
        "registers2": registers,
        "maxInstructionCount": max(len(program1), len(program2)) + 1,
        "index": 0
    }

    distinguishing_atoms = infer_atoms_for_testcase(tc, allowed_obs)
    
    # 7. Output result
    if args.regs:
        print("```text")
        print("Registers:")
        for reg in range(1, 32):
            key = str(reg)
            if key in registers:
                print(f"  x{reg:2d}: {registers[key]}")
        print("```\n")

    if args.side_by_side:
        print("```text")
        print(build_pair_table(tc["registers1"], tc["registers2"], tc["program1"], tc["program2"], args.show_init))
        print("```\n")

    output_list = [{"type": t, "observation": o} for t, o in sorted(distinguishing_atoms)]
    print(json.dumps(output_list, indent=2))

if __name__ == "__main__":
    main()
