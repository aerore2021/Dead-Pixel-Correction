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

    // 双地址读取：当前坐标和下一个坐标
    reg [BAD_POINT_BIT-1:0] current_addr;
    reg [BAD_POINT_BIT-1:0] next_addr;
    wire re;
    reg re_frame_start;
    
    // 当前坐标BRAM读取
    wire [31:0] current_rdata;
    wire [WIDTH_BITS-1:0] current_bad_y = current_rdata[31:16];
    wire [HEIGHT_BITS-1:0] current_bad_x = current_rdata[15:0];
    
    // 下一个坐标BRAM读取
    wire [31:0] next_rdata;
    wire [WIDTH_BITS-1:0] next_bad_y = next_rdata[31:16];
    wire [HEIGHT_BITS-1:0] next_bad_x = next_rdata[15:0];
    
    // 当前像素位置转换为32位坐标进行比较 (行优先)
    wire [31:0] current_coord = {current_y, current_x};
    
    // 当前手动坐标的5x5区域边界计算
    wire [WIDTH_BITS-1:0] current_region_x_min = (current_bad_x >= 2) ? current_bad_x - 2 : 0;
    wire [WIDTH_BITS-1:0] current_region_x_max = current_bad_x + 2;
    wire [HEIGHT_BITS-1:0] current_region_y_min = (current_bad_y >= 2) ? current_bad_y - 2 : 0;
    wire [HEIGHT_BITS-1:0] current_region_y_max = current_bad_y + 2;
    
    // 下一个手动坐标的5x5区域开始位置
    wire [WIDTH_BITS-1:0] next_region_x_min = (next_bad_x >= 2) ? next_bad_x - 2 : 0;
    wire [HEIGHT_BITS-1:0] next_region_y_min = (next_bad_y >= 2) ? next_bad_y - 2 : 0;
    wire [31:0] next_region_start_coord = {next_region_y_min, next_region_x_min};
    
    // 当前区域匹配判断
    wire x_in_current_region = (current_x >= current_region_x_min) && (current_x <= current_region_x_max);
    wire y_in_current_region = (current_y >= current_region_y_min) && (current_y <= current_region_y_max);
    wire in_current_region = x_in_current_region && y_in_current_region && (current_addr < bad_point_num);
    
    // 智能切换逻辑：当扫描到下一个手动坐标的5x5区域开始位置时切换
    wire has_next = (next_addr < bad_point_num);
    wire should_advance = has_next && (current_coord >= next_region_start_coord);
    
    // 地址更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_addr <= 0;
            next_addr <= 1;
            re_frame_start <= 1;
        end
        else begin
            re_frame_start <= frame_start;
            
            if (frame_start && !re_frame_start) begin
                // 帧开始，重置地址
                current_addr <= 0;
                next_addr <= 1;
            end
            else if (should_advance) begin
                // 切换到下一个手动坐标
                current_addr <= current_addr + 1;
                next_addr <= (next_addr + 1 < bad_point_num) ? next_addr + 1 : next_addr;
            end
        end
    end
    
    // 输出逻辑
    assign bad_pixel_match = in_current_region;
    assign re = 1'b1;  // 总是使能读取
    assign next_bad_x = current_bad_x;
    assign next_bad_y = current_bad_y;
    
    // BRAM例化 - 当前坐标
    BRAM_BadPoint_Dual BRAM_current (
        .clka(S_AXI_ACLK),
        .wea(wen_lut),
        .addra(waddr_lut),
        .dina(wdata_lut),
        
        .clkb(clk),
        .enb(re),
        .addrb(current_addr),
        .doutb(current_rdata)
    );
    
    // BRAM例化 - 下一个坐标（用于预判切换时机）
    BRAM_BadPoint_Dual BRAM_next (
        .clka(S_AXI_ACLK),
        .wea(wen_lut),
        .addra(waddr_lut),
        .dina(wdata_lut),
        
        .clkb(clk),
        .enb(re),
        .addrb(next_addr),
        .doutb(next_rdata)
    );

endmodule
