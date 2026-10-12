"""Fixed architectural regressions for JALR bit-zero clearing and signed offsets."""
import ctypes
import sys

library = ctypes.CDLL(sys.argv[1])
trace = library.contract_architectural_trace_v1
pointer = ctypes.POINTER(ctypes.c_uint32)
trace.argtypes = [pointer, ctypes.c_int, ctypes.c_int, pointer, pointer]
trace.restype = ctypes.c_int


def addi(rd, rs1, immediate):
    return ((immediate & 4095) << 20) | (rs1 << 15) | (rd << 7) | 0x13


for value, offset, tail, rd3 in [
    (0x109, 0, [0x100, 0x104, 0x108, 0x10c], 7),
    (0x111, 0, [0x100, 0x104, 0x110, 0x114], 0),
    (0x109, -8, [0x100, 0x104, 0x100, 0x104], 0),
]:
    words = (ctypes.c_uint32 * 2048)(*[0x13] * 2048)
    words[32] = addi(1, 0, value)
    words[33] = ((offset & 4095) << 20) | (1 << 15) | (2 << 7) | 0x67
    words[34] = addi(3, 0, 7)
    pcs = (ctypes.c_uint32 * 36)()
    registers = (ctypes.c_uint32 * 32)()
    status = trace(words, 36, 30000, pcs, registers)
    assert status == 0, (value, offset, status)
    assert list(pcs) == list(range(0x80, 0x100, 4)) + tail, (value, offset, list(pcs))
    assert registers[1] == value and registers[2] == 0x108 and registers[3] == rd3
    assert all(registers[rd] == 0 for rd in range(4, 32))
print("JALR architectural bit-zero and signed-offset checks passed")
