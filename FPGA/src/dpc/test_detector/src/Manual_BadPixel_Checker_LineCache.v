module Manual_BadPixel_Checker_LineCache #(
    parameter WIDTH_BITS = 10,
    parameter HEIGHT_BITS = 10,
    parameter BAD_POINT_NUM = 128,
    parameter BAD_POINT_BIT = 7,
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 512,
    parameter MAX_REGIONS_PER_LINE = 16  // 每行最多16个手动区域
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

    // 行区间缓存：每行存储该行内的手动区域信息
    // 格式：{region_end_x[9:0], region_start_x[9:0]} = 20位
    reg [19:0] line_regions [0:MAX_REGIONS_PER_LINE-1];
    reg [3:0] line_region_count;
    reg [HEIGHT_BITS-1:0] cached_line_y;
    
    // 全局手动坐标存储（原始BRAM）
    wire [31:0] coord_rdata;
    wire [HEIGHT_BITS-1:0] bad_y = coord_rdata[31:16];
    wire [WIDTH_BITS-1:0] bad_x = coord_rdata[15:0];
    
    // 状态机
    localparam STATE_IDLE = 3'b000;
    localparam STATE_SCAN_COORDS = 3'b001;
    localparam STATE_BUILD_LINE_CACHE = 3'b010;
    localparam STATE_RUNNING = 3'b011;
    localparam STATE_NEXT_LINE = 3'b100;
    
    reg [2:0] state;
    reg [BAD_POINT_BIT-1:0] scan_addr;
    reg re_frame_start;
    
    // 当前扫描行的目标行范围（考虑5x5扩展）
    wire [HEIGHT_BITS-1:0] target_line_start = (current_y >= 2) ? current_y - 2 : 0;
    wire [HEIGHT_BITS-1:0] target_line_end = current_y + 2;
    
    // 检查当前行是否需要更新缓存
    wire need_update_cache = (cached_line_y != current_y) || (state != STATE_RUNNING);
    
    // 并行区域匹配检查
    wire [MAX_REGIONS_PER_LINE-1:0] region_matches;
    genvar i;
    generate
        for (i = 0; i < MAX_REGIONS_PER_LINE; i = i + 1) begin : gen_region_match
            wire [9:0] region_start_x = line_regions[i][9:0];
            wire [9:0] region_end_x = line_regions[i][19:10];
            wire valid_region = (i < line_region_count);
            wire x_in_range = (current_x >= region_start_x) && (current_x <= region_end_x);
            
            assign region_matches[i] = valid_region && x_in_range;
        end
    endgenerate
    
    // 状态机控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            scan_addr <= 0;
            line_region_count <= 0;
            cached_line_y <= 0;
            re_frame_start <= 1;
            
            // 清空行缓存
            for (integer j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                line_regions[j] <= 20'h0;
            end
        end
        else begin
            re_frame_start <= frame_start;
            
            case (state)
                STATE_IDLE: begin
                    if (frame_start && !re_frame_start) begin
                        state <= STATE_RUNNING;
                        cached_line_y <= 0;
                    end
                end
                
                STATE_RUNNING: begin
                    if (need_update_cache) begin
                        // 需要为新行构建缓存
                        state <= STATE_SCAN_COORDS;
                        scan_addr <= 0;
                        line_region_count <= 0;
                        cached_line_y <= current_y;
                        
                        // 清空行缓存
                        for (integer j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                            line_regions[j] <= 20'h0;
                        end
                    end
                    else if (frame_start && !re_frame_start) begin
                        state <= STATE_IDLE;
                    end
                end
                
                STATE_SCAN_COORDS: begin
                    if (scan_addr < bad_point_num) begin
                        state <= STATE_BUILD_LINE_CACHE;
                    end
                    else begin
                        state <= STATE_RUNNING;
                    end
                end
                
                STATE_BUILD_LINE_CACHE: begin
                    // 检查当前手动坐标是否影响当前扫描行
                    wire [HEIGHT_BITS-1:0] region_y_start = (bad_y >= 2) ? bad_y - 2 : 0;
                    wire [HEIGHT_BITS-1:0] region_y_end = bad_y + 2;
                    wire affects_current_line = (current_y >= region_y_start) && (current_y <= region_y_end);
                    
                    if (affects_current_line && (line_region_count < MAX_REGIONS_PER_LINE)) begin
                        // 计算该手动坐标在当前行的X范围
                        wire [WIDTH_BITS-1:0] region_x_start = (bad_x >= 2) ? bad_x - 2 : 0;
                        wire [WIDTH_BITS-1:0] region_x_end = bad_x + 2;
                        
                        // 添加到行缓存
                        line_regions[line_region_count] <= {region_x_end, region_x_start};
                        line_region_count <= line_region_count + 1;
                    end
                    
                    // 移动到下一个手动坐标
                    scan_addr <= scan_addr + 1;
                    state <= STATE_SCAN_COORDS;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
    
    // 输出逻辑
    assign bad_pixel_match = (state == STATE_RUNNING) ? (|region_matches) : 1'b0;
    assign next_bad_x = bad_x;
    assign next_bad_y = bad_y;
    
    // 原始坐标BRAM例化
    BRAM_BadPoint_Dual BRAM_coord (
        .clka(S_AXI_ACLK),
        .wea(wen_lut),
        .addra(waddr_lut),
        .dina(wdata_lut),
        
        .clkb(clk),
        .enb(1'b1),
        .addrb(scan_addr),
        .doutb(coord_rdata)
    );

endmodule
