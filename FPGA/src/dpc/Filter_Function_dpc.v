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
// * 计算中心像素与周围八个像素值的差；
// * 判断八个差值是否都为正值或者都为负值；
// * 如果有的为正有的为负，那么就为正常值，否则进行下一步；
// * 设置一个阈值，如果八个差值的绝对值都超过该阈值，那么就判断为坏点；
// * 判断为坏点后就用八个临近的像素值的中位值来替换当前的像素值；

module Filter_Function_dpc #(
  parameter WIDTH = 8,
  parameter CNT_WIDTH = 10,
  parameter ROW = 512,
  parameter COL = 640,
  parameter AXI_DATA_WIDTH = 32,
  parameter AXI_ADDR_WIDTH = 32,
  parameter LATENCY_FILTER_FUNC = 7
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
  input  [WIDTH-1:0] threshold,
  input 			 smooth,
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
  output [WIDTH-1+1:0] F_data

);
    localparam lpm_drepresentation = "UNSIGNED";
    localparam lpm_hint            = "";
    localparam lpm_nrepresentation = "UNSIGNED";
    localparam lpm_pipeline        = 3;
    localparam lpm_type            = "LPM_DIVIDE";
    localparam lpm_widthd          = 4;
    localparam lpm_widthn          = WIDTH+3; 


  	wire [CNT_WIDTH-1:0]width_bad;
  	wire [CNT_WIDTH-1:0]height_bad;
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

    reg        [WIDTH-1:0] w11_without_bp;
    reg        [WIDTH-1:0] w12_without_bp;
    reg        [WIDTH-1:0] w13_without_bp;
    reg        [WIDTH-1:0] w21_without_bp;
    reg        [WIDTH-1:0] w22_without_bp;
    reg        [WIDTH-1:0] w23_without_bp;
    reg        [WIDTH-1:0] w31_without_bp;
    reg        [WIDTH-1:0] w32_without_bp;
    reg        [WIDTH-1:0] w33_without_bp;

	reg 		[CNT_WIDTH-1:0]hcnt_r[0:LATENCY_FILTER_FUNC-1-1];
	reg 		[CNT_WIDTH-1:0]vcnt_r[0:LATENCY_FILTER_FUNC-1-1];

	wire 		shift;

	reg	[1:0]	window_bp_num_stg0[0:2];
	reg [3:0]	window_bp_num_stg1;
	reg [3:0]	window_gp_num;


	// 计算和step1
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			window_bp_num_stg0[0] <= 0;
			window_bp_num_stg0[1] <= 0;
			window_bp_num_stg0[2] <= 0;
			w11_without_bp <= 'd0;
			w12_without_bp <= 'd0;
			w13_without_bp <= 'd0;
			w21_without_bp <= 'd0;
			w22_without_bp <= 'd0;
			w23_without_bp <= 'd0;
			w31_without_bp <= 'd0;
			w32_without_bp <= 'd0;
			w33_without_bp <= 'd0;
			
		end
		else if (in_valid) begin
			window_bp_num_stg0[0] <= w11_flag + w12_flag + w13_flag;
			window_bp_num_stg0[1] <= w21_flag + w23_flag;
			window_bp_num_stg0[2] <= w31_flag + w32_flag + w33_flag;	
			
			w11_without_bp <= w11_flag ? 'd0 : w11_uint_ex;
			w12_without_bp <= w12_flag ? 'd0 : w12_uint_ex;
			w13_without_bp <= w13_flag ? 'd0 : w13_uint_ex;
			w21_without_bp <= w21_flag ? 'd0 : w21_uint_ex;
			w23_without_bp <= w23_flag ? 'd0 : w23_uint_ex;
			w31_without_bp <= w31_flag ? 'd0 : w31_uint_ex;
			w32_without_bp <= w32_flag ? 'd0 : w32_uint_ex;
			w33_without_bp <= w33_flag ? 'd0 : w33_uint_ex;			

		end
	end

    reg        [WIDTH-1+2:0] w1_without_bp_stg1;
    reg        [WIDTH-1+2:0] w2_without_bp_stg1;
    reg        [WIDTH-1+2:0] w3_without_bp_stg1;


	// 计算和step2
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			window_bp_num_stg1 <= 'd0;
			w1_without_bp_stg1 <= 'd0;
			w2_without_bp_stg1 <= 'd0;
			w3_without_bp_stg1 <= 'd0;
		end
		else if (in_valid) begin
			window_bp_num_stg1 <= window_bp_num_stg0[0] + window_bp_num_stg0[1] + window_bp_num_stg0[2];
			w1_without_bp_stg1 <= w11_without_bp + w12_without_bp + w13_without_bp;
			w2_without_bp_stg1 <= w21_without_bp + w23_without_bp;
			w3_without_bp_stg1 <= w31_without_bp + w32_without_bp + w33_without_bp;
		end
	end

    reg        [WIDTH-1+3:0] w_without_bp_stg2;

	// 计算和step3
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			window_gp_num <= 0;
			w_without_bp_stg2 <= 0;
		end
		else if (in_valid) begin
			window_gp_num <= 4'd8 - window_bp_num_stg1;
			w_without_bp_stg2 <= w1_without_bp_stg1 + w2_without_bp_stg1 + w3_without_bp_stg1;
		end
	end

	wire [WIDTH-1:0]w_ave;
	lpm_divide #
    (
        .lpm_drepresentation    (lpm_drepresentation ),
        .lpm_hint               (lpm_hint            ),
        .lpm_nrepresentation    (lpm_nrepresentation ),
        .lpm_pipeline           (lpm_pipeline        ),
        .lpm_type               (lpm_type            ),
        .lpm_widthd             (lpm_widthd          ),
        .lpm_widthn             (lpm_widthn          )
    )
    lpm_divide_inst
    (
        .aclr          (!aresetn),
        .clken         (in_valid),
        .clock         (aclk),
        .denom         (window_gp_num),  
        .numer         (w_without_bp_stg2),
        .quotient      (w_ave),
        .remain        ()
    );




    // 将3*3窗口的值赋给临时变量
    reg [WIDTH-1:0] t1_p1, t1_p2, t1_p3;
	reg [WIDTH-1:0] t1_p4, t1_p5, t1_p6;
	reg [WIDTH-1:0] t1_p7, t1_p8, t1_p9;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t1_p1 <= 0; t1_p2 <= 0; t1_p3 <= 0;
			t1_p4 <= 0; t1_p5 <= 0; t1_p6 <= 0;
			t1_p7 <= 0; t1_p8 <= 0; t1_p9 <= 0;
		end
		else if (in_valid) begin
            t1_p1 <= w11_uint_ex; t1_p2 <= w12_uint_ex; t1_p3 <= w13_uint_ex;
            t1_p4 <= w21_uint_ex; t1_p5 <= w22_uint_ex; t1_p6 <= w23_uint_ex;
            t1_p7 <= w31_uint_ex; t1_p8 <= w32_uint_ex; t1_p9 <= w33_uint_ex;		
		end
	end

    //中值滤波 step1
	reg [WIDTH-1:0] t2_min1, t2_med1, t2_max1;
	reg [WIDTH-1:0] t2_min2, t2_med2, t2_max2;
	reg [WIDTH-1:0] t2_min3, t2_med3, t2_max3;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t2_min1 <= 0; t2_med1 <= 0; t2_max1 <= 0;
			t2_min2 <= 0; t2_med2 <= 0; t2_max2 <= 0;
			t2_min3 <= 0; t2_med3 <= 0; t2_max3 <= 0;
		end
		else if (in_valid) begin
			t2_min1 <= min(t1_p1, t1_p2, t1_p3);
			t2_med1 <= med(t1_p1, t1_p2, t1_p3);
			t2_max1 <= max(t1_p1, t1_p2, t1_p3);
			t2_min2 <= min(t1_p4, t1_p5, t1_p6);
			t2_med2 <= med(t1_p4, t1_p5, t1_p6);
			t2_max2 <= max(t1_p4, t1_p5, t1_p6);
			t2_min3 <= min(t1_p7, t1_p8, t1_p9);
			t2_med3 <= med(t1_p7, t1_p8, t1_p9);
			t2_max3 <= max(t1_p7, t1_p8, t1_p9);
		end
	end

	//中值滤波 step2
	reg [WIDTH-1:0] t3_max_of_min, t3_med_of_med, t3_min_of_max;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t3_max_of_min <= 0; t3_med_of_med <= 0; t3_min_of_max <= 0;
		end
		else if (in_valid) begin
			t3_max_of_min <= max(t2_min1, t2_min2, t2_min3);
			t3_med_of_med <= med(t2_med1, t2_med2, t2_med3);
			t3_min_of_max <= min(t2_max1, t2_max2, t2_max3);
		end
	end

	//中值滤波 step3
	reg [WIDTH-1:0] t4_medium;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t4_medium <= 0;
		end
		else if (in_valid) begin
			t4_medium <= med(t3_max_of_min, t3_med_of_med, t3_min_of_max);
		end
	end

	//将中值打1拍对齐到坏点检测的时序
	reg [WIDTH-1:0] t5_medium;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t5_medium <= 0;
		end
		else if (in_valid) begin
			t5_medium <= t4_medium;
		end
	end

	//坏点检测 step1 (将像素值从无符号数转为有符号数: 高位补0, 表示正数)
	reg signed [WIDTH:0] t2_p1, t2_p2, t2_p3;
	reg signed [WIDTH:0] t2_p4, t2_p5, t2_p6;
	reg signed [WIDTH:0] t2_p7, t2_p8, t2_p9;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t2_p1 <= 0; t2_p2 <= 0; t2_p3 <= 0;
			t2_p4 <= 0; t2_p5 <= 0; t2_p6 <= 0;
			t2_p7 <= 0; t2_p8 <= 0; t2_p9 <= 0;
		end
		else if (in_valid) begin
			t2_p1 <= {1'b0,t1_p1}; t2_p2 <= {1'b0,t1_p2}; t2_p3 <= {1'b0,t1_p3};
			t2_p4 <= {1'b0,t1_p4}; t2_p5 <= {1'b0,t1_p5}; t2_p6 <= {1'b0,t1_p6};
			t2_p7 <= {1'b0,t1_p7}; t2_p8 <= {1'b0,t1_p8}; t2_p9 <= {1'b0,t1_p9};
		end
	end

	//坏点检测 step2 (计算中心像素与周围八个像素值的差)
	reg [WIDTH-1:0] t3_center;
	reg signed [WIDTH:0] t3_diff1, t3_diff2, t3_diff3, t3_diff4, t3_diff5, t3_diff6, t3_diff7, t3_diff8;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t3_center <= 0;
			t3_diff1 <= 0; t3_diff2 <= 0;
			t3_diff3 <= 0; t3_diff4 <= 0;
			t3_diff5 <= 0; t3_diff6 <= 0;
			t3_diff7 <= 0; t3_diff8 <= 0;
		end
		else if (in_valid) begin
			t3_center <= t2_p5[WIDTH-1:0];
			t3_diff1 <= t2_p5 - t2_p1;
			t3_diff2 <= t2_p5 - t2_p2;
			t3_diff3 <= t2_p5 - t2_p3;
			t3_diff4 <= t2_p5 - t2_p4;
			t3_diff5 <= t2_p5 - t2_p6;
			t3_diff6 <= t2_p5 - t2_p7;
			t3_diff7 <= t2_p5 - t2_p8;
			t3_diff8 <= t2_p5 - t2_p9;
		end
	end

	//坏点检测 step3 (判断差值是否都为正或都为负,并计算差值绝对值)
	reg t4_defective_pix;
	reg [WIDTH-1:0] t4_center;
	reg [WIDTH-1:0] t4_diff1, t4_diff2, t4_diff3, t4_diff4, t4_diff5, t4_diff6, t4_diff7, t4_diff8;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t4_defective_pix <= 0;
			t4_center <= 0;
			t4_diff1 <= 0; t4_diff2 <= 0;
			t4_diff3 <= 0; t4_diff4 <= 0;
			t4_diff5 <= 0; t4_diff6 <= 0;
			t4_diff7 <= 0; t4_diff8 <= 0;
		end
		else if (in_valid) begin
			t4_center <= t3_center;
			// 判断差值是否都为正或都为负
			t4_defective_pix <= smooth ? ((8'b0000_0000 == {t3_diff1[WIDTH],t3_diff2[WIDTH],t3_diff3[WIDTH],t3_diff4[WIDTH],t3_diff5[WIDTH],t3_diff6[WIDTH],t3_diff7[WIDTH],t3_diff8[WIDTH]})
							 || (8'b1111_1111 == {t3_diff1[WIDTH],t3_diff2[WIDTH],t3_diff3[WIDTH],t3_diff4[WIDTH],t3_diff5[WIDTH],t3_diff6[WIDTH],t3_diff7[WIDTH],t3_diff8[WIDTH]})) : 1;
			// 判断符号位(最高位)是否为1(负数)
			t4_diff1 <= t3_diff1[WIDTH] ? 1'sd0 - t3_diff1 : t3_diff1;
			t4_diff2 <= t3_diff2[WIDTH] ? 1'sd0 - t3_diff2 : t3_diff2;
			t4_diff3 <= t3_diff3[WIDTH] ? 1'sd0 - t3_diff3 : t3_diff3;
			t4_diff4 <= t3_diff4[WIDTH] ? 1'sd0 - t3_diff4 : t3_diff4;
			t4_diff5 <= t3_diff5[WIDTH] ? 1'sd0 - t3_diff5 : t3_diff5;
			t4_diff6 <= t3_diff6[WIDTH] ? 1'sd0 - t3_diff6 : t3_diff6;
			t4_diff7 <= t3_diff7[WIDTH] ? 1'sd0 - t3_diff7 : t3_diff7;
			t4_diff8 <= t3_diff8[WIDTH] ? 1'sd0 - t3_diff8 : t3_diff8;
		end
	end

	//坏点检测 step4 (判断差值的绝对值是否都超过阈值)
	reg t5_defective_pix;
	reg [WIDTH-1:0] t5_center;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t5_defective_pix <= 0;
			t5_center <= 0;
		end
		else if (in_valid) begin
			t5_center <= t4_center; 
			t5_defective_pix <= t4_defective_pix && (smooth ? (t4_diff1 > threshold && t4_diff2 > threshold 
								&& t4_diff3 > threshold && t4_diff4 > threshold && t4_diff5 > threshold 
								&& t4_diff6 > threshold && t4_diff7 > threshold && t4_diff8 > threshold) : 1);
		end
	end

	// 坏点检测 step5 判断坏点条件是否成立
	// 1. t5_defective_pix
	// 2. threshold不等于0, threshold=0不开启坏点替换, 意思是所有点都不是坏点
	// 3. smooth=1, 平缓模式
	// 4. smooth=0, 强力模式
	reg t6_defective_pix;
	reg [WIDTH-1:0] t6_center;
	reg [WIDTH-1:0] t6_medium;

	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t6_defective_pix <= 0;
			t6_center <= 0;
			t6_medium <= 0;
		end
		else if (in_valid) begin
			t6_center <= t5_center; 
			t6_medium <= t5_medium;
			t6_defective_pix <= t5_defective_pix && 
								threshold &&
								(smooth || 
								(~smooth && ((t5_center >= t5_medium && t5_center - t5_medium > threshold) || 
								(t5_center <= t5_medium && t5_medium - t5_center > threshold) )));
		end
	end

	// 坏点检测 step6 (如果是坏点, 输出中值滤波后的像素值; 非坏点或关闭坏点替换功能时, 输出原像素值)
	reg [WIDTH-1:0] t7_center;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t7_center <= 0;
		end
		else if (in_valid) begin
			// 如果threshold为0, 那么不做坏点替换.
			// 如果没开启强力模式, 那么判断该点是否被标记为坏点.
			// 如果开启了强力模式, 那么判断中心像素值和3*3窗口的中位数差值是否大于阈值, 若大于则为坏点.
			t7_center <= shift ? w_ave : t6_defective_pix ? t6_medium : t6_center;
		end
	end

	integer i;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			for (i=0; i<LATENCY_FILTER_FUNC-1; i=i+1) begin
				hcnt_r[i] <= 0;
				vcnt_r[i] <= 0;
			end
		end
		else if (in_valid) begin
			hcnt_r[0] <= in_hcnt;
			vcnt_r[0] <= in_vcnt;
			for (i=1; i<LATENCY_FILTER_FUNC-1; i=i+1) begin
				hcnt_r[i] <= hcnt_r[i-1];
				vcnt_r[i] <= vcnt_r[i-1];
			end
		end
	end

	assign shift = in_valid && (hcnt_r[LATENCY_FILTER_FUNC-2] == width_bad) && (vcnt_r[LATENCY_FILTER_FUNC-2] == height_bad);

	manual #(
		.WIDTH_BITS		(CNT_WIDTH),
		.HEIGHT_BITS  	(CNT_WIDTH),
		.BAD_POINT_MUN  (128),
		.BAD_POINT_BIT  (7)

	)manual_inst(
		.clk		(aclk),
		.S_AXI_ACLK	(S_AXI_ACLK),
		.rst_n		(aresetn),
		.shift		(shift),
		.width_bad	(width_bad),
		.height_bad	(height_bad),
		.bad_point_num(bad_point_num),
		.wen_lut	(wen_lut),
		.waddr_lut	(waddr_lut),
		.wdata_lut	(wdata_lut)
	);




	assign F_data = t7_center;

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

    // 最小值函数
	function [WIDTH-1:0] min;
		input [WIDTH-1:0] a, b, c;
		begin
			min = (a < b) ? ((a < c) ? a : c) : ((b < c) ? b : c);
		end
	endfunction

    // 中值函数
	function [WIDTH-1:0] med;
		input [WIDTH-1:0] a, b, c;
		begin
			med = (a < b) ? ((b < c) ? b : (a < c ? c : a)) : ((b > c) ? b : (a > c ? c : a));
		end
	endfunction

    // 最大值函数
	function [WIDTH-1:0] max;
		input [WIDTH-1:0] a, b, c;
		begin
			max = (a > b) ? ((a > c) ? a : c) : ((b > c) ? b : c);
		end
	endfunction

endmodule
