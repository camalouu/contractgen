module atk(
    input  logic clk_i,
    input  logic observation_1_i,
    input  logic observation_2_i,
    output logic equivalent_o
);
    initial equivalent_o = 1'b1;
    always @(clk_i) begin
        if (observation_1_i != observation_2_i)
            equivalent_o = 1'b0;
    end
endmodule
