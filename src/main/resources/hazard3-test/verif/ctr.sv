// HAZARD3_TEST does not extract architectural contract observations from RTL.
// Keep the legacy top's port shape while making its unused contract comparator
// permanently equivalent; Spike is the sole source of atom distinguishability.
module ctr (
    input logic clk_i,
    input logic retire_i,
    input logic [31:0] instr_1_i,
    input logic [31:0] instr_2_i,
    input logic [4:0] rd_1,
    input logic [4:0] rd_2,
    input logic [4:0] rs1_1,
    input logic [4:0] rs1_2,
    input logic [4:0] rs2_1,
    input logic [4:0] rs2_2,
    input logic [31:0] reg_rs1_1,
    input logic [31:0] reg_rs1_2,
    input logic [31:0] reg_rs2_1,
    input logic [31:0] reg_rs2_2,
    input logic [31:0] reg_rd_1,
    input logic [31:0] reg_rd_2,
    input logic [31:0] mem_addr_1,
    input logic [31:0] mem_addr_2,
    input logic [31:0] mem_r_data_1,
    input logic [31:0] mem_r_data_2,
    input logic [3:0] mem_r_mask_1,
    input logic [3:0] mem_r_mask_2,
    input logic [31:0] mem_w_data_1,
    input logic [31:0] mem_w_data_2,
    input logic [3:0] mem_w_mask_1,
    input logic [3:0] mem_w_mask_2,
    input logic [31:0] new_pc_1,
    input logic [31:0] new_pc_2,
    output logic ctr_equiv_o
);
    assign ctr_equiv_o = 1'b1;
endmodule
