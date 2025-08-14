/*
 * DPC校正模块 - 基于k值标志的像素校正
 * 
 * 功能：
 * 1. 接收检测器输出的带坏点标志的k值流
 * 2. 对坏点位置进行3×3邻域非坏点均值校正
 * 3. 正常像素透传
 */

module DPC_Corrector #(
    parameter WIDTH = 16,                    // 像素数据位宽
    parameter K_WIDTH = 16,                  // k值位宽
    parameter CNT_WIDTH = 10,                // 坐标计数器位宽
    parameter FRAME_HEIGHT = 512,            // 帧高度
    parameter FRAME_WIDTH = 640,             // 帧宽度
    parameter LATENCY = 5                    // 流水线延迟级数
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
    
    // k值输入流（带坏点标志位）
    input  wire                     k_axis_tvalid,
    input  wire [K_WIDTH-1:0]       k_axis_tdata,    // MSB为坏点标志
    
    // 输出像素流
    input  wire                     m_axis_tready,
    output wire                     m_axis_tvalid,
    output wire [WIDTH-1:0]         m_axis_tdata,
    output wire                     m_axis_tuser,
    output wire                     m_axis_tlast,
    
    // 配置接口
    input  wire                     enable,          // 模块使能
    
    // 调试输出
    output wire                     debug_bp_corrected,  // 坏点被校正
    output wire [WIDTH-1:0]         debug_original_pixel, // 原始像素值
    output wire [WIDTH-1:0]         debug_corrected_pixel // 校正后像素值
);

    // 内部信号定义
    wire data_valid = s_axis_tvalid & s_axis_tready & k_axis_tvalid;
    
    // 从k值中提取坏点标志
    wire is_bad_pixel = k_axis_tdata[K_WIDTH-1];
    
    // 坐标计数器
    reg [CNT_WIDTH-1:0] x_cnt, y_cnt;
    wire frame_start = s_axis_tuser;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            x_cnt <= 0;
            y_cnt <= 0;
        end
        else if (data_valid) begin
            if (frame_start) begin
                x_cnt <= 0;
                y_cnt <= 0;
            end
            else if (s_axis_tlast) begin
                x_cnt <= 0;
                y_cnt <= y_cnt + 1;
            end
            else begin
                x_cnt <= x_cnt + 1;
            end
        end
    end

    // ================================================================
    // 第一级：3×3窗口生成（像素数据和坏点标志）
    // ================================================================
    
    // Line Buffer for 3x3 pixel window
    reg [WIDTH-1:0] pixel_line_buffer1 [0:1023];
    reg [WIDTH-1:0] pixel_line_buffer2 [0:1023];
    
    // Line Buffer for 3x3 bad pixel flag window
    reg bp_flag_line_buffer1 [0:1023];
    reg bp_flag_line_buffer2 [0:1023];
    
    // 3x3像素窗口寄存器
    reg [WIDTH-1:0] w11, w12, w13;
    reg [WIDTH-1:0] w21, w22, w23;
    reg [WIDTH-1:0] w31, w32, w33;
    
    // 3x3坏点标志窗口寄存器
    reg bp11, bp12, bp13;
    reg bp21, bp22, bp23;
    reg bp31, bp32, bp33;
    
    // 窗口移位逻辑
    always @(posedge aclk) begin
        if (data_valid) begin
            // 像素数据窗口更新
            w11 <= pixel_line_buffer2[x_cnt];
            w12 <= pixel_line_buffer1[x_cnt];
            w13 <= s_axis_tdata;
            
            w21 <= pixel_line_buffer2[x_cnt+1];
            w22 <= pixel_line_buffer1[x_cnt+1];
            w23 <= w13;
            
            w31 <= pixel_line_buffer2[x_cnt+2];
            w32 <= pixel_line_buffer1[x_cnt+2];
            w33 <= w23;
            
            // 坏点标志窗口更新
            bp11 <= bp_flag_line_buffer2[x_cnt];
            bp12 <= bp_flag_line_buffer1[x_cnt];
            bp13 <= is_bad_pixel;
            
            bp21 <= bp_flag_line_buffer2[x_cnt+1];
            bp22 <= bp_flag_line_buffer1[x_cnt+1];
            bp23 <= bp13;
            
            bp31 <= bp_flag_line_buffer2[x_cnt+2];
            bp32 <= bp_flag_line_buffer1[x_cnt+2];
            bp33 <= bp23;
            
            // Line buffer更新
            pixel_line_buffer2[x_cnt] <= pixel_line_buffer1[x_cnt];
            pixel_line_buffer1[x_cnt] <= s_axis_tdata;
            
            bp_flag_line_buffer2[x_cnt] <= bp_flag_line_buffer1[x_cnt];
            bp_flag_line_buffer1[x_cnt] <= is_bad_pixel;
        end
    end

    // ================================================================
    // 第二级：延迟一级流水线
    // ================================================================
    
    reg t2_data_valid;
    reg [WIDTH-1:0] t2_w22;
    reg t2_bp22;
    reg [WIDTH-1:0] t2_w11, t2_w12, t2_w13;
    reg [WIDTH-1:0] t2_w21, t2_w23;
    reg [WIDTH-1:0] t2_w31, t2_w32, t2_w33;
    reg t2_bp11, t2_bp12, t2_bp13;
    reg t2_bp21, t2_bp23;
    reg t2_bp31, t2_bp32, t2_bp33;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t2_data_valid <= 0;
            t2_w22 <= 0;
            t2_bp22 <= 0;
            t2_w11 <= 0; t2_w12 <= 0; t2_w13 <= 0;
            t2_w21 <= 0; t2_w23 <= 0;
            t2_w31 <= 0; t2_w32 <= 0; t2_w33 <= 0;
            t2_bp11 <= 0; t2_bp12 <= 0; t2_bp13 <= 0;
            t2_bp21 <= 0; t2_bp23 <= 0;
            t2_bp31 <= 0; t2_bp32 <= 0; t2_bp33 <= 0;
        end
        else begin
            t2_data_valid <= data_valid && (x_cnt >= 2) && (y_cnt >= 2);
            t2_w22 <= w22;
            t2_bp22 <= bp22;
            t2_w11 <= w11; t2_w12 <= w12; t2_w13 <= w13;
            t2_w21 <= w21; t2_w23 <= w23;
            t2_w31 <= w31; t2_w32 <= w32; t2_w33 <= w33;
            t2_bp11 <= bp11; t2_bp12 <= bp12; t2_bp13 <= bp13;
            t2_bp21 <= bp21; t2_bp23 <= bp23;
            t2_bp31 <= bp31; t2_bp32 <= bp32; t2_bp33 <= bp33;
        end
    end

    // ================================================================
    // 第三级：邻域坏点检查和计数
    // ================================================================
    
    reg t3_data_valid;
    reg t3_bp_match;
    reg [WIDTH-1:0] t3_center;
    reg [3:0] t3_valid_neighbor_count;
    reg [WIDTH+3-1:0] t3_neighbor_sum;
    
    // 组合逻辑计算有效邻域像素
    wire [3:0] valid_count;
    wire [WIDTH+3-1:0] neighbor_sum;
    
    assign valid_count = (!t2_bp11) + (!t2_bp12) + (!t2_bp13) + (!t2_bp21) + 
                        (!t2_bp23) + (!t2_bp31) + (!t2_bp32) + (!t2_bp33);
                        
    assign neighbor_sum = ((!t2_bp11) ? t2_w11 : 0) + ((!t2_bp12) ? t2_w12 : 0) + 
                         ((!t2_bp13) ? t2_w13 : 0) + ((!t2_bp21) ? t2_w21 : 0) + 
                         ((!t2_bp23) ? t2_w23 : 0) + ((!t2_bp31) ? t2_w31 : 0) + 
                         ((!t2_bp32) ? t2_w32 : 0) + ((!t2_bp33) ? t2_w33 : 0);
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t3_data_valid <= 0;
            t3_bp_match <= 0;
            t3_center <= 0;
            t3_valid_neighbor_count <= 0;
            t3_neighbor_sum <= 0;
        end
        else begin
            t3_data_valid <= t2_data_valid;
            t3_bp_match <= t2_bp22;
            t3_center <= t2_w22;
            t3_valid_neighbor_count <= valid_count;
            t3_neighbor_sum <= neighbor_sum;
        end
    end

    // ================================================================
    // 第四级：校正值计算和输出选择
    // ================================================================
    
    reg t4_data_valid;
    reg t4_bp_corrected;
    reg [WIDTH-1:0] t4_output_pixel;
    reg [WIDTH-1:0] t4_original_pixel;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t4_data_valid <= 0;
            t4_bp_corrected <= 0;
            t4_output_pixel <= 0;
            t4_original_pixel <= 0;
        end
        else begin
            t4_data_valid <= t3_data_valid;
            t4_bp_corrected <= t3_bp_match && enable;
            t4_original_pixel <= t3_center;
            
            // 校正值选择
            if (t3_bp_match && enable && t3_valid_neighbor_count > 0) begin
                // 坏点用邻域均值
                t4_output_pixel <= t3_neighbor_sum / t3_valid_neighbor_count;
            end
            else begin
                // 正常像素保持原值
                t4_output_pixel <= t3_center;
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
    assign m_axis_tdata = t4_output_pixel;
    assign m_axis_tuser = user_delay[LATENCY-1];
    assign m_axis_tlast = last_delay[LATENCY-1];
    
    // 调试信号
    assign debug_bp_corrected = t4_bp_corrected;
    assign debug_original_pixel = t4_original_pixel;
    assign debug_corrected_pixel = t4_output_pixel;

endmodule
