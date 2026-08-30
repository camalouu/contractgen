module hazard3_test_top (
    input  logic clk,
    input  logic rst_ni,
    output logic finished_o,
    output logic atk_equiv_o
);
    top paired_hazard3 (
        .clk(clk),
        .rst_ni(rst_ni)
    );

    assign finished_o = paired_hazard3.finished;
    assign atk_equiv_o = paired_hazard3.atk_equiv;
endmodule
