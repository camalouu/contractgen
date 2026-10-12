`define NO_OP     32'h00000013
`define MAX_INSTR 2048

module instr_mem #(
    parameter int unsigned ID = 0
) (
    input  logic        clk_i,
    input  logic        enable_i,
    input  logic        instr_req_i,
    input  logic [31:0] instr_addr_i,
    output logic        instr_gnt_o,
    output logic [31:0] instr_o
);
    import "DPI-C" function int contract_simple_instr_word(input int core_id, input int word_index);

    wire [31:0] image_addr = instr_addr_i - 32'h80;
    assign instr_gnt_o = instr_req_i;
    always_comb begin
        instr_o = enable_i && ((image_addr >> 2) < `MAX_INSTR)
            ? $unsigned(contract_simple_instr_word(ID,image_addr >> 2)) : `NO_OP;
    end
endmodule
