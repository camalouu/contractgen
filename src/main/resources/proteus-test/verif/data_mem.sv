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
    localparam integer ENTRY_COUNT = 256;
    logic valid [0:ENTRY_COUNT-1];
    logic [31:0] addresses [0:ENTRY_COUNT-1];
    logic [7:0] values [0:ENTRY_COUNT-1];
    integer next_entry;
    integer i;
    integer lane;
    integer slot;
    logic [31:0] read_value;

    assign cmd_ready_o = 1'b1;
    initial begin
        for (i = 0; i < ENTRY_COUNT; i = i + 1) begin
            valid[i] = 1'b0;
            addresses[i] = 32'b0;
            values[i] = 8'b0;
        end
        next_entry = 0;
        rsp_valid_o = 1'b0;
        rsp_data_o = 32'b0;
        rsp_id_o = 2'b0;
    end

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            rsp_valid_o <= 1'b0;
        end else begin
            rsp_valid_o <= 1'b0;
            if (cmd_valid_i && cmd_ready_o) begin
                if (cmd_write_i) begin
                    for (lane = 0; lane < 4; lane = lane + 1) begin
                        if (cmd_wmask_i[lane]) begin
                            slot = -1;
                            for (i = 0; i < ENTRY_COUNT; i = i + 1)
                                if (valid[i] && addresses[i] == cmd_addr_i + lane)
                                    slot = i;
                            if (slot < 0) begin
                                slot = next_entry;
                                next_entry = (next_entry + 1) % ENTRY_COUNT;
                            end
                            valid[slot] <= 1'b1;
                            addresses[slot] <= cmd_addr_i + lane;
                            values[slot] <= cmd_wdata_i[lane*8 +: 8];
                        end
                    end
                end else begin
                    read_value = 32'b0;
                    for (lane = 0; lane < 4; lane = lane + 1)
                        for (i = 0; i < ENTRY_COUNT; i = i + 1)
                            if (valid[i] && addresses[i] == cmd_addr_i + lane)
                                read_value[lane*8 +: 8] = values[i];
                    rsp_data_o <= read_value;
                    rsp_id_o <= cmd_id_i;
                    rsp_valid_o <= 1'b1;
                end
            end
        end
    end
endmodule
