/*
 * DPC检测模块 - 基于k值的自动坏点检测
 * 
 * 功能：
 * 1. 基于k值检测坏点（k=0为死点，k值偏差大的为盲点）
 * 2. 跳过手动坏点列表中的像素
 * 3. 将检测到的坏点坐标输出给上位机
 * 4. 不进行校正，只做检测

 * > 输出的k是窗口的中心，而不是右下角
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
    
    // 输出k值流 (带坏点标志位)
    output wire                     k_out_tvalid,
    output wire [K_WIDTH-1:0]       k_out_tdata,    // 最高位为坏点标志，低位为k值
    
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
    output wire                     auto_bp_valid,    // 检测到坏点时有效
    output reg [CNT_WIDTH-1:0]      auto_bp_x,        // 坏点X坐标
    output reg [CNT_WIDTH-1:0]      auto_bp_y,        // 坏点Y坐标
    
    // 检测状态
    output wire                     frame_detection_done,  // 帧检测完成
    output wire [AUTO_BP_BIT-1:0]   detected_bp_count     // 当前帧检测到的坏点数量
);
    localparam LATENCY_CENTER = FRAME_WIDTH + 1; // 从右下角到中心
    localparam LATENCY_PADDING = 2; // padding带来的延时
    localparam LATENCY_MEDIAN = 3; // 中值延时
    localparam LATENCY_K_VLD = 1; // 得到有效k数组的延时
    localparam LATENCY_TOTAL = LATENCY_CENTER + LATENCY_PADDING + LATENCY_MEDIAN + LATENCY_K_VLD;

    // 内部信号定义
    wire data_valid = s_axis_tvalid & s_axis_tready & k_axis_tvalid;
    wire [CNT_WIDTH-1:0] frame_height = FRAME_HEIGHT;
    wire [CNT_WIDTH-1:0] frame_width = FRAME_WIDTH;
    
    // 输入k值没有标志位，在处理过程中添加标志位
    wire [K_WIDTH-1:0] k_value_in = k_axis_tdata;  // 输入的完整k值
    
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
    // k值窗口缓存 (3x3):LATENCY=FRAME_WIDTH*2+2
    // 扩展k值位宽，加入手动坏点标志位
    // ================================================================
    
    // 为k值添加手动坏点标志位
    wire [K_WIDTH:0] k_with_manual_flag;  // 扩展1位用于标志位
    assign k_with_manual_flag = {manual_bp_match|(k_axis_tdata == 'd0), k_axis_tdata}; // 手动要和输入的坐标对齐，以及加入DP检测
    
    reg [K_WIDTH:0] k_line_buffer1;
    reg [K_WIDTH:0] k_line_buffer2;

    reg [K_WIDTH:0] k_line_buffer1_r [0:2];
    reg [K_WIDTH:0] k_line_buffer2_r [0:2];
    reg [K_WIDTH:0] k_axis_tdata_r [0:2];

    // 3x3 k值窗口
    reg [K_WIDTH:0] k11, k12, k13;
    reg [K_WIDTH:0] k21, k22, k23;
    reg [K_WIDTH:0] k31, k32, k33;

    reg [K_WIDTH:0] k11_r, k12_r, k13_r;
    reg [K_WIDTH:0] k21_r, k22_r, k23_r;
    reg [K_WIDTH:0] k31_r, k32_r, k33_r;

    always @(posedge aclk) begin
        k_line_buffer1_r[2] <= k_line_buffer1;
        k_line_buffer1_r[1] <= k_line_buffer1_r[2];
        k_line_buffer1_r[0] <= k_line_buffer1_r[1];

        k_line_buffer2_r[2] <= k_line_buffer2;
        k_line_buffer2_r[1] <= k_line_buffer2_r[2];
        k_line_buffer2_r[0] <= k_line_buffer2_r[1];

        k_axis_tdata_r[2] <= k_with_manual_flag;
        k_axis_tdata_r[1] <= k_axis_tdata_r[2];
        k_axis_tdata_r[0] <= k_axis_tdata_r[1];
    end

    LineBuf_dpc #(
        .WIDTH   	(K_WIDTH+1   ),  // 增加1位用于标志位
        .LATENCY 	(FRAME_WIDTH  ))
    u_LineBuf_k_1(
        .reset    	(aresetn     ),
        .clk      	(aclk       ),
        .in_valid 	(k_axis_tvalid  ),
        .data_in  	(k_with_manual_flag   ),
        .data_out 	(k_line_buffer1  )
    );
    
    LineBuf_dpc #(
        .WIDTH   	(K_WIDTH+1   ),  // 增加1位用于标志位
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
    // 盲点检测逻辑 (流水线第3级开始)
    // ================================================================

    // 流水线第3级：计算邻域k值中值
    // k值排序网络
    wire [K_WIDTH:0] k_neighbors [0:7];
    assign k_neighbors[0] = k11;
    assign k_neighbors[1] = k12;
    assign k_neighbors[2] = k13;
    assign k_neighbors[3] = k21;
    assign k_neighbors[4] = k23;
    assign k_neighbors[5] = k31;
    assign k_neighbors[6] = k32;
    assign k_neighbors[7] = k33;


    reg [K_WIDTH-1:0] k_neighbors_vld [0:7];
    integer k_vld_cnt;

    always @(posedge aclk) begin
        if (!aresetn) begin
            k_vld_cnt = 0;
            for (integer idx = 0; idx < 8; idx = idx + 1) begin
                k_neighbors_vld[idx] <= 0;
            end
        end
        else begin
            k_vld_cnt = 0;
            for (integer i = 0; i<8; i = i + 1) begin
                // 有效k值赋值，LATENCY_K_VLD = 1
                if (!k_neighbors[i][K_WIDTH]) begin
                    k_neighbors_vld[k_vld_cnt] <= k_neighbors[i][K_WIDTH-1:0];
                    k_vld_cnt = k_vld_cnt + 1;
                end
            end
        end
    end

    // 快速中值计算模块实例化
    wire median_valid;
    wire [K_WIDTH-1:0] k_median;
    wire [K_WIDTH-1:0] k_center;
    // LATENCY_MEDIAN = 3
    Fast_Median_Calculator #(
        .DATA_WIDTH(K_WIDTH),
        .MAX_COUNT(8)
    ) u_median_calc (
        .clk(aclk),
        .rst_n(aresetn),
        .valid_in(data_valid),
        .data_array(k_neighbors_vld),
        .valid_count(k_vld_cnt),
        .valid_out(median_valid),
        .median_out(k_median),
        .center_out(k_center)
    );


    // ================================================================
    // 坏点输出逻辑
    // ================================================================
    
    // 检测到的坏点计数器
    reg [AUTO_BP_BIT:0] bp_count;
    wire frame_done_r;
    
    reg [3:0] delay_total_cnt = 0;
    wire delayed;

    assign delayed = (delay_total_cnt >= LATENCY_TOTAL);
    assign auto_bp_valid = k22[K_WIDTH] | (k_center > k_median + K_THRESHOLD) | (k_center < k_median - K_THRESHOLD);
    assign frame_done_r = (auto_bp_x == frame_width - 1) && (auto_bp_y == frame_height - 1);
    always @(posedge aclk) begin
        if (!aresetn) begin
            auto_bp_x <= 0;
            auto_bp_y <= 0;
            bp_count <= 0;
        end
        else begin
            delay_total_cnt <= delay_total_cnt + 1;
            if (delayed) begin
                if (auto_bp_y == frame_height - 1)begin
                    auto_bp_x <= 0;
                    auto_bp_y <= auto_bp_y + 1;
                end
                else begin
                    auto_bp_x <= auto_bp_x + 1;
                end
                if (auto_bp_valid) begin
                    bp_count <= bp_count + 1;
                end
            end
        end
    end


    // ================================================================
    // 透传输出
    // ================================================================
    
    // 数据透传，不做修改
    // 这里肯定不对，需要做latency的
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tlast = s_axis_tlast;
    
    assign k_out_tvalid = median_valid;
    assign k_out_tdata = {auto_bp_valid, k_center};
    // 状态输出
    assign frame_detection_done = frame_done_r;
    assign detected_bp_count = bp_count;

endmodule