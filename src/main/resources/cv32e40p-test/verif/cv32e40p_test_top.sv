module cv32e40p_test_top (
    input logic clk, input logic rst_ni,
    output logic finished_o, output logic atk_equiv_o
);
    logic [1:0] core_clk, retire;
    logic synchronized_retire;
    logic [1:0] instr_req, instr_gnt, instr_rvalid;
    logic [1:0][31:0] instr_addr, instr_rdata;
    logic [1:0] data_req, data_gnt, data_rvalid, data_we;
    logic [1:0][3:0] data_be;
    logic [1:0][31:0] data_addr, data_wdata, data_rdata;

    genvar core_index;
    generate for (core_index = 0; core_index < 2; core_index++) begin : gen_core
        cv32e40p_top #(
            .COREV_PULP(0), .COREV_CLUSTER(0), .FPU(0), .ZFINX(0),
            .NUM_MHPMCOUNTERS(1)
        ) core (
            .clk_i(core_clk[core_index]), .rst_ni(rst_ni),
            .pulp_clock_en_i(1'b0), .scan_cg_en_i(1'b0),
            .boot_addr_i(32'b0), .mtvec_addr_i(32'b0),
            .dm_halt_addr_i(32'b0), .hart_id_i(core_index),
            .dm_exception_addr_i(32'b0),
            .instr_req_o(instr_req[core_index]), .instr_gnt_i(instr_gnt[core_index]),
            .instr_rvalid_i(instr_rvalid[core_index]), .instr_addr_o(instr_addr[core_index]),
            .instr_rdata_i(instr_rdata[core_index]),
            .data_req_o(data_req[core_index]), .data_gnt_i(data_gnt[core_index]),
            .data_rvalid_i(data_rvalid[core_index]), .data_we_o(data_we[core_index]),
            .data_be_o(data_be[core_index]), .data_addr_o(data_addr[core_index]),
            .data_wdata_o(data_wdata[core_index]), .data_rdata_i(data_rdata[core_index]),
            .irq_i(32'b0), .irq_ack_o(), .irq_id_o(), .debug_req_i(1'b0),
            .debug_havereset_o(), .debug_running_o(), .debug_halted_o(),
            .fetch_enable_i(1'b1), .core_sleep_o()
        );
        assign retire[core_index] = core.core_i.mhpmevent_minstret;
        cv32e40p_obi_instr_mem #(.ID(core_index + 1)) imem (
            .clk_i(core_clk[core_index]), .req_i(instr_req[core_index]),
            .addr_i(instr_addr[core_index]), .gnt_o(instr_gnt[core_index]),
            .rvalid_o(instr_rvalid[core_index]), .rdata_o(instr_rdata[core_index])
        );
        cv32e40p_obi_data_mem dmem (
            .clk_i(core_clk[core_index]), .req_i(data_req[core_index]),
            .we_i(data_we[core_index]), .be_i(data_be[core_index]),
            .addr_i(data_addr[core_index]), .wdata_i(data_wdata[core_index]),
            .gnt_o(data_gnt[core_index]), .rvalid_o(data_rvalid[core_index]),
            .rdata_o(data_rdata[core_index])
        );
    end endgenerate

    clk_sync clocks (
        .clk_i(clk), .retire_1_i(retire[0]), .retire_2_i(retire[1]),
        .clk_1_o(core_clk[0]), .clk_2_o(core_clk[1]), .retire_o(synchronized_retire)
    );
    atk attacker (
        .clk_i(clk), .atk_observation_1_i(core_clk[0]),
        .atk_observation_2_i(core_clk[1]), .atk_equiv_o(atk_equiv_o)
    );
    cv32e40p_retire_control control (
        .clk_i(clk), .reset_i(!rst_ni), .retire_i(synchronized_retire), .finished_o(finished_o)
    );
endmodule
