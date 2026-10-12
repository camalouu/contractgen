module data_mem #(parameter bit RAW_ADDRESS = 0, parameter bit ASYNC = 0) (
    input logic clk_i, data_req_i, data_we_i,
    input logic [3:0] data_be_i,
    input logic [31:0] data_addr_i, data_wdata_i,
    input logic [2:0] type_i,
    output logic data_gnt_o, data_rvalid_o,
    output logic [31:0] data_rdata_o,
    output logic data_err_o
);
    logic [7:0] bytes_by_address [bit [31:0]];
    logic [31:0] response, key, pending_rdata;
    logic pending_dph;
    integer lane;
    generate if (ASYNC) begin
        initial bytes_by_address.delete();
        assign data_gnt_o=data_req_i;
        assign data_rvalid_o=data_req_i;
        assign data_err_o=0;
        always_comb begin
            response=0;
            for(int k=0;k<4;k++) begin
                if(bytes_by_address.exists((RAW_ADDRESS ? data_addr_i : {data_addr_i[31:2],2'b0})+32'(k)))
                    response[k*8 +: 8]=bytes_by_address[(RAW_ADDRESS ? data_addr_i : {data_addr_i[31:2],2'b0})+32'(k)];
            end
            if(RAW_ADDRESS) case(type_i)
                3'b001: response={{24{response[7]}},response[7:0]};
                3'b010: response={{16{response[15]}},response[15:0]};
                3'b101: response={24'b0,response[7:0]};
                3'b110: response={16'b0,response[15:0]};
                default: ;
            endcase
            data_rdata_o=response;
        end
        always @(posedge clk_i) if(data_req_i && data_we_i)
            for(int k=0;k<4;k++) if(data_be_i[k])
                bytes_by_address[(RAW_ADDRESS ? data_addr_i : {data_addr_i[31:2],2'b0})+32'(k)]=data_wdata_i[k*8 +: 8];
    end else begin
    initial begin
        bytes_by_address.delete();
        data_gnt_o = 0; data_rvalid_o = 0; data_rdata_o = 0;
        data_err_o = 0; pending_rdata = 0; pending_dph = 0;
    end
    always @(posedge clk_i) begin
        data_gnt_o <= data_req_i;
        data_rvalid_o <= pending_dph;
        data_rdata_o <= pending_rdata;
        data_err_o <= 0;
        pending_dph <= data_req_i;
        if (data_req_i) begin
            response = 0;
            for (lane = 0; lane < 4; lane++) begin
                key = (RAW_ADDRESS ? data_addr_i : {data_addr_i[31:2],2'b0}) + 32'(lane);
                if (bytes_by_address.exists(key)) response[lane*8 +: 8] = bytes_by_address[key];
                if (data_we_i && data_be_i[lane]) bytes_by_address[key] = data_wdata_i[lane*8 +: 8];
            end
            if (RAW_ADDRESS) begin
                case (type_i)
                    3'b001: response = {{24{response[7]}},response[7:0]};
                    3'b010: response = {{16{response[15]}},response[15:0]};
                    3'b101: response = {24'b0,response[7:0]};
                    3'b110: response = {16'b0,response[15:0]};
                    default: ;
                endcase
            end
            pending_rdata <= response;
        end
    end
    end endgenerate
endmodule
