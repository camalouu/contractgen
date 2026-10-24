module darkriscv_test_top (
    input  logic clk,
    input  logic reset,
    output logic finished_o,
    output logic atk_equiv_o
);
    import "DPI-C" function void contract_reference_retire(input int core_id,
        input int unsigned pc, input int unsigned instruction, input int rd, input int unsigned value, input int trap);
    import "DPI-C" function int contract_dark_debug_enable();
    top paired_darkriscv (.clk(clk), .reset(reset));
    assign finished_o = paired_darkriscv.finished;
    assign atk_equiv_o = paired_darkriscv.atk_equiv;
    logic [31:0] actual_instruction_1, actual_instruction_2;
    logic [4:0] actual_rd_1, actual_rd_2;
    always @(posedge paired_darkriscv.clock_1) begin
        if(contract_dark_debug_enable() && paired_darkriscv.core_1.PC >= 32'h100)
            $display("Dark pc=%h instruction=%h flush=%b decode=%b flushed=%b reset=%b next=%h jreq=%b",paired_darkriscv.core_1.PC,paired_darkriscv.core_1.XIDATA,paired_darkriscv.core_1.FLUSH,paired_darkriscv.core_1.decode_reg,paired_darkriscv.core_1.flushed,paired_darkriscv.core_1.XRES,paired_darkriscv.core_1.NXPC,paired_darkriscv.core_1.JREQ);

        actual_instruction_1 <= paired_darkriscv.core_1.XIDATA;
        actual_rd_1 <= paired_darkriscv.core_1.AUIPC || paired_darkriscv.core_1.JAL || paired_darkriscv.core_1.JALR || paired_darkriscv.core_1.LUI || paired_darkriscv.core_1.LCC || paired_darkriscv.core_1.MCC || paired_darkriscv.core_1.RCC ? paired_darkriscv.core_1.DPTR : 0;
    end
    always @(posedge paired_darkriscv.clock_2) begin
        actual_instruction_2 <= paired_darkriscv.core_2.XIDATA;
        actual_rd_2 <= paired_darkriscv.core_2.AUIPC || paired_darkriscv.core_2.JAL || paired_darkriscv.core_2.JALR || paired_darkriscv.core_2.LUI || paired_darkriscv.core_2.LCC || paired_darkriscv.core_2.MCC || paired_darkriscv.core_2.RCC ? paired_darkriscv.core_2.DPTR : 0;
    end
    always @(negedge paired_darkriscv.clock_1) if (paired_darkriscv.retire_1)
        contract_reference_retire(1,paired_darkriscv.trace_pc_1,actual_instruction_1,actual_rd_1,
`ifdef DARKRISCV_THREE_STAGE
            paired_darkriscv.core_1.REG1[(31-actual_rd_1)*32 +: 32]
`else
            paired_darkriscv.core_1.REG1[actual_rd_1]
`endif
,0);
    always @(negedge paired_darkriscv.clock_2) if (paired_darkriscv.retire_2)
        contract_reference_retire(2,paired_darkriscv.trace_pc_2,actual_instruction_2,actual_rd_2,
`ifdef DARKRISCV_THREE_STAGE
            paired_darkriscv.core_2.REG1[(31-actual_rd_2)*32 +: 32]
`else
            paired_darkriscv.core_2.REG1[actual_rd_2]
`endif
,0);
endmodule
