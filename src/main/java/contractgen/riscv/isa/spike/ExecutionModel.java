package contractgen.riscv.isa.spike;

import picocli.CommandLine;

/** Versioned architectural semantics, independent of processor identity and timing. */
public enum ExecutionModel {
    RV32_V1("rv32-v1");

    private final String id;
    ExecutionModel(String id) { this.id = id; }
    @Override public String toString() { return id; }

    public static ExecutionModel parse(String id) {
        for (var model : values()) if (model.id.equals(id)) return model;
        throw new IllegalArgumentException("Unknown execution model: " + id);
    }

    public static final class Converter implements CommandLine.ITypeConverter<ExecutionModel> {
        @Override public ExecutionModel convert(String value) { return parse(value); }
    }
}
