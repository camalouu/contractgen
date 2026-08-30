`define COUNT 32

module data_mem (
    input  logic        clk_i,
    input  logic        data_req_i,
    input  logic        data_we_i,
    input  logic [3:0]  data_be_i,
    input  logic [31:0] data_addr_i,
    input  logic [31:0] data_wdata_i,
    output logic        data_gnt_o,
    output logic        data_rvalid_o,
    output logic [31:0] data_rdata_o,
    output logic        data_err_o
);
    logic [31:0] last_addr [`COUNT - 1:0];
    logic [7:0] last_values [`COUNT - 1:0];
    logic [32:0] temp;
    logic [31:0] pending_rdata;
    logic pending_dph;
    integer i;

    initial begin
        for (i = 0; i < `COUNT; i = i + 1) begin
            last_addr[i] = 32'b0;
            last_values[i] = 8'b0;
        end
        data_gnt_o = 1'b0;
        data_rvalid_o = 1'b0;
        data_rdata_o = 32'b0;
        data_err_o = 1'b0;
        pending_rdata = 32'b0;
        pending_dph = 1'b0;
    end

    always @(posedge clk_i) begin
        data_gnt_o <= data_req_i;
        data_rvalid_o <= pending_dph;
        data_rdata_o <= pending_rdata;
        data_err_o <= 1'b0;
        pending_dph <= data_req_i;

        if (data_req_i) begin
            temp = data_addr_i % 32'h1000;
            for (i = 0; i < `COUNT; i = i + 1) begin
                if (data_be_i[0] && data_addr_i == last_addr[i]) temp[7:0] = last_values[i];
                if (data_be_i[1] && data_addr_i + 1 == last_addr[i]) temp[15:8] = last_values[i];
                if (data_be_i[2] && data_addr_i + 2 == last_addr[i]) temp[23:16] = last_values[i];
                if (data_be_i[3] && data_addr_i + 3 == last_addr[i]) temp[31:24] = last_values[i];
            end
            if (data_we_i) begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (data_be_i[i]) begin
                        for (integer j = 1; j < `COUNT; j = j + 1) begin
                            last_addr[j - 1] = last_addr[j];
                            last_values[j - 1] = last_values[j];
                        end
                        last_addr[`COUNT - 1] = data_addr_i + i;
                        last_values[`COUNT - 1] = data_wdata_i[(i * 8) +: 8];
                    end
                end
            end
            pending_rdata <= temp[31:0];
        end
    end
endmodule
