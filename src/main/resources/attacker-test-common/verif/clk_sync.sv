module clk_sync (
    input  logic clk_i,
    input  logic retire_1_i,
    input  logic retire_2_i,
    output logic clk_1_o,
    output logic clk_2_o,
    output logic retire_o
);
    initial begin
        clk_1_o = 1'b0;
        clk_2_o = 1'b0;
    end
    always @(clk_i) begin
        if (retire_1_i == retire_2_i) begin
            clk_1_o <= clk_i;
            clk_2_o <= clk_i;
        end else if (retire_1_i) begin
            clk_2_o <= clk_i;
        end else if (retire_2_i) begin
            clk_1_o <= clk_i;
        end
    end
    assign retire_o = retire_1_i && retire_2_i;
endmodule
