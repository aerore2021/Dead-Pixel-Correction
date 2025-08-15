/*
 * DPC校正模块 - 基于Detector输出的窗口和标志进行校正
 * 
 * 功能：
 * 1. 接收Detector输出的3x3像素窗口和坏点标志
 * 2. 对坏点位置进行3×3邻域非坏点均值校正
 * 3. 正常像素透传
 */

module DPC_Corrector #(
    parameter WIDTH = 16,                    // 像素数据位宽
    parameter K_WIDTH = 16,                  // k值位宽
    parameter CNT_WIDTH = 10,                // 坐标计数器位宽
    parameter FRAME_HEIGHT = 512,            // 帧高度
    parameter FRAME_WIDTH = 640,             // 帧宽度
    parameter LATENCY = 2                    // 流水线延迟级数
)(
    // 时钟和复位
    input  wire                     aclk,
    input  wire                     aresetn,
    
    // 输入像素流 (来自Detector)
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire [WIDTH-1:0]         s_axis_tdata,    // 中心像素 (w22)
    input  wire                     s_axis_tuser,    // SOF
    input  wire                     s_axis_tlast,    // EOL
    
    // 3x3窗口像素输入 (来自Detector)
    input  wire [WIDTH-1:0]         w11,
    input  wire [WIDTH-1:0]         w12,
    input  wire [WIDTH-1:0]         w13,
    input  wire [WIDTH-1:0]         w21,
    input  wire [WIDTH-1:0]         w23,
    input  wire [WIDTH-1:0]         w31,
    input  wire [WIDTH-1:0]         w32,
    input  wire [WIDTH-1:0]         w33,
    
    // k值输入流（带坏点标志位）
    input  wire                     k_out_tvalid,
    input  wire [K_WIDTH:0]         k_out_tdata,     // MSB为坏点标志
    input  wire                     k11_vld,         // 1表示有效像素，0表示坏点
    input  wire                     k12_vld,
    input  wire                     k13_vld,
    input  wire                     k21_vld,
    input  wire                     k23_vld,
    input  wire                     k31_vld,
    input  wire                     k32_vld,
    input  wire                     k33_vld,
    
    // 输出像素流
    input  wire                     m_axis_tready,
    output wire                     m_axis_tvalid,
    output wire [WIDTH-1:0]         m_axis_tdata,
    output wire                     m_axis_tuser,
    output wire                     m_axis_tlast,
    
    // 配置接口
    input  wire                     enable,          // 模块使能
    
    /* 暂时注释掉坏点表读取功能，但保留接口以备后用
    // 坏点列表接口
    input  wire                     S_AXI_ACLK,
    input  wire [ALL_BP_BIT-1:0]    all_bp_num,
    input  wire                     all_bp_wen,
    input  wire [ALL_BP_BIT-1:0]    all_bp_waddr,
    input  wire [31:0]              all_bp_wdata,
    input  wire                     bp_table_ready,
    */
    
    // 调试输出
    output wire                     debug_bp_corrected,   // 坏点被校正
    output wire [WIDTH-1:0]         debug_original_pixel, // 原始像素值
    output wire [WIDTH-1:0]         debug_corrected_pixel // 校正后像素值
);

    // 内部信号定义
    wire data_valid = s_axis_tvalid & s_axis_tready & k_out_tvalid;
    
    // 从k值中提取中心像素坏点标志
    wire center_is_bad_pixel = k_out_tdata[K_WIDTH];  // MSB为坏点标志

    // ================================================================
    // 第一级：邻域坏点检查和计数
    // ================================================================
    
    reg t1_data_valid;
    reg t1_center_bad;
    reg [WIDTH-1:0] t1_center_pixel;
    reg [3:0] t1_valid_neighbor_count;
    reg [WIDTH+3-1:0] t1_neighbor_sum;
    
    // 组合逻辑计算有效邻域像素 (k_vld=1表示有效像素)
    wire [3:0] valid_count;
    wire [WIDTH+3-1:0] neighbor_sum;
    
    assign valid_count = k11_vld + k12_vld + k13_vld + k21_vld + 
                        k23_vld + k31_vld + k32_vld + k33_vld;
                        
    assign neighbor_sum = (k11_vld ? w11 : 0) + (k12_vld ? w12 : 0) + 
                         (k13_vld ? w13 : 0) + (k21_vld ? w21 : 0) + 
                         (k23_vld ? w23 : 0) + (k31_vld ? w31 : 0) + 
                         (k32_vld ? w32 : 0) + (k33_vld ? w33 : 0);
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            t1_data_valid <= 0;
            t1_center_bad <= 0;
            t1_center_pixel <= 0;
            t1_valid_neighbor_count <= 0;
            t1_neighbor_sum <= 0;
        end
        else begin
            t1_data_valid <= data_valid;
            t1_center_bad <= center_is_bad_pixel;
            t1_center_pixel <= s_axis_tdata;
            t1_valid_neighbor_count <= valid_count;
            t1_neighbor_sum <= neighbor_sum;
        end
    end

    // ================================================================
    // 第二级：校正值计算和输出选择
    // ================================================================
    
    reg t2_data_valid;
    reg t2_bp_corrected;
    reg [WIDTH-1:0] t2_output_pixel;
    reg [WIDTH-1:0] t2_original_pixel;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t2_data_valid <= 0;
            t2_bp_corrected <= 0;
            t2_output_pixel <= 0;
            t2_original_pixel <= 0;
        end
        else begin
            t2_data_valid <= t1_data_valid;
            t2_bp_corrected <= t1_center_bad && enable;
            t2_original_pixel <= t1_center_pixel;
            
            // 校正值选择
            if (t1_center_bad && enable && t1_valid_neighbor_count > 0) begin
                // 坏点用邻域均值校正
                t2_output_pixel <= t1_neighbor_sum / t1_valid_neighbor_count;
            end
            else begin
                // 正常像素保持原值
                t2_output_pixel <= t1_center_pixel;
            end
        end
    end

    // ================================================================
    // 流水线控制信号延迟
    // ================================================================
    
    reg [LATENCY-1:0] valid_delay;
    reg [LATENCY-1:0] user_delay;
    reg [LATENCY-1:0] last_delay;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            valid_delay <= 0;
            user_delay <= 0;
            last_delay <= 0;
        end
        else begin
            // 控制信号延迟链
            valid_delay <= {valid_delay[LATENCY-2:0], data_valid};
            user_delay <= {user_delay[LATENCY-2:0], s_axis_tuser};
            last_delay <= {last_delay[LATENCY-2:0], s_axis_tlast};
        end
    end

    // ================================================================
    // 输出接口
    // ================================================================
    
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = valid_delay[LATENCY-1];
    assign m_axis_tdata = t2_output_pixel;
    assign m_axis_tuser = user_delay[LATENCY-1];
    assign m_axis_tlast = last_delay[LATENCY-1];
    
    // 调试信号
    assign debug_bp_corrected = t2_bp_corrected;
    assign debug_original_pixel = t2_original_pixel;
    assign debug_corrected_pixel = t2_output_pixel;

endmodule
