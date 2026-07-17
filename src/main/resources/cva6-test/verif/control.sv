module control (
    input logic clk_i,
    input logic retire_i,
    output logic finished_o
);
    import "DPI-C" function int contract_cva6_max_instr_count();

    int retire_count = 0;
    int max_instr_count;

    initial begin
        finished_o = 1'b0;
        max_instr_count = contract_cva6_max_instr_count();
    end

    always @(negedge clk_i) begin
        if (retire_i == 1'b1) begin
            retire_count = retire_count + 1;
        end

        if (retire_count >= max_instr_count) begin
            finished_o <= 1'b1;
        end
    end
endmodule
