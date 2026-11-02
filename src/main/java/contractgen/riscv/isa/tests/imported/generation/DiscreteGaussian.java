package contractgen.riscv.isa.tests.imported.generation;

import java.util.Locale;
import java.util.random.RandomGenerator;

/**
 * A Gaussian distribution over the integers {@code min..max}: {@code i} has a probability proportional to
 * exp(−(i − mean)² / (2 · deviation²)). The mean may lie outside the range; with deviation 0, the distribution is
 * concentrated on the integer of the range nearest to the mean.
 * <p>
 * The text form (command line, experiment presets) is {@code mean=<x>,sd=<x>,min=<n>,max=<n>}; a plain number
 * {@code n} is the constant n. See {@link #parse(String, DiscreteGaussian)} for leaving out keys.
 */
public record DiscreteGaussian(double mean, double deviation, int min, int max) {

    public DiscreteGaussian {
        if (!Double.isFinite(mean)) throw new IllegalArgumentException("mean " + mean + " is not a number");
        if (!Double.isFinite(deviation) || deviation < 0) throw new IllegalArgumentException("sd " + deviation + " is not a non-negative number");
        if (min > max) throw new IllegalArgumentException("min " + min + " is greater than max " + max);
    }

    /** @return the distribution that is always {@code n} */
    public static DiscreteGaussian constant(int n) {
        return new DiscreteGaussian(n, 0, n, n);
    }

    public int sample(RandomGenerator r) {
        return sample(r, max);
    }

    /**
     * @return a sample of the distribution restricted to {@code min..min(max, upper)}; {@code upper} if it is less than
     * {@code min}
     */
    public int sample(RandomGenerator r, int upper) {
        int hi = Math.min(max, upper);
        if (hi <= min) return hi;
        // the integer nearest to the mean has the largest weight; weights relative to it do not all underflow
        int nearest = (int) Math.max(min, Math.min(hi, Math.round(mean)));
        if (deviation == 0) return nearest;
        double[] weights = new double[hi - min + 1];
        double sum = 0;
        for (int i = min; i <= hi; i++) {
            weights[i - min] = Math.exp((square(nearest - mean) - square(i - mean)) / (2 * deviation * deviation));
            sum += weights[i - min];
        }
        double u = r.nextDouble() * sum;
        for (int i = min; i < hi; i++) {
            u -= weights[i - min];
            if (u < 0) return i;
        }
        return hi;
    }

    private static double square(double x) {
        return x * x;
    }

    /** Parses the text form, which must give all four keys (or be a plain number). */
    public static DiscreteGaussian parse(String spec) {
        return parse(spec, null);
    }

    /**
     * Parses the text form. Keys may come in any order, and keys left out keep their values in {@code defaults}
     * ({@code max=5} changes only the maximum). A plain number {@code n} is the constant n.
     *
     * @param defaults the values of the keys left out; if null, all keys are required
     */
    public static DiscreteGaussian parse(String spec, DiscreteGaussian defaults) {
        String s = spec.strip();
        if (s.matches("-?\\d+")) return constant(Integer.parseInt(s));
        Double mean = null, deviation = null;
        Integer min = null, max = null;
        for (String part : s.split(",")) {
            String[] kv = part.split("=", 2);
            if (kv.length != 2) throw new IllegalArgumentException("expected key=value instead of '" + part.strip() + "'");
            String value = kv[1].strip();
            try {
                switch (kv[0].strip().toLowerCase(Locale.ROOT)) {
                    case "mean" -> mean = Double.parseDouble(value);
                    case "sd" -> deviation = Double.parseDouble(value);
                    case "min" -> min = Integer.parseInt(value);
                    case "max" -> max = Integer.parseInt(value);
                    default -> throw new IllegalArgumentException("unknown key '" + kv[0].strip() + "' (keys: mean, sd, min, max)");
                }
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("not a number: '" + part.strip() + "'");
            }
        }
        if (defaults == null && (mean == null || deviation == null || min == null || max == null)) {
            throw new IllegalArgumentException("'" + s + "' needs all of mean, sd, min and max");
        }
        return new DiscreteGaussian(mean != null ? mean : defaults.mean, deviation != null ? deviation : defaults.deviation,
                min != null ? min : defaults.min, max != null ? max : defaults.max);
    }

    /** @return the text form */
    @Override
    public String toString() {
        return "mean=" + number(mean) + ",sd=" + number(deviation) + ",min=" + min + ",max=" + max;
    }

    private static String number(double x) {
        return x == Math.rint(x) && Math.abs(x) < 1e15 ? Long.toString((long) x) : Double.toString(x);
    }
}
