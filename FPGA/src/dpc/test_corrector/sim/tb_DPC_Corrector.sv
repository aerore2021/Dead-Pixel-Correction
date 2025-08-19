/*
 * DPC_Corrector Testbench
 *
 * 设计目标：
 * - 复用 detector 的测试输入（像素流和 k 值），实例化 Detector 和 Corrector
 * - 在发送每个像素时采样 Detector 的窗口和 k_vld 标志，基于这些信号计算期望输出
 * - 当 Corrector 输出有效像素时，与期望输出按顺序比较，统计校正误差和检测准确率
 *
 * 验证项：
 * 1) 坏点判断是否准确（Detector 输出的中心坏点标志 vs 预设的坏点列表）
 * 2) 校正是否准确（Corrector 输出 vs 用 Detector 提供的窗口和 k_vld 计算的期望值）
 */

`timescale 1ns/1ps

module tb_DPC_Corrector();

    // 参数（与 detector TB 保持一致，使用小图像便于仿真）
    parameter WIDTH = 16;
    parameter K_WIDTH = 16;
    parameter CNT_WIDTH = 10;
    parameter FRAME_HEIGHT = 20;
    parameter FRAME_WIDTH = 20;
    parameter THRESHOLD_AUTO = 300;
    parameter THRESHOLD_MANUAL = 150;
    parameter CLK_PERIOD = 10;
    parameter AXI_CLK_PERIOD = 5;
    parameter LATENCY = 2; // 与 DPC_Corrector 的默认一致

    // 时钟与复位
    reg aclk;
    reg aresetn;
    reg S_AXI_ACLK;

    // 像素/ k 流
    reg s_axis_tvalid;
    wire s_axis_tready;
    reg [WIDTH-1:0] s_axis_tdata;
    reg s_axis_tuser;
    reg s_axis_tlast;

    reg k_axis_tvalid;
    reg [K_WIDTH-1:0] k_axis_tdata;

    // Corrector 输出接口
    reg m_axis_tready;
    wire m_axis_tvalid;
    wire [WIDTH-1:0] m_axis_tdata;
    wire m_axis_tuser;
    wire m_axis_tlast;

    // Detector -> Corrector 窗口与 k_out 信号
    wire [WIDTH-1:0] w11, w12, w13;
    wire [WIDTH-1:0] w21, w23;
    wire [WIDTH-1:0] w31, w32, w33;

    wire k_out_tvalid;
    wire [K_WIDTH:0] k_out_tdata;
    wire k11_vld, k12_vld, k13_vld;
    wire k21_vld, k23_vld;
    wire k31_vld, k32_vld, k33_vld;

    // 配置接口
    reg enable;
    reg [K_WIDTH-1:0] k_threshold;

    // 手动坏点表接口（复用 detector setup）
    reg [6:0] manual_bp_num;
    reg manual_wen;
    reg [6:0] manual_waddr;
    reg [31:0] manual_wdata;

    // 自动坏点输出（用于记录检测坐标）
    wire auto_bp_valid;
    wire [CNT_WIDTH-1:0] auto_bp_x;
    wire [CNT_WIDTH-1:0] auto_bp_y;
    reg [7:0] auto_bp_read_addr;
    wire [31:0] auto_bp_read_data;

    // 状态监控
    wire frame_detection_done;
    wire [7:0] detected_bp_count;
    wire delayed;

    // 测试数据存储（与 detector TB 对齐）
    reg [WIDTH-1:0] test_image [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    reg [K_WIDTH-1:0] test_k_values [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];

    // 预设的坏点列表（与 detector TB 一致）
    reg [4:0] bad_pixel_x [0:2];
    reg [4:0] bad_pixel_y [0:2];
    reg [4:0] manual_pixel_x [0:2];
    reg [4:0] manual_pixel_y [0:2];
    integer manual_pixel_count;

    // 控制与计数
    integer row, col;
    integer frame_count;
    integer pixel_index;

    // 用于验证的队列：在发送像素时采样 detector 提供的窗口与 k_vld，并计算期望输出
    // 使用线性索引 idx = y*FRAME_WIDTH + x
    integer total_pixels = FRAME_WIDTH * FRAME_HEIGHT;
    reg [WIDTH-1:0] expected_output [0:4095]; // 支持最大像素数
    reg expected_is_bad [0:4095]; // 期望中心是否被判为坏点（根据预设坏点列表）
    reg detected_by_detector [0:4095]; // detector 实际标记

    // 保存 detector 在采样时提供的窗口与 k_vld 用于计算期望
    reg [WIDTH-1:0] sampled_w11 [0:4095];
    reg [WIDTH-1:0] sampled_w12 [0:4095];
    reg [WIDTH-1:0] sampled_w13 [0:4095];
    reg [WIDTH-1:0] sampled_w21 [0:4095];
    reg [WIDTH-1:0] sampled_w23 [0:4095];
    reg [WIDTH-1:0] sampled_w31 [0:4095];
    reg [WIDTH-1:0] sampled_w32 [0:4095];
    reg [WIDTH-1:0] sampled_w33 [0:4095];
    reg sampled_k11_vld [0:4095];
    reg sampled_k12_vld [0:4095];
    reg sampled_k13_vld [0:4095];
    reg sampled_k21_vld [0:4095];
    reg sampled_k23_vld [0:4095];
    reg sampled_k31_vld [0:4095];
    reg sampled_k32_vld [0:4095];
    reg sampled_k33_vld [0:4095];

    // 记录发送顺序和输出顺序
    integer send_count;
    integer out_count;

    // 实例化被测模块：Detector + Corrector
    DPC_Detector_test #(
        .WIDTH(WIDTH),
        .K_WIDTH(K_WIDTH),
        .CNT_WIDTH(CNT_WIDTH),
        .MANUAL_BP_NUM(128),
        .MANUAL_BP_BIT(7),
        .AUTO_BP_NUM(256),
        .AUTO_BP_BIT(8),
        .THRESHOLD_AUTO(THRESHOLD_AUTO),
        .THRESHOLD_MANUAL(THRESHOLD_MANUAL),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .FRAME_WIDTH(FRAME_WIDTH)
    ) detector (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        .k_axis_tvalid(k_axis_tvalid),
        .k_axis_tdata(k_axis_tdata),
        .m_axis_tready(), // not used here
        .m_axis_tvalid(),
        .m_axis_tdata(),
        .m_axis_tuser(),
        .m_axis_tlast(),
        .w11(w11), .w12(w12), .w13(w13),
        .w21(w21), .w23(w23),
        .w31(w31), .w32(w32), .w33(w33),
        .k_out_tvalid(k_out_tvalid),
        .k_out_tdata(k_out_tdata),
        .k11_vld(k11_vld), .k12_vld(k12_vld), .k13_vld(k13_vld),
        .k21_vld(k21_vld), .k23_vld(k23_vld),
        .k31_vld(k31_vld), .k32_vld(k32_vld), .k33_vld(k33_vld),
        .enable(enable),
        .k_threshold(k_threshold),
        .S_AXI_ACLK(S_AXI_ACLK),
        .manual_bp_num(manual_bp_num),
        .manual_wen(manual_wen),
        .manual_waddr(manual_waddr),
        .manual_wdata(manual_wdata),
        .auto_bp_valid(auto_bp_valid),
        .auto_bp_x(auto_bp_x),
        .auto_bp_y(auto_bp_y),
        .auto_bp_read_addr(auto_bp_read_addr),
        .auto_bp_read_data(auto_bp_read_data),
        .frame_detection_done(frame_detection_done),
        .detected_bp_count(detected_bp_count),
        .delayed(delayed)
    );

    DPC_Corrector_test #(
        .WIDTH(WIDTH),
        .K_WIDTH(K_WIDTH),
        .CNT_WIDTH(CNT_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .FRAME_WIDTH(FRAME_WIDTH),
        .LATENCY(LATENCY)
    ) corrector (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready), // share ready between detector and corrector in this TB
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        .w11(w11), .w12(w12), .w13(w13),
        .w21(w21), .w23(w23),
        .w31(w31), .w32(w32), .w33(w33),
        .k_out_tvalid(k_out_tvalid),
        .k_out_tdata(k_out_tdata),
        .k11_vld(k11_vld), .k12_vld(k12_vld), .k13_vld(k13_vld),
        .k21_vld(k21_vld), .k23_vld(k23_vld),
        .k31_vld(k31_vld), .k32_vld(k32_vld), .k33_vld(k33_vld),
        .m_axis_tready(m_axis_tready),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast),
        .enable(enable),
        .debug_bp_corrected(),
        .debug_original_pixel(),
        .debug_corrected_pixel()
    );

    // 时钟生成
    initial begin
        aclk = 0; forever #(CLK_PERIOD/2) aclk = ~aclk;
    end
    initial begin
        S_AXI_ACLK = 0; forever #(AXI_CLK_PERIOD/2) S_AXI_ACLK = ~S_AXI_ACLK;
    end

    // 初始化
    initial begin
        aresetn = 1'b0;
        s_axis_tvalid = 1'b0;
        k_axis_tvalid = 1'b0;
        s_axis_tdata = 0;
        k_axis_tdata = 0;
        s_axis_tuser = 0;
        s_axis_tlast = 0;
        m_axis_tready = 1'b1;
        enable = 1'b1;
        k_threshold = THRESHOLD_AUTO;
        manual_bp_num = 0;
        manual_wen = 0;
        manual_waddr = 0;
        manual_wdata = 0;
        auto_bp_read_addr = 0;

        send_count = 0;
        out_count = 0;

        #(CLK_PERIOD*10);
        aresetn = 1'b1;
        #(CLK_PERIOD*5);

        // 设置手动区域并等待（复用 detector TB 的 task）
        setup_manual_bad_pixels();
        #(CLK_PERIOD * 200);

        // 生成测试数据
        generate_test_data();
        #(CLK_PERIOD * 100);

        // 发送并采样
        send_frame_and_sample();

        // 等待一段时间，收集 corrector 输出
        #(CLK_PERIOD * 500);

        // 验证输出
        verify_corrector_outputs();

        $display("Testbench finished");
        $finish;
    end

    // 波形
    initial begin
        $dumpfile("tb_DPC_Corrector.vcd");
        $dumpvars(0, tb_DPC_Corrector);
    end

    // ------------------------
    // 复用 detector TB 中的手动区域配置
    // ------------------------
    task setup_manual_bad_pixels();
    begin
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h00;
        manual_wdata = {16'd5, 16'd15};
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;

        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h01;
        manual_wdata = {16'd8, 16'd8};
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;

        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h02;
        manual_wdata = {16'd12, 16'd3};
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;

        manual_bp_num = 3;
    end
    endtask

    // ------------------------
    // 生成测试数据（与 detector TB 保持一致）
    // ------------------------
    task generate_test_data();
    begin
        integer i,j;
        reg [15:0] base_value;
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                base_value = 2000 + i * 50 + j * 10;
                test_image[i][j] = base_value;
                test_k_values[i][j] = base_value + $random % 40 - 20;
            end
        end

        // 手动区域弱坏点和自动坏点设置（与 detector TB 保持一致）
        // 微弱坏点1: (9,7)
        test_k_values[7][9] = (2000 + 7 * 50 + 9 * 10) + 200;
        // 微弱坏点2: (7,9)
        test_k_values[9][7] = (2000 + 9 * 50 + 7 * 10) - 240;
        // 微弱坏点3: (14,4)
        test_k_values[4][14] = (2000 + 4 * 50 + 14 * 10) + 180;
        // 微弱坏点4: (16,6)
        test_k_values[6][16] = (2000 + 6 * 50 + 16 * 10) - 220;
        // 微弱坏点5: (2,11)
        test_k_values[11][2] = (2000 + 11 * 50 + 2 * 10) + 170;

        manual_pixel_count = 3;
        manual_pixel_x[0] = 15; manual_pixel_y[0] = 5;
        manual_pixel_x[1] = 8; manual_pixel_y[1] = 8;
        manual_pixel_x[2] = 3; manual_pixel_y[2] = 12;

        // 自动坏点
        bad_pixel_x[0] = 3; bad_pixel_y[0] = 4;
        bad_pixel_x[1] = 12; bad_pixel_y[1] = 8;
        bad_pixel_x[2] = 18; bad_pixel_y[2] = 15;

        // 设置明显坏点 k 值
        // 死点
        test_image[bad_pixel_y[0]][bad_pixel_x[0]] = 0;
        test_k_values[bad_pixel_y[0]][bad_pixel_x[0]] = 0;
        // 盲点高
        test_image[bad_pixel_y[1]][bad_pixel_x[1]] = 2000 + bad_pixel_y[1] * 50 + bad_pixel_x[1] * 10;
        test_k_values[bad_pixel_y[1]][bad_pixel_x[1]] = test_image[bad_pixel_y[1]][bad_pixel_x[1]] + THRESHOLD_AUTO + 50;
        // 盲点低
        test_image[bad_pixel_y[2]][bad_pixel_x[2]] = 2000 + bad_pixel_y[2] * 50 + bad_pixel_x[2] * 10;
        test_k_values[bad_pixel_y[2]][bad_pixel_x[2]] = test_image[bad_pixel_y[2]][bad_pixel_x[2]] - THRESHOLD_AUTO - 50;
    end
    endtask

    // ------------------------
    // 发送一帧并在每像素采样 detector 输出
    // ------------------------
    task send_frame_and_sample();
    begin
        integer i,j;
        pixel_index = 0;
        send_count = 0;

        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                @(posedge aclk);
                s_axis_tvalid = 1'b1;
                k_axis_tvalid = 1'b1;
                s_axis_tdata = test_image[i][j];
                k_axis_tdata = test_k_values[i][j];
                s_axis_tuser = (i==0 && j==0);
                s_axis_tlast = (j == FRAME_WIDTH-1);

                // 等待 ready
                while (!s_axis_tready) @(posedge aclk);

                // 在 detector 为当前像素产生 k_out 时采样窗口与 k_vld
                // detector 在同一个时钟沿可能就生成 k_out_tvalid
                // 等待 k_out_tvalid 高
                @(posedge aclk);
                if (!k_out_tvalid) begin
                    // 若未立即有效，等待到有效为止（防止丢失）
                    while (!k_out_tvalid) @(posedge aclk);
                end

                // 记录采样的窗口和 k_vld（与像素对应）
                sampled_w11[pixel_index] = w11;
                sampled_w12[pixel_index] = w12;
                sampled_w13[pixel_index] = w13;
                sampled_w21[pixel_index] = w21;
                sampled_w23[pixel_index] = w23;
                sampled_w31[pixel_index] = w31;
                sampled_w32[pixel_index] = w32;
                sampled_w33[pixel_index] = w33;

                sampled_k11_vld[pixel_index] = k11_vld;
                sampled_k12_vld[pixel_index] = k12_vld;
                sampled_k13_vld[pixel_index] = k13_vld;
                sampled_k21_vld[pixel_index] = k21_vld;
                sampled_k23_vld[pixel_index] = k23_vld;
                sampled_k31_vld[pixel_index] = k31_vld;
                sampled_k32_vld[pixel_index] = k32_vld;
                sampled_k33_vld[pixel_index] = k33_vld;

                // 中心坏点标志
                detected_by_detector[pixel_index] = k_out_tdata[K_WIDTH];

                // 计算期望输出：如果中心被标记为坏点且有有效邻域，使用邻域均值
                begin : calc_expected
                    integer cnt;
                    reg [WIDTH+3-1:0] sum;
                    cnt = 0;
                    sum = 0;
                    if (sampled_k11_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w11[pixel_index]; end
                    if (sampled_k12_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w12[pixel_index]; end
                    if (sampled_k13_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w13[pixel_index]; end
                    if (sampled_k21_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w21[pixel_index]; end
                    if (sampled_k23_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w23[pixel_index]; end
                    if (sampled_k31_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w31[pixel_index]; end
                    if (sampled_k32_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w32[pixel_index]; end
                    if (sampled_k33_vld[pixel_index]) begin cnt = cnt + 1; sum = sum + sampled_w33[pixel_index]; end

                    if (detected_by_detector[pixel_index] && cnt > 0) begin
                        expected_output[pixel_index] = sum / cnt;
                    end else begin
                        expected_output[pixel_index] = s_axis_tdata; // 中心原值
                    end
                end

                // 记录期望真值（用于检测准确性判断），我们把事先设置的明显坏点和微弱坏点都作为真坏点
                expected_is_bad[pixel_index] = 0;
                // 自动坏点
                if ((i == bad_pixel_y[0] && j == bad_pixel_x[0]) ||
                    (i == bad_pixel_y[1] && j == bad_pixel_x[1]) ||
                    (i == bad_pixel_y[2] && j == bad_pixel_x[2])) expected_is_bad[pixel_index] = 1;
                // 手动区域内的微弱坏点
                if ((i == 7 && j == 9) || (i == 9 && j == 7) || (i == 4 && j == 14) || (i == 6 && j == 16) || (i == 11 && j == 2)) expected_is_bad[pixel_index] = 1;

                pixel_index = pixel_index + 1;
                send_count = send_count + 1;
            end
        end

        // 结束帧
        @(posedge aclk);
        s_axis_tvalid = 1'b0;
        k_axis_tvalid = 1'b0;
        s_axis_tuser = 1'b0;
        s_axis_tlast = 1'b0;
    end
    endtask

    // ------------------------
    // 监听 Corrector 输出并逐项对比
    // ------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            out_count <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                // 取出对应的期望值并比较
                if (out_count < total_pixels) begin
                    if (m_axis_tdata !== expected_output[out_count]) begin
                        $display("[Mismatch] pixel %0d: got=%0d expected=%0d at time=%0t", out_count, m_axis_tdata, expected_output[out_count], $time);
                    end
                end
                out_count <= out_count + 1;
            end
        end
    end

    // ------------------------
    // 最终验证与报告
    // ------------------------
    task verify_corrector_outputs();
    begin
        integer i;
        integer mismatches;
        integer detected_correct;
        integer detected_false_pos;
        integer detected_false_neg;

        mismatches = 0;
        detected_correct = 0;
        detected_false_pos = 0;
        detected_false_neg = 0;

        // 等待输出全部完成
        while (out_count < total_pixels) @(posedge aclk);

        // 对比所有像素
        for (i = 0; i < total_pixels; i = i + 1) begin
            if (expected_output[i] !== /* silence x */ expected_output[i]) begin end // keep lint happy
            // 校正比较
            // 这里我们打印不匹配，但在仿真中上面的 always 会已输出不匹配信息
        end

        // 检测准确性统计（使用 sampled detector 标志 vs 预设真值）
        for (i = 0; i < total_pixels; i = i + 1) begin
            if (detected_by_detector[i]) begin
                if (expected_is_bad[i]) detected_correct = detected_correct + 1;
                else detected_false_pos = detected_false_pos + 1;
            end else begin
                if (expected_is_bad[i]) detected_false_neg = detected_false_neg + 1;
            end
        end

        $display("=======================================");
        $display("Corrector Verification Summary:");
        $display("Total pixels: %0d", total_pixels);
        $display("Sent pixels: %0d", send_count);
        $display("Produced outputs: %0d", out_count);
        $display("Detector: true positives=%0d false_positives=%0d false_negatives=%0d", detected_correct, detected_false_pos, detected_false_neg);
        $display("Note: For pixel-level correction mismatches, check runtime mismatch prints above.");
        $display("=======================================");
    end
    endtask

endmodule
