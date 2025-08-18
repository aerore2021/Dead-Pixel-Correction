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

module DPC_Detector_test #(
    parameter WIDTH = 16,                    // 像素数据位宽
    parameter K_WIDTH = 16,                  // k值位宽
    parameter CNT_WIDTH = 10,                // 坐标计数器位宽
    parameter MANUAL_BP_NUM = 128,           // 手动坏点最大数量
    parameter MANUAL_BP_BIT = 7,             // 手动坏点地址位宽
    parameter AUTO_BP_NUM = 256,             // 自动检测坏点最大数量
    parameter AUTO_BP_BIT = 8,               // 自动检测坏点地址位宽
    parameter THRESHOLD_AUTO = 100,          // 自动检测阈值
    parameter THRESHOLD_MANUAL = 50,         // 手动检测小阈值
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

    // 输出像素流 (中间的位置)
    input  wire                     m_axis_tready,
    output wire                     m_axis_tvalid,
    output wire [WIDTH-1:0]         m_axis_tdata,
    output wire                     m_axis_tuser,
    output wire                     m_axis_tlast,
    output wire [WIDTH-1:0]         w11, // 未padding
    output wire [WIDTH-1:0]         w12,
    output wire [WIDTH-1:0]         w13,
    output wire [WIDTH-1:0]         w21,
    output wire [WIDTH-1:0]         w23,
    output wire [WIDTH-1:0]         w31,
    output wire [WIDTH-1:0]         w32,
    output wire [WIDTH-1:0]         w33,

    // 输出k值流 (带坏点标志位)
    output wire                     k_out_tvalid,
    output wire [K_WIDTH:0]         k_out_tdata,    // 最高位为坏点标志，低位为k值
    output wire                     k11_vld,
    output wire                     k12_vld,
    output wire                     k13_vld,
    output wire                     k21_vld,
    output wire                     k23_vld,
    output wire                     k31_vld,
    output wire                     k32_vld,
    output wire                     k33_vld,

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

    // AXI读取坏点列表接口
    input  wire [AUTO_BP_BIT-1:0]   auto_bp_read_addr,  // 软核读取地址
    output wire [31:0]              auto_bp_read_data,  // 坏点数据 {Y[15:0], X[15:0]}

    // 检测状态
    output wire                     frame_detection_done,  // 帧检测完成
    output wire [AUTO_BP_BIT-1:0]   detected_bp_count     // 当前帧检测到的坏点数量
  );

  localparam LATENCY_CENTER = FRAME_WIDTH + 1; // 从右下角到中心
  localparam LATENCY_PADDING = 3; // padding带来的延时
  localparam LATENCY_MEDIAN = 3; // 中值延时
  localparam LATENCY_K_VLD = 1; // 得到有效k数组的延时
  localparam LATENCY_TO_MEDIAN = LATENCY_CENTER + LATENCY_PADDING + LATENCY_MEDIAN + LATENCY_K_VLD;
  localparam LATENCY_TOTAL_TO_CENTER = LATENCY_CENTER + LATENCY_PADDING + LATENCY_MEDIAN + LATENCY_K_VLD; // 第一个输入到有效输出的时间，需要加上一行一列的延时
  localparam LATENCY_TOTAL = LATENCY_PADDING + LATENCY_MEDIAN + LATENCY_K_VLD; // 流水线的总延时，输入到输出的总延时

  // 内部信号定义
  wire data_valid = s_axis_tvalid & s_axis_tready & k_axis_tvalid;
  wire [CNT_WIDTH-1:0] frame_height = FRAME_HEIGHT;
  wire [CNT_WIDTH-1:0] frame_width = FRAME_WIDTH;

  // 坐标计数器
  reg [CNT_WIDTH-1:0] x_cnt, y_cnt;
  reg frame_start_pulse, frame_end_pulse;

  always @(posedge aclk)
  begin
    if (!aresetn)
    begin
      x_cnt <= 0;
      y_cnt <= 0;
      frame_start_pulse <= 0;
      frame_end_pulse <= 0;
    end
    else if (data_valid)
    begin
      frame_start_pulse <= s_axis_tuser & ~frame_start_pulse;

      if (x_cnt == frame_width-1)
      begin
        x_cnt <= 0;
        y_cnt <= y_cnt + 1;
        frame_end_pulse <= (y_cnt == frame_height - 1);
      end
      else
      begin
        x_cnt <= x_cnt + 1;
        frame_end_pulse <= 0;
      end
    end
    else
    begin
      frame_start_pulse <= 0;
    end
  end

  // ================================================================
  // k值窗口缓存 (3x3):LATENCY=FRAME_WIDTH*2+2
  // 扩展k值位宽，加入手动坏点标志位
  // ================================================================

  // 为k值添加手动坏点标志位
  wire [K_WIDTH:0] k_with_flag;  // 扩展1位用于标志位
  assign k_with_flag = {(k_axis_tdata == 'd0), k_axis_tdata}; // 手动要和输入的坐标对齐，以及加入DP检测

  wire [K_WIDTH:0] k_line_buffer1;
  wire [K_WIDTH:0] k_line_buffer2;

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

  always @(posedge aclk)
  begin
    k_line_buffer1_r[2] <= k_line_buffer1;
    k_line_buffer1_r[1] <= k_line_buffer1_r[2];
    k_line_buffer1_r[0] <= k_line_buffer1_r[1];

    k_line_buffer2_r[2] <= k_line_buffer2;
    k_line_buffer2_r[1] <= k_line_buffer2_r[2];
    k_line_buffer2_r[0] <= k_line_buffer2_r[1];

    k_axis_tdata_r[2] <= k_with_flag;
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
                .data_in  	(k_with_flag   ),
                .data_out 	(k_line_buffer1  )
              );

  LineBuf_dpc #(
                .WIDTH   	(K_WIDTH+1   ),  // 增加1位用于标志位
                .LATENCY 	(FRAME_WIDTH  ))
              u_LineBuf_k_2(
                .reset    	(aresetn     ),
                .clk      	(aclk       ),
                .in_valid 	(k_axis_tvalid  ),
                .data_in  	(k_line_buffer1   ),
                .data_out 	(k_line_buffer2  )
              );

  wire is_first_row, is_last_row, is_first_col, is_last_col;
  wire is_sec_row, is_last_sec_row, is_sec_col, is_last_sec_col;
  reg is_sec_row_r, is_last_sec_row_r, is_sec_col_r, is_last_sec_col_r;
  reg is_sec_row_r2, is_last_sec_row_r2;

  assign is_first_row = (y_cnt == 0);
  assign is_last_row = (y_cnt == FRAME_HEIGHT - 1);
  assign is_first_col = (x_cnt == 0);
  assign is_last_col = (x_cnt == FRAME_WIDTH - 1);

  assign is_sec_row = (y_cnt == 1);
  assign is_last_sec_row = (y_cnt == FRAME_HEIGHT - 2);
  assign is_sec_col = (x_cnt == 1);
  assign is_last_sec_col = (x_cnt == FRAME_WIDTH - 2);

  // 窗口移位逻辑: LATENCY_PADDING = 2
  always @(posedge aclk)
  begin
    if (~aresetn)
    begin
      k11_r <= 'd0;
      k12_r <= 'd0;
      k13_r <= 'd0;
      k21_r <= 'd0;
      k22_r <= 'd0;
      k23_r <= 'd0;
      k31_r <= 'd0;
      k32_r <= 'd0;
      k33_r <= 'd0;

      k11 <= 'd0;
      k12 <= 'd0;
      k13 <= 'd0;
      k21 <= 'd0;
      k22 <= 'd0;
      k23 <= 'd0;
      k31 <= 'd0;
      k32 <= 'd0;
      k33 <= 'd0;

      is_sec_row_r <= 0;
      is_last_sec_row_r <= 0;
      is_sec_col_r <= 0;
      is_last_sec_col_r <= 0;
      is_sec_row_r2 <= 0;
      is_last_sec_row_r2 <= 0;
    end

    else
    begin
      // step 1
      k11_r <= (is_sec_col_r) ? k_line_buffer2_r[1] : k_line_buffer2_r[0];
      k21_r <= (is_sec_col_r) ? k_line_buffer1_r[1] : k_line_buffer1_r[0];
      k31_r <= (is_sec_col_r) ? k_axis_tdata_r[1] : k_axis_tdata_r[0];

      k12_r <= k_line_buffer2_r[1];
      k22_r <= k_line_buffer1_r[1];
      k32_r <= k_axis_tdata_r[1];

      k13_r <= (is_last_sec_col_r) ? k_line_buffer2_r[1] : k_line_buffer2_r[2];
      k23_r <= (is_last_sec_col_r) ? k_line_buffer1_r[1] : k_line_buffer1_r[2];
      k33_r <= (is_last_sec_col_r) ? k_axis_tdata_r[1] : k_axis_tdata_r[2];
      // step 2
      k11 <= (is_sec_row_r2) ? k21_r : k11_r;
      k12 <= (is_sec_row_r2) ? k22_r : k12_r;
      k13 <= (is_sec_row_r2) ? k23_r : k13_r;

      k21 <= k21_r;
      k22 <= k22_r;
      k23 <= k23_r;

      k31 <= (is_last_sec_row_r2) ? k21_r : k31_r;
      k32 <= (is_last_sec_row_r2) ? k22_r : k32_r;
      k33 <= (is_last_sec_row_r2) ? k23_r : k33_r;

      is_sec_row_r <= is_sec_row;
      is_sec_row_r2 <= is_sec_row_r;
      is_last_sec_row_r <= is_last_sec_row;
      is_last_sec_row_r2 <= is_last_sec_row_r;
      is_sec_col_r <= is_sec_col;
      is_last_sec_col_r <= is_last_sec_col;
    end
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

  always @(posedge aclk)
  begin
    if (!aresetn)
    begin
      k_vld_cnt = 0;
      for (integer idx = 0; idx < 8; idx = idx + 1)
      begin
        k_neighbors_vld[idx] <= 0;
      end
    end
    else
    begin
      k_vld_cnt = 0;
      for (integer i = 0; i<8; i = i + 1)
      begin
        // 有效k值赋值，LATENCY_K_VLD = 1
        if (!k_neighbors[i][K_WIDTH])
        begin
          k_neighbors_vld[k_vld_cnt] <= k_neighbors[i][K_WIDTH-1:0];
          k_vld_cnt = k_vld_cnt + 1;
        end
      end
    end
  end

  // 快速中值计算模块实例化
  wire [3:0] k_vld_cnt_in;
  assign k_vld_cnt_in = k_vld_cnt;

  wire median_valid;
  wire [K_WIDTH-1:0] k_median;
  wire [K_WIDTH-1:0] k_center;
  wire [K_WIDTH:0]   k_center_with_flag;
  // LATENCY_MEDIAN = 3
  Fast_Median_Calculator #(
                           .DATA_WIDTH(K_WIDTH),
                           .MAX_COUNT(8)
                         ) u_median_calc (
                           .clk(aclk),
                           .rst_n(aresetn),
                           .valid_in(data_valid),
                           .data0(k_neighbors_vld[0]),
                           .data1(k_neighbors_vld[1]),
                           .data2(k_neighbors_vld[2]),
                           .data3(k_neighbors_vld[3]),
                           .data4(k_neighbors_vld[4]),
                           .data5(k_neighbors_vld[5]),
                           .data6(k_neighbors_vld[6]),
                           .data7(k_neighbors_vld[7]),
                           .valid_count(k_vld_cnt_in),
                           .median_out(k_median)
                         );

  localparam LATENCY_CENTER2MEDIAN = 4;
  reg [K_WIDTH:0] k_center_with_flag_r [0:3];
  reg k11_flag_r [0:3];
  reg k12_flag_r [0:3];
  reg k13_flag_r [0:3];
  reg k21_flag_r [0:3];
  reg k23_flag_r [0:3];
  reg k31_flag_r [0:3];
  reg k32_flag_r [0:3];
  reg k33_flag_r [0:3];

  always @(posedge aclk)
  begin
    k_center_with_flag_r[0] <= k22;
    k_center_with_flag_r[1] <= k_center_with_flag_r[0];
    k_center_with_flag_r[2] <= k_center_with_flag_r[1];
    k_center_with_flag_r[3] <= k_center_with_flag_r[2];

    k11_flag_r[0] <= k11[K_WIDTH];
    k12_flag_r[0] <= k12[K_WIDTH];
    k13_flag_r[0] <= k13[K_WIDTH];
    k21_flag_r[0] <= k21[K_WIDTH];
    k23_flag_r[0] <= k23[K_WIDTH];
    k31_flag_r[0] <= k31[K_WIDTH];
    k32_flag_r[0] <= k32[K_WIDTH];
    k33_flag_r[0] <= k33[K_WIDTH];

    k11_flag_r[1] <= k11_flag_r[0];
    k12_flag_r[1] <= k12_flag_r[0];
    k13_flag_r[1] <= k13_flag_r[0];
    k21_flag_r[1] <= k21_flag_r[0];
    k23_flag_r[1] <= k23_flag_r[0];
    k31_flag_r[1] <= k31_flag_r[0];
    k32_flag_r[1] <= k32_flag_r[0];
    k33_flag_r[1] <= k33_flag_r[0];

    k11_flag_r[2] <= k11_flag_r[1];
    k12_flag_r[2] <= k12_flag_r[1];
    k13_flag_r[2] <= k13_flag_r[1];
    k21_flag_r[2] <= k21_flag_r[1];
    k23_flag_r[2] <= k23_flag_r[1];
    k31_flag_r[2] <= k31_flag_r[1];
    k32_flag_r[2] <= k32_flag_r[1];
    k33_flag_r[2] <= k33_flag_r[1];

    k11_flag_r[3] <= k11_flag_r[2];
    k12_flag_r[3] <= k12_flag_r[2];
    k13_flag_r[3] <= k13_flag_r[2];
    k21_flag_r[3] <= k21_flag_r[2];
    k23_flag_r[3] <= k23_flag_r[2];
    k31_flag_r[3] <= k31_flag_r[2];
    k32_flag_r[3] <= k32_flag_r[2];
    k33_flag_r[3] <= k33_flag_r[2];
  end
  assign k_center_with_flag = k_center_with_flag_r[3];
  assign k_center = k_center_with_flag[K_WIDTH-1:0];
  // ================================================================
  // 坏点输出逻辑和列表存储
  // ================================================================

  // 检测到的坏点计数器
  reg [AUTO_BP_BIT:0] bp_count;
  reg [AUTO_BP_BIT:0] bp_write_addr;
  wire frame_done_r;

  // BRAM接口信号
  wire                        bp_bram_clka, bp_bram_clkb;
  wire                        bp_bram_ena, bp_bram_enb;
  wire                        bp_bram_wea;
  wire [AUTO_BP_BIT-1:0]      bp_bram_addra, bp_bram_addrb;
  wire [31:0]                 bp_bram_dina, bp_bram_douta, bp_bram_doutb;

  // BRAM时钟分配
  assign bp_bram_clka = aclk;
  assign bp_bram_clkb = aclk;

  // 写端口控制 (Port A)
  assign bp_bram_ena = 1'b1;
  assign bp_bram_addra = bp_write_addr;
  assign bp_bram_dina = {6'b0, auto_bp_y, 6'b0, auto_bp_x};

  // 读端口控制 (Port B)
  assign bp_bram_enb = 1'b1;
  assign bp_bram_addrb = auto_bp_read_addr;

  // 坏点列表BRAM实例化
  // BadPixel_List_BRAM #(
  //     .DATA_WIDTH(32),
  //     .ADDR_WIDTH(AUTO_BP_BIT),
  //     .DEPTH(AUTO_BP_NUM)
  // ) bp_list_bram (
  //     .clka(bp_bram_clka),
  //     .wea(bp_bram_wea),
  //     .addra(bp_bram_addra),
  //     .dina(bp_bram_dina)

  //     .clkb(bp_bram_clkb),
  //     .enb(bp_bram_enb),
  //     .addrb(bp_bram_addrb),
  //     .doutb(bp_bram_doutb)
  // );

  reg [15:0] delay_total_cnt;
  reg frame_end;
  wire delayed;
  wire padding_valid;
  wire linebuf_m_valid;
  wire k_thres_mux;

  assign delayed = (delay_total_cnt > LATENCY_TOTAL_TO_CENTER);
  assign median_valid = (delay_total_cnt > LATENCY_TO_MEDIAN);
  assign padding_valid = (delay_total_cnt > LATENCY_CENTER + LATENCY_PADDING);
  assign linebuf_m_valid = (delay_total_cnt > LATENCY_TOTAL-1); // 减一是因为后面有一个延时
  assign frame_done_r = (auto_bp_x == frame_width - 1) && (auto_bp_y == frame_height - 1);

  always @(posedge aclk)
  begin
    if (!aresetn)
    begin
      auto_bp_x <= 0;
      auto_bp_y <= 0;
      bp_count <= 0;
      bp_write_addr <= 0;
      delay_total_cnt <= 'd0;
      frame_end <= 0;
    end
    else
    begin
      if (s_axis_tvalid)
      begin
        delay_total_cnt <= delay_total_cnt + 'd1;
      end
      // 帧开始时重置坏点计数和写地址
      if (frame_start_pulse)
      begin
        bp_count <= 0;
        bp_write_addr <= 0;
      end

      if (delayed)
      begin
        if (auto_bp_x == frame_width - 1)
        begin
          auto_bp_x <= 0;
          auto_bp_y <= auto_bp_y + 1;
        end
        else
        begin
          auto_bp_x <= auto_bp_x + 1;
        end
      end
      if (frame_done_r)
      begin
        frame_end <= 1;
      end
    end
  end


  // ================================================================
  // 手动坏点匹配检测
  // ================================================================

  wire manual_bp_match;
  wire [CNT_WIDTH-1:0] manual_bp_x, manual_bp_y;
  assign k_thres_mux = (manual_bp_match) ? THRESHOLD_MANUAL : THRESHOLD_AUTO;
  assign auto_bp_valid = (k_center_with_flag[K_WIDTH]) | (k_center > k_median + k_thres_mux) | (k_center < k_median - k_thres_mux);

  
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
                            .current_x(auto_bp_x),
                            .current_y(auto_bp_y),
                            .frame_start(m_axis_tuser),

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

  // BRAM写入控制逻辑
  reg bp_write_en;
  always @(posedge aclk)
  begin
    if (!aresetn)
    begin
      bp_write_en <= 1'b0;
    end
    else
    begin
      // 检测到坏点且未超过最大数量时使能写入
      bp_write_en <= delayed && auto_bp_valid && (bp_write_addr < AUTO_BP_NUM);

      // 更新写地址和计数
      if (bp_write_en)
      begin
        bp_write_addr <= bp_write_addr + 1;
        bp_count <= bp_count + 1;
      end
    end
  end

  assign bp_bram_wea = bp_write_en;

  // AXI读取坏点列表接口 - 添加边界检查
  assign auto_bp_read_data = (auto_bp_read_addr < bp_count) ? bp_bram_doutb : 32'h0;


  // ================================================================
  // 延迟对齐的输出
  // ================================================================

  // 像素数据输出（延迟对齐）
  // 像素延迟缓存，与k值处理对齐
  wire [WIDTH-1:0] m_axis_tdata_reg;
  wire [WIDTH-1:0] m_axis_tdata_reg_row_1;
  wire [WIDTH-1:0] m_axis_tdata_reg_row_2;

  LineBuf_dpc #(
                .WIDTH   	(WIDTH   ),
                .LATENCY 	(LATENCY_TOTAL-1 )) // 减一是因为后面有一个延时
              s_axis_tdata_delay(
                .reset    	(aresetn     ),
                .clk      	(aclk       ),
                .in_valid 	(s_axis_tvalid  ),
                .data_in  	(s_axis_tdata   ),
                .data_out 	(m_axis_tdata_reg )
              );

  LineBuf_dpc #(
                .WIDTH   	(WIDTH   ),
                .LATENCY 	(FRAME_WIDTH  ))
              s_axis_tdata_linebuf_row_1(
                .reset    	(aresetn     ),
                .clk      	(aclk       ),
                .in_valid 	(linebuf_m_valid  ),
                .data_in  	(m_axis_tdata_reg   ),
                .data_out 	( m_axis_tdata_reg_row_1)
              );

  LineBuf_dpc #(
                .WIDTH   	(WIDTH   ),
                .LATENCY 	(FRAME_WIDTH  ))
              s_axis_tdata_linebuf_row_2(
                .reset    	(aresetn     ),
                .clk      	(aclk       ),
                .in_valid 	(linebuf_m_valid  ),
                .data_in  	(m_axis_tdata_reg_row_1   ),
                .data_out 	( m_axis_tdata_reg_row_2)
              );

  reg [WIDTH-1:0] m_axis_tdata_reg_r [0:2];
  reg [WIDTH-1:0] m_axis_tdata_reg_row_1_r [0:2];
  reg [WIDTH-1:0] m_axis_tdata_reg_row_2_r [0:2];

  always @(posedge aclk)
  begin
    m_axis_tdata_reg_r[2] <= m_axis_tdata_reg_r[1];
    m_axis_tdata_reg_r[1] <= m_axis_tdata_reg_r[0];
    m_axis_tdata_reg_r[0] <= m_axis_tdata_reg;

    m_axis_tdata_reg_row_1_r[2] <= m_axis_tdata_reg_row_1_r[1];
    m_axis_tdata_reg_row_1_r[1] <= m_axis_tdata_reg_row_1_r[0];
    m_axis_tdata_reg_row_1_r[0] <= m_axis_tdata_reg_row_1;

    m_axis_tdata_reg_row_2_r[2] <= m_axis_tdata_reg_row_2_r[1];
    m_axis_tdata_reg_row_2_r[1] <= m_axis_tdata_reg_row_2_r[0];
    m_axis_tdata_reg_row_2_r[0] <= m_axis_tdata_reg_row_2;
  end

  wire [WIDTH-1:0] m_axis_tdata_reg_center;

  assign m_axis_tdata_reg_center = m_axis_tdata_reg_row_1_r[1];
  assign s_axis_tready = m_axis_tready;
  assign m_axis_tvalid = delayed && ~frame_end;
  assign m_axis_tdata = m_axis_tdata_reg_center;
  assign m_axis_tuser = (auto_bp_x == 0 && auto_bp_y == 0);
  assign m_axis_tlast = (auto_bp_x == frame_width - 1);
  assign w11 = m_axis_tdata_reg_row_2_r[2];
  assign w12 = m_axis_tdata_reg_row_2_r[1];
  assign w13 = m_axis_tdata_reg_row_2_r[0];
  assign w21 = m_axis_tdata_reg_row_1_r[2];
  assign w23 = m_axis_tdata_reg_row_1_r[0];
  assign w31 = m_axis_tdata_reg_r[2];
  assign w32 = m_axis_tdata_reg_r[1];
  assign w33 = m_axis_tdata_reg_r[0];


  // k值输出（带坏点标志位）
  assign k_out_tvalid = median_valid;
  assign k_out_tdata = {auto_bp_valid, k_center};
  assign k11_vld = (!k11_flag_r[3]);
  assign k12_vld = (!k12_flag_r[3]);
  assign k13_vld = (!k13_flag_r[3]);
  assign k21_vld = (!k21_flag_r[3]);
  assign k23_vld = (!k23_flag_r[3]);
  assign k31_vld = (!k31_flag_r[3]);
  assign k32_vld = (!k32_flag_r[3]);
  assign k33_vld = (!k33_flag_r[3]);

  // 状态输出
  assign frame_detection_done = frame_done_r;
  assign detected_bp_count = bp_count;

endmodule
