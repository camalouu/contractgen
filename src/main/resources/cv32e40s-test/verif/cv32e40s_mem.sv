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

module cv32e40s_data_mem (
    input logic clk_i, rst_ni, req_i, we_i,
    input logic [3:0] be_i,
    input logic [31:0] addr_i, wdata_i,
    output logic gnt_o, rvalid_o,
    output logic [31:0] rdata_o
);
    logic [7:0] bytes_by_address [bit [31:0]];
    logic [31:0] response, key;
    integer lane;
    initial bytes_by_address.delete();
    assign gnt_o = rst_ni && req_i;
    initial begin rvalid_o = 0; rdata_o = 0; end
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin bytes_by_address.delete(); rvalid_o <= 0; rdata_o <= 0; end
        else begin
        rvalid_o <= req_i;
        if (req_i) begin
            response = 0;
            for (lane = 0; lane < 4; lane++) begin
                key = {addr_i[31:2],2'b0} + 32'(lane);
                if (bytes_by_address.exists(key)) response[lane*8 +: 8] = bytes_by_address[key];
                if (we_i && be_i[lane]) bytes_by_address[key] = wdata_i[lane*8 +: 8];
            end
            rdata_o <= response;
        end
        end
    end
endmodule
