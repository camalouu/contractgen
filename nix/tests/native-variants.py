"""Variant timing fixtures, failure handling, and isolation through the public native ABIs."""
import concurrent.futures
import ctypes as C
import sys

U = C.c_uint32
I = C.c_int
UP = C.POINTER(U)
IP = C.POINTER(I)


def addi(rd, rs1, value):
    return ((value & 4095) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def load(rd, rs1):
    return (rs1 << 15) | (2 << 12) | (rd << 7) | 3


def image(program):
    words = (U * 2048)(*[0x13] * 2048)
    for n, instruction in enumerate(program):
        words[32 + n] = instruction
    return words


def check(path, kind):
    library = C.CDLL(path)
    ibex = kind.startswith('ibex')
    batch = library.contract_ibex_test_attacker_batch_v4 if ibex else library.contract_simple_attacker_batch_v1
    batch.argtypes = [I, I, IP, IP, UP, UP, IP] + ([IP, IP] if ibex else [])
    batch.restype = I

    def run(first, second, cycles=10000, bound=44):
        status, cutoff, execution = (I * 1)(), (I * 1)(), (I * 1)()
        args = [1, cycles, (I * 1)(0), (I * 1)(bound), image(first), image(second), status]
        if ibex:
            args.extend([cutoff, execution])
        result = batch(*args)
        return result, status[0]

    same = [addi(1, 0, 17), addi(2, 1, 1)]
    if ibex:
        if kind == 'ibex-cache':
            # Same zero-valued loads: repeated address hits only in the left run.
            first = [addi(1, 0, 0), addi(2, 0, 0), load(3, 1), load(4, 2)]
            second = [addi(1, 0, 0), addi(2, 0, 4), load(3, 1), load(4, 2)]
        else:
            multiply = (2 << 20) | (1 << 15) | (3 << 7) | 0x02000033
            first = [addi(1, 0, 7), addi(2, 0, 1), multiply]
            second = [addi(1, 0, 7), addi(2, 0, 2047), multiply]
    else:
        # Taken versus not-taken branch, followed by identical instructions.
        first = [addi(1, 0, 0), 0x00008463, addi(3, 0, 7), addi(4, 0, 9)]
        second = [addi(1, 0, 1), *first[1:]]

    expected = 0 if kind == 'ibex-small' else 1
    assert run(first, second) == (0, expected), (kind, 'timing fixture', run(first, second))
    assert run(same, same, cycles=1)[1] == 2, (kind, 'short cycle budget')
    malformed = run(same, same, bound=-1)
    assert malformed[1] == 3, (kind, 'malformed retirement bound', malformed)

    def repeat(_):
        for _ in range(8):
            assert run(first, second) == (0, expected), kind
            assert run(same, same) == (0, 0), kind
            assert run(first, first) == (0, 0), kind
            assert run(second, second) == (0, 0), kind

    repeat(0)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as workers:
        list(workers.map(repeat, range(4)))
    print(kind, 'timing, timeout/error handling, cold-state and concurrent isolation passed')


if len(sys.argv) != 11:
    raise SystemExit('Expected five (library, kind) pairs')
for n in range(1, len(sys.argv), 2):
    check(sys.argv[n], sys.argv[n + 1])
