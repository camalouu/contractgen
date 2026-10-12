`define NO_OP     32'h00000013
`define MAX_INSTR 2048

module instr_mem #(
    parameter int unsigned ID = 0
) (
    input  logic        clk_i,
    input  logic        enable_i,
    input  logic        instr_req_i,
    input  logic [31:0] instr_addr_i,
    output logic        instr_gnt_o, instr_rvalid_o,
    output logic [31:0] instr_o
);
    import "DPI-C" function int contract_hazard3_instr_word(input int core_id, input int word_index);

    logic [31:0] instr_addr;
    assign instr_addr = instr_addr_i - 32'h80;

    initial begin
        instr_o = `NO_OP;
        instr_rvalid_o = 1'b0;
    end

    assign instr_gnt_o = instr_req_i;
    always @(posedge clk_i) begin
        instr_rvalid_o <= instr_req_i;
        if (instr_req_i) begin
            instr_o <= enable_i && ((instr_addr >> 2) < `MAX_INSTR)
                    ? $unsigned(contract_hazard3_instr_word(ID, instr_addr >> 2))
                    : `NO_OP;
        end else begin
            instr_o <= `NO_OP;
        end
    end
endmodule
