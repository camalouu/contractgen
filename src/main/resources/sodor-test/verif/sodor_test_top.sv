module sodor_test_top (
    input  logic clk,
    input  logic reset,
    output logic finished_o,
    output logic atk_equiv_o
);
    import "DPI-C" function void contract_reference_retire(input int core_id,
        input int unsigned pc, input int unsigned instruction, input int rd, input int unsigned value, input int trap);
    import "DPI-C" function void contract_reference_write(input int core_id, input int rd, input int unsigned value);
    top paired_sodor (.clk(clk), .reset(reset));
    assign finished_o = paired_sodor.finished;
    assign atk_equiv_o = paired_sodor.atk_equiv;
    always @(negedge paired_sodor.clock_1) if (paired_sodor.retire_1)
        contract_reference_retire(1,paired_sodor.trace_pc_1,paired_sodor.retire_instr_1,paired_sodor.rd_1,paired_sodor.rd_wdata_1,paired_sodor.rvfi_trap_1);
    always @(negedge paired_sodor.clock_2) if (paired_sodor.retire_2)
        contract_reference_retire(2,paired_sodor.trace_pc_2,paired_sodor.retire_instr_2,paired_sodor.rd_2,paired_sodor.rd_wdata_2,paired_sodor.rvfi_trap_2);
    always @(posedge paired_sodor.clock_1) if (!reset && paired_sodor.core_1.DatPath_2stage.regfile_MPORT_1_en)
        contract_reference_write(1,int'(paired_sodor.core_1.DatPath_2stage.regfile_MPORT_1_addr),paired_sodor.core_1.DatPath_2stage.regfile_MPORT_1_data);
    always @(posedge paired_sodor.clock_2) if (!reset && paired_sodor.core_2.DatPath_2stage.regfile_MPORT_1_en)
        contract_reference_write(2,int'(paired_sodor.core_2.DatPath_2stage.regfile_MPORT_1_addr),paired_sodor.core_2.DatPath_2stage.regfile_MPORT_1_data);
endmodule
