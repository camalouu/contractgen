module cv32e40p_obi_instr_mem #(
    parameter int unsigned ID = 1,
    parameter int unsigned MAX_INSTR = 2048
) (
    input  logic clk_i,
    input  logic req_i,
    input  logic [31:0] addr_i,
    output logic gnt_o,
    output logic rvalid_o,
    output logic [31:0] rdata_o
);
    import "DPI-C" function int contract_simple_instr_word(input int core_id, input int word_index);

    assign gnt_o = req_i;
    initial begin rvalid_o = 1'b0; rdata_o = 32'h00000013; end
    always_ff @(posedge clk_i) begin
        rvalid_o <= req_i;
        if (req_i)
            rdata_o <= ((addr_i >> 2) < MAX_INSTR)
                    ? $unsigned(contract_simple_instr_word(ID, addr_i >> 2))
                    : 32'h00000013;
    end
endmodule
