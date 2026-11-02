package contractgen.riscv.isa.tests.imported.generation;

import org.junit.jupiter.api.Test;

import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

class DiscreteGaussianTest {

    @Test
    void parsesTheTextForm() {
        DiscreteGaussian d = DiscreteGaussian.parse("mean=2.5,sd=1,min=0,max=31");
        assertEquals(new DiscreteGaussian(2.5, 1, 0, 31), d);
        assertEquals("mean=2.5,sd=1,min=0,max=31", d.toString());
        assertEquals(d, DiscreteGaussian.parse(d.toString()));
        assertEquals(DiscreteGaussian.constant(7), DiscreteGaussian.parse("7", d));
        // keys in any order, with spaces; missing keys keep the defaults
        assertEquals(new DiscreteGaussian(2.5, 3, 0, 5), DiscreteGaussian.parse(" max = 5, sd=3 ", d));
    }

    @Test
    void rejectsMalformedAndInconsistentForms() {
        DiscreteGaussian d = new DiscreteGaussian(1, 1, 0, 10);
        assertThrows(IllegalArgumentException.class, () -> DiscreteGaussian.parse("mean=1,sd=1"));
        assertThrows(IllegalArgumentException.class, () -> DiscreteGaussian.parse("mu=1", d));
        assertThrows(IllegalArgumentException.class, () -> DiscreteGaussian.parse("mean", d));
        assertThrows(IllegalArgumentException.class, () -> DiscreteGaussian.parse("max=1.5", d));
        assertThrows(IllegalArgumentException.class, () -> DiscreteGaussian.parse("sd=-1", d));
        assertThrows(IllegalArgumentException.class, () -> DiscreteGaussian.parse("min=11", d));
    }

    /** The frequencies match exp(−(i − mean)² / (2 sd²)), normalized over min..max. */
    @Test
    void samplesFollowTheDistribution() {
        DiscreteGaussian d = new DiscreteGaussian(1, 1.5, 0, 6);
        Random r = new Random(1);
        int n = 200_000;
        int[] counts = new int[7];
        for (int k = 0; k < n; k++) counts[d.sample(r)]++;
        double sum = 0;
        for (int i = 0; i <= 6; i++) sum += Math.exp(-(i - 1) * (i - 1) / (2 * 1.5 * 1.5));
        for (int i = 0; i <= 6; i++) {
            double expected = Math.exp(-(i - 1) * (i - 1) / (2 * 1.5 * 1.5)) / sum;
            assertEquals(expected, counts[i] / (double) n, 0.005, "P(" + i + ")");
        }
    }

    @Test
    void edgeCases() {
        Random r = new Random(2);
        // no deviation: the integer of the range nearest to the mean
        assertEquals(3, new DiscreteGaussian(2.6, 0, 0, 10).sample(r));
        assertEquals(10, new DiscreteGaussian(20, 0, 0, 10).sample(r));
        // a mean far outside the range: its nearest end, without underflow
        assertEquals(0, new DiscreteGaussian(-1e6, 0.5, 0, 10).sample(r));
        assertEquals(10, new DiscreteGaussian(1e6, 0.5, 0, 10).sample(r));
        // a tiny deviation between two integers
        int s = new DiscreteGaussian(2.5, 1e-4, 0, 10).sample(r);
        assertTrue(s == 2 || s == 3, "sample " + s);
        // restricted to an upper bound
        DiscreteGaussian d = new DiscreteGaussian(8, 2, 2, 10);
        for (int k = 0; k < 1000; k++) {
            int v = d.sample(r, 4);
            assertTrue(v >= 2 && v <= 4, "sample " + v);
        }
        assertEquals(1, d.sample(r, 1));
        assertEquals(5, DiscreteGaussian.constant(5).sample(r));
    }
}
