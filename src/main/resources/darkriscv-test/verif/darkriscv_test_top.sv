module darkriscv_test_top (
    input  logic clk,
    input  logic reset,
    output logic finished_o,
    output logic atk_equiv_o
);
    top paired_darkriscv (.clk(clk), .reset(reset));
    assign finished_o = paired_darkriscv.finished;
    assign atk_equiv_o = paired_darkriscv.atk_equiv;
endmodule
