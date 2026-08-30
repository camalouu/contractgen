module top(
    input  logic        clk,
    output logic        finished_o,
    output logic        atk_equiv_o,
    output logic [31:0] retire_count_o,
    output logic        rvfi_valid_1_o,
    output logic        rvfi_valid_2_o,
    output logic [63:0] rvfi_order_1_o,
    output logic [63:0] rvfi_order_2_o,
    output logic [31:0] rvfi_insn_1_o,
    output logic [31:0] rvfi_insn_2_o,
    output logic        rvfi_trap_1_o,
    output logic        rvfi_trap_2_o
);
    logic reset;
    integer reset_edges;
    initial begin
        reset = 1'b1;
        reset_edges = 0;
    end
    always @(posedge clk) begin
        if (reset_edges < 4)
            reset_edges <= reset_edges + 1;
        else
            reset <= 1'b0;
    end

    logic clock_1, clock_2;
    logic retire_1, retire_2, paired_retire;

    logic ibus_cmd_valid_1, ibus_cmd_valid_2;
    logic ibus_cmd_ready_1, ibus_cmd_ready_2;
    logic [31:0] ibus_cmd_addr_1, ibus_cmd_addr_2;
    logic [1:0] ibus_cmd_id_1, ibus_cmd_id_2;
    logic ibus_rsp_valid_1, ibus_rsp_valid_2;
    logic ibus_rsp_ready_1, ibus_rsp_ready_2;
    logic [31:0] ibus_rsp_data_1, ibus_rsp_data_2;
    logic [1:0] ibus_rsp_id_1, ibus_rsp_id_2;

    logic dbus_cmd_valid_1, dbus_cmd_valid_2;
    logic dbus_cmd_ready_1, dbus_cmd_ready_2;
    logic [31:0] dbus_cmd_addr_1, dbus_cmd_addr_2;
    logic [1:0] dbus_cmd_id_1, dbus_cmd_id_2;
    logic dbus_cmd_write_1, dbus_cmd_write_2;
    logic [31:0] dbus_cmd_wdata_1, dbus_cmd_wdata_2;
    logic [3:0] dbus_cmd_wmask_1, dbus_cmd_wmask_2;
    logic dbus_rsp_valid_1, dbus_rsp_valid_2;
    logic dbus_rsp_ready_1, dbus_rsp_ready_2;
    logic [31:0] dbus_rsp_data_1, dbus_rsp_data_2;
    logic [1:0] dbus_rsp_id_1, dbus_rsp_id_2;

    ProteusContractCore core_1(
        .clk(clock_1), .reset(reset), .retire(retire_1),
        .rvfi_valid(rvfi_valid_1_o), .rvfi_order(rvfi_order_1_o),
        .rvfi_insn(rvfi_insn_1_o), .rvfi_trap(rvfi_trap_1_o),
        .ibus_cmd_valid(ibus_cmd_valid_1), .ibus_cmd_ready(ibus_cmd_ready_1),
        .ibus_cmd_payload_address(ibus_cmd_addr_1), .ibus_cmd_payload_id(ibus_cmd_id_1),
        .ibus_rsp_valid(ibus_rsp_valid_1), .ibus_rsp_ready(ibus_rsp_ready_1),
        .ibus_rsp_payload_rdata(ibus_rsp_data_1), .ibus_rsp_payload_id(ibus_rsp_id_1),
        .dbus_cmd_valid(dbus_cmd_valid_1), .dbus_cmd_ready(dbus_cmd_ready_1),
        .dbus_cmd_payload_address(dbus_cmd_addr_1), .dbus_cmd_payload_id(dbus_cmd_id_1),
        .dbus_cmd_payload_write(dbus_cmd_write_1), .dbus_cmd_payload_wdata(dbus_cmd_wdata_1),
        .dbus_cmd_payload_wmask(dbus_cmd_wmask_1), .dbus_rsp_valid(dbus_rsp_valid_1),
        .dbus_rsp_ready(dbus_rsp_ready_1), .dbus_rsp_payload_rdata(dbus_rsp_data_1),
        .dbus_rsp_payload_id(dbus_rsp_id_1)
    );

    ProteusContractCore core_2(
        .clk(clock_2), .reset(reset), .retire(retire_2),
        .rvfi_valid(rvfi_valid_2_o), .rvfi_order(rvfi_order_2_o),
        .rvfi_insn(rvfi_insn_2_o), .rvfi_trap(rvfi_trap_2_o),
        .ibus_cmd_valid(ibus_cmd_valid_2), .ibus_cmd_ready(ibus_cmd_ready_2),
        .ibus_cmd_payload_address(ibus_cmd_addr_2), .ibus_cmd_payload_id(ibus_cmd_id_2),
        .ibus_rsp_valid(ibus_rsp_valid_2), .ibus_rsp_ready(ibus_rsp_ready_2),
        .ibus_rsp_payload_rdata(ibus_rsp_data_2), .ibus_rsp_payload_id(ibus_rsp_id_2),
        .dbus_cmd_valid(dbus_cmd_valid_2), .dbus_cmd_ready(dbus_cmd_ready_2),
        .dbus_cmd_payload_address(dbus_cmd_addr_2), .dbus_cmd_payload_id(dbus_cmd_id_2),
        .dbus_cmd_payload_write(dbus_cmd_write_2), .dbus_cmd_payload_wdata(dbus_cmd_wdata_2),
        .dbus_cmd_payload_wmask(dbus_cmd_wmask_2), .dbus_rsp_valid(dbus_rsp_valid_2),
        .dbus_rsp_ready(dbus_rsp_ready_2), .dbus_rsp_payload_rdata(dbus_rsp_data_2),
        .dbus_rsp_payload_id(dbus_rsp_id_2)
    );

    instr_mem #(.ID(1)) instr_mem_1(
        .clk_i(clock_1), .reset_i(reset), .cmd_valid_i(ibus_cmd_valid_1),
        .cmd_ready_o(ibus_cmd_ready_1), .cmd_addr_i(ibus_cmd_addr_1), .cmd_id_i(ibus_cmd_id_1),
        .rsp_valid_o(ibus_rsp_valid_1), .rsp_ready_i(ibus_rsp_ready_1),
        .rsp_data_o(ibus_rsp_data_1), .rsp_id_o(ibus_rsp_id_1));
    instr_mem #(.ID(2)) instr_mem_2(
        .clk_i(clock_2), .reset_i(reset), .cmd_valid_i(ibus_cmd_valid_2),
        .cmd_ready_o(ibus_cmd_ready_2), .cmd_addr_i(ibus_cmd_addr_2), .cmd_id_i(ibus_cmd_id_2),
        .rsp_valid_o(ibus_rsp_valid_2), .rsp_ready_i(ibus_rsp_ready_2),
        .rsp_data_o(ibus_rsp_data_2), .rsp_id_o(ibus_rsp_id_2));

    data_mem data_mem_1(
        .clk_i(clock_1), .reset_i(reset), .cmd_valid_i(dbus_cmd_valid_1),
        .cmd_ready_o(dbus_cmd_ready_1), .cmd_addr_i(dbus_cmd_addr_1), .cmd_id_i(dbus_cmd_id_1),
        .cmd_write_i(dbus_cmd_write_1), .cmd_wdata_i(dbus_cmd_wdata_1), .cmd_wmask_i(dbus_cmd_wmask_1),
        .rsp_valid_o(dbus_rsp_valid_1), .rsp_ready_i(dbus_rsp_ready_1),
        .rsp_data_o(dbus_rsp_data_1), .rsp_id_o(dbus_rsp_id_1));
    data_mem data_mem_2(
        .clk_i(clock_2), .reset_i(reset), .cmd_valid_i(dbus_cmd_valid_2),
        .cmd_ready_o(dbus_cmd_ready_2), .cmd_addr_i(dbus_cmd_addr_2), .cmd_id_i(dbus_cmd_id_2),
        .cmd_write_i(dbus_cmd_write_2), .cmd_wdata_i(dbus_cmd_wdata_2), .cmd_wmask_i(dbus_cmd_wmask_2),
        .rsp_valid_o(dbus_rsp_valid_2), .rsp_ready_i(dbus_rsp_ready_2),
        .rsp_data_o(dbus_rsp_data_2), .rsp_id_o(dbus_rsp_id_2));

    clk_sync synchronizer(
        .clk_i(clk), .retire_1_i(retire_1), .retire_2_i(retire_2),
        .clk_1_o(clock_1), .clk_2_o(clock_2), .retire_o(paired_retire));
    atk attacker(
        .clk_i(clk), .observation_1_i(clock_1), .observation_2_i(clock_2),
        .equivalent_o(atk_equiv_o));
    control controller(
        .clk_i(clk), .reset_i(reset), .paired_retire_i(paired_retire),
        .finished_o(finished_o), .retire_count_o(retire_count_o));
endmodule
