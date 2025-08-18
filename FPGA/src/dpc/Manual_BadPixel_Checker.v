module Manual_BadPixel_Checker #(
    parameter WIDTH_BITS = 10,
    parameter HEIGHT_BITS = 10,
    parameter BAD_POINT_NUM = 128,
    parameter BAD_POINT_BIT = 7
)(
    input clk,
    input rst_n,
    input S_AXI_ACLK,
    
    // 当前处理位置
    input [WIDTH_BITS-1:0] current_x,
    input [HEIGHT_BITS-1:0] current_y,
    input frame_start,
    
    // 手动坏点表配置
    input [BAD_POINT_BIT-1:0] bad_point_num,
    input wen_lut,
    input [BAD_POINT_BIT-1:0] waddr_lut,
    input [31:0] wdata_lut,
    
    // 输出
    output bad_pixel_match,
    output [WIDTH_BITS-1:0] next_bad_x,
    output [HEIGHT_BITS-1:0] next_bad_y
);

    // 读地址和控制
    reg [BAD_POINT_BIT-1:0] raddr;
    wire re;
    reg re_frame_start;
    wire [31:0] rdata;
    wire [WIDTH_BITS-1:0] bad_x = rdata[31:16];
    wire [HEIGHT_BITS-1:0] bad_y = rdata[15:0];
    
    // 读取控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raddr <= 0;
            re_frame_start <= 1;
        end
        else begin
            re_frame_start <= frame_start;
            
            if (frame_start && !re_frame_start) begin
                // 帧开始，重置读地址
                raddr <= 0;
            end
            else if (bad_pixel_match && raddr < bad_point_num) begin
                // 匹配到坏点，读取下一个
                raddr <= raddr + 1;
            end
        end
    end
    
    // 坏点匹配判断
    assign bad_pixel_match = (current_x == bad_x) && (current_y == bad_y) && (raddr < bad_point_num);
    assign re = bad_pixel_match;
    assign next_bad_x = bad_x;
    assign next_bad_y = bad_y;
    
    // BRAM例化
    BRAM_BadPoint_Dual #(
        .ADDR_WIDTH(BAD_POINT_BIT),
        .DATA_WIDTH(32),
        .DEPTH(BAD_POINT_NUM)
    ) BRAM_inst (
        .clka(S_AXI_ACLK),
        .ena(1'b1),
        .wea(wen_lut),
        .addra(waddr_lut),
        .dina(wdata_lut),
        
        .clkb(clk),
        .enb(re),
        .web(1'b0),
        .addrb(raddr),
        .dinb(32'h0),
        .doutb(rdata)
    );

endmodule
