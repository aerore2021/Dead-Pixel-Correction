/*
 * =============================================================================
 * Manual Bad Pixel Checker with Line Cache Optimization
 * =============================================================================
 * 
 * 检测原理：
 *   手动坐标(x,y)扩展为5x5区域：[x-2:x+2][y-2:y+2]
 *   对当前行Y，找出所有影响该行的5x5区域的X范围
 *   像素流到达时，并行检查X坐标是否在任一区间内
 * 
 * =============================================================================
 */

module Manual_BadPixel_Checker #(
    parameter WIDTH_BITS = 10,          // X坐标位宽
    parameter HEIGHT_BITS = 10,         // Y坐标位宽
    parameter BAD_POINT_NUM = 128,      // 最大手动坐标数量
    parameter BAD_POINT_BIT = 7,        // 坐标索引位宽 (log2(128)=7)
    parameter IMAGE_WIDTH = 640,        // 图像实际宽度
    parameter IMAGE_HEIGHT = 512,       // 图像实际高度
    parameter MAX_REGIONS_PER_LINE = 16 // 每行最多缓存的区域数量
)(
    // 时钟和复位
    input clk,                          // 主处理时钟
    input rst_n,                        // 异步复位，低有效
    input S_AXI_ACLK,                   // AXI时钟(用于配置BRAM)
    
    // 当前处理位置 (来自像素流pipeline)
    input [WIDTH_BITS-1:0] current_x,  // 当前像素X坐标
    input [HEIGHT_BITS-1:0] current_y, // 当前像素Y坐标
    input frame_start,                  // 帧开始信号(SOF)
    
    // 手动坐标表配置接口 (AXI写入)
    input [BAD_POINT_BIT-1:0] bad_point_num,  // 有效手动坐标数量
    input wen_lut,                      // BRAM写使能
    input [BAD_POINT_BIT-1:0] waddr_lut,       // BRAM写地址
    input [31:0] wdata_lut,             // BRAM写数据 {Y[15:0], X[15:0]}
    
    // 检测结果输出
    output bad_pixel_match,             // 当前像素是否在手动区域内
    output [WIDTH_BITS-1:0] next_bad_x, // 下一个手动坐标X (调试用)
    output [HEIGHT_BITS-1:0] next_bad_y // 下一个手动坐标Y (调试用)
);

    // =============================================================================
    // 行缓存存储结构
    // =============================================================================
    
    // 当前行缓存 (正在使用)
    reg [19:0] current_line_regions [0:MAX_REGIONS_PER_LINE-1];
    reg [3:0] current_line_region_count;      // 当前行的有效区域数量
    reg [HEIGHT_BITS-1:0] current_cached_line_y; // 当前缓存对应的行号
    
    // 下一行缓存 (正在构建)
    reg [19:0] next_line_regions [0:MAX_REGIONS_PER_LINE-1];
    reg [3:0] next_line_region_count;         // 下一行的有效区域数量
    reg [HEIGHT_BITS-1:0] next_cached_line_y; // 下一行缓存对应的行号
    
    // =============================================================================
    // BRAM接口和手动坐标解析
    // =============================================================================
    
    /*
     * 手动坐标存储：
     *   存储格式：32位 = {Y[15:0], X[15:0]}
     *   根据WIDTH_BITS和HEIGHT_BITS截取
     */
    
    wire [31:0] coord_rdata;                  // BRAM读出的坐标数据
    wire [HEIGHT_BITS-1:0] bad_y = coord_rdata[31:16]; // 手动坐标Y
    wire [WIDTH_BITS-1:0] bad_x = coord_rdata[15:0];   // 手动坐标X
    
    // =============================================================================
    // 状态机定义和控制信号
    // =============================================================================
    
    /*
     * 状态机设计说明：
     * 
     * 设计目标：
     *   1. 帧开始后立即为第一行(Y=0)构建缓存，确保像素流到达时缓存已准备好
     *   2. 在处理每一行像素时，提前为下一行构建缓存
     *   3. 每到行末时切换缓存，实现双缓存流水线处理
     * 
     * 工作流程：
     *   1. 帧开始(frame_start) -> 立即开始为第一行构建缓存
     *   2. 缓存构建完成 -> 进入RUNNING状态开始检测
     *   3. 行末检测(line_end) -> 为下一行构建缓存并切换
     *   4. 重复步骤3直到帧结束
     * 
     * 状态转移图：
     * 
     *           frame_start
     *    IDLE ─────────────────> SCAN_COORDS (为Y=0构建缓存)
     *     ↑                         │
     *     │                         ↓
     *     │                  BUILD_LINE_CACHE
     *     │                         │
     *     │                         ↓
     *     │                    SWAP_CACHE
     *     │                         │
     *     │                         ↓
     *     │                     RUNNING ←─┐
     *     │                         │     │
     *     │  frame_start            │     │ line_end && next_line_valid
     *     └─────────────────────────┘     │
     *                                     │
     *           ┌─────────────────────────┘
     *           ↓
     *      SCAN_COORDS (为下一行构建缓存)
     *           │
     *           ↓
     *    BUILD_LINE_CACHE
     *           │
     *           ↓
     *      SWAP_CACHE
     *           │
     *           └─────────────────────────> RUNNING
     * 
     * 关键设计点：
     *   - 第一行缓存在像素流开始前就构建完成
     *   - 后续行的缓存在前一行处理的最后时刻构建并切换
     *   - 双缓存策略确保检测过程不被中断
     */
    
    // 状态编码
    localparam STATE_IDLE            = 3'b000;  // 空闲状态，等待帧开始
    localparam STATE_SCAN_COORDS     = 3'b001;  // 扫描手动坐标索引
    localparam STATE_BUILD_LINE_CACHE = 3'b010; // 构建行缓存(处理BRAM延迟)
    localparam STATE_RUNNING         = 3'b011;  // 运行状态，进行检测
    localparam STATE_SWAP_CACHE      = 3'b100;  // 切换缓存
    
    // =============================================================================
    // 跨时钟域信号同步器
    // =============================================================================
    
    /*
     * 跨时钟域同步设计：
     *   主处理域(clk): current_x, current_y, frame_start
     *   配置域(S_AXI_ACLK): 状态机, BRAM访问, 缓存构建
     * 
     * 同步策略：
     *   使用双级寄存器同步器防止亚稳态
     *   边沿检测器检测信号变化
     */
    
    // 将clk域信号同步到S_AXI_ACLK域
    reg [WIDTH_BITS-1:0] current_x_sync_1, current_x_sync_2;
    reg [HEIGHT_BITS-1:0] current_y_sync_1, current_y_sync_2;
    reg frame_start_sync_1, frame_start_sync_2;
    
    // 同步后的信号
    wire [WIDTH_BITS-1:0] current_x_synced = current_x_sync_2;
    wire [HEIGHT_BITS-1:0] current_y_synced = current_y_sync_2;
    wire frame_start_synced = frame_start_sync_2;
    
    // 双级同步器
    always @(posedge S_AXI_ACLK) begin
        if (!rst_n) begin
            current_x_sync_1 <= 0;
            current_x_sync_2 <= 0;
            current_y_sync_1 <= 0;
            current_y_sync_2 <= 0;
            frame_start_sync_1 <= 0;
            frame_start_sync_2 <= 0;
        end
        else begin
            // 第一级同步
            current_x_sync_1 <= current_x;
            current_y_sync_1 <= current_y;
            frame_start_sync_1 <= frame_start;
            
            // 第二级同步
            current_x_sync_2 <= current_x_sync_1;
            current_y_sync_2 <= current_y_sync_1;
            frame_start_sync_2 <= frame_start_sync_1;
        end
    end
    
    // 状态机寄存器 (运行在S_AXI_ACLK域)
    reg [2:0] state;                           // 当前状态
    reg [BAD_POINT_BIT-1:0] scan_addr;        // BRAM扫描地址
    reg re_frame_start_synced;                 // 同步后的帧开始信号边沿检测
    
    // 缓存控制信号
    reg [HEIGHT_BITS-1:0] building_line_y;    // 正在构建缓存的目标行
    reg cache_building;                       // 缓存构建标志
    reg initial_cache_built;                  // 是否已构建过初始缓存
    reg [WIDTH_BITS-1:0] prev_current_x_synced; // 上一个时钟的同步X坐标
    reg [HEIGHT_BITS-1:0] prev_current_y_synced; // 上一个时钟的同步Y坐标
    
    // =============================================================================
    // 区域计算和行变化检测
    // =============================================================================
    
    /*
     * 5x5区域扩展计算：
     *   手动坐标(bad_x, bad_y)扩展为5x5区域
     *   Y轴范围：[bad_y-2, bad_y+2]
     *   X轴范围：[bad_x-2, bad_x+2]
     *   边界处理：坐标<2时截断为0
     */
    
    // 当前读取坐标的5x5区域Y轴范围
    wire [HEIGHT_BITS-1:0] region_y_start = (bad_y >= 2) ? bad_y - 2 : 0;
    wire [HEIGHT_BITS-1:0] region_y_end = bad_y + 2;
    
    // 判断该坐标是否影响正在构建的目标行
    wire affects_building_line = (building_line_y >= region_y_start) && 
                                (building_line_y <= region_y_end);
    
    // 当前读取坐标的5x5区域X轴范围
    wire [WIDTH_BITS-1:0] region_x_start = (bad_x >= 2) ? bad_x - 2 : 0;
    wire [WIDTH_BITS-1:0] region_x_end = bad_x + 2;
    
    /*
     * 行变化检测和行末检测：
     *   使用同步后的信号检测像素流状态变化
     *   触发缓存更新和切换
     */
    
    wire line_changed_synced = (current_y_synced != prev_current_y_synced);    // 行变化检测
    wire line_end_synced = (current_x_synced == IMAGE_WIDTH - 1);             // 行末检测
    wire need_prefetch_synced = line_changed_synced && (current_y_synced != current_cached_line_y); // 需要更新缓存
    
    // =============================================================================
    // 并行区域匹配检测逻辑 (运行在clk域)
    // =============================================================================
    
    // 将S_AXI_ACLK域的缓存数据同步到clk域
    reg [19:0] current_line_regions_sync [0:MAX_REGIONS_PER_LINE-1];
    reg [3:0] current_line_region_count_sync_1, current_line_region_count_sync_2;
    reg [HEIGHT_BITS-1:0] current_cached_line_y_sync_1, current_cached_line_y_sync_2;
    reg [2:0] state_sync_1, state_sync_2;
    integer j, k;
    // 双级同步器将缓存信息同步到clk域
    always @(posedge clk) begin
        if (!rst_n) begin
            current_line_region_count_sync_1 <= 0;
            current_line_region_count_sync_2 <= 0;
            current_cached_line_y_sync_1 <= {HEIGHT_BITS{1'b1}};
            current_cached_line_y_sync_2 <= {HEIGHT_BITS{1'b1}};
            state_sync_1 <= STATE_IDLE;
            state_sync_2 <= STATE_IDLE;
            
            for (j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                current_line_regions_sync[j] <= 20'h0;
            end
        end
        else begin
            // 第一级同步
            current_line_region_count_sync_1 <= current_line_region_count;
            current_cached_line_y_sync_1 <= current_cached_line_y;
            state_sync_1 <= state;
            
            // 第二级同步
            current_line_region_count_sync_2 <= current_line_region_count_sync_1;
            current_cached_line_y_sync_2 <= current_cached_line_y_sync_1;
            state_sync_2 <= state_sync_1;
            
            // 同步缓存数据 (仅在状态稳定时更新)
            if (state_sync_1 == STATE_RUNNING) begin
                for ( j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                    current_line_regions_sync[j] <= current_line_regions[j];
                end
            end
        end
    end
    
    wire [MAX_REGIONS_PER_LINE-1:0] region_matches;
    genvar i;
    generate
        for (i = 0; i < MAX_REGIONS_PER_LINE; i = i + 1) begin : gen_region_match
            // 解析同步后缓存中的区间信息
            wire [9:0] region_start_x = current_line_regions_sync[i][9:0];
            wire [9:0] region_end_x = current_line_regions_sync[i][19:10];
            
            // 区间有效性检查
            wire valid_region = (i < current_line_region_count_sync_2);
            
            // X坐标范围检查
            wire x_in_range = (current_x >= region_start_x) && (current_x <= region_end_x);
            
            // 该区间的匹配结果
            assign region_matches[i] = valid_region && x_in_range;
            
            
        end
    endgenerate
    
    // 双缓存预取状态机
    always @(posedge S_AXI_ACLK) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            scan_addr <= 0;
            current_line_region_count <= 0;
            next_line_region_count <= 0;
            current_cached_line_y <= {HEIGHT_BITS{1'b1}};  // 无效值
            next_cached_line_y <= {HEIGHT_BITS{1'b1}};
            building_line_y <= 0;
            re_frame_start_synced <= 0;
            cache_building <= 0;
            prev_current_y_synced <= 0;
            prev_current_x_synced <= 0;
            initial_cache_built <= 0;
            
            // 清空双缓存
            for ( j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                current_line_regions[j] <= 20'h0;
                next_line_regions[j] <= 20'h0;
            end
        end
        else begin
            re_frame_start_synced <= frame_start_synced;
            prev_current_y_synced <= current_y_synced;
            prev_current_x_synced <= current_x_synced;
            
            case (state)
                STATE_IDLE: begin
                    if (frame_start_synced && !re_frame_start_synced) begin
                        // 帧开始时，立即开始为第一行(Y=0)构建缓存
                        building_line_y <= 0;
                        cache_building <= 1;
                        scan_addr <= 0;
                        next_line_region_count <= 0;
                        initial_cache_built <= 0;
                        
                        // 清空下一行缓存
                        for ( j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                            next_line_regions[j] <= 20'h0;
                        end
                        
                        state <= STATE_SCAN_COORDS;
                    end
                end
                
                STATE_SCAN_COORDS: begin
                    if (scan_addr < bad_point_num) begin
                        state <= STATE_BUILD_LINE_CACHE;
                    end
                    else begin
                        // 缓存构建完成，切换到当前缓存
                        state <= STATE_SWAP_CACHE;
                    end
                end
                
                STATE_BUILD_LINE_CACHE: begin
                    // 处理BRAM读取延迟，等待一个时钟周期
                    // 同时检查当前手动坐标是否影响正在构建的目标行
                    if (affects_building_line && (next_line_region_count < MAX_REGIONS_PER_LINE)) begin
                        // 添加到下一行缓存
                        next_line_regions[next_line_region_count] <= {region_x_end, region_x_start};
                        next_line_region_count <= next_line_region_count + 1;
                    end
                    
                    state <= STATE_SCAN_COORDS;
                    scan_addr <= scan_addr + 1;
                end
                
                STATE_SWAP_CACHE: begin
                    // 将构建好的缓存切换为当前缓存
                    current_cached_line_y <= building_line_y;
                    current_line_region_count <= next_line_region_count;
                    for ( j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                        current_line_regions[j] <= next_line_regions[j];
                    end
                    
                    
                    
                    cache_building <= 0;
                    
                    // 如果是初始缓存构建完成，进入运行状态
                    if (!initial_cache_built) begin
                        initial_cache_built <= 1;
                        state <= STATE_RUNNING;
                    end
                    else begin
                        // 后续缓存切换完成，回到运行状态
                        state <= STATE_RUNNING;
                    end
                end
                
                STATE_RUNNING: begin
                    // 检测到行末且下一行需要新的缓存
                    if (line_end_synced && !cache_building && (current_y_synced + 1 < IMAGE_HEIGHT)) begin
                        // 开始为下一行构建缓存
                        building_line_y <= current_y_synced + 1;
                        cache_building <= 1;
                        scan_addr <= 0;
                        next_line_region_count <= 0;
                        
                        // 清空下一行缓存
                        for ( j = 0; j < MAX_REGIONS_PER_LINE; j = j + 1) begin
                            next_line_regions[j] <= 20'h0;
                        end
                        
                        state <= STATE_SCAN_COORDS;
                    end
                    else if (frame_start_synced && !re_frame_start_synced) begin
                        // 新帧开始，重新初始化
                        state <= STATE_IDLE;
                        cache_building <= 0;
                        initial_cache_built <= 0;
                    end
                end
                
                default: begin
                    state <= STATE_IDLE;
                    cache_building <= 0;
                    initial_cache_built <= 0;
                end
            endcase
        end
    end
    // 输出逻辑 - 只要不在IDLE状态就可以进行检测
    // 使用当前缓存进行检测，即使在后台更新缓存时也不中断检测
    // =============================================================================
    // 输出结果生成
    // =============================================================================
    
    /*
     * 输出信号设计：
     *   bad_pixel_match: 最终的手动坏点检测结果
     *   检测逻辑：使用同步到clk域的状态和缓存数据进行检测
     * 
     * 时序考虑：
     *   组合逻辑输出，与像素时钟同步
     *   确保检测结果与当前处理像素精确对应
     *   支持连续流水线处理
     * 
     * 跨时钟域处理：
     *   使用双级同步器同步状态和缓存数据到clk域
     *   确保输出结果时序正确且无亚稳态
     */
    
    // 最终检测结果：使用同步后的状态进行判断
    assign bad_pixel_match = (state_sync_2 != STATE_IDLE) ? (|region_matches) : 1'b0;
    // =============================================================================
    // 调试输出信号生成
    // =============================================================================

    // 调试用输出：显示当前扫描的坐标
    assign next_bad_x = bad_x;
    assign next_bad_y = bad_y;
    
    // 原始坐标BRAM例化
    BRAM_BadPoint_Dual BRAM_coord (
        .clk(S_AXI_ACLK),
        .we(wen_lut),
        .waddr(waddr_lut),
        .wdata_a(wdata_lut),
        
        .re(1'b1),
        .raddr(scan_addr),
        .rdata_b(coord_rdata)
    );
endmodule
