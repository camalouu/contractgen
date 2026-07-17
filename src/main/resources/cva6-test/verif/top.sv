`include "cva6_axi_pkg.sv"
`include "rvfi_pkg.sv"

import ariane_pkg::*;
import rvfi_pkg::*;
import cva6_config_pkg::*;
import build_config_pkg::*;

module top (
    input logic clk,
    input logic rst_ni,
    output logic finished_o,
    output logic atk_equiv_o,
    output logic trap_o
);
    localparam config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
    typedef `RVFI_PROBES_INSTR_T(Cfg) rvfi_probes_instr_t;
    typedef `RVFI_PROBES_CSR_T(Cfg) rvfi_probes_csr_t;
    typedef struct packed {
        rvfi_probes_csr_t csr;
        rvfi_probes_instr_t instr;
    } rvfi_probes_t;
    typedef `RVFI_CSR_ELMT_T(Cfg) rvfi_csr_elmt_t;
    typedef `RVFI_INSTR_T(Cfg) rvfi_instr_t;
    typedef `RVFI_CSR_T(Cfg, rvfi_csr_elmt_t) rvfi_csr_t;

    logic clock;
    initial clock = 1'b0;
    always @(posedge clk) begin
        clock <= !clock;
    end

    logic clock_1;
    logic clock_2;
    logic reset_1;
    logic reset_2;
    assign reset_1 = rst_ni;
    assign reset_2 = rst_ni;

    logic req_1;
    logic req_2;
    logic we_1;
    logic we_2;
    logic [63:0] addr_1;
    logic [63:0] addr_2;
    logic [3:0] be_1;
    logic [3:0] be_2;
    logic [63:0] data_w_1;
    logic [63:0] data_w_2;
    logic [63:0] data_r_1;
    logic [63:0] data_r_2;

    logic retire;
    logic enable_1;
    logic enable_2;
    logic issue_1;
    logic issue_2;
    logic retire_1;
    logic retire_2;
    logic trap_1;
    logic trap_2;
    rvfi_probes_t rvfi_1;
    rvfi_probes_t rvfi_2;
    rvfi_instr_t rvfi_instr_1;
    rvfi_instr_t rvfi_instr_2;
    rvfi_csr_t rvfi_csr_1;
    rvfi_csr_t rvfi_csr_2;

    // Match the original CVA6 Verilator harness: it never stops issuing early;
    // completion is based solely on paired RVFI retirements.
    assign enable_1 = 1'b1;
    assign enable_2 = 1'b1;

    mem #(
        .ID(1)
    ) mem_1 (
        .clk_i(clock_1),
        .enable_i(enable_1),
        .req_i(req_1),
        .we_i(we_1),
        .addr_i(addr_1),
        .be_i(be_1),
        .data_i(data_w_1),
        .data_o(data_r_1)
    );

    mem #(
        .ID(2)
    ) mem_2 (
        .clk_i(clock_2),
        .enable_i(enable_2),
        .req_i(req_2),
        .we_i(we_2),
        .addr_i(addr_2),
        .be_i(be_2),
        .data_i(data_w_2),
        .data_o(data_r_2)
    );

    cva6_axi_pkg::noc_req_t axi_req_1;
    cva6_axi_pkg::noc_resp_t axi_resp_1;
    cva6_axi_pkg::noc_req_t axi_req_2;
    cva6_axi_pkg::noc_resp_t axi_resp_2;

    AXI_BUS #(
        .AXI_ADDR_WIDTH(64),
        .AXI_DATA_WIDTH(64),
        .AXI_ID_WIDTH(4),
        .AXI_USER_WIDTH(2)
    ) axi_bus_1 ();

    axi_converter axi_converter_1 (
        .axi_req_i(axi_req_1),
        .axi_resp_o(axi_resp_1),
        .master(axi_bus_1.Master)
    );

    AXI_BUS #(
        .AXI_ADDR_WIDTH(64),
        .AXI_DATA_WIDTH(64),
        .AXI_ID_WIDTH(4),
        .AXI_USER_WIDTH(2)
    ) axi_bus_2 ();

    axi_converter axi_converter_2 (
        .axi_req_i(axi_req_2),
        .axi_resp_o(axi_resp_2),
        .master(axi_bus_2.Master)
    );

    axi2mem #(
        .AXI_ID_WIDTH(4),
        .AXI_ADDR_WIDTH(64),
        .AXI_DATA_WIDTH(64),
        .AXI_USER_WIDTH(2)
    ) axi2mem_1 (
        .clk_i(clock_1),
        .rst_ni(reset_1),
        .slave(axi_bus_1.Slave),
        .req_o(req_1),
        .we_o(we_1),
        .addr_o(addr_1),
        .be_o(be_1),
        .data_o(data_w_1),
        .data_i(data_r_1),
        .user_o(),
        .user_i()
    );

    axi2mem #(
        .AXI_ID_WIDTH(4),
        .AXI_ADDR_WIDTH(64),
        .AXI_DATA_WIDTH(64),
        .AXI_USER_WIDTH(2)
    ) axi2mem_2 (
        .clk_i(clock_2),
        .rst_ni(reset_2),
        .slave(axi_bus_2.Slave),
        .req_o(req_2),
        .we_o(we_2),
        .addr_o(addr_2),
        .be_o(be_2),
        .data_o(data_w_2),
        .data_i(data_r_2),
        .user_o(),
        .user_i()
    );

    cva6 core_1 (
        .clk_i(clock_1),
        .rst_ni(reset_1),
        .boot_addr_i(64'h8000_0000),
        .hart_id_i(32'h0),
        .irq_i(2'b0),
        .ipi_i(1'b0),
        .time_irq_i(1'b0),
        .debug_req_i(1'b0),
        .rvfi_probes_o(rvfi_1),
        .cvxif_req_o(),
        .cvxif_resp_i(0),
        .noc_req_o(axi_req_1),
        .noc_resp_i(axi_resp_1),
        .enable_issue_i(enable_1),
        .issue_o(issue_1),
        .retire_o(),
        .trap_o()
    );

    cva6 core_2 (
        .clk_i(clock_2),
        .rst_ni(reset_2),
        .boot_addr_i(64'h8000_0000),
        .hart_id_i(32'h0),
        .irq_i(2'b0),
        .ipi_i(1'b0),
        .time_irq_i(1'b0),
        .debug_req_i(1'b0),
        .rvfi_probes_o(rvfi_2),
        .cvxif_req_o(),
        .cvxif_resp_i(0),
        .noc_req_o(axi_req_2),
        .noc_resp_i(axi_resp_2),
        .enable_issue_i(enable_2),
        .issue_o(issue_2),
        .retire_o(),
        .trap_o()
    );

    cva6_rvfi #(
        .CVA6Cfg(build_config_pkg::build_config(cva6_config_pkg::cva6_cfg)),
        .rvfi_instr_t(rvfi_instr_t),
        .rvfi_csr_t(rvfi_csr_t),
        .rvfi_probes_instr_t(rvfi_probes_instr_t),
        .rvfi_probes_csr_t(rvfi_probes_csr_t),
        .rvfi_probes_t(rvfi_probes_t)
    ) cva6_rvfi_1 (
        .clk_i(clock_1),
        .rst_ni(reset_1),
        .rvfi_probes_i(rvfi_1),
        .rvfi_instr_o(rvfi_instr_1),
        .rvfi_csr_o(rvfi_csr_1)
    );

    cva6_rvfi #(
        .CVA6Cfg(build_config_pkg::build_config(cva6_config_pkg::cva6_cfg)),
        .rvfi_instr_t(rvfi_instr_t),
        .rvfi_csr_t(rvfi_csr_t),
        .rvfi_probes_instr_t(rvfi_probes_instr_t),
        .rvfi_probes_csr_t(rvfi_probes_csr_t),
        .rvfi_probes_t(rvfi_probes_t)
    ) cva6_rvfi_2 (
        .clk_i(clock_2),
        .rst_ni(reset_2),
        .rvfi_probes_i(rvfi_2),
        .rvfi_instr_o(rvfi_instr_2),
        .rvfi_csr_o(rvfi_csr_2)
    );

    assign retire_1 = rvfi_instr_1.valid;
    assign retire_2 = rvfi_instr_2.valid;
    assign trap_1 = rvfi_instr_1.trap;
    assign trap_2 = rvfi_instr_2.trap;

    atk atk (
        .clk_i(clock),
        .atk_observation_1_i(clock_1),
        .atk_observation_2_i(clock_2),
        .atk_equiv_o(atk_equiv_o)
    );

    clk_sync clk_sync (
        .clk_i(clock),
        .retire_1_i(retire_1),
        .retire_2_i(retire_2),
        .clk_1_o(clock_1),
        .clk_2_o(clock_2),
        .retire_o(retire)
    );

    control control (
        .clk_i(clock),
        .retire_i(retire),
        .finished_o(finished_o)
    );

    assign trap_o = trap_1 || trap_2;
endmodule

module axi_converter (
    input cva6_axi_pkg::noc_req_t axi_req_i,
    output cva6_axi_pkg::noc_resp_t axi_resp_o,
    AXI_BUS.Master master
);
    assign master.aw_id = axi_req_i.aw.id;
    assign master.aw_addr = axi_req_i.aw.addr;
    assign master.aw_len = axi_req_i.aw.len;
    assign master.aw_size = axi_req_i.aw.size;
    assign master.aw_burst = axi_req_i.aw.burst;
    assign master.aw_lock = axi_req_i.aw.lock;
    assign master.aw_cache = axi_req_i.aw.cache;
    assign master.aw_prot = axi_req_i.aw.prot;
    assign master.aw_qos = axi_req_i.aw.qos;
    assign master.aw_region = axi_req_i.aw.region;
    assign master.aw_atop = axi_req_i.aw.atop;
    assign master.aw_user = axi_req_i.aw.user;
    assign master.aw_valid = axi_req_i.aw_valid;

    assign master.w_data = axi_req_i.w.data;
    assign master.w_strb = axi_req_i.w.strb;
    assign master.w_last = axi_req_i.w.last;
    assign master.w_user = axi_req_i.w.user;
    assign master.w_valid = axi_req_i.w_valid;
    assign master.b_ready = axi_req_i.b_ready;

    assign master.ar_id = axi_req_i.ar.id;
    assign master.ar_addr = axi_req_i.ar.addr;
    assign master.ar_len = axi_req_i.ar.len;
    assign master.ar_size = axi_req_i.ar.size;
    assign master.ar_burst = axi_req_i.ar.burst;
    assign master.ar_lock = axi_req_i.ar.lock;
    assign master.ar_cache = axi_req_i.ar.cache;
    assign master.ar_prot = axi_req_i.ar.prot;
    assign master.ar_qos = axi_req_i.ar.qos;
    assign master.ar_region = axi_req_i.ar.region;
    assign master.ar_user = axi_req_i.ar.user;
    assign master.ar_valid = axi_req_i.ar_valid;
    assign master.r_ready = axi_req_i.r_ready;

    assign axi_resp_o.aw_ready = master.aw_ready;
    assign axi_resp_o.ar_ready = master.ar_ready;
    assign axi_resp_o.w_ready = master.w_ready;
    assign axi_resp_o.b_valid = master.b_valid;
    assign axi_resp_o.b.id = master.b_id;
    assign axi_resp_o.b.resp = master.b_resp;
    assign axi_resp_o.b.user = master.b_user;
    assign axi_resp_o.r_valid = master.r_valid;
    assign axi_resp_o.r.id = master.r_id;
    assign axi_resp_o.r.data = master.r_data;
    assign axi_resp_o.r.resp = master.r_resp;
    assign axi_resp_o.r.last = master.r_last;
    assign axi_resp_o.r.user = master.r_user;
endmodule
