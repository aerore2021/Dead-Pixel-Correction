module DPC_Corrector_test #(
    parameter WIDTH = 16,                    // 像素数据位宽
    parameter K_WIDTH = 16,                  // k值位宽
    parameter CNT_WIDTH = 10,                // 坐标计数器位宽
    parameter FRAME_HEIGHT = 512,            // 帧高度
    parameter FRAME_WIDTH = 640              // 帧宽度
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
    input  wire [WIDTH-1:0]         s_axis_tdata_w11,
    input  wire [WIDTH-1:0]         s_axis_tdata_w12,
    input  wire [WIDTH-1:0]         s_axis_tdata_w13,
    input  wire [WIDTH-1:0]         s_axis_tdata_w21,
    input  wire [WIDTH-1:0]         s_axis_tdata_w23,
    input  wire [WIDTH-1:0]         s_axis_tdata_w31,
    input  wire [WIDTH-1:0]         s_axis_tdata_w32,
    input  wire [WIDTH-1:0]         s_axis_tdata_w33,
    
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
    localparam LATENCY_PADDING = 2; // 第一级
    localparam LATENCY_VLD_CNT_AND_SUM = 1; // 第二级
    localparam LATENCY_MEAN = 4; // 第三级
    localparam LATENCY_TOTAL = LATENCY_PADDING + LATENCY_VLD_CNT_AND_SUM + LATENCY_MEAN;
    localparam LATENCY_TOTAL_WIDTH = 4;

    // 内部信号定义
    wire data_valid = s_axis_tvalid & s_axis_tready & k_out_tvalid;
    
    // 从k值中提取中心像素坏点标志
    // wire center_is_bad_pixel = k_out_tdata[K_WIDTH];  // MSB为坏点标志
    // ================================================================
    // 输入坐标生成
    // ================================================================
    reg [CNT_WIDTH-1:0] x_cnt, y_cnt;
    always @(posedge aclk) begin
        if (~aresetn) begin
            x_cnt <= 'd0;
            y_cnt <= 'd0;
        end
        else begin
            if (s_axis_tvalid && s_axis_tready) begin
                if (s_axis_tlast) begin
                    x_cnt <= 'd0;
                    y_cnt <= y_cnt + 1;
                end else begin
                    x_cnt <= x_cnt + 1;
                end
            end
        end
    end
    wire is_1st_col, is_1st_row, is_last_col, is_last_row;
    wire is_2nd_col, is_2nd_row, is_last_2nd_col, is_last_2nd_row;
    assign is_1st_col = (x_cnt == 'd0);
    assign is_1st_row = (y_cnt == 'd0);
    assign is_last_col = (x_cnt == FRAME_WIDTH - 1);
    assign is_last_row = (y_cnt == FRAME_HEIGHT - 1);
    assign is_2nd_col = (x_cnt == 'd1);
    assign is_2nd_row = (y_cnt == 'd1);
    assign is_last_2nd_col = (x_cnt == FRAME_WIDTH - 2);
    assign is_last_2nd_row = (y_cnt == FRAME_HEIGHT - 2);

    // ================================================================
    // 第一级：输入padding
    // ================================================================
    reg [WIDTH-1:0] w11_r, w12_r, w13_r, w21_r, w22_r, w23_r, w31_r, w32_r, w33_r;
    reg [WIDTH-1:0] w11, w12, w13, w21, w22, w23, w31, w32, w33;
    reg is_1st_row_r, is_2nd_row_r, is_last_row_r, is_last_2nd_row_r;
    reg k11_vld_r, k12_vld_r, k13_vld_r, k21_vld_r, k22_vld_r, k23_vld_r, k31_vld_r, k32_vld_r, k33_vld_r;
    reg k11_vld_r2, k12_vld_r2, k13_vld_r2, k21_vld_r2, k22_vld_r2, k23_vld_r2, k31_vld_r2, k32_vld_r2, k33_vld_r2;
    reg data_valid_r, data_valid_r2;
    reg [K_WIDTH:0] k_out_tdata_r, k_out_tdata_r2;
    reg t1_enable, t1_enable_r;
    always @(posedge aclk) begin
        if (!aresetn) begin
            w11 <= 'd0; w12 <= 'd0; w13 <= 'd0;
            w21 <= 'd0; w22 <= 'd0; w23 <= 'd0;
            w31 <= 'd0; w32 <= 'd0; w33 <= 'd0;

            w11_r <= 'd0; w12_r <= 'd0; w13_r <= 'd0;
            w21_r <= 'd0; w22_r <= 'd0; w23_r <= 'd0;
            w31_r <= 'd0; w32_r <= 'd0; w33_r <= 'd0;

            is_1st_row_r <= 0; is_2nd_row_r <= 0; is_last_row_r <= 0; is_last_2nd_row_r <= 0;
            k11_vld_r <= 0; k12_vld_r <= 0; k13_vld_r <= 0; k21_vld_r <= 0; k22_vld_r <= 0; k23_vld_r <= 0; k31_vld_r <= 0; k32_vld_r <= 0; k33_vld_r <= 0;
            k11_vld_r2 <= 0; k12_vld_r2 <= 0; k13_vld_r2 <= 0; k21_vld_r2 <= 0; k22_vld_r2 <= 0; k23_vld_r2 <= 0; k31_vld_r2 <= 0; k32_vld_r2 <= 0; k33_vld_r2 <= 0;
            data_valid_r <= 0; data_valid_r2 <= 0;
            k_out_tdata_r <= 'd0; k_out_tdata_r2 <= 'd0;
            t1_enable <= 0; t1_enable_r <= 0;
        end

        else begin
            // step 1
            w11_r <= (is_1st_col) ? s_axis_tdata_w13 : (is_2nd_col ? s_axis_tdata_w12 : s_axis_tdata_w11);
            w21_r <= (is_1st_col) ? s_axis_tdata_w23 : (is_2nd_col ? s_axis_tdata : s_axis_tdata_w21);
            w31_r <= (is_1st_col) ? s_axis_tdata_w33 : (is_2nd_col ? s_axis_tdata_w32 : s_axis_tdata_w31);

            w12_r <= (is_1st_col) ? s_axis_tdata_w13 : (is_last_col ? s_axis_tdata_w11 : s_axis_tdata_w12);
            // w22_r <= (is_1st_col) ? s_axis_tdata_w23 : (is_last_col ? s_axis_tdata_w21 : s_axis_tdata);
            w22_r <= s_axis_tdata;
            w32_r <= (is_1st_col) ? s_axis_tdata_w33 : (is_last_col ? s_axis_tdata_w31 : s_axis_tdata_w32);

            w13_r <= (is_last_col) ? s_axis_tdata_w11 : (is_last_2nd_col ? s_axis_tdata_w12 : s_axis_tdata_w13);
            w23_r <= (is_last_col) ? s_axis_tdata_w21 : (is_last_2nd_col ? s_axis_tdata : s_axis_tdata_w23);
            w33_r <= (is_last_col) ? s_axis_tdata_w31 : (is_last_2nd_col ? s_axis_tdata_w32 : s_axis_tdata_w33);
            
            k11_vld_r <= (is_1st_col) ? k13_vld : (is_2nd_col ? k12_vld : k11_vld);
            k21_vld_r <= (is_1st_col) ? k23_vld : (is_2nd_col ? k_out_tdata[K_WIDTH] : k21_vld);
            k31_vld_r <= (is_1st_col) ? k33_vld : (is_2nd_col ? k32_vld : k31_vld);

            k12_vld_r <= (is_1st_col) ? k13_vld : (is_last_col ? k11_vld : k12_vld);
            // k22_vld_r <= (is_1st_col) ? k23_vld : (is_last_col ? k21_vld : k_out_tdata[K_WIDTH]);
            k22_vld_r <= k_out_tdata[K_WIDTH];
            k32_vld_r <= (is_1st_col) ? k33_vld : (is_last_col ? k31_vld : k32_vld);

            k13_vld_r <= (is_last_col) ? k11_vld : (is_last_2nd_col ? k12_vld : k13_vld);
            k23_vld_r <= (is_last_col) ? k21_vld : (is_last_2nd_col ? k_out_tdata[K_WIDTH] : k23_vld);
            k33_vld_r <= (is_last_col) ? k31_vld : (is_last_2nd_col ? k32_vld : k33_vld);

            // step 2
            w11 <= (is_1st_row_r) ? w31_r : (is_2nd_row_r ? w21_r : w11_r);
            w12 <= (is_1st_row_r) ? w32_r : (is_2nd_row_r ? w22_r : w12_r);
            w13 <= (is_1st_row_r) ? w33_r : (is_2nd_row_r ? w23_r : w13_r);

            w21 <= (is_1st_row_r) ? w31_r : (is_last_row_r ? w11_r : w21_r);
            // w22 <= (is_1st_row_r) ? w32_r : (is_last_row_r ? w12_r : w22_r);
            w22 <= w22_r;
            w23 <= (is_1st_row_r) ? w33_r : (is_last_row_r ? w13_r : w23_r);

            w31 <= (is_last_row_r) ? w11_r : (is_last_2nd_row_r ? w21_r : w31_r);
            w32 <= (is_last_row_r) ? w12_r : (is_last_2nd_row_r ? w22_r : w32_r);
            w33 <= (is_last_row_r) ? w13_r : (is_last_2nd_row_r ? w23_r : w33_r);
            
            k11_vld_r2 <= (is_1st_row_r) ? k31_vld_r : (is_2nd_row_r ? k21_vld_r : k11_vld_r);
            k12_vld_r2 <= (is_1st_row_r) ? k32_vld_r : (is_2nd_row_r ? k22_vld_r : k12_vld_r);
            k13_vld_r2 <= (is_1st_row_r) ? k33_vld_r : (is_2nd_row_r ? k23_vld_r : k13_vld_r);

            k21_vld_r2 <= (is_1st_row_r) ? k31_vld_r : (is_last_row_r ? k11_vld_r : k21_vld_r);
            // k22_vld_r2 <= (is_1st_row_r) ? k32_vld_r : (is_last_row_r ? k12_vld_r : k22_vld_r);
            k22_vld_r2 <= k22_vld_r;
            k23_vld_r2 <= (is_1st_row_r) ? k33_vld_r : (is_last_row_r ? k13_vld_r : k23_vld_r);

            k31_vld_r2 <= (is_last_row_r) ? k11_vld_r : (is_last_2nd_row_r ? k21_vld_r : k31_vld_r);
            k32_vld_r2 <= (is_last_row_r) ? k12_vld_r : (is_last_2nd_row_r ? k22_vld_r : k32_vld_r);
            k33_vld_r2 <= (is_last_row_r) ? k13_vld_r : (is_last_2nd_row_r ? k23_vld_r : k33_vld_r);

            // 其他信号的延迟
            is_1st_row_r <= is_1st_row; is_2nd_row_r <= is_2nd_row; 
            is_last_row_r <= is_last_row; is_last_2nd_row_r <= is_last_2nd_row;

            data_valid_r <= data_valid; data_valid_r2 <= data_valid_r;
            k_out_tdata_r <= k_out_tdata; k_out_tdata_r2 <= k_out_tdata_r;
            t1_enable_r <= enable; t1_enable <= t1_enable_r;

        end
    end

    // ================================================================
    // 第二级：邻域坏点检查和计数(并行)
    // ================================================================
    
    reg t2_data_valid;
    reg t2_center_bad;
    reg t2_enable;
    reg [WIDTH-1:0] t2_center_pixel;
    wire [3:0] t2_valid_neighbor_count;
    wire [WIDTH+3-1:0] t2_neighbor_sum;
    wire t2_pixel_mux;
    wire t2_bp_corrected;

    // 组合逻辑计算有效邻域像素 (k_vld=1表示有效像素)
    reg [3:0] valid_count;
    reg [WIDTH+3-1:0] neighbor_sum;

    always @(posedge aclk) begin
        if (~aresetn) begin
            valid_count <= 'd0;
            neighbor_sum <= 'd0;
        end
        else begin
            valid_count <= k11_vld_r2 + k12_vld_r2 + k13_vld_r2 + k21_vld_r2 + k23_vld_r2 + k31_vld_r2 + k32_vld_r2 + k33_vld_r2;
            neighbor_sum <= (k11_vld_r2 ? w11 : 0) + (k12_vld_r2 ? w12 : 0) +
                            (k13_vld_r2 ? w13 : 0) + (k21_vld_r2 ? w21 : 0) +
                            (k23_vld_r2 ? w23 : 0) + (k31_vld_r2 ? w31 : 0) +
                            (k32_vld_r2 ? w32 : 0) + (k33_vld_r2 ? w33 : 0);
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            t2_data_valid <= 0;
            t2_center_bad <= 0;
            t2_center_pixel <= 0;
        end
        else begin
            t2_data_valid <= data_valid_r2;
            t2_center_bad <= !k_out_tdata_r2[K_WIDTH];
            t2_center_pixel <= w22;
            t2_enable <= t1_enable;
        end
    end
    assign t2_valid_neighbor_count = valid_count;
    assign t2_neighbor_sum = neighbor_sum;
    assign t2_pixel_mux = t2_center_bad && t2_enable && (t2_valid_neighbor_count > 0); //如果是1，用均值校正
    assign t2_bp_corrected = t2_center_bad && t2_enable;
    // ================================================================
    // 第二级：校正值计算除法器和输出选择
    // ================================================================
    
    wire t3_data_valid;
    wire t3_bp_corrected;
    wire [WIDTH-1:0] t3_output_pixel;
    wire [WIDTH-1:0] t3_original_pixel;
    wire t3_pixel_mux;

    reg t3_data_valid_r [0:LATENCY_MEAN-1];
    reg t3_bp_corrected_r [0:LATENCY_MEAN-1];
    reg [WIDTH-1:0] t3_original_pixel_r [0:LATENCY_MEAN-1];
    reg t3_pixel_mux_r [0:LATENCY_MEAN-1];

    always @(posedge aclk) begin
        if (!aresetn) begin
            t3_data_valid_r[0] <= 0;
            t3_bp_corrected_r[0] <= 0;
            t3_original_pixel_r[0] <= 'd0;
            t3_pixel_mux_r[0] <= 0;

            t3_data_valid_r[1] <= 0;
            t3_bp_corrected_r[1] <= 0;
            t3_original_pixel_r[1] <= 'd0;
            t3_pixel_mux_r[1] <= 0;

            t3_data_valid_r[2] <= 0;
            t3_bp_corrected_r[2] <= 0;
            t3_original_pixel_r[2] <= 'd0;
            t3_pixel_mux_r[2] <= 0;

            t3_data_valid_r[3] <= 0;
            t3_bp_corrected_r[3] <= 0;
            t3_original_pixel_r[3] <= 'd0;
            t3_pixel_mux_r[3] <= 0;
        end
        else begin
            t3_data_valid_r[0] <= t2_data_valid;
            t3_bp_corrected_r[0] <= t2_bp_corrected;
            t3_original_pixel_r[0] <= t2_center_pixel;
            t3_pixel_mux_r[0] <= t2_pixel_mux;

            t3_data_valid_r[1] <= t3_data_valid_r[0];
            t3_bp_corrected_r[1] <= t3_bp_corrected_r[0];
            t3_original_pixel_r[1] <= t3_original_pixel_r[0];
            t3_pixel_mux_r[1] <= t3_pixel_mux_r[0];

            t3_data_valid_r[2] <= t3_data_valid_r[1];
            t3_bp_corrected_r[2] <= t3_bp_corrected_r[1];
            t3_original_pixel_r[2] <= t3_original_pixel_r[1];
            t3_pixel_mux_r[2] <= t3_pixel_mux_r[1];

            t3_data_valid_r[3] <= t3_data_valid_r[2];
            t3_bp_corrected_r[3] <= t3_bp_corrected_r[2];
            t3_original_pixel_r[3] <= t3_original_pixel_r[2];
            t3_pixel_mux_r[3] <= t3_pixel_mux_r[2];
        end
    end

    localparam LPM_DREPRESENTATION = "UNSIGNED";
    localparam LPM_HINT = "";
    localparam LPM_NREPRESENTATION = "UNSIGNED";
    localparam LPM_PIPLINE = LATENCY_MEAN;
    localparam LPM_TYPE = "LPM_DIVIDE";
    localparam LPM_WIDTHN = WIDTH+3;
    localparam LPM_WIDTHD = 4;
    wire clken = 1'b1;
    wire [WIDTH-1:0] t3_neighbor_vld_mean;
    
    lpm_divide #(
        .lpm_drepresentation 	(LPM_DREPRESENTATION    ),
        .lpm_hint            	(LPM_HINT            ),
        .lpm_nrepresentation 	(LPM_NREPRESENTATION    ),
        .lpm_pipeline        	(LPM_PIPLINE            ),
        .lpm_type            	(LPM_TYPE              ),
        .lpm_widthd          	(LPM_WIDTHD           ),
        .lpm_widthn          	(LPM_WIDTHN           ))
    u_lpm_divide(
        .aclr     	(~aresetn      ),
        .clock    	(aclk     ),
        .clken    	(clken     ),
        .numer    	(t2_neighbor_sum     ),
        .denom    	(t2_valid_neighbor_count     ),
        .quotient 	(t3_neighbor_vld_mean  ),
        .remain   	(    )
    );
    
    assign t3_data_valid = t3_data_valid_r[LATENCY_MEAN-1];
    assign t3_bp_corrected = t3_bp_corrected_r[LATENCY_MEAN-1];
    assign t3_original_pixel = t3_original_pixel_r[LATENCY_MEAN-1];
    assign t3_pixel_mux = t3_pixel_mux_r[LATENCY_MEAN-1];
    assign t3_output_pixel = (t3_pixel_mux) ? t3_neighbor_vld_mean : t3_original_pixel;

    // ================================================================
    // 输出接口
    // ================================================================
    reg [LATENCY_TOTAL_WIDTH-1:0] delay_cnt;
    wire delayed = (delay_cnt >= LATENCY_TOTAL);
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            delay_cnt <= 'd0;
        end
        else if (delay_cnt <= LATENCY_TOTAL) begin
            delay_cnt <= delay_cnt + 'd1;
        end
    end
    
    // ================================================================
    // 输出坐标生成
    // ================================================================
    wire frame_output_end;
    reg [CNT_WIDTH-1:0] x_cnt_out, y_cnt_out;
    always @(posedge aclk) begin
        if (~aresetn) begin
            x_cnt_out <= 'd0;
            y_cnt_out <= 'd0;
        end
        else begin
            if (m_axis_tvalid) begin
                if (m_axis_tlast) begin
                    x_cnt_out <= 'd0;
                    y_cnt_out <= y_cnt_out + 1;
                end else begin
                    x_cnt_out <= x_cnt_out + 1;
                end
            end
        end
    end

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = t3_data_valid;
    assign m_axis_tdata = t3_output_pixel;
    assign m_axis_tuser = (x_cnt_out=='d0)&&(y_cnt_out=='d0);
    assign m_axis_tlast = (x_cnt_out==FRAME_WIDTH-1);
    
    // 调试信号
    assign debug_bp_corrected = t3_bp_corrected;
    assign debug_original_pixel = t3_original_pixel;
    assign debug_corrected_pixel = t3_output_pixel;

endmodule
