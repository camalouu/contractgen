module cv32e40p_obi_data_mem #(
    parameter int unsigned COUNT = 32
) (
    input logic clk_i, input logic req_i, input logic we_i,
    input logic [3:0] be_i, input logic [31:0] addr_i, input logic [31:0] wdata_i,
    output logic gnt_o, output logic rvalid_o, output logic [31:0] rdata_o
);
    logic [7:0] bytes_by_address [bit [31:0]];
    logic [31:0] response, key;
    integer lane;
    initial bytes_by_address.delete();
    assign gnt_o = req_i;
    initial begin rvalid_o = 0; rdata_o = 0; end
    always @(posedge clk_i) begin
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
endmodule
