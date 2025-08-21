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

    // 参数定义 - 扩展测试图像尺寸和复杂度
    parameter WIDTH = 16;
    parameter K_WIDTH = 16;
    parameter CNT_WIDTH = 10;
    parameter FRAME_HEIGHT = 32;     // 扩大测试图像尺寸到32x32
    parameter FRAME_WIDTH = 32;      
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
    
    // 坏点信息存储 - 扩展到更多类型的坏点
    reg [4:0] bad_pixel_x [0:7]; // 8个自动坏点的x坐标（不同排列模式）
    reg [4:0] bad_pixel_y [0:7]; // 8个自动坏点的y坐标
    reg [4:0] manual_pixel_x [0:7]; // 8个手动区域中心坐标（避免与自动坏点重叠）
    reg [4:0] manual_pixel_y [0:7];
    
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
        $display("=== Setting up Manual Bad Pixels with Diverse Patterns ===");
        
        // 手动区域1: 中心坐标(5,5) - 左上角区域
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h00;
        manual_wdata = {16'd5, 16'd5}; // y=5, x=5
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域2: 中心坐标(26,6) - 右上角区域
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h01;
        manual_wdata = {16'd6, 16'd26}; // y=6, x=26
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域3: 中心坐标(7,25) - 左下角区域
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h02;
        manual_wdata = {16'd25, 16'd7}; // y=25, x=7
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域4: 中心坐标(25,25) - 右下角区域
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h03;
        manual_wdata = {16'd25, 16'd25}; // y=25, x=25
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域5: 中心坐标(16,10) - 中央区域
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h04;
        manual_wdata = {16'd10, 16'd16}; // y=10, x=16
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域6: 中心坐标(2,15) - 边界测试（左边界）
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h05;
        manual_wdata = {16'd15, 16'd2}; // y=15, x=2
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域7: 中心坐标(29,15) - 边界测试（右边界）
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h06;
        manual_wdata = {16'd15, 16'd29}; // y=15, x=29
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        // 手动区域8: 中心坐标(16,1) - 边界测试（上边界）
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h07;
        manual_wdata = {16'd1, 16'd16}; // y=1, x=16
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        
        manual_bp_num = 8;
        $display("Manual regions setup completed: 8 regions covering corners, center, and boundaries.");
    end
    endtask
    
    // 生成测试数据
    task generate_test_data();
    begin
        integer i, j;
        reg [15:0] base_value;
        
        $display("=== Generating 32x32 Enhanced Test Image Data ===");
        
        // 生成具有渐变背景的图像数据（更真实的测试环境）
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                // 使用渐变背景：从左上角800到右下角1200
                base_value = 800 + ((i * FRAME_WIDTH + j) * 400) / (FRAME_HEIGHT * FRAME_WIDTH);
                test_image[i][j] = base_value;
                test_k_values[i][j] = base_value + $random % 40 - 20; // k值加噪声
                expected_output[i][j] = base_value; // 初始期望输出
            end
        end
        
        // 设置8个自动检测坏点 - 不同的排列模式
        $display("=== Setting up Auto Bad Pixels with Different Patterns ===");
        
        // 1. 单独死点 (x=3,y=3)
        bad_pixel_x[0] = 3; bad_pixel_y[0] = 3;
        
        // 2-3. 2x1横向排列 (x=12,y=8) (x=13,y=8)
        bad_pixel_x[1] = 12; bad_pixel_y[1] = 8;
        bad_pixel_x[2] = 13; bad_pixel_y[2] = 8;
        
        // 4-5. 1x2纵向排列 (x=20,y=12) (x=20,y=13)
        bad_pixel_x[3] = 20; bad_pixel_y[3] = 12;
        bad_pixel_x[4] = 20; bad_pixel_y[4] = 13;
        
        // 6-9. 2x2方形排列 (x=28,y=28) (x=29,y=28) (x=28,y=29) (x=29,y=29)
        bad_pixel_x[5] = 28; bad_pixel_y[5] = 28;
        bad_pixel_x[6] = 29; bad_pixel_y[6] = 28;
        bad_pixel_x[7] = 28; bad_pixel_y[7] = 29;
        // 第8个坏点稍后设置为边界测试
        
        // 8. 边界坏点 (x=0,y=16) - 左边界
        bad_pixel_x[7] = 0; bad_pixel_y[7] = 16;
        
        // 设置手动区域中心坐标（确保不与自动坏点重叠）
        manual_pixel_x[0] = 5; manual_pixel_y[0] = 5;    // 区域1中心
        manual_pixel_x[1] = 26; manual_pixel_y[1] = 6;   // 区域2中心
        manual_pixel_x[2] = 7; manual_pixel_y[2] = 25;   // 区域3中心
        manual_pixel_x[3] = 25; manual_pixel_y[3] = 25;  // 区域4中心
        manual_pixel_x[4] = 16; manual_pixel_y[4] = 10;  // 区域5中心
        manual_pixel_x[5] = 2; manual_pixel_y[5] = 15;   // 区域6中心
        manual_pixel_x[6] = 29; manual_pixel_y[6] = 15;  // 区域7中心
        manual_pixel_x[7] = 16; manual_pixel_y[7] = 1;   // 区域8中心
        
        // 设置自动检测坏点数据和期望校正值
        for (i = 0; i < 8; i = i + 1) begin
            case (i)
                0: begin // 死点 (图像值=0, k=0)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 0;  
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 0;  
                    expected_output[bad_pixel_y[i]][bad_pixel_x[i]] = calculate_expected_correction(bad_pixel_x[i], bad_pixel_y[i]);
                    $display("Auto Bad Point %0d: Dead point, (x=%0d,y=%0d), expected correction=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i], expected_output[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
                1, 2: begin // 2x1横向亮点排列
                    reg [15:0] normal_value;
                    normal_value = test_image[bad_pixel_y[i]][bad_pixel_x[i]];  // 保存原始背景值
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 4095;  // 亮点：饱和值
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = normal_value + THRESHOLD_AUTO + 100;  
                    expected_output[bad_pixel_y[i]][bad_pixel_x[i]] = calculate_expected_correction(bad_pixel_x[i], bad_pixel_y[i]);
                    $display("Auto Bad Point %0d: Bright point (2x1 pattern), (x=%0d,y=%0d), expected correction=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i], expected_output[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
                3, 4: begin // 1x2纵向暗点排列
                    reg [15:0] normal_value;
                    normal_value = test_image[bad_pixel_y[i]][bad_pixel_x[i]];  
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = normal_value - 400;   // 暗点
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = normal_value - THRESHOLD_AUTO - 80;  
                    expected_output[bad_pixel_y[i]][bad_pixel_x[i]] = calculate_expected_correction(bad_pixel_x[i], bad_pixel_y[i]);
                    $display("Auto Bad Point %0d: Dark point (1x2 pattern), (x=%0d,y=%0d), expected correction=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i], expected_output[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
                5, 6, 7: begin // 2x2方形排列（前3个）和边界测试
                    reg [15:0] normal_value;
                    normal_value = test_image[bad_pixel_y[i]][bad_pixel_x[i]];  
                    if (i == 7) begin
                        // 边界测试：左边界坏点
                        test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 200;   // 极暗点
                        test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 100;  
                        $display("Auto Bad Point %0d: Boundary test (left edge), (x=%0d,y=%0d)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                    end else begin
                        // 2x2排列中的点
                        test_image[bad_pixel_y[i]][bad_pixel_x[i]] = normal_value + 600;   // 中等亮点
                        test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = normal_value + THRESHOLD_AUTO + 120;  
                        $display("Auto Bad Point %0d: Medium bright (2x2 pattern), (x=%0d,y=%0d)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                    end
                    expected_output[bad_pixel_y[i]][bad_pixel_x[i]] = calculate_expected_correction(bad_pixel_x[i], bad_pixel_y[i]);
                end
            endcase
        end
        
        // 设置手动区域内的微弱坏点（自动检测不到但手动区域能检测到）
        $display("=== Setting up Manual Bad Pixels (weak defects) ===");
        
        // 手动坏点1: (4,4) 在区域[3:7][3:7]内 - 微弱亮点
        test_image[4][4] = test_image[4][4] + 120;  // 轻微偏亮
        test_k_values[4][4] = test_k_values[4][4] + 180;  // k值偏差
        expected_output[4][4] = calculate_expected_correction(4, 4);
        $display("Manual Bad Point 1: (x=4,y=4), weak bright defect");
        
        // 手动坏点2: (6,6) 在区域[3:7][3:7]内 - 微弱暗点
        test_image[6][6] = test_image[6][6] - 130;  // 轻微偏暗
        test_k_values[6][6] = test_k_values[6][6] - 190;  
        expected_output[6][6] = calculate_expected_correction(6, 6);
        $display("Manual Bad Point 2: (x=6,y=6), weak dark defect");
        
        // 手动坏点3: (27,5) 在区域[24:28][4:8]内 - 边界+微弱缺陷
        test_image[5][27] = test_image[5][27] + 110;  
        test_k_values[5][27] = test_k_values[5][27] + 160;  
        expected_output[5][27] = calculate_expected_correction(27, 5);
        $display("Manual Bad Point 3: (x=27,y=5), boundary + weak bright");
        
        // 手动坏点4: (8,26) 在区域[5:9][23:27]内 - 角落微弱缺陷
        test_image[26][8] = test_image[26][8] - 140;  
        test_k_values[26][8] = test_k_values[26][8] - 200;  
        expected_output[26][8] = calculate_expected_correction(8, 26);
        $display("Manual Bad Point 4: (x=8,y=26), corner weak dark");
        
        // 手动坏点5: (24,24) 在区域[23:27][23:27]内 - 角落微弱缺陷
        test_image[24][24] = test_image[24][24] + 125;  
        test_k_values[24][24] = test_k_values[24][24] + 175;  
        expected_output[24][24] = calculate_expected_correction(24, 24);
        $display("Manual Bad Point 5: (x=24,y=24), corner weak bright");
        
        // 手动坏点6: (17,9) 在区域[14:18][8:12]内 - 中央微弱缺陷
        test_image[9][17] = test_image[9][17] - 115;  
        test_k_values[9][17] = test_k_values[9][17] - 165;  
        expected_output[9][17] = calculate_expected_correction(17, 9);
        $display("Manual Bad Point 6: (x=17,y=9), center weak dark");
        
        // 手动坏点7: (1,14) 在区域[0:4][13:17]内 - 左边界微弱缺陷
        test_image[14][1] = test_image[14][1] + 135;  
        test_k_values[14][1] = test_k_values[14][1] + 185;  
        expected_output[14][1] = calculate_expected_correction(1, 14);
        $display("Manual Bad Point 7: (x=1,y=14), left boundary weak bright");
        
        // 手动坏点8: (30,16) 在区域[27:31][13:17]内 - 右边界微弱缺陷
        test_image[16][30] = test_image[16][30] - 145;  
        test_k_values[16][30] = test_k_values[16][30] - 195;  
        expected_output[16][30] = calculate_expected_correction(30, 16);
        $display("Manual Bad Point 8: (x=30,y=16), right boundary weak dark");
        
        $display("Test data generation completed with enhanced complexity.");
        $display("- Image size: 32x32 with gradient background");
        $display("- Auto bad pixels: 8 (single, 2x1, 1x2, 2x2, boundary patterns)");
        $display("- Manual bad pixels: 8 (weak defects in different regions)");
        $display("- Total test complexity: corners, edges, center, various patterns");
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
                    // 检查邻域像素是否为坏点
                    if (!is_bad_pixel(nx, ny)) begin
                        sum = sum + test_image[ny][nx]; // 使用实际测试图像数据
                        count = count + 1;
                    end
                end
            end
        end
        
        if (count > 0)
            calculate_expected_correction = sum / count;
        else
            calculate_expected_correction = 1000; // 默认值
    end
    endfunction
    
    // 检查是否为已知坏点（扩展到新的坏点模式）
    function is_bad_pixel;
        input [4:0] x, y;
        integer i;
    begin
        is_bad_pixel = 0;
        
        // 检查自动坏点
        for (i = 0; i < 8; i = i + 1) begin
            if (x == bad_pixel_x[i] && y == bad_pixel_y[i]) begin
                is_bad_pixel = 1;
                return;
            end
        end
        
        // 检查手动区域坏点
        if ((x == 4 && y == 4) || (x == 6 && y == 6) || (x == 27 && y == 5) || 
            (x == 8 && y == 26) || (x == 24 && y == 24) || (x == 17 && y == 9) ||
            (x == 1 && y == 14) || (x == 30 && y == 16)) begin
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
        total_expected_bp = 16; // 8个自动 + 8个手动
        correct_detections = 0;
        correct_corrections = 0;
        detection_errors = 0;
        correction_errors = 0;
        correction_tolerance = 20; // 校正值允许20的误差（考虑到渐变背景）
        
        $display("");
        $display("========================================");
        $display("=== ENHANCED DETECTION AND CORRECTION VERIFICATION ===");
        $display("========================================");
        
        // 1. 验证检测结果
        $display("=== Detection Verification ===");
        $display("Expected bad pixels: %0d (8 auto + 8 manual)", total_expected_bp);
        $display("Actually detected: %0d", detected_count);
        
        // 检查自动坏点检测 (8个不同模式的坏点)
        $display("--- Auto Bad Pixel Detection ---");
        for (i = 0; i < 8; i = i + 1) begin
            found = 0;
            for (j = 0; j < detected_count; j = j + 1) begin
                if (detected_bp_list_x[j] == bad_pixel_x[i] && 
                    detected_bp_list_y[j] == bad_pixel_y[i]) begin
                    found = 1;
                    correct_detections = correct_detections + 1;
                    break;
                end
            end
            
            case (i)
                0: begin
                    if (found) begin
                        $display("  ✓ Auto BP %0d at (%0d,%0d) - DETECTED (single dead point)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                    end else begin
                        $display("  ✗ Auto BP %0d at (%0d,%0d) - MISSED (single dead point)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                        detection_errors = detection_errors + 1;
                    end
                end
                1, 2: begin
                    if (found) begin
                        $display("  ✓ Auto BP %0d at (%0d,%0d) - DETECTED (2x1 bright pattern)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                    end else begin
                        $display("  ✗ Auto BP %0d at (%0d,%0d) - MISSED (2x1 bright pattern)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                        detection_errors = detection_errors + 1;
                    end
                end
                3, 4: begin
                    if (found) begin
                        $display("  ✓ Auto BP %0d at (%0d,%0d) - DETECTED (1x2 dark pattern)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                    end else begin
                        $display("  ✗ Auto BP %0d at (%0d,%0d) - MISSED (1x2 dark pattern)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                        detection_errors = detection_errors + 1;
                    end
                end
                5, 6: begin
                    if (found) begin
                        $display("  ✓ Auto BP %0d at (%0d,%0d) - DETECTED (2x2 bright pattern)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                    end else begin
                        $display("  ✗ Auto BP %0d at (%0d,%0d) - MISSED (2x2 bright pattern)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                        detection_errors = detection_errors + 1;
                    end
                end
                7: begin
                    if (found) begin
                        $display("  ✓ Auto BP %0d at (%0d,%0d) - DETECTED (boundary test)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                    end else begin
                        $display("  ✗ Auto BP %0d at (%0d,%0d) - MISSED (boundary test)", 
                                 i+1, bad_pixel_x[i], bad_pixel_y[i]);
                        detection_errors = detection_errors + 1;
                    end
                end
            endcase
        end
        
        // 检查手动区域坏点检测
        $display("--- Manual Bad Pixel Detection ---");
        if (check_manual_detection(4, 4)) begin
            $display("  ✓ Manual BP (4,4) - DETECTED (corner weak bright)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (4,4) - MISSED (corner weak bright)");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(6, 6)) begin
            $display("  ✓ Manual BP (6,6) - DETECTED (corner weak dark)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (6,6) - MISSED (corner weak dark)");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(27, 5)) begin
            $display("  ✓ Manual BP (27,5) - DETECTED (boundary weak bright)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (27,5) - MISSED (boundary weak bright)");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(8, 26)) begin
            $display("  ✓ Manual BP (8,26) - DETECTED (corner weak dark)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (8,26) - MISSED (corner weak dark)");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(24, 24)) begin
            $display("  ✓ Manual BP (24,24) - DETECTED (corner weak bright)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (24,24) - MISSED (corner weak bright)");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(17, 9)) begin
            $display("  ✓ Manual BP (17,9) - DETECTED (center weak dark)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (17,9) - MISSED (center weak dark)");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(1, 14)) begin
            $display("  ✓ Manual BP (1,14) - DETECTED (left boundary weak bright)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (1,14) - MISSED (left boundary weak bright)");
            detection_errors = detection_errors + 1;
        end
        
        if (check_manual_detection(30, 16)) begin
            $display("  ✓ Manual BP (30,16) - DETECTED (right boundary weak dark)");
            correct_detections = correct_detections + 1;
        end else begin
            $display("  ✗ Manual BP (30,16) - MISSED (right boundary weak dark)");
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
                end
            end
        end
        
        // 3. 总体评估和模式分析
        $display("");
        $display("=== PATTERN-SPECIFIC ANALYSIS ===");
        
        // 分析不同模式的检测成功率
        $display("Pattern Detection Analysis:");
        $display("  - Single dead point: %s", (check_manual_detection(bad_pixel_x[0], bad_pixel_y[0]) ? "✓" : "✗"));
        $display("  - 2x1 bright pattern: %s", 
                 ((check_manual_detection(bad_pixel_x[1], bad_pixel_y[1]) && 
                   check_manual_detection(bad_pixel_x[2], bad_pixel_y[2])) ? "✓ (both)" : "⚠ (partial)"));
        $display("  - 1x2 dark pattern: %s", 
                 ((check_manual_detection(bad_pixel_x[3], bad_pixel_y[3]) && 
                   check_manual_detection(bad_pixel_x[4], bad_pixel_y[4])) ? "✓ (both)" : "⚠ (partial)"));
        $display("  - 2x2 bright pattern: %s", 
                 ((check_manual_detection(bad_pixel_x[5], bad_pixel_y[5]) && 
                   check_manual_detection(bad_pixel_x[6], bad_pixel_y[6])) ? "✓ (partial)" : "⚠ (limited)"));
        $display("  - Boundary defects: %s", 
                 (check_manual_detection(bad_pixel_x[7], bad_pixel_y[7]) ? "✓" : "✗"));
        
        $display("");
        $display("=== BOUNDARY EFFECTS ANALYSIS ===");
        
        // 分析边界像素的校正质量
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                if (is_bad_pixel(j, i) && 
                    (i == 0 || i == FRAME_HEIGHT-1 || j == 0 || j == FRAME_WIDTH-1)) begin
                    reg [15:0] correction_quality;
                    correction_quality = abs_diff(actual_output[i][j], expected_output[i][j]);
                    $display("  Boundary BP (%0d,%0d): correction quality = %0d (tolerance = %0d)", 
                             j, i, correction_quality, correction_tolerance);
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
        
        // 评估标准更加严格
        if (detection_errors == 0 && correction_errors == 0) begin
            $display("🎉 PERFECT: All bad pixels detected and corrected successfully!");
            $display("   - Complex patterns handled correctly");
            $display("   - Boundary effects properly managed");
            $display("   - Weak defects detected in manual regions");
        end else if (detection_errors <= 2 && correction_errors <= 2) begin
            $display("✅ EXCELLENT: Near-perfect performance with enhanced complexity");
            $display("   - Most patterns handled correctly");
            $display("   - Minor issues within acceptable range");
        end else if (detection_errors <= 4 && correction_errors <= 4) begin
            $display("✅ GOOD: Acceptable performance with complex patterns");
            $display("   - Basic functionality working");
            $display("   - Some pattern-specific improvements needed");
        end else begin
            $display("⚠️  NEEDS IMPROVEMENT: Multiple errors with complex patterns");
            $display("   - Pattern detection may need tuning");
            $display("   - Boundary handling requires attention");
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
        $display("DPC Corrector Enhanced Integration Testbench Starts");
        $display("Frame Size: %0dx%0d (Enhanced complexity)", FRAME_WIDTH, FRAME_HEIGHT);
        $display("Testing: Detector + Corrector with diverse patterns");
        $display("Test Features:");
        $display("  - Boundary effects (edge padding)");
        $display("  - Multiple bad pixel patterns (1x1, 2x1, 1x2, 2x2)");
        $display("  - Manual weak defects vs Auto strong defects");
        $display("  - Corner, edge, and center region coverage");
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
        $display("Enhanced Integration Testbench Completed Successfully");
        $display("Test Summary:");
        $display("  - Image: 32x32 with gradient background");
        $display("  - Auto BP: 8 with diverse patterns (single, 2x1, 1x2, 2x2, boundary)");
        $display("  - Manual BP: 8 weak defects in strategic locations");
        $display("  - Boundary testing: corners, edges, center regions");
        $display("  - Pattern complexity: realistic defect scenarios");
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
