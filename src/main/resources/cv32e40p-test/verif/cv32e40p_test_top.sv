module cv32e40p_test_top (
    input logic clk, input logic rst_ni,
    output logic finished_o, output logic atk_equiv_o
);
    import "DPI-C" function void contract_reference_retire(input int core_id, input int unsigned pc, input int unsigned instruction, input int rd, input int unsigned value, input int trap);
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
            .boot_addr_i(32'h80), .mtvec_addr_i(32'b0),
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
  cv32e40p_rvfi #(
      .FPU(0),
      .ZFINX(0),
      .NUM_MHPMCOUNTERS(1)
  ) rvfi_i (
      .clk_i (core.core_i.clk_i),
      .rst_ni(core.core_i.rst_ni),

      .is_decoding_i    (core.core_i.id_stage_i.is_decoding_o),
      .is_illegal_i     (core.core_i.id_stage_i.illegal_insn_dec),
      .trigger_match_i  (core.core_i.id_stage_i.trigger_match_i),
      .data_misaligned_i(core.core_i.data_misaligned),
      .lsu_data_we_ex_i (core.core_i.data_we_ex),
      .debug_mode_i     (core.core_i.debug_mode),
      .debug_cause_i    (core.core_i.debug_cause),
      //// Instr IF probes ////
      .instr_req_i      (core.core_i.instr_req_o),
      .instr_grant_i    (core.core_i.instr_gnt_i),
      .instr_rvalid_i   (core.core_i.instr_rvalid_i),
      .prefetch_req_i   (core.core_i.instr_req_int),
      .pc_set_i         (core.core_i.pc_set),

      .instr_valid_id_i    (core.core_i.instr_valid_id),
      .instr_rdata_id_i    (core.core_i.instr_rdata_id),
      .is_fetch_failed_id_i(core.core_i.is_fetch_failed_id),
      .instr_req_int_i     (core.core_i.instr_req_int),
      .clear_instr_valid_i (core.core_i.clear_instr_valid),
      //// IF probes ////
      .instr_valid_if_i    (core.core_i.if_stage_i.instr_valid),
      .if_valid_i          (core.core_i.if_stage_i.if_valid),
      .if_ready_i          (core.core_i.if_stage_i.if_ready),
      .instr_if_i          (core.core_i.if_stage_i.instr_aligned),
      .pc_if_i             (core.core_i.pc_if),
      //// ID probes ////
      .pc_id_i             (core.core_i.id_stage_i.pc_id_i),
      .id_valid_i          (core.core_i.id_stage_i.id_valid_o),
      .id_ready_i          (core.core_i.id_stage_i.id_ready_o),

      .rs1_addr_id_i     (core.core_i.id_stage_i.regfile_addr_ra_id),
      .rs2_addr_id_i     (core.core_i.id_stage_i.regfile_addr_rb_id),
      .rs3_addr_id_i     (core.core_i.id_stage_i.regfile_addr_rc_id),
      .operand_a_fw_id_i (core.core_i.id_stage_i.operand_a_fw_id),
      .operand_b_fw_id_i (core.core_i.id_stage_i.operand_b_fw_id),
      .operand_c_fw_id_i (core.core_i.id_stage_i.operand_c_fw_id),
      // .instr         (core.core_i.id_stage_i.instr     ),
      .is_compressed_id_i(core.core_i.id_stage_i.is_compressed_i),
      .ebrk_insn_dec_i   (core.core_i.id_stage_i.ebrk_insn_dec),
      .ecall_insn_dec_i  (core.core_i.id_stage_i.ecall_insn_dec),
      .mret_insn_dec_i   (core.core_i.id_stage_i.mret_insn_dec),
      .mret_dec_i        (core.core_i.id_stage_i.mret_dec),

      .csr_cause_i     (core.core_i.csr_cause),
      .debug_csr_save_i(core.core_i.debug_csr_save),

      // HWLOOP regs
      .hwlp_start_q_i  ('0),
      .hwlp_end_q_i    ('0),
      .hwlp_counter_q_i('0),
      .hwlp_counter_n_i('0),

      .minstret_i         (core.core_i.id_stage_i.minstret),
      //// EX probes ////
      .ex_valid_i         (core.core_i.ex_valid),
      .ex_ready_i         (core.core_i.ex_ready),
      .ex_reg_addr_i      (core.core_i.regfile_alu_waddr_fw),
      .ex_reg_we_i        (core.core_i.regfile_alu_we_fw),
      .ex_reg_wdata_i     (core.core_i.regfile_alu_wdata_fw),
      .apu_en_ex_i        (core.core_i.apu_en_ex),
      .apu_singlecycle_i  (core.core_i.ex_stage_i.apu_singlecycle),
      .apu_multicycle_i   (core.core_i.ex_stage_i.apu_multicycle),
      .wb_contention_lsu_i(core.core_i.ex_stage_i.wb_contention_lsu),
      .wb_contention_i    (core.core_i.ex_stage_i.wb_contention),
      .regfile_we_lsu_i   (core.core_i.ex_stage_i.regfile_we_lsu),
      // .rf_we_alu_i    (core.core_i.id_stage_i.regfile_alu_we_fw_i),
      // .rf_addr_alu_i  (core.core_i.id_stage_i.regfile_alu_waddr_fw_i),
      // .rf_wdata_alu_i (core.core_i.id_stage_i.regfile_alu_wdata_fw_i),

      .mult_ready_i        (core.core_i.ex_stage_i.mult_ready),
      .alu_ready_i         (core.core_i.ex_stage_i.alu_ready),
      //// WB probes ////
      .wb_valid_i          (core.core_i.wb_valid),
      .wb_ready_i          (core.core_i.lsu_ready_wb),
      //// LSU probes ////
      .data_we_ex_i        (core.core_i.data_we_ex),
      .data_atop_ex_i      (core.core_i.data_atop_ex),
      .data_type_ex_i      (core.core_i.data_type_ex),
      .alu_operand_c_ex_i  (core.core_i.alu_operand_c_ex),
      .data_reg_offset_ex_i(core.core_i.data_reg_offset_ex),
      .data_load_event_ex_i(core.core_i.data_load_event_ex),
      .data_sign_ext_ex_i  (core.core_i.data_sign_ext_ex),
      .lsu_rdata_i         (core.core_i.lsu_rdata),
      .data_req_ex_i       (core.core_i.data_req_ex),
      .alu_operand_a_ex_i  (core.core_i.alu_operand_a_ex),
      .alu_operand_b_ex_i  (core.core_i.alu_operand_b_ex),
      .useincr_addr_ex_i   (core.core_i.useincr_addr_ex),
      .data_misaligned_ex_i(core.core_i.data_misaligned_ex),
      .p_elw_start_i       (core.core_i.p_elw_start),
      .p_elw_finish_i      (core.core_i.p_elw_finish),
      .lsu_ready_ex_i      (core.core_i.lsu_ready_ex),
      .lsu_ready_wb_i      (core.core_i.lsu_ready_wb),

      .lsu_data_be_i(core.core_i.load_store_unit_i.data_be),

      .data_req_pmp_i(core.core_i.data_req_pmp),
      .data_gnt_pmp_i(core.core_i.data_gnt_pmp),
      .data_rvalid_i(core.core_i.data_rvalid_i),
      .data_err_pmp_i(core.core_i.data_err_pmp),
      .data_addr_pmp_i(core.core_i.data_addr_pmp),
      .data_we_i(core.core_i.data_we_o),
      .data_atop_i(core.core_i.data_atop_o),
      .data_be_i(core.core_i.data_be_o),
      .data_wdata_i(core.core_i.data_wdata_o),
      .data_rdata_i(core.core_i.data_rdata_i),
      // Register writes
      .rf_we_wb_i(core.core_i.id_stage_i.regfile_we_wb_i),
      .rf_addr_wb_i(core.core_i.id_stage_i.regfile_waddr_wb_i),
      .rf_wdata_wb_i(core.core_i.id_stage_i.regfile_wdata_wb_i),
      .regfile_alu_we_ex_i(core.core_i.id_stage_i.regfile_alu_we_ex_o),

      // APU
      .apu_req_i   (core.core_i.apu_req_o),
      .apu_gnt_i   (core.core_i.apu_gnt_i),
      .apu_rvalid_i(core.core_i.ex_stage_i.apu_valid),

      // Controller FSM probes
      .ctrl_fsm_cs_i(core.core_i.id_stage_i.controller_i.ctrl_fsm_cs),
      .pc_mux_i     (core.core_i.id_stage_i.controller_i.pc_mux_o),
      .exc_pc_mux_i (core.core_i.id_stage_i.controller_i.exc_pc_mux_o),

      //CSR
      .csr_addr_i     (core.core_i.cs_registers_i.csr_addr_i),
      .csr_we_i       (core.core_i.cs_registers_i.csr_we_int),
      .csr_wdata_int_i(core.core_i.cs_registers_i.csr_wdata_int),

      .csr_fregs_we_i(core.core_i.cs_registers_i.fregs_we_i),

      .csr_mstatus_n_i   (core.core_i.cs_registers_i.mstatus_n),
      .csr_mstatus_q_i   (core.core_i.cs_registers_i.mstatus_q),
      .csr_mstatus_fs_n_i(core.core_i.cs_registers_i.mstatus_fs_n),
      .csr_mstatus_fs_q_i(core.core_i.cs_registers_i.mstatus_fs_q),

      .csr_misa_n_i(core.core_i.cs_registers_i.MISA_VALUE),  // WARL
      .csr_misa_q_i(core.core_i.cs_registers_i.MISA_VALUE),

      .csr_tdata1_n_i           (core.core_i.cs_registers_i.tmatch_control_rdata),//csr_wdata_int                                   ),
      .csr_tdata1_q_i           (core.core_i.cs_registers_i.tmatch_control_rdata),//gen_trigger_regs.tmatch_control_exec_q          ),
      .csr_tdata1_we_i(core.core_i.cs_registers_i.gen_trigger_regs.tmatch_control_we),

      .csr_tdata2_n_i           (core.core_i.cs_registers_i.tmatch_value_rdata),//csr_wdata_int                                   ),
      .csr_tdata2_q_i           (core.core_i.cs_registers_i.tmatch_value_rdata),//gen_trigger_regs.tmatch_control_exec_q          ),
      .csr_tdata2_we_i(core.core_i.cs_registers_i.gen_trigger_regs.tmatch_value_we),

      .csr_tinfo_n_i({16'h0, core.core_i.cs_registers_i.tinfo_types}),
      .csr_tinfo_q_i({16'h0, core.core_i.cs_registers_i.tinfo_types}),

      .csr_mie_n_i       (core.core_i.cs_registers_i.mie_n),
      .csr_mie_q_i       (core.core_i.cs_registers_i.mie_q),
      .csr_mie_we_i      (core.core_i.cs_registers_i.csr_mie_we),
      .csr_mtvec_n_i     (core.core_i.cs_registers_i.mtvec_n),
      .csr_mtvec_q_i     (core.core_i.cs_registers_i.mtvec_q),
      .csr_mtvec_mode_n_i(core.core_i.cs_registers_i.mtvec_mode_n),
      .csr_mtvec_mode_q_i(core.core_i.cs_registers_i.mtvec_mode_q),

      .csr_mcountinhibit_q_i (core.core_i.cs_registers_i.mcountinhibit_q),
      .csr_mcountinhibit_n_i (core.core_i.cs_registers_i.mcountinhibit_n),
      .csr_mcountinhibit_we_i(core.core_i.cs_registers_i.mcountinhibit_we),

      .csr_mhpmevent_n_i(core.core_i.cs_registers_i.mhpmevent_n),
      .csr_mhpmevent_q_i(core.core_i.cs_registers_i.mhpmevent_q),
      .csr_mhpmevent_we_i(core.core_i.cs_registers_i.mhpmevent_we),
      .csr_mscratch_q_i(core.core_i.cs_registers_i.mscratch_q),
      .csr_mscratch_n_i(core.core_i.cs_registers_i.mscratch_n),
      .csr_mepc_q_i(core.core_i.cs_registers_i.mepc_q),
      .csr_mepc_n_i(core.core_i.cs_registers_i.mepc_n),
      .csr_mcause_q_i(core.core_i.cs_registers_i.mcause_q),
      .csr_mcause_n_i(core.core_i.cs_registers_i.mcause_n),
      .csr_mip_n_i(core.core_i.cs_registers_i.mip),
      .csr_mip_q_i(core.core_i.cs_registers_i.mip),
      .csr_mip_we_i('0),  //(core.core_i.cs_registers_i.mip)


      .csr_dcsr_q_i(core.core_i.cs_registers_i.dcsr_q),
      .csr_dcsr_n_i(core.core_i.cs_registers_i.dcsr_n),

      .csr_dpc_n_i(core.core_i.cs_registers_i.depc_n),
      .csr_dpc_q_i(core.core_i.cs_registers_i.depc_q),
      .csr_dpc_we_i('0),  //core.core_i.cs_registers_i.),
      .csr_dscratch0_n_i(core.core_i.cs_registers_i.dscratch0_n),
      .csr_dscratch0_q_i(core.core_i.cs_registers_i.dscratch0_q),
      .csr_dscratch0_we_i('0),  //core.core_i.cs_registers_i.),

      .csr_dscratch1_n_i(core.core_i.cs_registers_i.dscratch1_n),
      .csr_dscratch1_q_i(core.core_i.cs_registers_i.dscratch1_q),
      .csr_dscratch1_we_i('0),  //core.core_i.cs_registers_i.),

      .csr_mhpmcounter_q_i          (core.core_i.cs_registers_i.mhpmcounter_q),
      .csr_mhpmcounter_write_lower_i(core.core_i.cs_registers_i.mhpmcounter_write_lower),
      .csr_mhpmcounter_write_upper_i(core.core_i.cs_registers_i.mhpmcounter_write_upper),

      .csr_mvendorid_i({
        cv32e40p_pkg::MVENDORID_BANK, cv32e40p_pkg::MVENDORID_OFFSET
      }),  //TODO: get this from the design instead of the pkg
      .csr_marchid_i(cv32e40p_pkg::MARCHID),  //TODO: get this from the design instead of the pkg

      .csr_fcsr_fflags_n_i (core.core_i.cs_registers_i.fflags_n),
      .csr_fcsr_fflags_q_i (core.core_i.cs_registers_i.fflags_q),
      .csr_fcsr_fflags_we_i(core.core_i.cs_registers_i.fflags_we_i),
      .csr_fcsr_frm_n_i    (core.core_i.cs_registers_i.frm_n),
      .csr_fcsr_frm_q_i    (core.core_i.cs_registers_i.frm_q)
  );

        assign retire[core_index] = rvfi_i.rvfi_valid;
        always @(negedge core_clk[core_index]) if (rst_ni && retire[core_index])
            contract_reference_retire(core_index+1,rvfi_i.rvfi_pc_rdata,rvfi_i.rvfi_insn,rvfi_i.rvfi_rd_addr[0],rvfi_i.rvfi_rd_wdata[0],rvfi_i.rvfi_trap[0]);
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
