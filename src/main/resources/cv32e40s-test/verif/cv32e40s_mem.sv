module cv32e40s_instr_mem #(parameter int ID = 1) (
    input logic clk_i, rst_ni, req_i, boot_i, timing_i,
    input logic [31:0] addr_i,
    output logic gnt_o, rvalid_o,
    output logic [31:0] rdata_o
);
    import "DPI-C" function int contract_cv32e40s_instr_word(input int core_id, input int word_index);
    assign gnt_o = rst_ni && req_i;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin rvalid_o <= 0; rdata_o <= 32'h00000013; end
        else begin
            rvalid_o <= req_i && gnt_o;
            if (req_i && gnt_o) begin
                // CSRRWI x0, cpuctrl (0xbf0), 16 or 17; JAL x0, 0x80.
                if (boot_i && addr_i == 0) rdata_o <= timing_i ? 32'hbf08d073 : 32'hbf085073;
                else if (boot_i && addr_i == 4) rdata_o <= 32'h07c0006f;
                else if (addr_i >= 32'h80 && addr_i < 32'h2080)
                    rdata_o <= $unsigned(contract_cv32e40s_instr_word(ID, (addr_i - 32'h80) >> 2));
                else rdata_o <= 32'h00000013;
            end
        end
    end
endmodule

// Match the adapted Spike's bounded synthetic memory, including raw bus-address
// byte-lane keys (not a general-purpose RAM). Unwritten reads return zero.
module cv32e40s_data_mem (
    input logic clk_i, rst_ni, req_i, we_i,
    input logic [3:0] be_i,
    input logic [31:0] addr_i, wdata_i,
    output logic gnt_o, rvalid_o,
    output logic [31:0] rdata_o
);
    logic [31:0] addresses [32];
    logic [7:0] values [32];
    logic [31:0] response;
    integer i, lane, j;
    assign gnt_o = rst_ni && req_i;
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_o <= 0; rdata_o <= 0;
            for (i = 0; i < 32; i++) begin addresses[i] = 0; values[i] = 0; end
        end else begin
            rvalid_o <= req_i && gnt_o;
            if (req_i && gnt_o) begin
                response = 0;
                for (i = 0; i < 32; i++)
                    for (lane = 0; lane < 4; lane++)
                        if (be_i[lane] && addresses[i] == addr_i + lane)
                            response[lane*8 +: 8] = values[i];
                rdata_o <= response;
                if (we_i) for (lane = 0; lane < 4; lane++) if (be_i[lane]) begin
                    for (j = 1; j < 32; j++) begin
                        addresses[j-1] = addresses[j]; values[j-1] = values[j];
                    end
                    addresses[31] = addr_i + lane;
                    values[31] = wdata_i[lane*8 +: 8];
                end
            end
        end
    end
endmodule
