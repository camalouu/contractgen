module atk(
    input logic clk_i,
    input logic atk_observation_1_i,
    input logic atk_observation_2_i,
    output logic atk_equiv_o
);

    initial atk_equiv_o = 1'b1;

    always @(clk_i) begin
        if (atk_observation_1_i != atk_observation_2_i) begin
            atk_equiv_o <= 1'b0;
        end
    end
endmodule
