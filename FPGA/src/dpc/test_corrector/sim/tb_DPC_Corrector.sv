/*
 * DPC校正器集成测试台
 * 
 * 功能：
 * 1. 集成Detector和Corrector模块进行端到端测试
 * 2. 使用与detector testbench相同的测试数据
 * 3. 验证坏点检测的准确性
 * 4. 验证坏点校正的有效性
 * 5. 对比校正前后的图像质量
 */

`timescale 1ns/1ps

module tb_DPC_Corrector();

    // 参数定义 - 与detector testbench保持一致
    parameter WIDTH = 16;
    parameter K_WIDTH = 16;
    parameter CNT_WIDTH = 10;
    parameter FRAME_HEIGHT = 20;     // 测试图像尺寸20x20（小尺寸用于调试）
    parameter FRAME_WIDTH = 20;      
    parameter THRESHOLD_AUTO = 300;  // 自动检测阈值
    parameter THRESHOLD_MANUAL = 150; // 手动检测阈值
    parameter CLK_PERIOD = 10; // 10ns时钟周期
    parameter AXI_CLK_PERIOD = 5; // 5ns AXI时钟周期
    
    // 时钟和复位信号
    reg aclk;
    reg aresetn;
    reg S_AXI_ACLK;
    
    // 输入像素流（到detector）
    reg s_axis_tvalid;
    wire s_axis_tready;
    reg [WIDTH-1:0] s_axis_tdata;
    reg s_axis_tuser;
    reg s_axis_tlast;
    
    // k值输入流（到detector）
    reg k_axis_tvalid;
    reg [K_WIDTH-1:0] k_axis_tdata;
    
    // detector到corrector的信号
    wire detector_m_axis_tvalid;
    wire [WIDTH-1:0] detector_m_axis_tdata;
    wire detector_m_axis_tuser;
    wire detector_m_axis_tlast;
    
    // detector输出的3x3窗口
    wire [WIDTH-1:0] w11, w12, w13;
    wire [WIDTH-1:0] w21, w23;
    wire [WIDTH-1:0] w31, w32, w33;
    
    // detector输出的k值流（带坏点标志）
    wire k_out_tvalid;
    wire [K_WIDTH:0] k_out_tdata;
    wire k11_vld, k12_vld, k13_vld;
    wire k21_vld, k23_vld;
    wire k31_vld, k32_vld, k33_vld;
    
    // corrector最终输出
    reg corrector_m_axis_tready;
    wire corrector_m_axis_tvalid;
    wire [WIDTH-1:0] corrector_m_axis_tdata;
    wire corrector_m_axis_tuser;
    wire corrector_m_axis_tlast;
    
    // detector配置接口
    reg detector_enable;
    reg [K_WIDTH-1:0] k_threshold;
    
    // 手动坏点表接口
    reg [6:0] manual_bp_num;
    reg manual_wen;
    reg [6:0] manual_waddr;
    reg [31:0] manual_wdata;
    
    // detector状态输出
    wire auto_bp_valid;
    wire [CNT_WIDTH-1:0] auto_bp_x;
    wire [CNT_WIDTH-1:0] auto_bp_y;
    wire frame_detection_done;
    wire [7:0] detected_bp_count;
    wire delayed;
    
    // corrector配置和调试接口
    reg corrector_enable;
    wire debug_bp_corrected;
    wire [WIDTH-1:0] debug_original_pixel;
    wire [WIDTH-1:0] debug_corrected_pixel;
    
    // 测试数据存储
    reg [WIDTH-1:0] test_image [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    reg [K_WIDTH-1:0] test_k_values [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    reg [WIDTH-1:0] expected_output [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1]; // 预期校正后的图像
    reg [WIDTH-1:0] actual_output [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];   // 实际校正后的图像
    
    // 坏点信息存储
    reg [4:0] bad_pixel_x [0:2]; // 3个自动坏点的x坐标
    reg [4:0] bad_pixel_y [0:2]; // 3个自动坏点的y坐标
    reg [4:0] manual_pixel_x [0:2]; // 3个手动区域中心坐标
    reg [4:0] manual_pixel_y [0:2];
    
    // 控制和统计信号
    integer row, col;
    integer frame_count;
    integer pixel_count;
    integer output_row, output_col;
    integer output_pixel_count;
    integer corrected_pixel_count;
    integer detection_errors;
    integer correction_errors;
    
    // 检测结果存储
    reg [15:0] detected_bp_list_x [0:255];
    reg [15:0] detected_bp_list_y [0:255];
    integer detected_count;
    
    // =============================================================================
    // DUT实例化 - Detector
    // =============================================================================
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
    ) detector_dut (
        .aclk(aclk),
        .aresetn(aresetn),
        
        // 输入像素流
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        
        // k值输入
        .k_axis_tvalid(k_axis_tvalid),
        .k_axis_tdata(k_axis_tdata),
        
        // 输出到corrector
        .m_axis_tready(1'b1), // corrector始终准备接收
        .m_axis_tvalid(detector_m_axis_tvalid),
        .m_axis_tdata(detector_m_axis_tdata),
        .m_axis_tuser(detector_m_axis_tuser),
        .m_axis_tlast(detector_m_axis_tlast),
        
        // 3x3窗口输出
        .w11(w11), .w12(w12), .w13(w13),
        .w21(w21), .w23(w23),
        .w31(w31), .w32(w32), .w33(w33),
        
        // k值输出（带坏点标志）
        .k_out_tvalid(k_out_tvalid),
        .k_out_tdata(k_out_tdata),
        .k11_vld(k11_vld), .k12_vld(k12_vld), .k13_vld(k13_vld),
        .k21_vld(k21_vld), .k23_vld(k23_vld),
        .k31_vld(k31_vld), .k32_vld(k32_vld), .k33_vld(k33_vld),
        
        // 配置接口
        .enable(detector_enable),
        .k_threshold(k_threshold),
        
        // 手动坏点表接口
        .S_AXI_ACLK(S_AXI_ACLK),
        .manual_bp_num(manual_bp_num),
        .manual_wen(manual_wen),
        .manual_waddr(manual_waddr),
        .manual_wdata(manual_wdata),
        
        // 状态输出
        .auto_bp_valid(auto_bp_valid),
        .auto_bp_x(auto_bp_x),
        .auto_bp_y(auto_bp_y),
        .frame_detection_done(frame_detection_done),
        .detected_bp_count(detected_bp_count),
        .delayed(delayed)
    );
    
    // =============================================================================
    // DUT实例化 - Corrector
    // =============================================================================
    DPC_Corrector_test #(
        .WIDTH(WIDTH),
        .K_WIDTH(K_WIDTH),
        .CNT_WIDTH(CNT_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .FRAME_WIDTH(FRAME_WIDTH)
    ) corrector_dut (
        .aclk(aclk),
        .aresetn(aresetn),
        
        // 输入来自detector
        .s_axis_tvalid(detector_m_axis_tvalid),
        .s_axis_tready(), // 输出未连接，corrector内部始终准备接收
        .s_axis_tdata(detector_m_axis_tdata),
        .s_axis_tuser(detector_m_axis_tuser),
        .s_axis_tlast(detector_m_axis_tlast),
        
        // 3x3窗口输入
        .s_axis_tdata_w11(w11), .s_axis_tdata_w12(w12), .s_axis_tdata_w13(w13),
        .s_axis_tdata_w21(w21), .s_axis_tdata_w23(w23),
        .s_axis_tdata_w31(w31), .s_axis_tdata_w32(w32), .s_axis_tdata_w33(w33),

        // k值输入（带坏点标志）
        .k_out_tvalid(k_out_tvalid),
        .k_out_tdata(k_out_tdata),
        .k11_vld(k11_vld), .k12_vld(k12_vld), .k13_vld(k13_vld),
        .k21_vld(k21_vld), .k23_vld(k23_vld),
        .k31_vld(k31_vld), .k32_vld(k32_vld), .k33_vld(k33_vld),
        
        // 最终输出
        .m_axis_tready(corrector_m_axis_tready),
        .m_axis_tvalid(corrector_m_axis_tvalid),
        .m_axis_tdata(corrector_m_axis_tdata),
        .m_axis_tuser(corrector_m_axis_tuser),
        .m_axis_tlast(corrector_m_axis_tlast),
        
        // 配置接口
        .enable(corrector_enable),
        
        // 调试输出
        .debug_bp_corrected(debug_bp_corrected),
        .debug_original_pixel(debug_original_pixel),
        .debug_corrected_pixel(debug_corrected_pixel)
    );
    
    // =============================================================================
    // 时钟生成
    // =============================================================================
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end
    
    initial begin
        S_AXI_ACLK = 0;
        forever #(AXI_CLK_PERIOD/2) S_AXI_ACLK = ~S_AXI_ACLK;
    end
    
    // =============================================================================
    // 测试数据生成任务 - 复用detector testbench的数据
    // =============================================================================
    
    // 配置手动坏点
    task setup_manual_bad_pixels();
    begin
        $display("=== Setting up Manual Bad Pixels ===");
        
        // 手动区域1: 中心坐标(15,5)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h00;
        manual_wdata = {16'd5, 16'd15}; // y=5, x=15
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域2: 中心坐标(8,8)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h01;
        manual_wdata = {16'd8, 16'd8}; // y=8, x=8
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域3: 中心坐标(3,12)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h02;
        manual_wdata = {16'd12, 16'd3}; // y=12, x=3
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        manual_bp_num = 3;
        $display("Manual regions setup completed.");
    end
    endtask
    
    // 生成测试数据
    task generate_test_data();
    begin
        integer i, j;
        reg [15:0] base_value;
        
        $display("=== Generating 20x20 Test Image Data ===");
        
        // 生成正常图像数据（渐变图像）
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                base_value = 2000 + i * 50 + j * 10;
                test_image[i][j] = base_value;
                test_k_values[i][j] = base_value + $random % 40 - 20;
                expected_output[i][j] = base_value; // 初始期望输出与输入相同
            end
        end
        
        // 设置自动检测坏点
        bad_pixel_x[0] = 3; bad_pixel_y[0] = 4;   // 第一个自动坏点 (x=3,y=4)
        bad_pixel_x[1] = 12; bad_pixel_y[1] = 8;  // 第二个自动坏点 (x=12,y=8)
        bad_pixel_x[2] = 18; bad_pixel_y[2] = 15; // 第三个自动坏点 (x=18,y=15)
        
        // 设置手动区域中心坐标
        manual_pixel_x[0] = 15; manual_pixel_y[0] = 5;  // 区域1中心
        manual_pixel_x[1] = 8; manual_pixel_y[1] = 8;   // 区域2中心
        manual_pixel_x[2] = 3; manual_pixel_y[2] = 12;  // 区域3中心
        
        // 设置自动检测坏点数据和期望校正值
        for (i = 0; i < 3; i = i + 1) begin
            case (i)
                0: begin // 死点 (图像值=0, k=0)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 0;  // 死点图像值为0
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 0;  // 死点k值也为0
                    // 计算期望校正值：周围8个邻域的均值
                    expected_output[bad_pixel_y[i]][bad_pixel_x[i]] = calculate_expected_correction(bad_pixel_x[i], bad_pixel_y[i]);
                    $display("Auto Bad Point %0d: Dead point, (x=%0d,y=%0d), image=%0d->%0d, expected correction=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i], test_image[bad_pixel_y[i]][bad_pixel_x[i]], 
                             2000 + bad_pixel_y[i] * 50 + bad_pixel_x[i] * 10, expected_output[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
                1: begin // 亮点 (图像值异常高)
                    reg [15:0] normal_value, expected_neighbor_k;
                    normal_value = 2000 + bad_pixel_y[i] * 50 + bad_pixel_x[i] * 10;  // 正常应该的值
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 4095;  // 亮点：饱和值
                    expected_neighbor_k = normal_value;  // 邻域k值基于正常值
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = expected_neighbor_k + THRESHOLD_AUTO + 50;  // k值也异常高
                    expected_output[bad_pixel_y[i]][bad_pixel_x[i]] = calculate_expected_correction(bad_pixel_x[i], bad_pixel_y[i]);
                    $display("Auto Bad Point %0d: Bright point, (x=%0d,y=%0d), image=%0d->%0d, expected correction=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i], test_image[bad_pixel_y[i]][bad_pixel_x[i]], 
                             normal_value, expected_output[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
                2: begin // 暗点 (图像值异常低)
                    reg [15:0] normal_value, expected_neighbor_k;
                    normal_value = 2000 + bad_pixel_y[i] * 50 + bad_pixel_x[i] * 10;  // 正常应该的值
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 500;   // 暗点：异常低值
                    expected_neighbor_k = normal_value;  // 邻域k值基于正常值
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = expected_neighbor_k - THRESHOLD_AUTO - 50;  // k值也异常低
                    expected_output[bad_pixel_y[i]][bad_pixel_x[i]] = calculate_expected_correction(bad_pixel_x[i], bad_pixel_y[i]);
                    $display("Auto Bad Point %0d: Dark point, (x=%0d,y=%0d), image=%0d->%0d, expected correction=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i], test_image[bad_pixel_y[i]][bad_pixel_x[i]], 
                             normal_value, expected_output[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
            endcase
        end
        
        // 设置手动区域内的微弱坏点及期望校正值
        // 微弱坏点1: (9,7) 在手动区域[6:10][6:10]内 - 轻微亮点
        test_image[7][9] = (2000 + 7 * 50 + 9 * 10) + 150;  // 比正常值高150
        test_k_values[7][9] = (2000 + 7 * 50 + 9 * 10) + 200;  // k值比正常高200
        expected_output[7][9] = calculate_expected_correction(9, 7);
        $display("Manual Bad Point 1: (x=9,y=7), image=%0d->%0d, expected correction=%0d", 
                 test_image[7][9], 2000 + 7 * 50 + 9 * 10, expected_output[7][9]);
        
        // 微弱坏点2: (7,9) 在手动区域[6:10][6:10]内 - 轻微暗点
        test_image[9][7] = (2000 + 9 * 50 + 7 * 10) - 180;  // 比正常值低180
        test_k_values[9][7] = (2000 + 9 * 50 + 7 * 10) - 240;  // k值比正常低240
        expected_output[9][7] = calculate_expected_correction(7, 9);
        $display("Manual Bad Point 2: (x=7,y=9), image=%0d->%0d, expected correction=%0d", 
                 test_image[9][7], 2000 + 9 * 50 + 7 * 10, expected_output[9][7]);
        
        // 微弱坏点3: (14,4) 在手动区域[13:17][3:7]内 - 轻微亮点
        test_image[4][14] = (2000 + 4 * 50 + 14 * 10) + 120;  // 比正常值高120
        test_k_values[4][14] = (2000 + 4 * 50 + 14 * 10) + 180;  // k值比正常高180
        expected_output[4][14] = calculate_expected_correction(14, 4);
        $display("Manual Bad Point 3: (x=14,y=4), image=%0d->%0d, expected correction=%0d", 
                 test_image[4][14], 2000 + 4 * 50 + 14 * 10, expected_output[4][14]);
        
        // 微弱坏点4: (16,6) 在手动区域[13:17][3:7]内 - 轻微暗点
        test_image[6][16] = (2000 + 6 * 50 + 16 * 10) - 160;  // 比正常值低160
        test_k_values[6][16] = (2000 + 6 * 50 + 16 * 10) - 220;  // k值比正常低220
        expected_output[6][16] = calculate_expected_correction(16, 6);
        $display("Manual Bad Point 4: (x=16,y=6), image=%0d->%0d, expected correction=%0d", 
                 test_image[6][16], 2000 + 6 * 50 + 16 * 10, expected_output[6][16]);
        
        // 微弱坏点5: (2,11) 在手动区域[1:5][10:14]内 - 轻微亮点
        test_image[11][2] = (2000 + 11 * 50 + 2 * 10) + 130;  // 比正常值高130
        test_k_values[11][2] = (2000 + 11 * 50 + 2 * 10) + 170;  // k值比正常高170
        expected_output[11][2] = calculate_expected_correction(2, 11);
        $display("Manual Bad Point 5: (x=2,y=11), image=%0d->%0d, expected correction=%0d", 
                 test_image[11][2], 2000 + 11 * 50 + 2 * 10, expected_output[11][2]);
        
        $display("Test data generation completed.");
    end
    endtask
    
    // 计算期望校正值（3x3邻域均值）
    function [WIDTH-1:0] calculate_expected_correction;
        input [4:0] x, y;
        integer sum, count;
        integer dx, dy, nx, ny;
    begin
        sum = 0;
        count = 0;
        
        // 遍历3x3邻域
        for (dx = -1; dx <= 1; dx = dx + 1) begin
            for (dy = -1; dy <= 1; dy = dy + 1) begin
                if (dx == 0 && dy == 0) continue; // 跳过中心像素
                
                nx = x + dx;
                ny = y + dy;
                
                // 边界检查
                if (nx >= 0 && nx < FRAME_WIDTH && ny >= 0 && ny < FRAME_HEIGHT) begin
                    // 检查邻域像素是否为坏点（这里简化：假设只有我们标记的坏点是坏的）
                    if (!is_bad_pixel(nx, ny)) begin
                        sum = sum + (2000 + ny * 50 + nx * 10); // 使用原始渐变值
                        count = count + 1;
                    end
                end
            end
        end
        
        if (count > 0)
            calculate_expected_correction = sum / count;
        else
            calculate_expected_correction = 2000; // 默认值
    end
    endfunction
    
    // 检查是否为已知坏点
    function is_bad_pixel;
        input [4:0] x, y;
        integer i;
    begin
        is_bad_pixel = 0;
        
        // 检查自动坏点
        for (i = 0; i < 3; i = i + 1) begin
            if (x == bad_pixel_x[i] && y == bad_pixel_y[i]) begin
                is_bad_pixel = 1;
                return;
            end
        end
        
        // 检查手动区域坏点
        if ((x == 9 && y == 7) || (x == 7 && y == 9) || 
            (x == 14 && y == 4) || (x == 16 && y == 6) || (x == 2 && y == 11)) begin
            is_bad_pixel = 1;
        end
    end
    endfunction
    
    // =============================================================================
    // 发送测试帧
    // =============================================================================
    task send_frame();
    begin
        integer i, j;
        
        $display("=== Start Sending Test Frame ===");
        frame_count = frame_count + 1;
        pixel_count = 0;
        
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                @(posedge aclk);
                
                s_axis_tvalid = 1'b1;
                k_axis_tvalid = 1'b1;
                s_axis_tdata = test_image[i][j];
                k_axis_tdata = test_k_values[i][j];
                s_axis_tuser = (i == 0 && j == 0) ? 1'b1 : 1'b0;
                s_axis_tlast = (j == FRAME_WIDTH - 1) ? 1'b1 : 1'b0;
                
                while (!s_axis_tready) @(posedge aclk);
                
                pixel_count = pixel_count + 1;
            end
        end
        
        @(posedge aclk);
        s_axis_tvalid = 1'b0;
        k_axis_tvalid = 1'b0;
        s_axis_tuser = 1'b0;
        s_axis_tlast = 1'b0;
        
        $display("Frame data sent, %0d pixels", pixel_count);
    end
    endtask
    
    // =============================================================================
    // 监控任务
    // =============================================================================
    
    // 监控坏点检测结果
    initial begin
        detected_count = 0;
        forever begin
            @(posedge aclk);
            if (auto_bp_valid && delayed) begin
                detected_bp_list_x[detected_count] = auto_bp_x;
                detected_bp_list_y[detected_count] = auto_bp_y;
                detected_count = detected_count + 1;
                $display("[Time %0t] Detected Bad Pixel %0d: (%0d,%0d)", 
                         $time, detected_count, auto_bp_x, auto_bp_y);
            end
        end
    end
    
    // 监控校正结果
    initial begin
        corrected_pixel_count = 0;
        forever begin
            @(posedge aclk);
            if (debug_bp_corrected) begin
                corrected_pixel_count = corrected_pixel_count + 1;
                $display("[Time %0t] Pixel Corrected %0d: original=%0d, corrected=%0d", 
                         $time, corrected_pixel_count, debug_original_pixel, debug_corrected_pixel);
            end
        end
    end
    
    // 监控输出像素流并收集实际输出
    initial begin
        output_pixel_count = 0;
        output_row = 0;
        output_col = 0;
        
        forever begin
            @(posedge aclk);
            if (corrector_m_axis_tvalid && corrector_m_axis_tready) begin
                // 收集实际输出
                actual_output[output_row][output_col] = corrector_m_axis_tdata;
                
                output_pixel_count = output_pixel_count + 1;
                
                // 更新坐标
                if (corrector_m_axis_tlast) begin
                    output_col = 0;
                    output_row = output_row + 1;
                end else begin
                    output_col = output_col + 1;
                end
                
                // 显示关键像素的校正结果
                if (is_bad_pixel(output_col, output_row)) begin
                    $display("Bad pixel output [%0d,%0d]: actual=%0d, expected=%0d", 
                             output_row, output_col, corrector_m_axis_tdata, expected_output[output_row][output_col]);
                end
            end
        end
    end
    
    // =============================================================================
    // 验证任务
    // =============================================================================
    
    // 验证检测和校正结果
    task verify_results();
        integer i, j;
        integer found;
        integer total_expected_bp;
        integer correct_detections;
        integer correct_corrections;
        integer correction_tolerance;
    begin
        total_expected_bp = 8; // 3个自动 + 5个手动
        correct_detections = 0;
        correct_corrections = 0;
        detection_errors = 0;
        correction_errors = 0;
        correction_tolerance = 10; // 校正值允许10的误差
        
        $display("");
        $display("========================================");
        $display("=== DETECTION AND CORRECTION VERIFICATION ===");
        $display("========================================");
        
        // 1. 验证检测结果
        $display("=== Detection Verification ===");
        $display("Expected bad pixels: %0d", total_expected_bp);
        $display("Actually detected: %0d", detected_count);
        
        // 检查自动坏点检测
        for (i = 0; i < 3; i = i + 1) begin
            found = 0;
            for (j = 0; j < detected_count; j = j + 1) begin
                if (detected_bp_list_x[j] == bad_pixel_x[i] && 
                    detected_bp_list_y[j] == bad_pixel_y[i]) begin
                    found = 1;
                    correct_detections = correct_detections + 1;
                    break;
                end
            end
            
            if (found) begin
                $display("  ✓ Auto BP %0d at (%0d,%0d) - DETECTED", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
            end else begin
                $display("  ✗ Auto BP %0d at (%0d,%0d) - MISSED", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
                detection_errors = detection_errors + 1;
            end
        end
        
        // 检查手动区域坏点检测
        if (check_manual_detection(9, 7)) begin
            $display("  ✓ Manual BP (9,7) - DETECTED");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (9,7) - MISSED");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(7, 9)) begin
            $display("  ✓ Manual BP (7,9) - DETECTED");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (7,9) - MISSED");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(14, 4)) begin
            $display("  ✓ Manual BP (14,4) - DETECTED");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (14,4) - MISSED");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(16, 6)) begin
            $display("  ✓ Manual BP (16,6) - DETECTED");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (16,6) - MISSED");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(2, 11)) begin
            $display("  ✓ Manual BP (2,11) - DETECTED");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (2,11) - MISSED");
            detection_errors = detection_errors + 1;
        end
        
        // 2. 验证校正结果
        $display("");
        $display("=== Correction Verification ===");
        
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                if (is_bad_pixel(j, i)) begin
                    // 这是坏点，检查是否被正确校正
                    if (abs_diff(actual_output[i][j], expected_output[i][j]) <= correction_tolerance) begin
                        $display("  ✓ BP (%0d,%0d): original=%0d, actual=%0d, expected=%0d, diff=%0d - CORRECTED", 
                                 j, i, test_image[i][j], actual_output[i][j], expected_output[i][j], 
                                 abs_diff(actual_output[i][j], expected_output[i][j]));
                        correct_corrections = correct_corrections + 1;
                    end else begin
                        $display("  ✗ BP (%0d,%0d): original=%0d, actual=%0d, expected=%0d, diff=%0d - ERROR", 
                                 j, i, test_image[i][j], actual_output[i][j], expected_output[i][j], 
                                 abs_diff(actual_output[i][j], expected_output[i][j]));
                        correction_errors = correction_errors + 1;
                    end
                end else begin
                    // 这是正常点，检查是否保持不变
                    if (actual_output[i][j] != test_image[i][j]) begin
                        $display("  ⚠ Normal pixel (%0d,%0d) changed: original=%0d, output=%0d", 
                                 j, i, test_image[i][j], actual_output[i][j]);
                    end
                end
            end
        end
        
        // 3. 总体评估
        $display("");
        $display("=== CORRECTION EFFECTIVENESS ANALYSIS ===");
        
        // 分析校正效果的定量指标
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                if (is_bad_pixel(j, i)) begin
                    reg [15:0] original_value, corrected_value, expected_value;
                    reg [15:0] original_error, corrected_error;
                    
                    original_value = test_image[i][j];
                    corrected_value = actual_output[i][j];
                    expected_value = expected_output[i][j];
                    
                    // 计算校正前后的误差
                    original_error = abs_diff(original_value, expected_value);
                    corrected_error = abs_diff(corrected_value, expected_value);
                    
                    $display("  BP (%0d,%0d): Error reduction: %0d -> %0d (improvement: %0d)", 
                             j, i, original_error, corrected_error, original_error - corrected_error);
                end
            end
        end
        
        $display("");
        $display("=== FINAL SUMMARY ===");
        $display("Detection Accuracy: %0d/%0d (%0.1f%%)", 
                 correct_detections, total_expected_bp, 
                 (correct_detections * 100.0) / total_expected_bp);
        $display("Correction Accuracy: %0d/%0d (%0.1f%%)", 
                 correct_corrections, total_expected_bp,
                 (correct_corrections * 100.0) / total_expected_bp);
        $display("Detection Errors: %0d", detection_errors);
        $display("Correction Errors: %0d", correction_errors);
        
        if (detection_errors == 0 && correction_errors == 0) begin
            $display("🎉 PERFECT: All bad pixels detected and corrected successfully!");
        end else if (detection_errors <= 1 && correction_errors <= 1) begin
            $display("✅ EXCELLENT: Near-perfect detection and correction");
        end else if (detection_errors <= 2 && correction_errors <= 2) begin
            $display("✅ GOOD: Good detection and correction performance");
        end else begin
            $display("⚠️  NEEDS IMPROVEMENT: Multiple detection or correction errors");
        end
        
        $display("========================================");
    end
    endtask
    
    // 检查手动区域坏点是否被检测
    function check_manual_detection;
        input [4:0] x, y;
        integer i;
    begin
        check_manual_detection = 0;
        for (i = 0; i < detected_count; i = i + 1) begin
            if (detected_bp_list_x[i] == x && detected_bp_list_y[i] == y) begin
                check_manual_detection = 1;
                return;
            end
        end
    end
    endfunction
    
    // 计算绝对差值
    function [WIDTH-1:0] abs_diff;
        input [WIDTH-1:0] a, b;
    begin
        if (a > b)
            abs_diff = a - b;
        else
            abs_diff = b - a;
    end
    endfunction
    
    // =============================================================================
    // 主测试流程
    // =============================================================================
    initial begin
        $display("========================================");
        $display("DPC Corrector Integration Testbench Starts");
        $display("Frame Size: %0dx%0d", FRAME_WIDTH, FRAME_HEIGHT);
        $display("Testing: Detector + Corrector integration");
        $display("========================================");
        
        // 初始化信号
        aresetn = 1'b0;
        s_axis_tvalid = 1'b0;
        k_axis_tvalid = 1'b0;
        s_axis_tdata = 16'b0;
        k_axis_tdata = 16'b0;
        s_axis_tuser = 1'b0;
        s_axis_tlast = 1'b0;
        corrector_m_axis_tready = 1'b1;
        
        // 配置信号
        detector_enable = 1'b1;
        corrector_enable = 1'b1;
        k_threshold = THRESHOLD_AUTO;
        
        // 手动坏点表初始化
        manual_bp_num = 7'b0;
        manual_wen = 1'b0;
        manual_waddr = 7'b0;
        manual_wdata = 32'b0;
        
        frame_count = 0;
        
        // 复位
        $display("=== System Reset ===");
        #(CLK_PERIOD * 10);
        aresetn = 1'b1;
        #(CLK_PERIOD * 5);
        
        // 配置手动坏点
        $display("=== Configuring Manual Bad Pixels ===");
        setup_manual_bad_pixels();
        #(CLK_PERIOD * 200);
        
        // 生成测试数据
        $display("=== Generating Test Data ===");
        generate_test_data();
        #(CLK_PERIOD * 100);
        
        // 发送测试帧
        $display("=== Sending Test Frame ===");
        send_frame();
        
        // 等待处理完成
        $display("=== Waiting for Processing Completion ===");
        wait(frame_detection_done);
        
        // 等待所有输出完成（估算值：帧大小 + 流水线延迟）
        #(CLK_PERIOD * (FRAME_HEIGHT * FRAME_WIDTH + 50));
        
        // 验证结果
        verify_results();
        
        $display("========================================");
        $display("Integration Testbench Completed Successfully");
        $display("========================================");
        
        #(CLK_PERIOD * 50);
        $finish;
    end
    
    // VCD波形文件生成
    initial begin
        $dumpfile("tb_DPC_Corrector.vcd");
        $dumpvars(0, tb_DPC_Corrector);
    end

endmodule
