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
    input logic we_i,
    input logic [63:0] addr_i,
    input logic [3:0] be_i,
    input logic [63:0] data_i,
    output logic [63:0] data_o
);
    import "DPI-C" function int contract_cva6_instr_word(input int core_id, input int word_index);

    (* nomem2reg *)
    logic [31:0] instr_mem [(`MAX_INSTR - 1):0];
    logic [31:0] last_addr [`COUNT - 1:0];
    logic [7:0] last_values [`COUNT - 1:0];

    logic [63:0] instr_addr;
    assign instr_addr = addr_i != 64'h0 ? addr_i - `BOOT_ADDR : addr_i;

    logic [31:0] instr_1;
    logic [31:0] instr_2;
    logic [31:0] data_1;
    logic [31:0] data_2;
    logic has_data_1;
    logic has_data_2;
    integer i;

    initial begin
        for (i = 0; i < `COUNT; i = i + 1) begin
            last_addr[i] = '0;
            last_values[i] = `NO_OP;
        end
        for (i = 0; i < `MAX_INSTR; i = i + 1) begin
            instr_mem[i] = contract_cva6_instr_word(ID, i);
        end
        data_o = {`NO_OP, `NO_OP};
    end

    always @(posedge clk_i) begin
        if (req_i == 1'b1) begin
            instr_1 = (enable_i && ((instr_addr >> 2) <= (`MAX_INSTR - 1))) ? instr_mem[(instr_addr >> 2)] : `NO_OP;
            instr_2 = (enable_i && ((instr_addr >> 2) <= (`MAX_INSTR - 2))) ? instr_mem[(instr_addr >> 2) + 1] : `NO_OP;
            data_1 = 32'b0;
            data_2 = 32'b0;
            has_data_1 = 1'b0;
            has_data_2 = 1'b0;
            for (i = 0; i < `COUNT; i = i + 1) begin
                if ((addr_i + 0) == last_addr[i]) begin
                    data_1[7:0] = last_values[i];
                    has_data_1 = 1'b1;
                end
                if ((addr_i + 4) == last_addr[i]) begin
                    data_2[7:0] = last_values[i];
                    has_data_2 = 1'b1;
                end
                if ((addr_i + 1) == last_addr[i]) begin
                    data_1[15:8] = last_values[i];
                    has_data_1 = 1'b1;
                end
                if ((addr_i + 5) == last_addr[i]) begin
                    data_2[15:8] = last_values[i];
                    has_data_2 = 1'b1;
                end
                if ((addr_i + 2) == last_addr[i]) begin
                    data_1[23:16] = last_values[i];
                    has_data_1 = 1'b1;
                end
                if ((addr_i + 6) == last_addr[i]) begin
                    data_2[23:16] = last_values[i];
                    has_data_2 = 1'b1;
                end
                if ((addr_i + 3) == last_addr[i]) begin
                    data_1[31:24] = last_values[i];
                    has_data_1 = 1'b1;
                end
                if ((addr_i + 7) == last_addr[i]) begin
                    data_2[31:24] = last_values[i];
                    has_data_2 = 1'b1;
                end
            end
            data_o <= {has_data_2 ? data_2 : instr_2, has_data_1 ? data_1 : instr_1};
            if (we_i) begin
                for (int byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                    if (be_i[byte_index]) begin
                        for (i = 1; i < `COUNT; i = i + 1) begin
                            last_addr[i - 1] = last_addr[i];
                            last_values[i - 1] = last_values[i];
                        end
                        last_addr[`COUNT - 1] = addr_i + byte_index;
                        last_values[`COUNT - 1] = data_i[(byte_index * 8) +: 8];
                    end
                end
            end
        end
    end
endmodule
