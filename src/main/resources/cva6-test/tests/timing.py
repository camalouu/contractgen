"""Native regressions for instruction-image corruption and identical-pair timing."""
import ctypes
import sys
from concurrent.futures import ThreadPoolExecutor

I, U = ctypes.c_int, ctypes.c_uint32
library = ctypes.CDLL(sys.argv[1])
batch = library.contract_cva6_test_attacker_batch
batch.argtypes = [I, I, ctypes.POINTER(I), ctypes.POINTER(I), ctypes.POINTER(U), ctypes.POINTER(U), ctypes.POINTER(I)]
batch.restype = I


def branch(funct3, offset):
    imm = offset & 8191
    return (((imm >> 12) & 1) << 31 | ((imm >> 5) & 63) << 25
            | 17 << 20 | funct3 << 12 | ((imm >> 1) & 15) << 8
            | ((imm >> 11) & 1) << 7 | 0x63)


def image(funct3, offset):
    words = [0x13] * 2048
    # x17 is nonzero; BLTU x0,x17 is taken, BEQ x0,x17 is not.
    words[16] = (2513 << 20) | (17 << 7) | 0x13
    words[32] = 0x33  # ADD x0,x0,x0, as in the failing generated test.
    words[33] = branch(funct3, offset)
    return words


def run(left, right, bound=46):
    a, b = (U * 2048)(*left), (U * 2048)(*right)
    index, count, status = (I * 1)(8470), (I * 1)(bound), (I * 1)(-1)
    result = batch(1, 10000, index, count, a, b, status)
    assert result == 0 and status[0] in (0, 1), (result, status[0])
    return status[0]


# Offset 1652 reaches PC 0x778 and then the formerly corrupted word at 0x780.
# Neighbouring targets and longer runs exercise other overwritten image words.
cases = [image(6, offset) for offset in (8, 16, 64, 752, 1644, 1652, 1660, 2048, 3408)]
for words in cases:
    for bound in (46, 64, 96):
        assert run(words, words, bound) == 0
with ThreadPoolExecutor(max_workers=4) as workers:
    assert list(workers.map(lambda words: run(words, words), cases * 3)) == [0] * (len(cases) * 3)
# Do not obtain equivalence by accidentally disabling the timing attacker.
assert run(image(0, 8), image(0, -8)) == 1
print("CVA6: 54 identical-pair runs and positive branch-timing control passed")
