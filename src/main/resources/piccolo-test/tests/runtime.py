"""Native failure, timing, reset and concurrent isolation regressions."""
import concurrent.futures
import ctypes
import sys

library = ctypes.CDLL(sys.argv[1])
u32 = ctypes.c_uint32
integer = ctypes.c_int
pointer = ctypes.POINTER(u32)
batch = library.contract_simple_attacker_batch_v1
batch.argtypes = [integer, integer, ctypes.POINTER(integer), ctypes.POINTER(integer), pointer, pointer, ctypes.POINTER(integer)]
batch.restype = integer

def image(instructions, registers=None):
    words = [0x13] * 2048
    for rd, value in (registers or {}).items():
        words[rd - 1] = ((value & 4095) << 20) | (rd << 7) | 0x13
    words[32:32 + len(instructions)] = instructions
    return (u32 * 2048)(*words)

def run(left, right, cycles=30000, count=36):
    index, bound, status = integer(0), integer(count), integer(-99)
    result = batch(1, cycles, ctypes.byref(index), ctypes.byref(bound), left, right, ctypes.byref(status))
    return result, status.value

nop = image([])
assert run(nop, nop) == (0, 0)
assert run(nop, nop, cycles=1)[1] in (2, 3)
assert run(nop, nop, count=-1)[0] != 0
assert batch(-1, 30000, None, None, None, None, None) != 0
trap = image([0x00000073]) # ECALL must fail even for an identical pair
assert run(trap, trap)[0] != 0
# Former upstream MMIO regions must reach ordinary persistent data memory.
trace = library.contract_architectural_trace_v1
trace.argtypes = [pointer, integer, integer, pointer, pointer]
trace.restype = integer
for address in (0x02000000, 0x0c000000, 0xc0000000):
    words = image([(address & 0xfffff000) | (1 << 7) | 0x37,
                   (123 << 20) | (2 << 7) | 0x13,
                   (2 << 20) | (1 << 15) | (2 << 12) | 0x23,
                   (1 << 15) | (2 << 12) | (3 << 7) | 3])
    pcs, registers = (u32 * 37)(), (u32 * 32)()
    assert trace(words, 37, 30000, pcs, registers) == 0
    assert registers[1] == address and registers[3] == 123
# DIVU exercises the supplied arithmetic unit, with unequal operand values.
div = (1 << 25) | (2 << 20) | (1 << 15) | (5 << 12) | (3 << 7) | 0x33
left = image([div, div], {1: 100, 2: 1})
right = image([div, div], {1: 100, 2: 100})
label = run(left, right)
assert label[0] == 0 and label[1] in (0, 1)
# Two loads hit the same cache line on the left, distinct lines on the right.
load1 = (1 << 15) | (2 << 12) | (3 << 7) | 3
load2 = (2 << 15) | (2 << 12) | (4 << 7) | 3
left = image([load1, load2], {1: 0, 2: 0})
right = image([load1, load2], {1: 0, 2: 64})
label = run(left, right)
assert label == (0, 1)
cycles = library.contract_piccolo_retirement_cycles_v1
cycles.argtypes = [pointer, integer, integer, pointer]
cycles.restype = integer
observed = []
for words in (left, right):
    captured = (u32 * 36)()
    assert cycles(words, 36, 30000, captured) == 0
    observed.append(list(captured))
assert observed[0][:33] == observed[1][:33]
assert observed[0][33] < observed[1][33], observed
store = image([(1 << 20) | (2 << 12) | 0x23], {1: 123})
fresh_load = image([(2 << 12) | (5 << 7) | 3])
for predecessor in [(nop, nop), (left, left), (right, right), (store, store), (trap, trap)]:
    run(*predecessor)
    assert run(left, right) == label
    assert run(nop, nop) == (0, 0)
    pcs, registers = (u32 * 34)(), (u32 * 32)()
    assert trace(fresh_load, 34, 30000, pcs, registers) == 0 and registers[5] == 0

def diagnostic(value):
    words = image([(value << 20) | (1 << 7) | 0x13])
    pcs, registers = (u32 * 34)(), (u32 * 32)()
    assert trace(words, 34, 30000, pcs, registers) == 0
    assert registers[1] == value and list(pcs) == list(range(0x80, 0x108, 4))
    return True

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    assert all(result == label for result in pool.map(lambda _: run(left, right), range(24)))
    assert all(pool.map(diagnostic, range(24)))
print('Piccolo native failure, timing and isolation checks passed')
