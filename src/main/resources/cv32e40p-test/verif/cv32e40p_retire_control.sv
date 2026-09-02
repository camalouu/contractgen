module cv32e40p_retire_control (
    input logic clk_i, input logic reset_i, input logic retire_i, output logic finished_o
);
    import "DPI-C" function int contract_simple_max_instr_count();
    integer retire_count;
    initial begin retire_count = 0; finished_o = 1'b0; end
    always @(negedge clk_i) begin
        if (reset_i) begin retire_count = 0; finished_o = 1'b0; end
        else if (retire_i) begin
            retire_count = retire_count + 1;
            if (retire_count >= contract_simple_max_instr_count()) finished_o = 1'b1;
        end
    end
endmodule
