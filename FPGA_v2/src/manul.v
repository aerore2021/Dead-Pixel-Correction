module manual #(
    parameter WIDTH_BITS = 10,
    parameter HEIGHT_BITS = 10,
    parameter BAD_POINT_MUN = 128,
    parameter BAD_POINT_BIT = clog2(BAD_POINT_MUN)


)(
    input clk,
    input rst_n,
    input shift,
    output [WIDTH_BITS-1:0]width_bad,
    output [HEIGHT_BITS-1:0]height_bad,
    input [BAD_POINT_BIT-1:0]bad_point_num,
    input S_AXI_ACLK,
    input wen_lut,
    input [BAD_POINT_BIT-1:0]waddr_lut,
    input [31:0]wdata_lut
);

    function integer clog2 (input integer bit_depth);
        begin
            for(clog2=0; bit_depth>1; clog2=clog2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    reg [BAD_POINT_BIT-1:0] raddr;
    wire re;
    reg re_frame_end;
    wire [31:0]rdata;
    wire rd_end;


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n || rd_end) begin
            raddr <= 'd0;
            re_frame_end <= 1'b1;
        end 
        else begin
            re_frame_end <= 1'b0;
            if (re) begin
                raddr <= raddr + 1'b1;
            end 
            else begin
                raddr <= raddr;
            end
        end
    end

    assign rd_end = raddr == bad_point_num+1 ;
    assign re = re_frame_end | shift;

    BRAM_badpoint BRAM_badpoint_inst(
        .enb ( re),
        .wea ( wen_lut ),
        .addra ( waddr_lut-'d4 ),
        .dina ( wdata_lut ),
        .doutb ( rdata ),
        .addrb ( raddr ),
        .clka ( S_AXI_ACLK ),
        .clkb ( clk )
    );
 


        
    assign width_bad = rdata[31:16];
    assign height_bad = rdata[15:0];




endmodule