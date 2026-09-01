module sodor_test_top (
    input  logic clk,
    input  logic reset,
    output logic finished_o,
    output logic atk_equiv_o
);
    top paired_sodor (.clk(clk), .reset(reset));
    assign finished_o = paired_sodor.finished;
    assign atk_equiv_o = paired_sodor.atk_equiv;
endmodule
