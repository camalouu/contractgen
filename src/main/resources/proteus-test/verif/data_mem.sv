module data_mem(
    input  logic        clk_i,
    input  logic        reset_i,
    input  logic        cmd_valid_i,
    output logic        cmd_ready_o,
    input  logic [31:0] cmd_addr_i,
    input  logic [1:0]  cmd_id_i,
    input  logic        cmd_write_i,
    input  logic [31:0] cmd_wdata_i,
    input  logic [3:0]  cmd_wmask_i,
    output logic        rsp_valid_o,
    input  logic        rsp_ready_i,
    output logic [31:0] rsp_data_o,
    output logic [1:0]  rsp_id_o
);
    logic [7:0] bytes_by_address [bit [31:0]];
    logic [31:0] read_value, key;
    integer lane;
    assign cmd_ready_o = 1;
    initial begin bytes_by_address.delete(); rsp_valid_o = 0; rsp_data_o = 0; rsp_id_o = 0; end
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin bytes_by_address.delete(); rsp_valid_o <= 0; end
        else begin
            rsp_valid_o <= 0;
            if (cmd_valid_i && cmd_ready_o) begin
                read_value = 0;
                for (lane=0;lane<4;lane++) begin
                    key = {cmd_addr_i[31:2],2'b0} + 32'(lane);
                    if (bytes_by_address.exists(key)) read_value[lane*8 +: 8] = bytes_by_address[key];
                    if (cmd_write_i && cmd_wmask_i[lane]) bytes_by_address[key] = cmd_wdata_i[lane*8 +: 8];
                end
                if (!cmd_write_i) begin rsp_data_o <= read_value; rsp_id_o <= cmd_id_i; rsp_valid_o <= 1; end
            end
        end
    end
endmodule
