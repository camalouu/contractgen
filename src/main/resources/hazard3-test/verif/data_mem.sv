module data_mem (
    input logic clk_i, data_req_i, data_we_i,
    input logic [3:0] data_be_i,
    input logic [31:0] data_addr_i, data_wdata_i,
    output logic data_gnt_o, data_rvalid_o,
    output logic [31:0] data_rdata_o,
    output logic data_err_o
);
    logic [7:0] bytes_by_address [bit [31:0]];
    logic pending_write = 0;
    logic [31:0] pending_base, key, response;
    logic [3:0] pending_be;
    integer lane;
    assign data_gnt_o = data_req_i;
    assign data_err_o = 0;
    initial begin bytes_by_address.delete(); data_rvalid_o=0; data_rdata_o=0; end
    // Hazard3 separates address acceptance from the following write-data phase.
    always @(posedge clk_i) begin
        if (pending_write)
            for(lane=0;lane<4;lane++) if(pending_be[lane])
                bytes_by_address[pending_base+32'(lane)] = data_wdata_i[lane*8 +: 8];
        pending_write <= data_req_i && data_we_i;
        pending_base <= {data_addr_i[31:2],2'b0};
        pending_be <= data_be_i;
        data_rvalid_o <= data_req_i;
        if (data_req_i) begin
            response=0;
            for(lane=0;lane<4;lane++) begin
                key={data_addr_i[31:2],2'b0}+32'(lane);
                if(bytes_by_address.exists(key)) response[lane*8 +: 8]=bytes_by_address[key];
            end
            data_rdata_o<=response;
        end
    end
endmodule
