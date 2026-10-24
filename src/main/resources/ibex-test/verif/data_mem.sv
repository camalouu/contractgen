module data_mem #(parameter bit CACHE = 0) (
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
    // Legacy CACHE variant: one remembered read address; misses add one enabled
    // core cycle. Stores bypass and invalidate the tag. Storage remains persistent.
    logic cache_valid = 0, cache_miss = 0;
    logic [31:0] cached_addr = 0;
    wire accept_request = data_req_i && (!CACHE || data_we_i || cache_miss
            || (cache_valid && cached_addr == data_addr_i));
    initial begin
        bytes_by_address.delete();
        if (!CACHE) data_gnt_o = 0;
        data_rvalid_o = 0; data_rdata_o = 0;
        data_err_o = 0; pending_rdata = 0; pending_dph = 0;
    end
    // A delayed read must not inherit the preceding store's registered grant.
    generate if (CACHE) assign data_gnt_o = accept_request; endgenerate
    always @(posedge clk_i) begin
        if (!CACHE) data_gnt_o <= accept_request;
        data_rvalid_o <= accept_request;
        
        data_err_o <= 0;
        pending_dph <= accept_request;
        if (CACHE) begin
            cache_miss <= data_req_i && !accept_request;
            if (accept_request) begin
                cache_valid <= !data_we_i;
                cached_addr <= data_addr_i;
            end
        end
        if (accept_request) begin
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
