module control (
    input  logic        clk_i,
    input  logic        retire_i,
    input  logic        fetch_1_i,
    input  logic        fetch_2_i,
    input  logic [31:0] instr_addr_1_i,
    input  logic [31:0] instr_addr_2_i,
    output logic        enable_1_o,
    output logic        enable_2_o,
    output logic        finished_o
);
    import "DPI-C" function int contract_hazard3_max_instr_count();

    integer retire_count;
    integer fetch_1_count;
    integer fetch_2_count;
    wire [31:0] max_instr_count = $unsigned(contract_hazard3_max_instr_count());

    initial begin
        retire_count = 0;
        fetch_1_count = 0;
        fetch_2_count = 0;
        enable_1_o = 1'b1;
        enable_2_o = 1'b1;
        finished_o = 1'b0;
    end

    always @(negedge clk_i) begin
        if (retire_i) retire_count = retire_count + 1;

        enable_1_o = 1;
        enable_2_o = 1;
        if (retire_count >= max_instr_count) finished_o <= 1;
    end
endmodule
