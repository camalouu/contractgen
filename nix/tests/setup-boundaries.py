"""Exercise persisted setup boundaries through the unchanged native v2 ABI."""
import ctypes
import json
import sys

lib = ctypes.CDLL(sys.argv[1])
lib.contract_spike_atoms_json_v2.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p]
lib.contract_spike_atoms_json_v2.restype = ctypes.c_void_p
lib.contract_spike_free.argtypes = [ctypes.c_void_p]


def instruction(kind, **fields):
    return dict(type=kind, **fields)


def setup(values):
    result = []
    for r in range(1, 32):
        value = values.get(r, 0)
        result += [instruction("LUI", rd=r, imm=(((value + 0x800) >> 12) & 0xfffff) << 12),
                   instruction("ADDI", rd=r, rs1=r, imm=value & 0xfff)]
    return result + [instruction("ADDI", rd=0, rs1=0, imm=0)]


def run(first, second, include, metadata=True):
    case = dict(index=0, registers1={str(r): 0 for r in range(1, 32)},
                registers2={str(r): 0 for r in range(1, 32)}, program1=first, program2=second,
                maxInstructionCount=max(len(first), len(second)) + 1)
    if metadata:
        case["setupEvidence"] = dict(setupInstructions=63, includeSetup=include)
    pointer = lib.contract_spike_atoms_json_v2(json.dumps([case]).encode(), b"RV32I", -1, b"rv32-v1")
    assert pointer
    try:
        response = json.loads(ctypes.string_at(pointer))
    finally:
        lib.contract_spike_free(pointer)
    assert response["setup_evidence_version"] == 1
    assert "error" not in response
    result = response["cases"][0]
    assert "error" not in result, result
    return {(a["type"], a["observation"]): a["first_retire"] for a in result["atoms"]}


body = [instruction("ADDI", rd=3, rs1=1, imm=0), instruction("ADD", rd=4, rs1=2, rs2=0)]
first = setup({1: 0x80000000, 2: 0xffffffff}) + body
second = setup({}) + body
included = run(first, second, True)
excluded = run(first, second, False)
assert ("LUI", "REG_RD") in included
assert ("LUI", "REG_RD") not in excluded
assert included[("ADDI", "REG_RD")] == 34
assert excluded[("ADDI", "REG_RD")] == 96  # repeated atom, first body instruction
assert excluded[("ADDI", "REG_RS1")] == 96
assert excluded[("ADD", "REG_RS1")] == 97  # final instruction must execute
assert included == run(first, second, True, metadata=False)  # old-file interpretation
first = setup({}) + [instruction("ADDI", rd=3, rs1=31, imm=0)]
second = setup({}) + [instruction("ADDI", rd=3, rs1=31, imm=0)]
second[61] = instruction("ADDI", rd=0, rs1=31, imm=0)
assert run(first, second, False)[("ADDI", "RAW_RS1_2")] == 96
print("Full-width setup, signed extremes, evidence boundaries, history and retirement bounds passed")
