import "DPI-C" context function int contract_proteus_max_instr_count();

module control(
    input  logic clk_i,
    input  logic reset_i,
    input  logic paired_retire_i,
    output logic finished_o,
    output logic [31:0] retire_count_o
);
    integer max_instr_count;
    initial begin
        max_instr_count = contract_proteus_max_instr_count();
        finished_o = 1'b0;
        retire_count_o = 32'b0;
    end

    always @(negedge clk_i) begin
        if (!reset_i && paired_retire_i) begin
            retire_count_o = retire_count_o + 1;
            if (retire_count_o >= max_instr_count)
                finished_o = 1'b1;
        end
    end
endmodule
