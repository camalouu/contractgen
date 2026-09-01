`define NO_OP 32'h00000013
`define MAX_INSTR 2048

module fwrisc_test_top (
    input  logic clk,
    input  logic reset,
    output logic finished_o,
    output logic atk_equiv_o
);
    import "DPI-C" function int contract_simple_instr_word(input int core_id, input int word_index);

    logic clock_1, clock_2;
    logic retire_1, retire_2, retire;
    logic enable_1, enable_2;
    logic [31:0] iaddr_1, iaddr_2, idata_1, idata_2;
    logic ivalid_1, ivalid_2;
    logic dvalid_1, dvalid_2, dwrite_1, dwrite_2;
    logic [31:0] daddr_1, daddr_2, dwdata_1, dwdata_2;
    logic [3:0] dwstb_1, dwstb_2;
    logic [31:0] drdata_1, drdata_2;
    logic dready_1, dready_2;

    wire [31:0] instr_index_1 = (iaddr_1 - 32'h8000_0000) >> 2;
    wire [31:0] instr_index_2 = (iaddr_2 - 32'h8000_0000) >> 2;
    assign idata_1 = enable_1 && (instr_index_1 < `MAX_INSTR)
            ? $unsigned(contract_simple_instr_word(1, instr_index_1)) : `NO_OP;
    assign idata_2 = enable_2 && (instr_index_2 < `MAX_INSTR)
            ? $unsigned(contract_simple_instr_word(2, instr_index_2)) : `NO_OP;

    fwrisc #(.ENABLE_COMPRESSED(0), .ENABLE_MUL_DIV(1), .ENABLE_DEP(0), .ENABLE_COUNTERS(1)) core_1 (
        .clock(clock_1), .reset(reset),
        .iaddr(iaddr_1), .idata(idata_1), .ivalid(ivalid_1), .iready(1'b1),
        .dvalid(dvalid_1), .daddr(daddr_1), .dwdata(dwdata_1), .dwstb(dwstb_1),
        .dwrite(dwrite_1), .drdata(drdata_1), .dready(dready_1), .irq(1'b0)
    );
    fwrisc #(.ENABLE_COMPRESSED(0), .ENABLE_MUL_DIV(1), .ENABLE_DEP(0), .ENABLE_COUNTERS(1)) core_2 (
        .clock(clock_2), .reset(reset),
        .iaddr(iaddr_2), .idata(idata_2), .ivalid(ivalid_2), .iready(1'b1),
        .dvalid(dvalid_2), .daddr(daddr_2), .dwdata(dwdata_2), .dwstb(dwstb_2),
        .dwrite(dwrite_2), .drdata(drdata_2), .dready(dready_2), .irq(1'b0)
    );

    assign retire_1 = core_1.instr_complete;
    assign retire_2 = core_2.instr_complete;

    data_mem data_mem_1 (
        .clk_i(clock_1), .data_req_i(dvalid_1), .data_we_i(dwrite_1),
        .data_be_i(dwstb_1), .data_addr_i(daddr_1), .data_wdata_i(dwdata_1),
        .data_gnt_o(), .data_rvalid_o(dready_1), .data_rdata_o(drdata_1), .data_err_o()
    );
    data_mem data_mem_2 (
        .clk_i(clock_2), .data_req_i(dvalid_2), .data_we_i(dwrite_2),
        .data_be_i(dwstb_2), .data_addr_i(daddr_2), .data_wdata_i(dwdata_2),
        .data_gnt_o(), .data_rvalid_o(dready_2), .data_rdata_o(drdata_2), .data_err_o()
    );

    clk_sync clocks (
        .clk_i(clk), .retire_1_i(retire_1), .retire_2_i(retire_2),
        .clk_1_o(clock_1), .clk_2_o(clock_2), .retire_o(retire)
    );
    atk attacker (
        .clk_i(clk), .atk_observation_1_i(clock_1),
        .atk_observation_2_i(clock_2), .atk_equiv_o(atk_equiv_o)
    );
    control control (
        .clk_i(clk), .reset_i(reset), .retire_i(retire),
        .fetch_1_i(ivalid_1), .fetch_2_i(ivalid_2),
        .instr_addr_1_i(iaddr_1), .instr_addr_2_i(iaddr_2),
        .enable_1_o(enable_1), .enable_2_o(enable_2), .finished_o(finished_o)
    );
endmodule
