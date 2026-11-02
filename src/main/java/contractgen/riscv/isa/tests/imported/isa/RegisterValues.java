package contractgen.riscv.isa.tests.imported.isa;

import java.util.List;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.random.RandomGenerator;

/**
 * Which values test generation puts into registers: the initial registers of a program and the values that modifier
 * functions load. {@link Program} initializes every register with {@code lui} + {@code addi} either way, so both
 * distributions produce the same memory layout.
 */
public enum RegisterValues {

    /**
     * The values of the original generator and of both papers: the sign extension of a random 12-bit immediate, as a
     * single addi sets them. Bits 12 to 31 are therefore always copies of bit 11.
     */
    LEGACY,

    /** Any 32-bit value, from the mixture of {@link #random(RandomGenerator)}. */
    FULL;

    private static final long[] SPECIAL = special();

    /**
     * A random 32-bit value (as an unsigned long), drawn with equal probability from four kinds:
     * <ul>
     *     <li>a {@link #LEGACY} value, so that small values and addresses near zero stay as frequent as before;</li>
     *     <li>a uniformly random value;</li>
     *     <li>a value of random magnitude: uniform below 2^k for a uniform k in 1..32 (for leaks of the size of an
     *     operand, such as early-terminating dividers);</li>
     *     <li>a special value: 0, 1, -1, the extremes of the signed range, a power of two, one less than a power of
     *     two, or a value next to a 4 KiB boundary.</li>
     * </ul>
     */
    public static long random(RandomGenerator r) {
        return switch (r.nextInt(4)) {
            case 0 -> Instruction.signExtend12(r.nextLong(4096)) & 0xffffffffL;
            case 1 -> r.nextLong(1L << 32);
            case 2 -> r.nextLong(1L << r.nextInt(1, 33));
            default -> SPECIAL[r.nextInt(SPECIAL.length)];
        };
    }

    /** A random non-zero 32-bit value of the {@link #FULL} distribution. */
    public static long randomNonZero(RandomGenerator r) {
        long v;
        do {
            v = random(r);
        } while (v == 0);
        return v;
    }

    private static long[] special() {
        SortedSet<Long> values = new TreeSet<>(List.of(0L, 1L, 0xffffffffL, 0x7fffffffL,
                0x80000000L));
        for (int k = 1; k < 32; k++) {
            values.add(1L << k);
            values.add((1L << k) - 1);
        }
        for (long page : new long[]{0x1000L, 0x2000L, 0x10000L, 0x80000000L, 0xfffff000L}) {
            values.add(page - 4);
            values.add(page - 1);
            values.add(page + 1);
        }
        return values.stream().mapToLong(Long::longValue).map(v -> v & 0xffffffffL).distinct().toArray();
    }
}
