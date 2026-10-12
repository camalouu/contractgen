module data_mem (
    input logic clk_i, data_req_i, data_we_i,
    input logic [3:0] data_be_i,
    input logic [31:0] data_addr_i, data_wdata_i,
    output logic data_gnt_o, data_rvalid_o,
    output logic [31:0] data_rdata_o,
    output logic data_err_o
);
    logic [7:0] bytes_by_address [bit [31:0]];
    logic [31:0] response, key, pending_rdata;
    logic pending_dph;
    integer lane;
    initial begin
        bytes_by_address.delete();
        data_gnt_o = 0; data_rvalid_o = 0; data_rdata_o = 0;
        data_err_o = 0; pending_rdata = 0; pending_dph = 0;
    end
    always @(posedge clk_i) begin
        data_gnt_o <= data_req_i;
        data_rvalid_o <= data_req_i;
        
        data_err_o <= 0;
        pending_dph <= data_req_i;
        if (data_req_i) begin
            response = 0;
            for (lane = 0; lane < 4; lane++) begin
                key = {data_addr_i[31:2],2'b0} + 32'(lane);
                if (bytes_by_address.exists(key)) response[lane*8 +: 8] = bytes_by_address[key];
                if (data_we_i && data_be_i[lane]) bytes_by_address[key] = data_wdata_i[lane*8 +: 8];
            end
            data_rdata_o <= response;
        end
    end
endmodule
