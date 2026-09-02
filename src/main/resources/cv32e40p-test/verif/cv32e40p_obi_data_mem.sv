module cv32e40p_obi_data_mem #(
    parameter int unsigned COUNT = 32
) (
    input logic clk_i, input logic req_i, input logic we_i,
    input logic [3:0] be_i, input logic [31:0] addr_i, input logic [31:0] wdata_i,
    output logic gnt_o, output logic rvalid_o, output logic [31:0] rdata_o
);
    logic [31:0] saved_addr [COUNT];
    logic [7:0] saved_value [COUNT];
    logic [31:0] response;
    integer i, j;

    assign gnt_o = req_i;
    initial begin
        rvalid_o = 1'b0; rdata_o = '0;
        for (i = 0; i < COUNT; i = i + 1) begin saved_addr[i] = '0; saved_value[i] = '0; end
    end
    always_ff @(posedge clk_i) begin
        rvalid_o <= req_i;
        if (req_i) begin
            response = addr_i % 32'h1000;
            for (i = 0; i < COUNT; i = i + 1) begin
                if (addr_i     == saved_addr[i]) response[7:0]   = saved_value[i];
                if (addr_i + 1 == saved_addr[i]) response[15:8]  = saved_value[i];
                if (addr_i + 2 == saved_addr[i]) response[23:16] = saved_value[i];
                if (addr_i + 3 == saved_addr[i]) response[31:24] = saved_value[i];
            end
            rdata_o <= response;
            if (we_i) for (i = 0; i < 4; i = i + 1) if (be_i[i]) begin
                for (j = 1; j < COUNT; j = j + 1) begin
                    saved_addr[j - 1] = saved_addr[j]; saved_value[j - 1] = saved_value[j];
                end
                saved_addr[COUNT - 1] = addr_i + i;
                saved_value[COUNT - 1] = wdata_i[(i * 8) +: 8];
            end
        end
    end
endmodule
