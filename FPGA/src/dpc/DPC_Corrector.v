/*
 * DPC校正模块 - 基于坏点列表的像素校正
 * 
 * 功能：
 * 1. 接收上位机提供的合并坏点列表（手动+自动）
 * 2. 对坏点位置进行3×3邻域非坏点均值校正
 * 3. 正常像素透传
 */

module DPC_Corrector #(
    parameter WIDTH = 16,                    // 像素数据位宽
    parameter CNT_WIDTH = 10,                // 坐标计数器位宽
    parameter ALL_BP_NUM = 512,              // 总坏点最大数量(手动+自动)
    parameter ALL_BP_BIT = 9,                // 总坏点地址位宽
    parameter LATENCY = 5                    // 流水线延迟
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
    
    // 输出像素流
    input  wire                     m_axis_tready,
    output wire                     m_axis_tvalid,
    output wire [WIDTH-1:0]         m_axis_tdata,
    output wire                     m_axis_tuser,
    output wire                     m_axis_tlast,
    
    // 配置接口
    input  wire                     enable,          // 模块使能
    input  wire [CNT_WIDTH-1:0]     frame_width,     // 帧宽度
    input  wire [CNT_WIDTH-1:0]     frame_height,    // 帧高度
    
    // 坏点列表接口
    input  wire                     S_AXI_ACLK,
    input  wire [ALL_BP_BIT:0]      all_bp_num,      // 总坏点数量
    input  wire                     all_bp_wen,      // 坏点表写使能
    input  wire [ALL_BP_BIT-1:0]    all_bp_waddr,    // 坏点表写地址
    input  wire [31:0]              all_bp_wdata,    // 坏点表写数据
    input  wire                     bp_table_ready,  // 坏点表准备完成
    
    // 调试输出
    output wire                     debug_bp_corrected,  // 坏点被校正
    output wire [WIDTH-1:0]         debug_original_pixel, // 原始像素值
    output wire [WIDTH-1:0]         debug_corrected_pixel // 校正后像素值
);

    // 内部信号定义
    wire data_valid = s_axis_tvalid & s_axis_tready;
    
    // 坐标计数器
    reg [CNT_WIDTH-1:0] x_cnt, y_cnt;
    reg frame_start_pulse;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            x_cnt <= 0;
            y_cnt <= 0;
            frame_start_pulse <= 0;
        end
        else if (data_valid) begin
            frame_start_pulse <= s_axis_tuser & ~frame_start_pulse;
            
            if (s_axis_tlast) begin
                x_cnt <= 0;
                if (s_axis_tuser) begin
                    y_cnt <= 0;
                end else begin
                    y_cnt <= y_cnt + 1;
                end
            end
            else begin
                x_cnt <= x_cnt + 1;
            end
        end
        else begin
            frame_start_pulse <= 0;
        end
    end

    // ================================================================
    // 第一级：3×3窗口生成
    // ================================================================
    
    // Line Buffer for 3x3 window
    reg [WIDTH-1:0] line_buffer1 [0:1023];
    reg [WIDTH-1:0] line_buffer2 [0:1023];
    
    // 3x3窗口寄存器
    reg [WIDTH-1:0] w11, w12, w13;
    reg [WIDTH-1:0] w21, w22, w23;
    reg [WIDTH-1:0] w31, w32, w33;
    
    // 窗口移位逻辑
    always @(posedge aclk) begin
        if (data_valid) begin
            // 像素数据窗口更新
            w11 <= line_buffer2[x_cnt];
            w12 <= line_buffer1[x_cnt];
            w13 <= s_axis_tdata;
            
            w21 <= line_buffer2[x_cnt+1];
            w22 <= line_buffer1[x_cnt+1];
            w23 <= w13;
            
            w31 <= line_buffer2[x_cnt+2];
            w32 <= line_buffer1[x_cnt+2];
            w33 <= w23;
            
            // Line buffer更新
            line_buffer2[x_cnt] <= line_buffer1[x_cnt];
            line_buffer1[x_cnt] <= s_axis_tdata;
        end
    end

    // ================================================================
    // 第二级：坏点检测
    // ================================================================
    
    wire bp_match;
    wire [CNT_WIDTH-1:0] bp_x, bp_y;
    
    BadPixel_Lookup #(
        .WIDTH_BITS(CNT_WIDTH),
        .HEIGHT_BITS(CNT_WIDTH),
        .BAD_POINT_NUM(ALL_BP_NUM),
        .BAD_POINT_BIT(ALL_BP_BIT)
    ) bp_lookup (
        .clk(aclk),
        .rst_n(aresetn),
        .S_AXI_ACLK(S_AXI_ACLK),
        
        // 当前处理位置 (考虑流水线延迟)
        .current_x(x_cnt - 1),
        .current_y(y_cnt),
        .frame_start(frame_start_pulse),
        
        // 坏点表配置
        .bad_point_num(all_bp_num),
        .wen_lut(all_bp_wen),
        .waddr_lut(all_bp_waddr),
        .wdata_lut(all_bp_wdata),
        .table_ready(bp_table_ready),
        
        // 输出
        .bad_pixel_match(bp_match),
        .next_bad_x(bp_x),
        .next_bad_y(bp_y)
    );

    // ================================================================
    // 第三级：坏点标记传递
    // ================================================================
    
    reg t3_data_valid;
    reg t3_bp_match;
    reg [WIDTH-1:0] t3_center;
    reg [WIDTH-1:0] t3_w11, t3_w12, t3_w13;
    reg [WIDTH-1:0] t3_w21, t3_w23;
    reg [WIDTH-1:0] t3_w31, t3_w32, t3_w33;
    reg [CNT_WIDTH-1:0] t3_x_cnt, t3_y_cnt;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t3_data_valid <= 0;
            t3_bp_match <= 0;
            t3_center <= 0;
            t3_w11 <= 0; t3_w12 <= 0; t3_w13 <= 0;
            t3_w21 <= 0; t3_w23 <= 0;
            t3_w31 <= 0; t3_w32 <= 0; t3_w33 <= 0;
            t3_x_cnt <= 0;
            t3_y_cnt <= 0;
        end
        else if (data_valid) begin
            t3_data_valid <= 1;
            t3_bp_match <= bp_match;
            t3_center <= w22;
            t3_w11 <= w11; t3_w12 <= w12; t3_w13 <= w13;
            t3_w21 <= w21; t3_w23 <= w23;
            t3_w31 <= w31; t3_w32 <= w32; t3_w33 <= w33;
            t3_x_cnt <= x_cnt - 1;
            t3_y_cnt <= y_cnt;
        end
        else begin
            t3_data_valid <= 0;
        end
    end

    // ================================================================
    // 第四级：邻域坏点检查和计数
    // ================================================================
    
    reg t4_data_valid;
    reg t4_bp_match;
    reg [WIDTH-1:0] t4_center;
    reg [3:0] t4_valid_neighbor_count;
    reg [WIDTH+3-1:0] t4_neighbor_sum;
    
    // 检查邻域8个像素是否为坏点（简化处理：假设邻域不是坏点）
    wire [7:0] neighbor_pixels [7:0];
    assign neighbor_pixels[0] = t3_w11;
    assign neighbor_pixels[1] = t3_w12;
    assign neighbor_pixels[2] = t3_w13;
    assign neighbor_pixels[3] = t3_w21;
    assign neighbor_pixels[4] = t3_w23;
    assign neighbor_pixels[5] = t3_w31;
    assign neighbor_pixels[6] = t3_w32;
    assign neighbor_pixels[7] = t3_w33;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t4_data_valid <= 0;
            t4_bp_match <= 0;
            t4_center <= 0;
            t4_valid_neighbor_count <= 0;
            t4_neighbor_sum <= 0;
        end
        else begin
            t4_data_valid <= t3_data_valid;
            t4_bp_match <= t3_bp_match;
            t4_center <= t3_center;
            
            // 简化处理：假设所有邻域都有效（实际应用中可以查表判断）
            t4_valid_neighbor_count <= 8;
            t4_neighbor_sum <= neighbor_pixels[0] + neighbor_pixels[1] + neighbor_pixels[2] + neighbor_pixels[3] +
                              neighbor_pixels[4] + neighbor_pixels[5] + neighbor_pixels[6] + neighbor_pixels[7];
        end
    end

    // ================================================================
    // 第五级：校正值计算和输出选择
    // ================================================================
    
    reg t5_data_valid;
    reg t5_bp_corrected;
    reg [WIDTH-1:0] t5_output_pixel;
    reg [WIDTH-1:0] t5_original_pixel;
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            t5_data_valid <= 0;
            t5_bp_corrected <= 0;
            t5_output_pixel <= 0;
            t5_original_pixel <= 0;
        end
        else begin
            t5_data_valid <= t4_data_valid;
            t5_bp_corrected <= t4_bp_match && enable;
            t5_original_pixel <= t4_center;
            
            // 校正值选择
            if (t4_bp_match && enable && t4_valid_neighbor_count > 0) begin
                // 坏点用邻域均值
                t5_output_pixel <= t4_neighbor_sum / t4_valid_neighbor_count;
            end
            else begin
                // 正常像素保持原值
                t5_output_pixel <= t4_center;
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
    assign m_axis_tdata = t5_output_pixel;
    assign m_axis_tuser = user_delay[LATENCY-1];
    assign m_axis_tlast = last_delay[LATENCY-1];
    
    // 调试输出
    assign debug_bp_corrected = t5_bp_corrected;
    assign debug_original_pixel = t5_original_pixel;
    assign debug_corrected_pixel = t5_output_pixel;

endmodule


// ================================================================
// 坏点查找模块
// ================================================================
module BadPixel_Lookup #(
    parameter WIDTH_BITS = 10,
    parameter HEIGHT_BITS = 10,
    parameter BAD_POINT_NUM = 512,
    parameter BAD_POINT_BIT = 9
)(
    input clk,
    input rst_n,
    input S_AXI_ACLK,
    
    // 当前处理位置
    input [WIDTH_BITS-1:0] current_x,
    input [HEIGHT_BITS-1:0] current_y,
    input frame_start,
    
    // 坏点表配置
    input [BAD_POINT_BIT:0] bad_point_num,
    input wen_lut,
    input [BAD_POINT_BIT-1:0] waddr_lut,
    input [31:0] wdata_lut,
    input table_ready,
    
    // 输出
    output bad_pixel_match,
    output [WIDTH_BITS-1:0] next_bad_x,
    output [HEIGHT_BITS-1:0] next_bad_y
);

    // 读地址和控制
    reg [BAD_POINT_BIT-1:0] raddr;
    reg re;
    reg re_frame_start;
    reg table_ready_r;
    wire [31:0] rdata;
    wire [WIDTH_BITS-1:0] bad_x = rdata[31:16];
    wire [HEIGHT_BITS-1:0] bad_y = rdata[15:0];
    
    // 表准备状态同步
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            table_ready_r <= 0;
        end
        else begin
            table_ready_r <= table_ready;
        end
    end
    
    // 读取控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raddr <= 0;
            re_frame_start <= 1;
            re <= 0;
        end
        else if (table_ready_r) begin
            re_frame_start <= frame_start;
            
            if (frame_start && !re_frame_start) begin
                // 帧开始，重置读地址
                raddr <= 0;
                re <= (bad_point_num > 0) ? 1 : 0;
            end
            else if (bad_pixel_match && raddr < bad_point_num - 1) begin
                // 匹配到坏点，读取下一个
                raddr <= raddr + 1;
                re <= 1;
            end
            else begin
                re <= 0;
            end
        end
        else begin
            re <= 0;
        end
    end
    
    // 坏点匹配判断
    assign bad_pixel_match = (current_x == bad_x) && (current_y == bad_y) && 
                            (raddr < bad_point_num) && table_ready_r;
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
