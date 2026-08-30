`define PROTEUS_NOP 32'h00000013
`define PROTEUS_MAX_INSTR 2048

import "DPI-C" context function int contract_proteus_instr_word(input int core_id, input int word_index);

module instr_mem #(
    parameter integer ID = 0
) (
    input  logic        clk_i,
    input  logic        reset_i,
    input  logic        cmd_valid_i,
    output logic        cmd_ready_o,
    input  logic [31:0] cmd_addr_i,
    input  logic [1:0]  cmd_id_i,
    output logic        rsp_valid_o,
    input  logic        rsp_ready_i,
    output logic [31:0] rsp_data_o,
    output logic [1:0]  rsp_id_o
);
    logic [31:0] mem [0:`PROTEUS_MAX_INSTR-1];
    integer i;
    integer word_index;

    assign cmd_ready_o = 1'b1;
    initial begin
        for (i = 0; i < `PROTEUS_MAX_INSTR; i = i + 1)
            mem[i] = contract_proteus_instr_word(ID, i);
        rsp_valid_o = 1'b0;
        rsp_data_o = `PROTEUS_NOP;
        rsp_id_o = 2'b0;
    end

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            rsp_valid_o <= 1'b0;
        end else begin
            rsp_valid_o <= 1'b0;
            if (cmd_valid_i && cmd_ready_o) begin
                word_index = (cmd_addr_i - 32'h80) >> 2;
                rsp_data_o <= (cmd_addr_i >= 32'h80 && word_index >= 0
                        && word_index < `PROTEUS_MAX_INSTR) ? mem[word_index] : `PROTEUS_NOP;
                rsp_id_o <= cmd_id_i;
                rsp_valid_o <= 1'b1;
            end
        end
    end
endmodule
