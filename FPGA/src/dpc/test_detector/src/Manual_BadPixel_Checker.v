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
    reg [BAD_POINT_BIT-1:0] next_raddr;
    wire re;
    reg re_frame_start;
    wire [31:0] rdata;
    wire [WIDTH_BITS-1:0] bad_y = rdata[31:16];
    wire [HEIGHT_BITS-1:0] bad_x = rdata[15:0];
    
    // 预计算下一个读地址
    always @(*) begin
        if (frame_start && !re_frame_start) begin
            next_raddr = 0;
        end
        else if ((current_x == bad_x + 5) && (current_y == bad_y + 5) && raddr < bad_point_num) begin
            next_raddr = raddr + 1;
        end
        else begin
            next_raddr = raddr;
        end
    end
    
    // 读取控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raddr <= 0;
            re_frame_start <= 1;
        end
        else begin
            re_frame_start <= frame_start;
            raddr <= next_raddr;
        end
    end
    
    // 坏点匹配判断
    wire x_is_in, y_is_in;
    assign x_is_in = (current_x <= bad_x + 5) && (current_x + 5 >= bad_x);
    assign y_is_in = (current_y <= bad_y + 5) && (current_y + 5 >= bad_y);
    assign bad_pixel_match = x_is_in && y_is_in && (raddr < bad_point_num);

    // BRAM读使能信号：always enable to support continuous reading
    assign re = 1'b1;
    assign next_bad_x = bad_x;
    assign next_bad_y = bad_y;
    
    // BRAM例化
    BRAM_BadPoint_Dual BRAM_inst (
        .clka(S_AXI_ACLK),
        .wea(wen_lut),
        .addra(waddr_lut),
        .dina(wdata_lut),
        
        .clkb(clk),
        .enb(re),
        .addrb(raddr),
        .doutb(rdata)
    );

endmodule
