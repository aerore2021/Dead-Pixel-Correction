/*
 * DPC检测模块 - 基于k值的自动坏点检测
 * 
 * 功能：
 * 1. 基于k值检测坏点（k=0为死点，k值偏差大的为盲点）
 * 2. 跳过手动坏点列表中的像素
 * 3. 将检测到的坏点坐标输出给上位机
 * 4. 不进行校正，只做检测
 */

module DPC_Detector #(
    parameter WIDTH = 16,                    // 像素数据位宽
    parameter K_WIDTH = 16,                  // k值位宽
    parameter CNT_WIDTH = 10,                // 坐标计数器位宽
    parameter MANUAL_BP_NUM = 128,           // 手动坏点最大数量
    parameter MANUAL_BP_BIT = 7,             // 手动坏点地址位宽
    parameter AUTO_BP_NUM = 256,             // 自动检测坏点最大数量
    parameter AUTO_BP_BIT = 8,               // 自动检测坏点地址位宽
    parameter THRESHOLD = 100,               // 盲点检测阈值
    parameter FRAME_HEIGHT = 512,            // 帧高度
    parameter FRAME_WIDTH = 640              // 帧宽度
)(
    // 时钟和复位
    input  wire                     aclk,
    input  wire                     aresetn,
    
    // 输入像素流
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire [WIDTH-1:0]         s_axis_tdata,
    input  wire                     s_axis_tuser,    // SOF
    input  wire                     s_axis_tlast,    // EOL
    
    // k值输入流 (与像素流对齐)
    input  wire                     k_axis_tvalid,
    input  wire [K_WIDTH-1:0]       k_axis_tdata,
    
    // 输出像素流 (透传，不做修改)
    input  wire                     m_axis_tready,
    output wire                     m_axis_tvalid,
    output wire [WIDTH-1:0]         m_axis_tdata,
    output wire                     m_axis_tuser,
    output wire                     m_axis_tlast,
    
    // 配置接口
    input  wire                     enable,          // 模块使能
    input  wire [K_WIDTH-1:0]       k_threshold,     // k值偏差阈值
    
    // 手动坏点表接口
    input  wire                     S_AXI_ACLK,
    input  wire [MANUAL_BP_BIT-1:0] manual_bp_num,
    input  wire                     manual_wen,
    input  wire [MANUAL_BP_BIT-1:0] manual_waddr,
    input  wire [31:0]              manual_wdata,
    
    // 自动检测坏点输出接口
    output reg                      auto_bp_valid,    // 检测到坏点时有效
    output reg [CNT_WIDTH-1:0]      auto_bp_x,        // 坏点X坐标
    output reg [CNT_WIDTH-1:0]      auto_bp_y,        // 坏点Y坐标
    output reg                      auto_bp_type,     // 坏点类型：0=死点，1=盲元
    input  wire                     auto_bp_ready,    // 上位机准备接收
    
    // 检测状态
    output wire                     frame_detection_done,  // 帧检测完成
    output wire [AUTO_BP_BIT-1:0]   detected_bp_count,     // 当前帧检测到的坏点数量
    
    // 调试输出
    output wire                     debug_manual_skip,     // 跳过手动坏点
    output wire                     debug_dead_pixel,      // 检测到死点
    output wire                     debug_stuck_pixel      // 检测到盲点
);

    // 内部信号定义
    wire data_valid = s_axis_tvalid & s_axis_tready & k_axis_tvalid;
    wire [CNT_WIDTH-1:0] frame_height = FRAME_HEIGHT; 
    // 坐标计数器
    reg [CNT_WIDTH-1:0] x_cnt, y_cnt;
    reg frame_start_pulse, frame_end_pulse;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            x_cnt <= 0;
            y_cnt <= 0;
            frame_start_pulse <= 0;
            frame_end_pulse <= 0;
        end
        else if (data_valid) begin
            frame_start_pulse <= s_axis_tuser & ~frame_start_pulse;
            
            if (s_axis_tlast) begin
                x_cnt <= 0;
                y_cnt <= y_cnt + 1;
                frame_end_pulse <= (y_cnt == frame_height - 1);
            end
            else begin
                x_cnt <= x_cnt + 1;
                frame_end_pulse <= 0;
            end
        end
        else begin
            frame_start_pulse <= 0;
        end
    end

    // ================================================================
    // 手动坏点检测模块
    // ================================================================
    
    wire manual_bp_match;
    wire [CNT_WIDTH-1:0] manual_bp_x, manual_bp_y;
    
    Manual_BadPixel_Checker #(
        .WIDTH_BITS(CNT_WIDTH),
        .HEIGHT_BITS(CNT_WIDTH),
        .BAD_POINT_NUM(MANUAL_BP_NUM),
        .BAD_POINT_BIT(MANUAL_BP_BIT)
    ) manual_checker (
        .clk(aclk),
        .rst_n(aresetn),
        .S_AXI_ACLK(S_AXI_ACLK),
        
        // 当前处理位置
        .current_x(x_cnt),
        .current_y(y_cnt),
        .frame_start(frame_start_pulse),
        
        // 手动坏点表配置
        .bad_point_num(manual_bp_num),
        .wen_lut(manual_wen),
        .waddr_lut(manual_waddr),
        .wdata_lut(manual_wdata),
        
        // 输出
        .bad_pixel_match(manual_bp_match),
        .next_bad_x(manual_bp_x),
        .next_bad_y(manual_bp_y)
    );

    // ================================================================
    // k值窗口缓存 (3x3)
    // ================================================================
    
    reg [K_WIDTH-1:0] k_line_buffer1;
    reg [K_WIDTH-1:0] k_line_buffer2;

    reg [K_WIDTH-1:0] k_line_buffer1_r [0:2];
    reg [K_WIDTH-1:0] k_line_buffer2_r [0:2];
    reg [K_WIDTH-1:0] k_axis_tdata_r [0:2];

    // 3x3 k值窗口
    reg [K_WIDTH-1:0] k11, k12, k13;
    reg [K_WIDTH-1:0] k21, k22, k23;
    reg [K_WIDTH-1:0] k31, k32, k33;

    reg [K_WIDTH-1:0] k11_r, k12_r, k13_r;
    reg [K_WIDTH-1:0] k21_r, k22_r, k23_r;
    reg [K_WIDTH-1:0] k31_r, k32_r, k33_r;

    always @(posedge aclk) begin
        k_line_buffer1_r[2] <= k_line_buffer1;
        k_line_buffer1_r[1] <= k_line_buffer1_r[2];
        k_line_buffer1_r[0] <= k_line_buffer1_r[1];

        k_line_buffer2_r[2] <= k_line_buffer2;
        k_line_buffer2_r[1] <= k_line_buffer2_r[2];
        k_line_buffer2_r[0] <= k_line_buffer2_r[1];

        k_axis_tdata_r[2] <= k_axis_tdata;
        k_axis_tdata_r[1] <= k_axis_tdata_r[2];
        k_axis_tdata_r[0] <= k_axis_tdata_r[1];
    end

    LineBuf_dpc #(
        .WIDTH   	(K_WIDTH   ),
        .LATENCY 	(FRAME_WIDTH  ))
    u_LineBuf_k_1(
        .reset    	(aresetn     ),
        .clk      	(aclk       ),
        .in_valid 	(k_axis_tvalid  ),
        .data_in  	(k_axis_tdata   ),
        .data_out 	(k_line_buffer1  )
    );
    
    LineBuf_dpc #(
        .WIDTH   	(K_WIDTH   ),
        .LATENCY 	(FRAME_WIDTH  ))
    u_LineBuf_dpc(
        .reset    	(aresetn     ),
        .clk      	(aclk       ),
        .in_valid 	(k_axis_tvalid  ),
        .data_in  	(k_line_buffer1   ),
        .data_out 	(k_line_buffer2  )
    );

    wire is_first_row, is_last_row, is_first_col, is_last_col;
    wire is_sec_row, is_last_sec_row, is_sec_col, is_last_sec_col;
    reg is_sec_row_r, is_last_sec_row_r;

    assign is_first_row = (y_cnt == 0);
    assign is_last_row = (y_cnt == FRAME_HEIGHT - 1);
    assign is_first_col = (x_cnt == 0);
    assign is_last_col = (x_cnt == FRAME_WIDTH - 1);

    assign is_sec_row = (y_cnt == 1);
    assign is_last_sec_row = (y_cnt == FRAME_HEIGHT - 2);
    assign is_sec_col = (x_cnt == 1);
    assign is_last_sec_col = (x_cnt == FRAME_WIDTH - 2);

    // 窗口移位逻辑: LATENCY_PADDING = 2
    always @(posedge aclk) begin
        // step 1
        k11_r <= (is_sec_col) ? k_line_buffer2_r[1] : k_line_buffer2_r[0];
        k21_r <= (is_sec_col) ? k_line_buffer1_r[1] : k_line_buffer1_r[0];
        k31_r <= (is_sec_col) ? k_axis_tdata_r[1] : k_axis_tdata_r[0];

        k12_r <= k_line_buffer2_r[1];
        k22_r <= k_line_buffer1_r[1];
        k32_r <= k_axis_tdata_r[1];

        k13_r <= (is_last_sec_col) ? k_line_buffer2_r[1] : k_line_buffer2_r[2];
        k23_r <= (is_last_sec_col) ? k_line_buffer1_r[1] : k_line_buffer1_r[2];
        k33_r <= (is_last_sec_col) ? k_axis_tdata_r[1] : k_axis_tdata_r[2];
        // step 2
        k11 <= (is_sec_row_r) ? k21_r : k11_r;
        k12 <= (is_sec_row_r) ? k22_r : k12_r;
        k13 <= (is_sec_row_r) ? k23_r : k13_r;

        k21 <= k21_r;
        k22 <= k22_r;
        k23 <= k23_r;

        k31 <= (is_last_sec_row_r) ? k21_r : k31_r;
        k32 <= (is_last_sec_row_r) ? k22_r : k32_r;
        k33 <= (is_last_sec_row_r) ? k23_r : k33_r;
    
        is_sec_row_r <= is_sec_row;
        is_last_sec_row_r <= is_last_sec_row;
    end

    // ================================================================
    // 坏点检测逻辑 (流水线第3级开始)
    // ================================================================
    
    // 流水线第3级：死点检测
    reg t3_data_valid;
    reg [CNT_WIDTH-1:0] t3_x_cnt, t3_y_cnt;
    reg [K_WIDTH-1:0] t3_k_center;
    reg [K_WIDTH-1:0] t3_k11, t3_k12, t3_k13;
    reg [K_WIDTH-1:0] t3_k21, t3_k23;
    reg [K_WIDTH-1:0] t3_k31, t3_k32, t3_k33;
    reg t3_manual_skip;
    reg t3_dead_pixel;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t3_data_valid <= 0;
            t3_x_cnt <= 0;
            t3_y_cnt <= 0;
            t3_k_center <= 0;
            t3_k11 <= 0; t3_k12 <= 0; t3_k13 <= 0;
            t3_k21 <= 0; t3_k23 <= 0;
            t3_k31 <= 0; t3_k32 <= 0; t3_k33 <= 0;
            t3_manual_skip <= 0;
            t3_dead_pixel <= 0;
        end
        else begin
            t3_data_valid <= data_valid;
            t3_x_cnt <= x_cnt - 1;  // 考虑窗口延迟
            t3_y_cnt <= y_cnt;
            t3_k_center <= k22;
            t3_k11 <= k11; t3_k12 <= k12; t3_k13 <= k13;
            t3_k21 <= k21; t3_k23 <= k23;
            t3_k31 <= k31; t3_k32 <= k32; t3_k33 <= k33;
            
            // 检查是否需要跳过(手动坏点)
            t3_manual_skip <= manual_bp_match;
            
            // 死点检测：k=0
            t3_dead_pixel <= (k22 == 0) && !manual_bp_match && enable;
        end
    end

    // 流水线第4级：盲点检测 - 计算邻域k值中值
    reg t4_data_valid;
    reg [CNT_WIDTH-1:0] t4_x_cnt, t4_y_cnt;
    reg [K_WIDTH-1:0] t4_k_center;
    reg t4_manual_skip;
    reg t4_dead_pixel;
    reg t4_stuck_pixel;
    reg [K_WIDTH-1:0] t4_k_median;
    
    // k值排序网络 (简化版本，只用于3x3窗口8个邻域值)
    wire [K_WIDTH-1:0] k_neighbors [7:0];
    assign k_neighbors[0] = (t3_k11 == 0 || (t3_manual_skip && (t3_x_cnt-1 == manual_bp_x) && (t3_y_cnt-1 == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k11;
    assign k_neighbors[1] = (t3_k12 == 0 || (t3_manual_skip && (t3_x_cnt == manual_bp_x) && (t3_y_cnt-1 == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k12;
    assign k_neighbors[2] = (t3_k13 == 0 || (t3_manual_skip && (t3_x_cnt+1 == manual_bp_x) && (t3_y_cnt-1 == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k13;
    assign k_neighbors[3] = (t3_k21 == 0 || (t3_manual_skip && (t3_x_cnt-1 == manual_bp_x) && (t3_y_cnt == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k21;
    assign k_neighbors[4] = (t3_k23 == 0 || (t3_manual_skip && (t3_x_cnt+1 == manual_bp_x) && (t3_y_cnt == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k23;
    assign k_neighbors[5] = (t3_k31 == 0 || (t3_manual_skip && (t3_x_cnt-1 == manual_bp_x) && (t3_y_cnt+1 == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k31;
    assign k_neighbors[6] = (t3_k32 == 0 || (t3_manual_skip && (t3_x_cnt == manual_bp_x) && (t3_y_cnt+1 == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k32;
    assign k_neighbors[7] = (t3_k33 == 0 || (t3_manual_skip && (t3_x_cnt+1 == manual_bp_x) && (t3_y_cnt+1 == manual_bp_y))) ? {K_WIDTH{1'b1}} : t3_k33;
    
    // 简化的中值计算 (使用平均值替代真正的中值以节省资源)
    wire [K_WIDTH+2:0] k_sum = k_neighbors[0] + k_neighbors[1] + k_neighbors[2] + k_neighbors[3] + 
                               k_neighbors[4] + k_neighbors[5] + k_neighbors[6] + k_neighbors[7];
    wire [K_WIDTH-1:0] k_avg = k_sum >> 3;  // 除以8
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t4_data_valid <= 0;
            t4_x_cnt <= 0;
            t4_y_cnt <= 0;
            t4_k_center <= 0;
            t4_manual_skip <= 0;
            t4_dead_pixel <= 0;
            t4_stuck_pixel <= 0;
            t4_k_median <= 0;
        end
        else begin
            t4_data_valid <= t3_data_valid;
            t4_x_cnt <= t3_x_cnt;
            t4_y_cnt <= t3_y_cnt;
            t4_k_center <= t3_k_center;
            t4_manual_skip <= t3_manual_skip;
            t4_dead_pixel <= t3_dead_pixel;
            t4_k_median <= k_avg;
            
            // 盲点检测：k值与邻域中值差异大于阈值
            if (t3_k_center != 0 && !t3_manual_skip && !t3_dead_pixel && enable) begin
                t4_stuck_pixel <= (t3_k_center > k_avg) ? 
                                  (t3_k_center - k_avg > k_threshold) : 
                                  (k_avg - t3_k_center > k_threshold);
            end else begin
                t4_stuck_pixel <= 0;
            end
        end
    end

    // ================================================================
    // 坏点输出逻辑
    // ================================================================
    
    // 检测到的坏点计数器
    reg [AUTO_BP_BIT:0] bp_count;
    reg frame_done_r;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            auto_bp_valid <= 0;
            auto_bp_x <= 0;
            auto_bp_y <= 0;
            auto_bp_type <= 0;
            bp_count <= 0;
            frame_done_r <= 0;
        end
        else begin
            frame_done_r <= frame_end_pulse;
            
            if (frame_start_pulse) begin
                bp_count <= 0;
            end
            
            // 输出检测到的坏点
            if (t4_data_valid && (t4_dead_pixel || t4_stuck_pixel) && auto_bp_ready) begin
                auto_bp_valid <= 1;
                auto_bp_x <= t4_x_cnt;
                auto_bp_y <= t4_y_cnt;
                auto_bp_type <= t4_stuck_pixel;  // 0=死点, 1=盲点
                bp_count <= bp_count + 1;
            end
            else if (auto_bp_ready) begin
                auto_bp_valid <= 0;
            end
        end
    end

    // ================================================================
    // 透传输出
    // ================================================================
    
    // 数据透传，不做修改
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tlast = s_axis_tlast;
    
    // 状态输出
    assign frame_detection_done = frame_done_r;
    assign detected_bp_count = bp_count;
    
    // 调试输出
    assign debug_manual_skip = t4_manual_skip;
    assign debug_dead_pixel = t4_dead_pixel;
    assign debug_stuck_pixel = t4_stuck_pixel;

endmodule