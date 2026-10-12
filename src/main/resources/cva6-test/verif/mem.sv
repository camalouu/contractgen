`define NO_OP     32'h00000013
`define MAX_INSTR 2048
`define COUNT 32
`define BOOT_ADDR 64'h80000000

module mem #(
    parameter int unsigned ID = 0
) (
    input logic clk_i,
    input logic enable_i,
    input logic req_i,
    input logic we_i, fetch_i,
    input logic [63:0] addr_i,
    input logic [7:0] be_i,
    input logic [63:0] data_i,
    output logic [63:0] data_o
);
    import "DPI-C" function int contract_cva6_instr_word(input int core_id, input int word_index);

    logic [7:0] bytes_by_address [bit [31:0]];
    logic [63:0] response;
    logic [31:0] key, word_value;
    integer lane;
    initial begin bytes_by_address.delete(); data_o = {32'h13,32'h13}; end
    always @(posedge clk_i) begin
        if (req_i) begin
            response = 0;
            for (lane=0;lane<8;lane++) begin
                key = {addr_i[31:3],3'b0} + 32'(lane);
                if (fetch_i && !we_i) begin
                    word_value = enable_i && key >= 32'h80 && key < 32'h2080
                        ? $unsigned(contract_cva6_instr_word(ID,(key-32'h80)>>2)) : 32'h13;
                    response[lane*8 +: 8] = word_value[(key[1:0]*8) +: 8];
                end else if (bytes_by_address.exists(key)) response[lane*8 +: 8] = bytes_by_address[key];
                if (we_i && be_i[lane]) bytes_by_address[key] = data_i[lane*8 +: 8];
            end
            data_o <= response;
        end
    end
endmodule
