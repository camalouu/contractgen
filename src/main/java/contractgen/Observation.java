package contractgen;

/**
 * The observation interface.
 */
public interface Observation {

    /**
     * @return the value of the observation corresponding to its severity.
     */
    int getValue();

    Type getType();

    ObservationType getObservation();

    boolean matchExceptType(Observation observation);

    /** Whether selecting this observation exposes its instruction-specific presence. */
    default boolean isTypeScoped() { return true; }

    @Override
    boolean equals(Object o);

    @Override
    int hashCode();

    @Override
    String toString();

    /**
     * @return whether this observation is applicable.
     */
    boolean isApplicable();
}
