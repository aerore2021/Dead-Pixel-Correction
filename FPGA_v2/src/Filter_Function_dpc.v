`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ZJU
// Engineer: HR
// 
// Create Date: 2022_12_09
// Design Name: 
// Module Name: Filter_Function
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 坏点替换 核心代码逻辑
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//	 坏点替换逻辑:
//   - 四个基本方向: 经过中心的, 水平/垂直/两支对角线方向
//   - 八个额外方向: 上+左上, 上+右上, 左+左上, 左+左下... 以此类推
//   - 基本方向选用两端点均值替代
//   - 额外方向选用经过该方向的最近邻替代. 比如上+左上最小, 则用左邻居替代
//   - 应排除有坏点的所有方向

module Filter_Function_dpc #(
  parameter WIDTH = 8,
  parameter CNT_WIDTH = 10,
  parameter ROW = 512,
  parameter COL = 640,
  parameter AXI_DATA_WIDTH = 32,
  parameter AXI_ADDR_WIDTH = 32,
  parameter LATENCY_FILTER_FUNC = 5
) (
  input              aclk,
  input              S_AXI_ACLK,
  input 			 aresetn,
  input              in_valid,
  input              is_first_row,
  input              is_last_row,
  input              is_first_column,
  input              is_last_column,
  input  [CNT_WIDTH-1:0]in_vcnt,
  input  [CNT_WIDTH-1:0]in_hcnt,
  input  [CNT_WIDTH-1:0]width_bad,
  input  [CNT_WIDTH-1:0]height_bad,
  input  [7:0]       bad_point_num,
  input                  wen_lut,
  input  [AXI_ADDR_WIDTH-1:0] waddr_lut,
  input  [AXI_DATA_WIDTH-1:0] wdata_lut,
  input  [WIDTH-1+1:0] w11_with_flag,
  input  [WIDTH-1+1:0] w12_with_flag,
  input  [WIDTH-1+1:0] w13_with_flag,
  input  [WIDTH-1+1:0] w21_with_flag,
  input  [WIDTH-1+1:0] w22_with_flag,
  input  [WIDTH-1+1:0] w23_with_flag,
  input  [WIDTH-1+1:0] w31_with_flag,
  input  [WIDTH-1+1:0] w32_with_flag,
  input  [WIDTH-1+1:0] w33_with_flag,
  output [WIDTH-1+1:0] F_data,  // {is_bad_point, pixel_data}
	output [CNT_WIDTH-1:0] out_hcnt,
	output [CNT_WIDTH-1:0] out_vcnt,
	output               out_valid

);
    localparam lpm_drepresentation = "UNSIGNED";
    localparam lpm_hint            = "";
    localparam lpm_nrepresentation = "UNSIGNED";
    localparam lpm_pipeline        = 3;
    localparam lpm_type            = "LPM_DIVIDE";
    localparam lpm_widthd          = 4;
    localparam lpm_widthn          = WIDTH+3; 

  	wire  [WIDTH-1:0] w11;
  	wire  [WIDTH-1:0] w12;
  	wire  [WIDTH-1:0] w13;
  	wire  [WIDTH-1:0] w21;
  	wire  [WIDTH-1:0] w22;
  	wire  [WIDTH-1:0] w23;
  	wire  [WIDTH-1:0] w31;
  	wire  [WIDTH-1:0] w32;
  	wire  [WIDTH-1:0] w33;

  	wire  w11_flag;
  	wire  w12_flag;
  	wire  w13_flag;
  	wire  w21_flag;
  	wire  w22_flag;
  	wire  w23_flag;
  	wire  w31_flag;
  	wire  w32_flag;
  	wire  w33_flag;

	assign w11 = w11_with_flag[WIDTH-1:0];
	assign w12 = w12_with_flag[WIDTH-1:0];
	assign w13 = w13_with_flag[WIDTH-1:0];
	assign w21 = w21_with_flag[WIDTH-1:0];
	assign w22 = w22_with_flag[WIDTH-1:0];
	assign w23 = w23_with_flag[WIDTH-1:0];
	assign w31 = w31_with_flag[WIDTH-1:0];
	assign w32 = w32_with_flag[WIDTH-1:0];
	assign w33 = w33_with_flag[WIDTH-1:0];

	assign w11_flag = w11_with_flag[WIDTH];
	assign w12_flag = w12_with_flag[WIDTH];
	assign w13_flag = w13_with_flag[WIDTH];
	assign w21_flag = w21_with_flag[WIDTH];
	assign w22_flag = w22_with_flag[WIDTH];
	assign w23_flag = w23_with_flag[WIDTH];
	assign w31_flag = w31_with_flag[WIDTH];
	assign w32_flag = w32_with_flag[WIDTH];
	assign w33_flag = w33_with_flag[WIDTH];

    // 经过边界值处理后的3*3窗口值
    wire        [WIDTH-1:0] w11_uint_ex;
    wire        [WIDTH-1:0] w12_uint_ex;
    wire        [WIDTH-1:0] w13_uint_ex;
    wire        [WIDTH-1:0] w21_uint_ex;
    wire        [WIDTH-1:0] w22_uint_ex;
    wire        [WIDTH-1:0] w23_uint_ex;
    wire        [WIDTH-1:0] w31_uint_ex;
    wire        [WIDTH-1:0] w32_uint_ex;
    wire        [WIDTH-1:0] w33_uint_ex;

	reg 		[CNT_WIDTH-1:0]hcnt_r[0:LATENCY_FILTER_FUNC-1];
	reg 		[CNT_WIDTH-1:0]vcnt_r[0:LATENCY_FILTER_FUNC-1];
	reg         [WIDTH-1+1:0] w22_delay[0:LATENCY_FILTER_FUNC-1];
	reg         [WIDTH-1+1:0] w22_flag_delay[0:LATENCY_FILTER_FUNC-1];
	wire 		shift;

	reg	[1:0]	window_bp_num_stg0[0:2];
	reg [3:0]	window_bp_num_stg1;
	reg [3:0]	window_gp_num;

	wire valid_horizontal, valid_vertical, valid_d1, valid_d2;
	assign valid_horizontal = ~w21_flag & ~w23_flag;
	assign valid_vertical   = ~w12_flag & ~w32_flag;
	assign valid_d1        = ~w11_flag & ~w33_flag;
	assign valid_d2        = ~w13_flag & ~w31_flag;

	wire [WIDTH-1:0] diff_horizontal, diff_vertical, diff_d1, diff_d2;
	assign diff_horizontal = (w23_uint_ex > w21_uint_ex) ? (w23_uint_ex - w21_uint_ex) : (w21_uint_ex - w23_uint_ex);
	assign diff_vertical   = (w32_uint_ex > w12_uint_ex) ? (w32_uint_ex - w12_uint_ex) : (w12_uint_ex - w32_uint_ex);
	assign diff_d1        = (w33_uint_ex > w11_uint_ex) ? (w33_uint_ex - w11_uint_ex) : (w11_uint_ex - w33_uint_ex);
	assign diff_d2        = (w31_uint_ex > w13_uint_ex) ? (w31_uint_ex - w13_uint_ex) : (w13_uint_ex - w31_uint_ex);
	
	wire [WIDTH:0] mean_horizontal, mean_vertical, mean_d1, mean_d2;
	assign mean_horizontal = valid_horizontal ? (w21_uint_ex + w23_uint_ex)>>1 : 0;
	assign mean_vertical   = valid_vertical   ? (w12_uint_ex + w32_uint_ex)>>1 : 0;
	assign mean_d1        = valid_d1        ? (w11_uint_ex + w33_uint_ex)>>1 : 0;
	assign mean_d2        = valid_d2        ? (w13_uint_ex + w31_uint_ex)>>1 : 0;
	// 左上加上, 右上加上, 左下加下, 右下加下, 左上加左, 左下加左, 右上加右, 右下加右
	wire valid_1112, valid_1213, valid_3132, valid_3233, valid_1121, valid_2131, valid_1323, valid_2333;
	assign valid_1112 = ~w11_flag & ~w12_flag & ~w21_flag;
	assign valid_1213 = ~w12_flag & ~w13_flag & ~w23_flag;
	assign valid_3132 = ~w31_flag & ~w32_flag & ~w21_flag;
	assign valid_3233 = ~w32_flag & ~w33_flag & ~w23_flag;
	assign valid_1121 = ~w11_flag & ~w12_flag & ~w21_flag;
	assign valid_2131 = ~w21_flag & ~w32_flag & ~w31_flag;
	assign valid_1323 = ~w12_flag & ~w23_flag & ~w13_flag;
	assign valid_2333 = ~w23_flag & ~w33_flag & ~w32_flag;

	wire [WIDTH-1:0] dif_adjacent_1, dif_adjacent_2, dif_adjacent_3, dif_adjacent_4, dif_adjacent_5, dif_adjacent_6, dif_adjacent_7, dif_adjacent_8;
	assign dif_adjacent_1 = (w11_uint_ex > w12_uint_ex) ? (w11_uint_ex - w12_uint_ex) : (w12_uint_ex - w11_uint_ex);
	assign dif_adjacent_2 = (w13_uint_ex > w12_uint_ex) ? (w13_uint_ex - w12_uint_ex) : (w12_uint_ex - w13_uint_ex);
	assign dif_adjacent_3 = (w31_uint_ex > w32_uint_ex) ? (w31_uint_ex - w32_uint_ex) : (w32_uint_ex - w31_uint_ex);
	assign dif_adjacent_4 = (w33_uint_ex > w32_uint_ex) ? (w33_uint_ex - w32_uint_ex) : (w32_uint_ex - w33_uint_ex);
	assign dif_adjacent_5 = (w11_uint_ex > w21_uint_ex) ? (w11_uint_ex - w21_uint_ex) : (w21_uint_ex - w11_uint_ex);
	assign dif_adjacent_6 = (w31_uint_ex > w21_uint_ex) ? (w31_uint_ex - w21_uint_ex) : (w21_uint_ex - w31_uint_ex);
	assign dif_adjacent_7 = (w13_uint_ex > w23_uint_ex) ? (w13_uint_ex - w23_uint_ex) : (w23_uint_ex - w13_uint_ex);
	assign dif_adjacent_8 = (w33_uint_ex > w23_uint_ex) ? (w33_uint_ex - w23_uint_ex) : (w23_uint_ex - w33_uint_ex);

	// Compare Stage 1
	reg [WIDTH-1:0] dif_basic_direction1_stg1, dif_basic_direction2_stg1; // 水平/垂直 or 对角线1/对角线2
	reg valid_dif_basic_direction1_stg1, valid_dif_basic_direction2_stg1;
	reg dir_type1_stg1, dir_type2_stg1; // 0:horizontal/diagonal1 1:vertical/diagonal2
	reg [1:0] basic_valid_num_stg1;
	reg [WIDTH:0] mean_basic1_stg1, mean_basic2_stg1;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			dif_basic_direction1_stg1 <= 0;
			dif_basic_direction2_stg1 <= 0;
			valid_dif_basic_direction1_stg1 <= 0;
			valid_dif_basic_direction2_stg1 <= 0;
			dir_type1_stg1 <= 0;
			dir_type2_stg1 <= 0;
			basic_valid_num_stg1 <= 0;
			mean_basic1_stg1 <= 0;
			mean_basic2_stg1 <= 0;
		end
		else if (in_valid) begin
			// 水平/垂直方向比较: 优先选有效的,都有效时选差值小的
			valid_dif_basic_direction1_stg1 <= valid_horizontal | valid_vertical;
			if (!valid_horizontal && !valid_vertical) begin
				dif_basic_direction1_stg1 <= {WIDTH{1'b1}};  // 都无效时置最大值
				dir_type1_stg1 <= 1'b0;
				mean_basic1_stg1 <= 0;
			end else if (!valid_horizontal) begin
				dif_basic_direction1_stg1 <= diff_vertical;
				dir_type1_stg1 <= 1'b1;
				mean_basic1_stg1 <= mean_vertical;
			end else if (!valid_vertical) begin
				dif_basic_direction1_stg1 <= diff_horizontal;
				dir_type1_stg1 <= 1'b0;
				mean_basic1_stg1 <= mean_horizontal;
			end else begin
				dif_basic_direction1_stg1 <= (diff_horizontal < diff_vertical) ? diff_horizontal : diff_vertical;
				dir_type1_stg1 <= (diff_horizontal < diff_vertical) ? 1'b0 : 1'b1;
				mean_basic1_stg1 <= (diff_horizontal < diff_vertical) ? mean_horizontal : mean_vertical;
			end
			
			// 对角线1/对角线2方向比较: 优先选有效的,都有效时选差值小的
			valid_dif_basic_direction2_stg1 <= valid_d1 | valid_d2;
			if (!valid_d1 && !valid_d2) begin
				dif_basic_direction2_stg1 <= {WIDTH{1'b1}};  // 都无效时置最大值
				dir_type2_stg1 <= 1'b0;
				mean_basic2_stg1 <= 0;
			end else if (!valid_d1) begin
				dif_basic_direction2_stg1 <= diff_d2;
				dir_type2_stg1 <= 1'b1;
				mean_basic2_stg1 <= mean_d2;
			end else if (!valid_d2) begin
				dif_basic_direction2_stg1 <= diff_d1;
				dir_type2_stg1 <= 1'b0;
				mean_basic2_stg1 <= mean_d1;
			end else begin
				dif_basic_direction2_stg1 <= (diff_d1 < diff_d2) ? diff_d1 : diff_d2;
				dir_type2_stg1 <= (diff_d1 < diff_d2) ? 1'b0 : 1'b1;
				mean_basic2_stg1 <= (diff_d1 < diff_d2) ? mean_d1 : mean_d2;
			end
			
			basic_valid_num_stg1 <= valid_horizontal + valid_vertical + valid_d1 + valid_d2;
		end
	end	

	// 左上加上, 右上加上, 左下加下, 右下加下, 左上加左, 左下加左, 右上加右, 右下加右
	reg [WIDTH-1:0] dif_adjacent_direction1_stg1, dif_adjacent_direction2_stg1, dif_adjacent_direction3_stg1, dif_adjacent_direction4_stg1;
	reg valid_dif_adjacent_direction1_stg1, valid_dif_adjacent_direction2_stg1, valid_dif_adjacent_direction3_stg1, valid_dif_adjacent_direction4_stg1;
	reg dir_type1_adj_stg1, dir_type2_adj_stg1, dir_type3_adj_stg1, dir_type4_adj_stg1; // 对应如上
	reg [WIDTH-1:0] adjacent_mean1_stg1, adjacent_mean2_stg1, adjacent_mean3_stg1, adjacent_mean4_stg1;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			dif_adjacent_direction1_stg1 <= 0;
			dif_adjacent_direction2_stg1 <= 0;
			dif_adjacent_direction3_stg1 <= 0;
			dif_adjacent_direction4_stg1 <= 0;
			valid_dif_adjacent_direction1_stg1 <= 0;
			valid_dif_adjacent_direction2_stg1 <= 0;
			valid_dif_adjacent_direction3_stg1 <= 0;
			valid_dif_adjacent_direction4_stg1 <= 0;
			dir_type1_adj_stg1 <= 0;
			dir_type2_adj_stg1 <= 0;
			dir_type3_adj_stg1 <= 0;
			dir_type4_adj_stg1 <= 0;
			adjacent_mean1_stg1 <= 0; adjacent_mean2_stg1 <= 0; adjacent_mean3_stg1 <= 0; adjacent_mean4_stg1 <= 0;
		end
		else if (in_valid) begin
			// 邻接方向组1: 左上+上 vs 右上+上
			valid_dif_adjacent_direction1_stg1 <= valid_1112 | valid_1213;
			if (!valid_1112 && !valid_1213) begin
				dif_adjacent_direction1_stg1 <= {WIDTH{1'b1}};
				dir_type1_adj_stg1 <= 1'b0;
				adjacent_mean1_stg1 <= 0;
			end else if (!valid_1112) begin
				dif_adjacent_direction1_stg1 <= dif_adjacent_2;
				dir_type1_adj_stg1 <= 1'b1;
				adjacent_mean1_stg1 <= w23_uint_ex;
			end else if (!valid_1213) begin
				dif_adjacent_direction1_stg1 <= dif_adjacent_1;
				dir_type1_adj_stg1 <= 1'b0;
				adjacent_mean1_stg1 <= w21_uint_ex;
			end else begin
				dif_adjacent_direction1_stg1 <= (dif_adjacent_1 < dif_adjacent_2) ? dif_adjacent_1 : dif_adjacent_2;
				dir_type1_adj_stg1 <= (dif_adjacent_1 < dif_adjacent_2) ? 1'b0 : 1'b1;
				adjacent_mean1_stg1 <= (dif_adjacent_1 < dif_adjacent_2) ? w21_uint_ex : w23_uint_ex;
			end
			
			// 邻接方向组2: 左下+下 vs 右下+下
			valid_dif_adjacent_direction2_stg1 <= valid_3132 | valid_3233;
			if (!valid_3132 && !valid_3233) begin
				dif_adjacent_direction2_stg1 <= {WIDTH{1'b1}};
				dir_type2_adj_stg1 <= 1'b0;
				adjacent_mean2_stg1 <= 0;
			end else if (!valid_3132) begin
				dif_adjacent_direction2_stg1 <= dif_adjacent_4;
				dir_type2_adj_stg1 <= 1'b1;
				adjacent_mean2_stg1 <= w23_uint_ex;
			end else if (!valid_3233) begin
				dif_adjacent_direction2_stg1 <= dif_adjacent_3;
				dir_type2_adj_stg1 <= 1'b0;
				adjacent_mean2_stg1 <= w21_uint_ex;
			end else begin
				dif_adjacent_direction2_stg1 <= (dif_adjacent_3 < dif_adjacent_4) ? dif_adjacent_3 : dif_adjacent_4;
				dir_type2_adj_stg1 <= (dif_adjacent_3 < dif_adjacent_4) ? 1'b0 : 1'b1;
				adjacent_mean2_stg1 <= (dif_adjacent_3 < dif_adjacent_4) ? w21_uint_ex : w23_uint_ex;
			end
			
			// 邻接方向组3: 左上+左 vs 左下+左
			valid_dif_adjacent_direction3_stg1 <= valid_1121 | valid_2131;
			if (!valid_1121 && !valid_2131) begin
				dif_adjacent_direction3_stg1 <= {WIDTH{1'b1}};
				dir_type3_adj_stg1 <= 1'b0;
				adjacent_mean3_stg1 <= 0;
			end else if (!valid_1121) begin
				dif_adjacent_direction3_stg1 <= dif_adjacent_6;
				dir_type3_adj_stg1 <= 1'b1;
				adjacent_mean3_stg1 <= w32_uint_ex;
			end else if (!valid_2131) begin
				dif_adjacent_direction3_stg1 <= dif_adjacent_5;
				dir_type3_adj_stg1 <= 1'b0;
				adjacent_mean3_stg1 <= w12_uint_ex;
			end else begin
				dif_adjacent_direction3_stg1 <= (dif_adjacent_5 < dif_adjacent_6) ? dif_adjacent_5 : dif_adjacent_6;
				dir_type3_adj_stg1 <= (dif_adjacent_5 < dif_adjacent_6) ? 1'b0 : 1'b1;
				adjacent_mean3_stg1 <= (dif_adjacent_5 < dif_adjacent_6) ? w12_uint_ex : w32_uint_ex;
			end
			
			// 邻接方向组4: 右上+右 vs 右下+右
			valid_dif_adjacent_direction4_stg1 <= valid_1323 | valid_2333;
			if (!valid_1323 && !valid_2333) begin
				dif_adjacent_direction4_stg1 <= {WIDTH{1'b1}};
				dir_type4_adj_stg1 <= 1'b0;
				adjacent_mean4_stg1 <= 0;
			end else if (!valid_1323) begin
				dif_adjacent_direction4_stg1 <= dif_adjacent_8;
				dir_type4_adj_stg1 <= 1'b1;
				adjacent_mean4_stg1 <= w32_uint_ex;
			end else if (!valid_2333) begin
				dif_adjacent_direction4_stg1 <= dif_adjacent_7;
				dir_type4_adj_stg1 <= 1'b0;
				adjacent_mean4_stg1 <= w12_uint_ex;
			end else begin
				dif_adjacent_direction4_stg1 <= (dif_adjacent_7 < dif_adjacent_8) ? dif_adjacent_7 : dif_adjacent_8;
				dir_type4_adj_stg1 <= (dif_adjacent_7 < dif_adjacent_8) ? 1'b0 : 1'b1;
				adjacent_mean4_stg1 <= (dif_adjacent_7 < dif_adjacent_8) ? w12_uint_ex : w32_uint_ex;
			end
		end
	end

	// Compare Stage 2
	reg [WIDTH-1:0] dif_basic_direction_stg2;
	reg valid_dif_basic_direction_stg2;
	reg [1:0] dir_type_stg2; // 0:horizantal 1:vertical 2:diagonal1 3:diagonal2
	reg [1:0] basic_valid_num_stg2;
	reg [WIDTH:0] mean_basic_stg2;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			dif_basic_direction_stg2 <= 0;
			valid_dif_basic_direction_stg2 <= 0;
			dir_type_stg2 <= 0;
			basic_valid_num_stg2 <= 0;
			mean_basic_stg2 <= 0;
		end
		else if (in_valid) begin
			valid_dif_basic_direction_stg2 <= valid_dif_basic_direction1_stg1 | valid_dif_basic_direction2_stg1;
			
			// 基本方向最终比较: 优先选有效的,都有效时选差值小的
			if (!valid_dif_basic_direction1_stg1 && !valid_dif_basic_direction2_stg1) begin
				dif_basic_direction_stg2 <= {WIDTH{1'b1}};
				dir_type_stg2 <= 2'b00;
				mean_basic_stg2 <= 0;
			end else if (!valid_dif_basic_direction1_stg1) begin
				dif_basic_direction_stg2 <= dif_basic_direction2_stg1;
				dir_type_stg2 <= dir_type2_stg1 + 2'd2;
				mean_basic_stg2 <= mean_basic2_stg1;
			end else if (!valid_dif_basic_direction2_stg1) begin
				dif_basic_direction_stg2 <= dif_basic_direction1_stg1;
				dir_type_stg2 <= dir_type1_stg1;
				mean_basic_stg2 <= mean_basic1_stg1;
			end else begin
				dif_basic_direction_stg2 <= (dif_basic_direction1_stg1 < dif_basic_direction2_stg1) ? dif_basic_direction1_stg1 : dif_basic_direction2_stg1;
				dir_type_stg2 <= (dif_basic_direction1_stg1 < dif_basic_direction2_stg1) ? dir_type1_stg1 : (dir_type2_stg1 + 2'd2);
				mean_basic_stg2 <= (dif_basic_direction1_stg1 < dif_basic_direction2_stg1) ? mean_basic1_stg1 : mean_basic2_stg1;
			end
			
			basic_valid_num_stg2 <= basic_valid_num_stg1;
		end
	end

	reg [WIDTH-1:0] dif_adjacent_direction1_stg2, dif_adjacent_direction2_stg2;
	reg valid_dif_adjacent_direction1_stg2, valid_dif_adjacent_direction2_stg2;
	reg [1:0] dir_type_adj_stg2; // 对应如上
	reg [WIDTH-1:0] adjacent_mean1_stg2, adjacent_mean2_stg2;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			dif_adjacent_direction1_stg2 <= 0;
			dif_adjacent_direction2_stg2 <= 0;
			valid_dif_adjacent_direction1_stg2 <= 0;
			valid_dif_adjacent_direction2_stg2 <= 0;
			dir_type_adj_stg2 <= 0;
			adjacent_mean1_stg2 <= 0;
			adjacent_mean2_stg2 <= 0;
		end
		else if (in_valid) begin
			// 邻接方向组合1: 上方组 vs 下方组
			valid_dif_adjacent_direction1_stg2 <= valid_dif_adjacent_direction1_stg1 | valid_dif_adjacent_direction2_stg1;
			if (!valid_dif_adjacent_direction1_stg1 && !valid_dif_adjacent_direction2_stg1) begin
				dif_adjacent_direction1_stg2 <= {WIDTH{1'b1}};
				adjacent_mean1_stg2 <= 0;
			end else if (!valid_dif_adjacent_direction1_stg1) begin
				dif_adjacent_direction1_stg2 <= dif_adjacent_direction2_stg1;
				adjacent_mean1_stg2 <= adjacent_mean2_stg1;
			end else if (!valid_dif_adjacent_direction2_stg1) begin
				dif_adjacent_direction1_stg2 <= dif_adjacent_direction1_stg1;
				adjacent_mean1_stg2 <= adjacent_mean1_stg1;
			end else begin
				dif_adjacent_direction1_stg2 <= (dif_adjacent_direction1_stg1 < dif_adjacent_direction2_stg1) ? dif_adjacent_direction1_stg1 : dif_adjacent_direction2_stg1;
				adjacent_mean1_stg2 <= (dif_adjacent_direction1_stg1 < dif_adjacent_direction2_stg1) ? adjacent_mean1_stg1 : adjacent_mean2_stg1;
			end
			
			// 邻接方向组合2: 左侧组 vs 右侧组
			valid_dif_adjacent_direction2_stg2 <= valid_dif_adjacent_direction3_stg1 | valid_dif_adjacent_direction4_stg1;
			if (!valid_dif_adjacent_direction3_stg1 && !valid_dif_adjacent_direction4_stg1) begin
				dif_adjacent_direction2_stg2 <= {WIDTH{1'b1}};
				adjacent_mean2_stg2 <= 0;
			end else if (!valid_dif_adjacent_direction3_stg1) begin
				dif_adjacent_direction2_stg2 <= dif_adjacent_direction4_stg1;
				adjacent_mean2_stg2 <= adjacent_mean4_stg1;
			end else if (!valid_dif_adjacent_direction4_stg1) begin
				dif_adjacent_direction2_stg2 <= dif_adjacent_direction3_stg1;
				adjacent_mean2_stg2 <= adjacent_mean3_stg1;
			end else begin
				dif_adjacent_direction2_stg2 <= (dif_adjacent_direction3_stg1 < dif_adjacent_direction4_stg1) ? dif_adjacent_direction3_stg1 : dif_adjacent_direction4_stg1;
				adjacent_mean2_stg2 <= (dif_adjacent_direction3_stg1 < dif_adjacent_direction4_stg1) ? adjacent_mean3_stg1 : adjacent_mean4_stg1;
			end
			
			dir_type_adj_stg2 <= (dif_adjacent_direction1_stg1 < dif_adjacent_direction2_stg1) ? dir_type1_adj_stg1 : (dir_type2_adj_stg1 + 2'd2);
		end
	end

	// Compare Stage 3
	reg [WIDTH-1:0] dif_adjacent_direction_stg3;
	reg valid_dif_adjacent_direction_stg3;
	reg [2:0] dir_type_adj_stg3; // 对应如上
	reg [WIDTH-1:0] adjacent_mean_stg3;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			dif_adjacent_direction_stg3 <= 0;
			valid_dif_adjacent_direction_stg3 <= 0;
			dir_type_adj_stg3 <= 0;
			adjacent_mean_stg3 <= 0;
		end
		else if (in_valid) begin
			valid_dif_adjacent_direction_stg3 <= valid_dif_adjacent_direction1_stg2 | valid_dif_adjacent_direction2_stg2;
			
			// 邻接方向最终比较
			if (!valid_dif_adjacent_direction1_stg2 && !valid_dif_adjacent_direction2_stg2) begin
				dif_adjacent_direction_stg3 <= {WIDTH{1'b1}};
				dir_type_adj_stg3 <= 3'b000;
				adjacent_mean_stg3 <= 0;
			end else if (!valid_dif_adjacent_direction1_stg2) begin
				dif_adjacent_direction_stg3 <= dif_adjacent_direction2_stg2;
				dir_type_adj_stg3 <= dir_type_adj_stg2 + 3'd4;
				adjacent_mean_stg3 <= adjacent_mean2_stg2;
			end else if (!valid_dif_adjacent_direction2_stg2) begin
				dif_adjacent_direction_stg3 <= dif_adjacent_direction1_stg2;
				dir_type_adj_stg3 <= dir_type_adj_stg2;
				adjacent_mean_stg3 <= adjacent_mean1_stg2;
			end else begin
				dif_adjacent_direction_stg3 <= (dif_adjacent_direction1_stg2 < dif_adjacent_direction2_stg2) ? dif_adjacent_direction1_stg2 : dif_adjacent_direction2_stg2;
				dir_type_adj_stg3 <= (dif_adjacent_direction1_stg2 < dif_adjacent_direction2_stg2) ? dir_type_adj_stg2 : (dir_type_adj_stg2 + 3'd4);
				adjacent_mean_stg3 <= (dif_adjacent_direction1_stg2 < dif_adjacent_direction2_stg2) ? adjacent_mean1_stg2 : adjacent_mean2_stg2;
			end
		end
	end

	reg [WIDTH-1:0] dif_basic_direction_stg3;
	reg valid_dif_basic_direction_stg3;
	reg [1:0] dir_type_stg3; 
	reg [1:0] basic_valid_num_stg3;
	reg [WIDTH:0] basic_mean_stg3;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			dif_basic_direction_stg3 <= 0;
			valid_dif_basic_direction_stg3 <= 0;
			dir_type_stg3 <= 0;
			basic_valid_num_stg3 <= 0;
			basic_mean_stg3 <= 0;
		end
		else if (in_valid) begin
			valid_dif_basic_direction_stg3 <= valid_dif_basic_direction_stg2;
			dif_basic_direction_stg3 <= dif_basic_direction_stg2;
			dir_type_stg3 <= dir_type_stg2;
			basic_valid_num_stg3 <= basic_valid_num_stg2;
			basic_mean_stg3 <= mean_basic_stg2;
		end
	end

	// Compare Stage 4
	reg [WIDTH-1:0] final_bp;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			final_bp <= 0;
		end
		else if (in_valid) begin
			if (basic_valid_num_stg3 >= 'd2) begin
				final_bp <= basic_mean_stg3[WIDTH-1:0];
			end
			else begin
				final_bp <= (dif_basic_direction_stg3 < dif_adjacent_direction_stg3) ? basic_mean_stg3[WIDTH-1:0] : adjacent_mean_stg3;
			end
		end
	end

	// 输出选择器：如果中心是坏点，输出均值；否则输出原始值
	reg [WIDTH-1:0] output_data;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			output_data <= 0;
		end
		else if (in_valid) begin
			output_data <= w22_flag_delay[3] ? {final_bp} : {w22_delay[3]};
		end
	end

	// 坐标延迟对齐
	integer i;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			for (i=0; i<LATENCY_FILTER_FUNC; i=i+1) begin
				hcnt_r[i] <= 0;
				vcnt_r[i] <= 0;
				w22_delay[i] <= 0;
				w22_flag_delay[i] <= 0;
			end
		end
		else if (in_valid) begin
			hcnt_r[0] <= in_hcnt;
			vcnt_r[0] <= in_vcnt;
			w22_delay[0] <= w22_uint_ex;
			w22_flag_delay[0] <= w22_flag;
			for (i=1; i<LATENCY_FILTER_FUNC; i=i+1) begin
				hcnt_r[i] <= hcnt_r[i-1];
				vcnt_r[i] <= vcnt_r[i-1];
				w22_delay[i] <= w22_delay[i-1];
				w22_flag_delay[i] <= w22_flag_delay[i-1];
			end
		end
	end

	// in_valid延迟对齐
	reg in_valid_delay[0:LATENCY_FILTER_FUNC-1];
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			for (i=0; i<LATENCY_FILTER_FUNC; i=i+1) begin
				in_valid_delay[i] <= 0;
			end
		end
		else begin
			in_valid_delay[0] <= in_valid;
			for (i=1; i<LATENCY_FILTER_FUNC; i=i+1) begin
				in_valid_delay[i] <= in_valid_delay[i-1];
			end
		end
	end

	assign shift = in_valid && (hcnt_r[LATENCY_FILTER_FUNC-2] == width_bad) && (vcnt_r[LATENCY_FILTER_FUNC-2] == height_bad);

	assign F_data = output_data;  // {is_bad_point, pixel_data}
	
	// 输出接口
	assign out_hcnt = hcnt_r[LATENCY_FILTER_FUNC-1];
	assign out_vcnt = vcnt_r[LATENCY_FILTER_FUNC-1];
	assign out_valid = in_valid_delay[LATENCY_FILTER_FUNC-1];

    // 边界值处理
    assign w11_uint_ex = is_first_row ? (is_first_column ? w22 : w21) : (is_first_column ? w12 : w11);
    assign w12_uint_ex = is_first_row ? w22 : w12;
    assign w13_uint_ex = is_first_row ? (is_last_column ? w22 : w23) : (is_last_column ? w12 : w13);
    assign w21_uint_ex = is_first_column ? w22 : w21;
    assign w22_uint_ex = w22;
    assign w23_uint_ex = is_last_column ? w22 : w23;
    assign w31_uint_ex = is_last_row ? (is_first_column ? w22 : w21) : (is_first_column ? w32 : w31);
    assign w32_uint_ex = is_last_row ? w22 : w32;
    assign w33_uint_ex = is_last_row ? (is_last_column ? w22 : w23) : (is_last_column ? w32 : w33);

endmodule
