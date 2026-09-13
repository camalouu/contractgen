module cv32e40s_test_top import cv32e40s_pkg::*; (
    input logic clk, rst_ni, timing_i,
    input logic inject_parity_error_i,
    input logic [31:0] max_instr_i,
    output logic finished_o, atk_equiv_o, error_o,
    output logic [31:0] retire_count_o,
    output logic [31:0] error_code_o, debug_pc_o, debug_cpuctrl_o
);
    logic [1:0] core_clk, retire, boot, instr_req, instr_gnt, instr_rvalid;
    logic [1:0] data_req, data_gnt, data_rvalid, data_we, major_alert, minor_alert, trap;
    logic [1:0][31:0] instr_addr, instr_rdata, data_addr, data_wdata, data_rdata, retire_pc;
    logic [1:0][3:0] data_be;
    logic [1:0][4:0] instr_rchk, data_rchk;
    logic [1:0][31:0] cpuctrl;
    logic [1:0] unsupported_alignment;
    logic paired_retire;
    logic measuring;
    integer boot_count;

    assign debug_pc_o = retire_pc[0];
    assign debug_cpuctrl_o = cpuctrl[0];
    localparam lfsr_cfg_t FIXED_LFSR = '{coeffs:32'h80000057, default_seed:32'h1};

    for (genvar n = 0; n < 2; n++) begin : gen_core
        assign instr_rchk[n] = {1'b0, ^instr_rdata[n][31:24], ^instr_rdata[n][23:16],
                               ^instr_rdata[n][15:8], ^instr_rdata[n][7:0]};
        assign data_rchk[n] = {1'b0, ^data_rdata[n][31:24], ^data_rdata[n][23:16],
                              ^data_rdata[n][15:8], ^data_rdata[n][7:0]};
        cv32e40s_core #(
            .RV32(RV32I), .M_EXT(M), .B_EXT(B_NONE), .DEBUG(0), .DBG_NUM_TRIGGERS(0),
            .PMA_NUM_REGIONS(0), .PMP_NUM_REGIONS(0), .CLIC(0),
            .LFSR0_CFG(FIXED_LFSR), .LFSR1_CFG(FIXED_LFSR), .LFSR2_CFG(FIXED_LFSR)
        ) core (
            .clk_i(core_clk[n]), .rst_ni(rst_ni), .scan_cg_en_i(1'b0),
            .boot_addr_i(32'b0), .mtvec_addr_i(32'h4000), .mhartid_i(32'b0), .mimpid_patch_i(4'b0),
            .dm_exception_addr_i(32'h4000), .dm_halt_addr_i(32'h4000),
            .instr_req_o(instr_req[n]), .instr_gnt_i(instr_gnt[n]), .instr_rvalid_i(instr_rvalid[n]),
            .instr_addr_o(instr_addr[n]), .instr_rdata_i(instr_rdata[n]), .instr_err_i(1'b0),
            .instr_gntpar_i((!instr_gnt[n]) ^ (inject_parity_error_i && n == 0)),
            .instr_rvalidpar_i(!instr_rvalid[n]), .instr_rchk_i(instr_rchk[n]),
            .data_req_o(data_req[n]), .data_gnt_i(data_gnt[n]), .data_rvalid_i(data_rvalid[n]),
            .data_addr_o(data_addr[n]), .data_we_o(data_we[n]), .data_be_o(data_be[n]),
            .data_wdata_o(data_wdata[n]), .data_rdata_i(data_rdata[n]), .data_err_i(1'b0),
            .data_gntpar_i(!data_gnt[n]), .data_rvalidpar_i(!data_rvalid[n]), .data_rchk_i(data_rchk[n]),
            .irq_i(32'b0), .wu_wfe_i(1'b0), .clic_irq_i(1'b0), .clic_irq_id_i(5'b0),
            .clic_irq_level_i(8'b0), .clic_irq_priv_i(2'b0), .clic_irq_shv_i(1'b0),
            .fencei_flush_ack_i(1'b1), .debug_req_i(1'b0), .fetch_enable_i(1'b1),
            .alert_major_o(major_alert[n]), .alert_minor_o(minor_alert[n]),
            .debug_pc_valid_o(retire[n]), .debug_pc_o(retire_pc[n])
        );
        assign cpuctrl[n] = core.cs_registers_i.cpuctrl_q;

        // The current Spike synthetic halfword model and generated workload use
        // word-aligned halfwords/words. Reject broader replay inputs explicitly.
        assign unsupported_alignment[n] = core.load_store_unit_i.trans_valid &&
            core.load_store_unit_i.trans.size != 0 && core.load_store_unit_i.trans.addr[1:0] != 0;
        assign trap[n] = core.ctrl_fsm.pc_set &&
            (core.ctrl_fsm.pc_mux inside {PC_TRAP_EXC, PC_TRAP_IRQ, PC_TRAP_DBD,
                                          PC_TRAP_DBE, PC_TRAP_NMI, PC_TRAP_CLICV});
        always_ff @(posedge core_clk[n] or negedge rst_ni) begin
            if (!rst_ni) boot[n] <= 1;
            else if (retire[n] && retire_pc[n] == 4) boot[n] <= 0;
        end
        cv32e40s_instr_mem #(.ID(n+1)) imem (
            .clk_i(core_clk[n]), .rst_ni(rst_ni), .req_i(instr_req[n]), .addr_i(instr_addr[n]),
            .boot_i(boot[n]), .timing_i(timing_i), .gnt_o(instr_gnt[n]),
            .rvalid_o(instr_rvalid[n]), .rdata_o(instr_rdata[n])
        );
        cv32e40s_data_mem dmem (
            .clk_i(core_clk[n]), .rst_ni(rst_ni), .req_i(data_req[n]), .addr_i(data_addr[n]),
            .we_i(data_we[n]), .be_i(data_be[n]), .wdata_i(data_wdata[n]),
            .gnt_o(data_gnt[n]), .rvalid_o(data_rvalid[n]), .rdata_o(data_rdata[n])
        );
    end

    clk_sync clocks (
        .clk_i(clk), .retire_1_i(retire[0]), .retire_2_i(retire[1]),
        .clk_1_o(core_clk[0]), .clk_2_o(core_clk[1]), .retire_o(paired_retire)
    );

    // Match the existing attacker: any difference in the synchronized clocks is sticky.
    always @(clk or negedge rst_ni) begin
        if (!rst_ni) atk_equiv_o <= 1;
        else if (measuring && !finished_o && core_clk[0] != core_clk[1]) atk_equiv_o <= 0;
    end

    always @(negedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            boot_count = 0;
            measuring = 0;
            retire_count_o = 0;
            finished_o = 0;
            error_o = 0;
            error_code_o = 0;
        end else if (!finished_o) begin
            if (|major_alert) error_code_o[0] = 1;
            if (|minor_alert) error_code_o[1] = 1;
            if (|trap) error_code_o[2] = 1;
            if (|unsupported_alignment) error_code_o[5] = 1;
            if (paired_retire) begin
                if (boot_count < 2) begin
                    if (retire_pc[0] != boot_count*4 || retire_pc[1] != boot_count*4) begin
                        error_code_o[3] = 1;
                    end
                    boot_count = boot_count + 1;
                    if (boot_count == 2) begin
                        if (cpuctrl[0] != (32'h10 | {31'b0,timing_i}) || cpuctrl[1] != cpuctrl[0]) begin
                            error_code_o[4] = 1;
                        end
                        measuring = 1;
                    end
                end else begin
                    retire_count_o = retire_count_o + 1;
                    if (retire_count_o >= max_instr_i) finished_o = 1;
                end
            end
            error_o = |error_code_o;
        end
    end
endmodule
