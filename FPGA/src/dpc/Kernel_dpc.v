module Kernel_dpc #(
  parameter WIDTH     = 8,
  parameter ROW       = 6,
  parameter COL       = 8,
  parameter AXI_DATA_WIDTH = 32,
  parameter AXI_ADDR_WIDTH = 32,
  parameter CNT_WIDTH = 10
) (
  input                  axis_aclk,
  input                  axis_aresetn,
  output                 s_axis_tready,
  input                  s_axis_tvalid,
  input  [    WIDTH-1:0] s_axis_tdata,
  input                  s_axis_tuser,
  input                  s_axis_tlast,
  input                  m_axis_tready,
  output                 m_axis_tvalid,
  output [    WIDTH-1:0] m_axis_tdata,
  output                 m_axis_tuser,
  output                 m_axis_tlast,
  input                  go,
  input  [    8-1:0]     bad_point_num,
  input  [    WIDTH-1:0] threshold,
  input                  smooth,
  input                  wen_lut,
  input                  S_AXI_ACLK,
  input  [AXI_ADDR_WIDTH-1:0] waddr_lut,
  input  [AXI_DATA_WIDTH-1:0] wdata_lut,
  output [CNT_WIDTH-1:0] width,
  output [CNT_WIDTH-1:0] height,
  output                 last_pixel_in_frame,
  output                 synced_go
);
  localparam LATENCY_LINEBUF = (2 - 1) * COL;
  localparam LATENCY_WINDOW = 3 - 1;
  localparam LATENCY_FILTER_FUNC = 7;
  localparam LATENCY_FILTER_IN = LATENCY_LINEBUF + LATENCY_WINDOW;
  localparam LATENCY_TOTAL = LATENCY_FILTER_IN + LATENCY_FILTER_FUNC;

  wire [WIDTH-1+1:0] linebuf_row1_data_out;
  wire [WIDTH-1+1:0] linebuf_row2_data_out;
  wire [WIDTH-1+1:0] w11;
  wire [WIDTH-1+1:0] w12;
  wire [WIDTH-1+1:0] w13;
  wire [WIDTH-1+1:0] w21;
  wire [WIDTH-1+1:0] w22;
  wire [WIDTH-1+1:0] w23;
  wire [WIDTH-1+1:0] w31;
  wire [WIDTH-1+1:0] w32;
  wire [WIDTH-1+1:0] w33;
  wire [WIDTH-1+1:0] F_data;

  wire [CNT_WIDTH-1:0] in_vcnt_delay;
  wire [CNT_WIDTH-1:0] in_hcnt_delay;
  wire [CNT_WIDTH-1:0] width_bad;
  wire [CNT_WIDTH-1:0] height_bad;
  wire bad_point_flag;
  assign bad_point_flag = (width_bad == in_hcnt) && (height_bad == in_vcnt);


  wire             is_first_row_in;
  wire             is_first_column_in;
  wire             is_last_row_in;
  wire             is_last_column_in;
  wire             filter_is_first_row;
  wire             filter_is_last_row;
  wire             filter_is_first_column;
  wire             filter_is_last_column;

  wire in_valid;

//   LineBuf_dpc #(
//     .WIDTH(WIDTH),
//     .COL  (COL)
//   ) linebuf_row1 (
//     .clk     (axis_aclk),
//     .in_valid(in_valid),
//     .data_in (linebuf_row2_data_out),
//     .data_out(linebuf_row1_data_out)
//   );

//   LineBuf_dpc #(
//     .WIDTH(WIDTH),
//     .COL  (COL)
//   ) linebuf_row2 (
//     .clk     (axis_aclk),
//     .in_valid(in_valid),
//     .data_in (s_axis_tdata),
//     .data_out(linebuf_row2_data_out)
//   );

  LineBuf #(
    .WIDTH(WIDTH+1),
    .LATENCY  (COL)
  ) linebuf_row1 (
    .reset   (~axis_aresetn),
    .clk     (axis_aclk),
    .in_valid(in_valid),
    .data_in (linebuf_row2_data_out),
    .data_out(linebuf_row1_data_out)
  );

  LineBuf #(
    .WIDTH(WIDTH+1),
    .LATENCY  (COL)
  ) linebuf_row2 (
    .reset   (~axis_aresetn),
    .clk     (axis_aclk),
    .in_valid(in_valid),
    .data_in ({bad_point_flag, s_axis_tdata}),
    .data_out(linebuf_row2_data_out)
  );


  Window_dpc #(
    .WIDTH(WIDTH+1)
  ) sliding_window (
    .clk     (axis_aclk),
    .in_valid(in_valid),
    .w1_in   ({bad_point_flag, s_axis_tdata}),
    .w2_in   (linebuf_row2_data_out),
    .w3_in   (linebuf_row1_data_out),
    .w11     (w11),
    .w12     (w12),
    .w13     (w13),
    .w21     (w21),
    .w22     (w22),
    .w23     (w23),
    .w31     (w31),
    .w32     (w32),
    .w33     (w33)
  );


  Filter_Function_dpc #(
    .WIDTH(WIDTH),
    .CNT_WIDTH(CNT_WIDTH),
    .ROW(ROW),
    .COL(COL),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .LATENCY_FILTER_FUNC(LATENCY_FILTER_FUNC)
  ) Fil_Func_U1 (
    .aclk               (axis_aclk),
    .S_AXI_ACLK        (S_AXI_ACLK),
    .aresetn            (axis_aresetn),
    .in_valid          (in_valid),
    .is_first_row      (filter_is_first_row),
    .is_last_row       (filter_is_last_row),
    .is_first_column   (filter_is_first_column),
    .is_last_column    (filter_is_last_column),
    .in_hcnt           (in_hcnt_delay),
    .in_vcnt           (in_vcnt_delay),
    .wen_lut           (wen_lut),
    .waddr_lut         (waddr_lut),
    .wdata_lut         (wdata_lut),
    .threshold         (threshold),
    .smooth            (smooth),
    .bad_point_num     (bad_point_num),
    .w11_with_flag     (w11),
    .w12_with_flag     (w12),
    .w13_with_flag     (w13),
    .w21_with_flag     (w21),
    .w22_with_flag     (w22),
    .w23_with_flag     (w23),
    .w31_with_flag     (w31),
    .w32_with_flag     (w32),
    .w33_with_flag     (w33),
    .F_data            (F_data)

  );

  wire shift;
	assign shift = in_valid && (width_bad == in_hcnt) && (height_bad == in_vcnt);;


	manual #(
		.WIDTH_BITS		(CNT_WIDTH),
		.HEIGHT_BITS  	(CNT_WIDTH),
		.BAD_POINT_MUN  (128),
		.BAD_POINT_BIT  (7)

	)manual_inst1(
		.clk		    (axis_aclk),
		.S_AXI_ACLK	(S_AXI_ACLK),
		.rst_n		  (axis_aresetn),
		.shift		  (shift),
		.width_bad	(width_bad),
		.height_bad	(height_bad),
		.bad_point_num(bad_point_num),
		.wen_lut	  (wen_lut),
		.waddr_lut	(waddr_lut),
		.wdata_lut	(wdata_lut)
	);



  // tuser, tlast stuff
  reg  [CNT_WIDTH-1:0] in_hcnt_reg;
  reg  [CNT_WIDTH-1:0] in_vcnt_reg;
  wire [CNT_WIDTH-1:0] in_hcnt;
  wire [CNT_WIDTH-1:0] in_vcnt;
  reg  [CNT_WIDTH-1:0] in_width;
  reg  [CNT_WIDTH-1:0] in_height;
  wire                 s_fire;
  reg  [CNT_WIDTH-1:0] hcnt;
  reg  [CNT_WIDTH-1:0] vcnt;
  wire                 m_fire;
  wire                 is_last_column;
  wire                 is_last_but_one_column;
  wire                 is_last_row;
  wire                 is_last_but_one_row;
  wire                 sobel_data_not_valid;
  wire                 will_get_next_in_frame;
  wire                 will_put_next_out_frame;
  wire                 is_first_column;
  wire                 is_first_row;
  // go edge detection
  reg go_a, go_b;
  wire go_rising, go_falling;
  always @(posedge axis_aclk) begin
    go_a <= go;
    go_b <= go_a;
  end

  assign go_rising  = ~go_b & go_a;
  assign go_falling = go_b & ~go_a;

  // fsm
  reg [2:0] state;
  localparam s_stop = 0;
  localparam s_go = 1;
  localparam s_need_to_go = 2;
  localparam s_need_to_stop = 3;

  wire ready_to_go;
  wire ready_to_stop;
  assign ready_to_go   = (state == s_go) | (state == s_need_to_stop);
  assign ready_to_stop = (state == s_stop) | (state == s_need_to_go);

  always @(posedge axis_aclk) begin
    if (~axis_aresetn) begin
      state <= s_stop;
    end else begin
      case (state)
        s_stop: begin
          if (go_rising) state <= s_need_to_go;
        end
        s_go: begin
          if (go_falling) state <= s_need_to_stop;
        end
        s_need_to_go: begin
          if (will_get_next_in_frame) state <= s_go;
        end
        s_need_to_stop: begin
          if (will_put_next_out_frame) state <= s_stop;
        end
        default: begin
          state <= s_need_to_stop;
        end
      endcase
    end
  end

  always @(posedge axis_aclk) begin
    if (~axis_aresetn) begin
      hcnt <= 'd0;
      vcnt <= 'd0;
    end else if (~ready_to_go) begin
      hcnt <= 'd0;
      vcnt <= 'd0;
    end else if (m_fire) begin
      if (hcnt < COL - 1) begin
        hcnt <= hcnt + 'd1;
      end else begin
        hcnt <= 'd0;
        if (vcnt < ROW - 1) vcnt <= vcnt + 'd1;
        else vcnt <= 'd0;
      end
    end
  end

  reg  [11:0] initial_delay_cnt;
  wire        initial_delayed;

  always @(posedge axis_aclk) begin
    if (~axis_aresetn) initial_delay_cnt <= 'd0;
    else if (~ready_to_go) initial_delay_cnt <= 'd0;
    else begin
      if (~initial_delayed & in_valid) initial_delay_cnt <= initial_delay_cnt + 'd1;
    end
  end

  assign initial_delayed         = initial_delay_cnt >= LATENCY_TOTAL;

  assign m_fire                  = m_axis_tvalid & m_axis_tready;

  assign is_last_column          = hcnt == COL - 1;
  assign is_last_but_one_column  = hcnt == COL - 2;
  assign is_last_row             = vcnt == ROW - 1;
  assign is_last_but_one_row     = vcnt == ROW - 2;
  assign will_put_next_out_frame = m_fire & is_last_row & is_last_column;

  assign m_axis_tvalid           = s_axis_tvalid & initial_delayed;
  assign m_axis_tlast            = m_fire & is_last_column;
  assign m_axis_tuser            = m_fire & (hcnt == 0) & (vcnt == 0);
  assign s_axis_tready           = m_axis_tready;
  assign m_axis_tdata            = F_data;

  always @(posedge axis_aclk) begin
    if (~axis_aresetn) begin
      in_hcnt_reg <= 'd0;
      in_vcnt_reg <= 'd0;
    end else begin
      if (s_fire) begin
        in_hcnt_reg <= in_hcnt_reg + 'd1;
        if (s_axis_tuser) begin  // start of frame
          in_height   <= in_vcnt_reg;
          in_vcnt_reg <= 'd0;  // note not aligned to tuser
        end else if (s_axis_tlast) begin  // end of line
          in_width    <= in_hcnt_reg + 'd1;
          in_hcnt_reg <= 'd0;
          in_vcnt_reg <= in_vcnt_reg + 'd1;
        end
      end
    end
  end

  assign in_hcnt                = in_hcnt_reg;
  assign in_vcnt                = in_vcnt_reg & {CNT_WIDTH{~s_axis_tuser}};  // align to tuser

  assign s_fire                 = s_axis_tready && s_axis_tvalid;
  assign is_first_row_in        = in_vcnt == 0;
  assign is_first_column_in     = in_hcnt == 0;
  assign is_last_row_in         = in_vcnt == ROW - 1;  // fixme
  assign is_last_column_in      = in_hcnt == COL - 1;  // fixme
  assign will_get_next_in_frame = s_fire & is_last_row_in & is_last_column_in;
  assign width                  = in_width;
  assign height                 = in_height;

  assign last_pixel_in_frame    = will_get_next_in_frame;
  assign synced_go              = ready_to_go;

  // align edge indicators to filter function input
  wire     [CNT_WIDTH+CNT_WIDTH+4-1:0] shift_reg_in, shift_reg_out;

  assign shift_reg_in = {is_first_row_in, is_last_row_in, is_first_column_in, is_last_column_in, in_vcnt, in_hcnt};


  LineBuf_dpc #(
    .WIDTH(24),
    .LATENCY  (LATENCY_FILTER_IN)
  ) linebuf_shift (
    .reset   (~axis_aresetn),
    .clk     (axis_aclk),
    .in_valid(in_valid),
    .data_in (shift_reg_in),
    .data_out(shift_reg_out)
  );



  assign {filter_is_first_row, filter_is_last_row, filter_is_first_column, filter_is_last_column, in_vcnt_delay, in_hcnt_delay} =
    shift_reg_out;

  assign in_valid = s_fire;

endmodule


