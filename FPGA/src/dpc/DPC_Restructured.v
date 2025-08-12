/*
 * DPC重构版本 - 基于k值判断的坏点检测和校正
 * 
 * 主要改动：
 * 1. 自动检测改为k值判断 (k=0为坏点)
 * 2. 保留手动坏点列表
 * 3. 输出统一的坏点检测结果
 * 4. 校正使用3×3邻域非坏点均值
 */

module DPC_Restructured #(
    parameter WIDTH = 16,                    // 像素数据位宽
    parameter K_WIDTH = 16,                  // k值位宽
    parameter CNT_WIDTH = 10,                // 坐标计数器位宽
    parameter BAD_POINT_NUM = 128,           // 手动坏点最大数量
    parameter BAD_POINT_BIT = 7,             // 手动坏点地址位宽
    parameter LATENCY = 7,                    // 流水线延迟
    parameter FRAME_WIDTH = 640,              // 帧宽度
    parameter FRAME_HEIGHT = 512              // 帧高度
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

    // 手动坏点表接口
    input  wire                     S_AXI_ACLK,
    input  wire [BAD_POINT_BIT-1:0] bad_point_num,
    input  wire                     wen_lut,
    input  wire [BAD_POINT_BIT-1:0] waddr_lut,
    input  wire [31:0]              wdata_lut,

    // 调试输出
    output wire                     debug_bad_pixel_detected,
    output wire                     debug_manual_bad_pixel,
    output wire                     debug_auto_bad_pixel
  );

  // 内部信号定义
  wire data_valid = s_axis_tvalid & s_axis_tready & k_axis_tvalid;

  // 坐标计数器
  reg [CNT_WIDTH-1:0] x_cnt, y_cnt;
  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn)
    begin
      x_cnt <= 0;
      y_cnt <= 0;
    end
    else if (data_valid)
    begin
      if (s_axis_tlast)
      begin
        x_cnt <= 0;
        y_cnt <= (s_axis_tuser) ? 0 : y_cnt + 1;
      end
      else
      begin
        x_cnt <= x_cnt + 1;
      end
    end
  end

  // ================================================================
  // 第一级：3×3窗口生成 + k值缓存
  // ================================================================

  // Line Buffer for 3x3 window
  reg [WIDTH-1:0] line_buffer1;
  reg [WIDTH-1:0] line_buffer2;
  reg [K_WIDTH-1:0] k_line_buffer1;
  reg [K_WIDTH-1:0] k_line_buffer2;

  LineBuf #(
            .WIDTH  (K_WIDTH),
            .LATENCY(FRAME_WIDTH)
          ) k_buffer_1 (
            .reset   (~aresetn),
            .clk     (aclk),
            .in_valid(data_valid),
            .data_in (k_axis_tdata),
            .data_out(k_line_buffer1)
          );
  LineBuf #(
            .WIDTH  (K_WIDTH),
            .LATENCY(FRAME_WIDTH)
          ) k_buffer2 (
            .reset   (~aresetn),
            .clk     (aclk),
            .in_valid(data_valid),
            .data_in (k_line_buffer1),
            .data_out(k_line_buffer2)
          );
  LineBuf #(
            .WIDTH  (WIDTH),
            .LATENCY(FRAME_WIDTH)
          ) data_buffer1 (
            .reset   (~aresetn),
            .clk     (aclk),
            .in_valid(data_valid),
            .data_in (s_axis_tdata),
            .data_out(line_buffer1)
          );
  LineBuf #(
            .WIDTH  (WIDTH),
            .LATENCY(FRAME_WIDTH)
          ) data_buffer2 (
            .reset   (~aresetn),
            .clk     (aclk),
            .in_valid(data_valid),
            .data_in (line_buffer1),
            .data_out(line_buffer2)
          );

  // 3x3窗口寄存器
  reg [WIDTH-1:0] w11, w12, w13;
  reg [WIDTH-1:0] w21, w22, w23;
  reg [WIDTH-1:0] w31, w32, w33;

  // 对应的k值窗口
  reg [K_WIDTH-1:0] k11, k12, k13;
  reg [K_WIDTH-1:0] k21, k22, k23;
  reg [K_WIDTH-1:0] k31, k32, k33;

  // 窗口移位逻辑
  always @(posedge aclk)
  begin
    if (data_valid)
    begin
      // 像素数据窗口更新
      w13 <= line_buffer2;
      w23 <= line_buffer1;
      w33 <= s_axis_tdata;

      w12 <= w13;
      w22 <= w23;
      w32 <= w33;

      w11 <= w12;
      w21 <= w22;
      w31 <= w32;

      // k值窗口更新
      k13 <= k_line_buffer2;
      k23 <= k_line_buffer1;
      k33 <= k_axis_tdata;

      k12 <= k13;
      k22 <= k23;
      k32 <= k33;

      k11 <= k12;
      k21 <= k22;
      k31 <= k32;
    end
  end

  // ================================================================
  // 第二级：手动坏点检测
  // ================================================================

  // 手动坏点表模块
  wire [CNT_WIDTH-1:0] manual_x, manual_y;
  wire manual_bad_pixel_match;

  Manual_BadPixel_Detector #(
                             .WIDTH_BITS(CNT_WIDTH),
                             .HEIGHT_BITS(CNT_WIDTH),
                             .BAD_POINT_NUM(BAD_POINT_NUM),
                             .BAD_POINT_BIT(BAD_POINT_BIT)
                           ) manual_detector (
                             .clk(aclk),
                             .rst_n(aresetn),
                             .S_AXI_ACLK(S_AXI_ACLK),

                             // 当前处理位置 (考虑流水线延迟)
                             .current_x(x_cnt - 2),
                             .current_y(y_cnt),
                             .frame_start(s_axis_tuser),

                             // 手动坏点表配置
                             .bad_point_num(bad_point_num),
                             .wen_lut(wen_lut),
                             .waddr_lut(waddr_lut),
                             .wdata_lut(wdata_lut),

                             // 输出
                             .bad_pixel_match(manual_bad_pixel_match)
                           );

  // ================================================================
  // 第三级：自动坏点检测 (基于k值)
  // ================================================================

  reg t3_manual_bad;
  reg t3_auto_bad;
  reg [WIDTH-1:0] t3_center;
  reg [WIDTH-1:0] t3_w11, t3_w12, t3_w13;
  reg [WIDTH-1:0] t3_w21, t3_w23;
  reg [WIDTH-1:0] t3_w31, t3_w32, t3_w33;
  reg [K_WIDTH-1:0] t3_k11, t3_k12, t3_k13;
  reg [K_WIDTH-1:0] t3_k21, t3_k22, t3_k23;
  reg [K_WIDTH-1:0] t3_k31, t3_k32, t3_k33;

  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn)
    begin
      t3_manual_bad <= 0;
      t3_auto_bad <= 0;
      t3_center <= 0;
      t3_w11 <= 0;
      t3_w12 <= 0;
      t3_w13 <= 0;
      t3_w21 <= 0;
      t3_w23 <= 0;
      t3_w31 <= 0;
      t3_w32 <= 0;
      t3_w33 <= 0;
      t3_k11 <= 0;
      t3_k12 <= 0;
      t3_k13 <= 0;
      t3_k21 <= 0;
      t3_k22 <= 0;
      t3_k23 <= 0;
      t3_k31 <= 0;
      t3_k32 <= 0;
      t3_k33 <= 0;
    end
    else if (data_valid)
    begin
      // 传递手动坏点检测结果
      t3_manual_bad <= manual_bad_pixel_match;

      // 基于k值的自动坏点检测: k22 == 0表示坏点
      t3_auto_bad <= (k22 == 0) && enable;

      // 传递像素数据
      t3_center <= w22;
      t3_w11 <= w13;
      t3_w12 <= w32;
      t3_w13 <= w33;
      t3_w21 <= w21;
      t3_w23 <= w32;
      t3_w31 <= w31;
      t3_w32 <= w32;
      t3_w33 <= w33;

      // 传递k值数据
      t3_k11 <= k11;
      t3_k12 <= k12;
      t3_k13 <= k13;
      t3_k21 <= k21;
      t3_k22 <= k22;
      t3_k23 <= k23;
      t3_k31 <= k31;
      t3_k32 <= k32;
      t3_k33 <= k33;
    end
  end

  // ================================================================
  // 第四级：坏点合并判断
  // ================================================================

  reg t4_is_bad_pixel;
  reg t4_manual_bad;
  reg t4_auto_bad;
  reg [WIDTH-1:0] t4_center;
  reg [WIDTH-1:0] t4_w11, t4_w12, t4_w13;
  reg [WIDTH-1:0] t4_w21, t4_w23;
  reg [WIDTH-1:0] t4_w31, t4_w32, t4_w33;
  reg [K_WIDTH-1:0] t4_k11, t4_k12, t4_k13;
  reg [K_WIDTH-1:0] t4_k21, t4_k22, t4_k23;
  reg [K_WIDTH-1:0] t4_k31, t4_k32, t4_k33;

  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn)
    begin
      t4_is_bad_pixel <= 0;
      t4_manual_bad <= 0;
      t4_auto_bad <= 0;
      t4_center <= 0;
      t4_w11 <= 0;
      t4_w12 <= 0;
      t4_w13 <= 0;
      t4_w21 <= 0;
      t4_w23 <= 0;
      t4_w31 <= 0;
      t4_w32 <= 0;
      t4_w33 <= 0;
      t4_k11 <= 0;
      t4_k12 <= 0;
      t4_k13 <= 0;
      t4_k21 <= 0;
      t4_k22 <= 0;
      t4_k23 <= 0;
      t4_k31 <= 0;
      t4_k32 <= 0;
      t4_k33 <= 0;
    end
    else if (data_valid)
    begin
      t4_manual_bad <= t3_manual_bad;
      t4_auto_bad <= t3_auto_bad;

      // 合并判断：手动或自动检测到的都是坏点
      t4_is_bad_pixel <= t3_manual_bad || t3_auto_bad;

      // 传递数据
      t4_center <= t3_center;
      t4_w11 <= t3_w11;
      t4_w12 <= t3_w12;
      t4_w13 <= t3_w13;
      t4_w21 <= t3_w21;
      t4_w23 <= t3_w23;
      t4_w31 <= t3_w31;
      t4_w32 <= t3_w32;
      t4_w33 <= t3_w33;
      t4_k11 <= t3_k11;
      t4_k12 <= t3_k12;
      t4_k13 <= t3_k13;
      t4_k21 <= t3_k21;
      t4_k22 <= t3_k22;
      t4_k23 <= t3_k23;
      t4_k31 <= t3_k31;
      t4_k32 <= t3_k32;
      t4_k33 <= t3_k33;
    end
  end

  // ================================================================
  // 第五级：3×3邻域非坏点计数和累加
  // ================================================================

  reg t5_is_bad_pixel;
  reg [WIDTH-1:0] t5_center;
  reg [3:0] t5_valid_neighbor_count;
  reg [WIDTH+3-1:0] t5_neighbor_sum;

  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn)
    begin
      t5_is_bad_pixel <= 0;
      t5_center <= 0;
      t5_valid_neighbor_count <= 0;
      t5_neighbor_sum <= 0;
    end
    else if (data_valid)
    begin
      t5_is_bad_pixel <= t4_is_bad_pixel;
      t5_center <= t4_center;

      // 计算3×3邻域中非坏点的数量和累加值
      t5_valid_neighbor_count <=
                              ((t4_k11 != 0) ? 1 : 0) + ((t4_k12 != 0) ? 1 : 0) + ((t4_k13 != 0) ? 1 : 0) +
                              ((t4_k21 != 0) ? 1 : 0) +                            ((t4_k23 != 0) ? 1 : 0) +
                              ((t4_k31 != 0) ? 1 : 0) + ((t4_k32 != 0) ? 1 : 0) + ((t4_k33 != 0) ? 1 : 0);

      t5_neighbor_sum <=
                      ((t4_k11 != 0) ? t4_w11 : 0) + ((t4_k12 != 0) ? t4_w12 : 0) + ((t4_k13 != 0) ? t4_w13 : 0) +
                      ((t4_k21 != 0) ? t4_w21 : 0) +                                 ((t4_k23 != 0) ? t4_w23 : 0) +
                      ((t4_k31 != 0) ? t4_w31 : 0) + ((t4_k32 != 0) ? t4_w32 : 0) + ((t4_k33 != 0) ? t4_w33 : 0);
    end
  end

  // ================================================================
  // 第六级：邻域均值计算
  // ================================================================

  reg t6_is_bad_pixel;
  reg [WIDTH-1:0] t6_center;
  reg [WIDTH-1:0] t6_corrected_value;

  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn)
    begin
      t6_is_bad_pixel <= 0;
      t6_center <= 0;
      t6_corrected_value <= 0;
    end
    else if (data_valid)
    begin
      t6_is_bad_pixel <= t5_is_bad_pixel;
      t6_center <= t5_center;

      // 计算邻域均值（避免除零）
      if (t5_valid_neighbor_count > 0)
      begin
        t6_corrected_value <= t5_neighbor_sum / t5_valid_neighbor_count;
      end
      else
      begin
        t6_corrected_value <= t5_center; // 如果没有有效邻域，保持原值
      end
    end
  end

  // ================================================================
  // 第七级：最终输出选择
  // ================================================================

  reg t7_output_valid;
  reg [WIDTH-1:0] t7_output_data;
  reg t7_output_user;
  reg t7_output_last;

  // 流水线控制信号延迟
  reg [LATENCY-1:0] valid_delay;
  reg [LATENCY-1:0] user_delay;
  reg [LATENCY-1:0] last_delay;

  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn)
    begin
      t7_output_valid <= 0;
      t7_output_data <= 0;
      t7_output_user <= 0;
      t7_output_last <= 0;
      valid_delay <= 0;
      user_delay <= 0;
      last_delay <= 0;
    end
    else
    begin
      // 控制信号延迟链
      valid_delay <= {valid_delay[LATENCY-2:0], data_valid};
      user_delay <= {user_delay[LATENCY-2:0], s_axis_tuser};
      last_delay <= {last_delay[LATENCY-2:0], s_axis_tlast};

      // 最终输出选择
      t7_output_valid <= valid_delay[LATENCY-1];
      t7_output_user <= user_delay[LATENCY-1];
      t7_output_last <= last_delay[LATENCY-1];

      if (t6_is_bad_pixel && enable)
      begin
        t7_output_data <= t6_corrected_value; // 坏点用校正值
      end
      else
      begin
        t7_output_data <= t6_center; // 正常点用原值
      end
    end
  end

  // ================================================================
  // 输出接口
  // ================================================================

  assign s_axis_tready = m_axis_tready;
  assign m_axis_tvalid = t7_output_valid;
  assign m_axis_tdata = t7_output_data;
  assign m_axis_tuser = t7_output_user;
  assign m_axis_tlast = t7_output_last;

  // 调试输出
  assign debug_bad_pixel_detected = t4_is_bad_pixel;
  assign debug_manual_bad_pixel = t4_manual_bad;
  assign debug_auto_bad_pixel = t4_auto_bad;

endmodule