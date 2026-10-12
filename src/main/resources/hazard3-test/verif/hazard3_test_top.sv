module hazard3_test_top (
    input  logic clk,
    input  logic rst_ni,
    output logic finished_o,
    output logic atk_equiv_o
);
    import "DPI-C" function void contract_reference_retire(input int core_id,
        input int unsigned pc, input int unsigned instruction, input int rd, input int unsigned value, input int trap);
    top paired_hazard3 (
        .clk(clk),
        .rst_ni(rst_ni)
    );

    assign finished_o = paired_hazard3.finished;
    assign atk_equiv_o = paired_hazard3.atk_equiv;
    always @(negedge paired_hazard3.clock_1) if (paired_hazard3.retire_1)
        contract_reference_retire(1,paired_hazard3.old_pc_1,paired_hazard3.retire_instr_1,paired_hazard3.rd_1,paired_hazard3.rd_wdata_1,paired_hazard3.rvfi_trap_1);
    always @(negedge paired_hazard3.clock_2) if (paired_hazard3.retire_2)
        contract_reference_retire(2,paired_hazard3.old_pc_2,paired_hazard3.retire_instr_2,paired_hazard3.rd_2,paired_hazard3.rd_wdata_2,paired_hazard3.rvfi_trap_2);
endmodule
