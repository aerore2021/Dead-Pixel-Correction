/*
 * DPC_Detector Testbench
 * 
 * 功能：
 * 1. 生成10x10的测试图像
 * 2. 随机加入3个坏点（死点和盲点）
 * 3. 生成对应的k值数据
 * 4. 验证坏点检测功能
 */

`timescale 1ns/1ps

module tb_DPC_Detector();

    // 参数定义
    parameter WIDTH = 16;
    parameter K_WIDTH = 16;
    parameter CNT_WIDTH = 10;
    parameter FRAME_HEIGHT = 10;
    parameter FRAME_WIDTH = 10;
    parameter THRESHOLD = 200;
    parameter CLK_PERIOD = 10; // 10ns时钟周期
    parameter AXI_CLK_PERIOD = 5; // 5ns AXI时钟周期 (2倍主时钟频率)
    
    // 测试信号定义
    reg aclk;
    reg aresetn;
    reg S_AXI_ACLK;  // AXI时钟，频率为aclk的2倍
    
    // 输入像素流
    reg s_axis_tvalid;
    wire s_axis_tready;
    reg [WIDTH-1:0] s_axis_tdata;
    reg s_axis_tuser;
    reg s_axis_tlast;
    
    // k值输入流
    reg k_axis_tvalid;
    reg [K_WIDTH-1:0] k_axis_tdata;
    
    // 输出像素流
    reg m_axis_tready;
    wire m_axis_tvalid;
    wire [WIDTH-1:0] m_axis_tdata;
    wire m_axis_tuser;
    wire m_axis_tlast;
    
    // 窗口输出
    wire [WIDTH-1:0] w11, w12, w13;
    wire [WIDTH-1:0] w21, w23;
    wire [WIDTH-1:0] w31, w32, w33;
    
    // k值输出流
    wire k_out_tvalid;
    wire [K_WIDTH:0] k_out_tdata;
    wire k11_vld, k12_vld, k13_vld;
    wire k21_vld, k23_vld;
    wire k31_vld, k32_vld, k33_vld;
    
    // 配置接口
    reg enable;
    reg [K_WIDTH-1:0] k_threshold;

    // 手动坏点表接口
    reg [6:0] manual_bp_num;
    reg manual_wen;
    reg [6:0] manual_waddr;
    reg [31:0] manual_wdata;
    
    // 自动检测坏点输出
    wire auto_bp_valid;
    wire [CNT_WIDTH-1:0] auto_bp_x;
    wire [CNT_WIDTH-1:0] auto_bp_y;
    
    // AXI读取接口
    reg [7:0] auto_bp_read_addr;
    wire [31:0] auto_bp_read_data;
    
    // 检测状态
    wire frame_detection_done;
    wire [7:0] detected_bp_count;
    
    // 测试数据存储
    reg [WIDTH-1:0] test_image [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    reg [K_WIDTH-1:0] test_k_values [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    reg [3:0] bad_pixel_x [0:2]; // 3个自动坏点的x坐标
    reg [3:0] bad_pixel_y [0:2]; // 3个自动坏点的y坐标
    
    // 手动坏点信息存储
    reg [3:0] manual_pixel_x [0:3]; // 4个手动坏点的x坐标
    reg [3:0] manual_pixel_y [0:3]; // 4个手动坏点的y坐标
    integer manual_pixel_count;
    
    // 控制信号
    integer row, col;
    integer frame_count;
    integer pixel_count;
    reg [15:0] detected_bp_list_x [0:255]; // 存储检测到的坏点x坐标
    reg [15:0] detected_bp_list_y [0:255]; // 存储检测到的坏点y坐标
    integer detected_count;
    
    // 用于监控输出像素流的计数器
    integer output_pixel_count;
    integer output_x_coord, output_y_coord;
    
    // 被测模块实例化
    DPC_Detector_test #(
        .WIDTH(WIDTH),
        .K_WIDTH(K_WIDTH),
        .CNT_WIDTH(CNT_WIDTH),
        .MANUAL_BP_NUM(128),
        .MANUAL_BP_BIT(7),
        .AUTO_BP_NUM(256),
        .AUTO_BP_BIT(8),
        .THRESHOLD(THRESHOLD),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .FRAME_WIDTH(FRAME_WIDTH)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        
        .k_axis_tvalid(k_axis_tvalid),
        .k_axis_tdata(k_axis_tdata),
        
        .m_axis_tready(m_axis_tready),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast),
        
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
        
        // 手动坏点表接口
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
        .detected_bp_count(detected_bp_count)
    );
    
    // 时钟生成
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end
    
    // AXI时钟生成 (频率为aclk的2倍)
    initial begin
        S_AXI_ACLK = 0;
        forever #(AXI_CLK_PERIOD/2) S_AXI_ACLK = ~S_AXI_ACLK;
    end

    // 配置手动坏点
    task setup_manual_bad_pixels();
    begin
        integer manual_bp_count;
        
        $display("=== Setting up Manual Bad Pixels ===");
        
        // 手动坏点按行列扫描顺序排列:
        // 1. (x=5,y=2) → 32'h00020005
        // 2. (x=5,y=3) → 32'h00030005  
        // 3. (x=5,y=4) → 32'h00040005
        // 4. (x=1,y=5) → 32'h00050001
        
        // 手动坏点1: (x=5,y=2)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h00;
        manual_wdata = {16'd2, 16'd5}; // y=2, x=5
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        $display("Manual Bad Pixel 1: (x=%0d,y=%0d), data=32'h%08h", 5, 2, {16'd2, 16'd5});
        
        // 手动坏点2: (x=5,y=3)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h01;
        manual_wdata = {16'd3, 16'd5}; // y=3, x=5
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        $display("Manual Bad Pixel 2: (x=%0d,y=%0d), data=32'h%08h", 5, 3, {16'd3, 16'd5});
        
        // 手动坏点3: (x=5,y=4)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h02;
        manual_wdata = {16'd3, 16'd6}; // y=3, x=6
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        $display("Manual Bad Pixel 3: (x=%0d,y=%0d), data=32'h%08h", 6, 3, {16'd3, 16'd6});
        
        // 手动坏点4: (x=1,y=5)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h03;
        manual_wdata = {16'd5, 16'd1}; // y=5, x=1
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        $display("Manual Bad Pixel 4: (x=%0d,y=%0d), data=32'h%08h", 1, 5, {16'd5, 16'd1});
        
        // 设置手动坏点总数
        manual_bp_count = 4;
        manual_bp_num = manual_bp_count;
        
        $display("Manual bad pixels setup completed. Total: %0d", manual_bp_count);
        $display("");
    end
    endtask

    // 生成测试数据
    task generate_test_data();
    begin
        integer i, j;
        reg [15:0] base_value;
        
        $display("=== Generating Test Data ===");
        
        // 生成正常图像数据（渐变图像）
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                base_value = 1000 + i * 100 + j * 10; // 渐变值
                test_image[i][j] = base_value;
                test_k_values[i][j] = base_value + $random % 20 - 10; // 正常k值，少量随机噪声
            end
        end
        
        // 设置手动坏点坐标记录（与setup_manual_bad_pixels()中的坐标保持一致）
        // 注意：x=列坐标，y=行坐标，按照行优先扫描顺序排列
        manual_pixel_count = 4;
        manual_pixel_x[0] = 5; manual_pixel_y[0] = 2; // 手动坏点1 (x=5,y=2)
        manual_pixel_x[1] = 5; manual_pixel_y[1] = 3; // 手动坏点2 (x=5,y=3)
        manual_pixel_x[2] = 6; manual_pixel_y[2] = 3; // 手动坏点3 (x=6,y=3)
        manual_pixel_x[3] = 1; manual_pixel_y[3] = 5; // 手动坏点4 (x=1,y=5)
        
        // 随机生成3个自动检测坏点位置（避免边界和手动坏点位置）
        // 注意：x=列坐标，y=行坐标
        bad_pixel_x[0] = 2; bad_pixel_y[0] = 3; // 第一个自动坏点 (x=2,y=3)
        bad_pixel_x[1] = 6; bad_pixel_y[1] = 4; // 第二个自动坏点 (x=6,y=4)
        bad_pixel_x[2] = 8; bad_pixel_y[2] = 7; // 第三个自动坏点 (x=8,y=7)
        
        // 设置自动检测坏点数据
        for (i = 0; i < 3; i = i + 1) begin
            case (i)
                0: begin // 死点 (k=0)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 0;
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 0;
                    $display("Auto Bad Point %0d: Dead point, (%0d,%0d), data=0, k=0", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i]);
                end
                1: begin // 盲点 (k值异常大)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 2000;
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 
                        test_image[bad_pixel_y[i]][bad_pixel_x[i]] + THRESHOLD + 30;
                    $display("Auto Bad Point %0d: Stuck point, (%0d,%0d), data=%0d, k=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i],
                             test_image[bad_pixel_y[i]][bad_pixel_x[i]],
                             test_k_values[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
                2: begin // 盲点 (k值异常小)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 500;
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 
                        test_image[bad_pixel_y[i]][bad_pixel_x[i]] - THRESHOLD - 30;
                    $display("Auto Bad Point %0d: Stuck point, (%0d,%0d), data=%0d, k=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i],
                             test_image[bad_pixel_y[i]][bad_pixel_x[i]],
                             test_k_values[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
            endcase
        end
        
        $display("Test data generated (3 auto bad pixels for detection testing).");
        $display("Manual bad pixels will be configured separately before frame input.");
    end
    endtask
    
    // 发送一帧图像数据
    task send_frame();
    begin
        integer i, j;
        
        $display("=== Start Sending Pixels ===");
        frame_count = frame_count + 1;
        pixel_count = 0;
        
        for (i = 0; i < FRAME_HEIGHT; i = i + 1) begin
            for (j = 0; j < FRAME_WIDTH; j = j + 1) begin
                @(posedge aclk);
                
                // 设置数据
                s_axis_tvalid = 1'b1;
                k_axis_tvalid = 1'b1;
                s_axis_tdata = test_image[i][j];
                k_axis_tdata = test_k_values[i][j];
                
                // 设置控制信号
                s_axis_tuser = (i == 0 && j == 0) ? 1'b1 : 1'b0; // SOF
                s_axis_tlast = (j == FRAME_WIDTH - 1) ? 1'b1 : 1'b0; // EOL
                
                // 等待握手
                while (!s_axis_tready) @(posedge aclk);
                
                pixel_count = pixel_count + 1;
                
                // 显示像素信息（可选）
                if (j == 0 || j == FRAME_WIDTH-1 || i == 0 || i == FRAME_HEIGHT-1) begin
                    $display("Send Pixel [%0d,%0d]: data=%0d, k=%0d, SOF=%b, EOL=%b", 
                             i, j, s_axis_tdata, k_axis_tdata, s_axis_tuser, s_axis_tlast);
                end
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
    
    // 监控坏点检测结果
    initial begin
        detected_count = 0;
        forever begin
            @(posedge aclk);
            if (m_axis_tvalid && auto_bp_valid) begin
                detected_bp_list_x[detected_count] = auto_bp_x;
                detected_bp_list_y[detected_count] = auto_bp_y;
                detected_count = detected_count + 1;
                $display("[Time %0t] Detected Bad Pixel %0d: (%0d,%0d)", 
                         $time, detected_count, auto_bp_x, auto_bp_y);
            end
        end
    end
    
    // 监控输出像素流 - 优化版本
    initial begin
        output_pixel_count = 0;
        output_x_coord = 0;
        output_y_coord = 0;
        
        forever begin
            @(posedge aclk);
            if (m_axis_tvalid && m_axis_tready) begin
                output_pixel_count = output_pixel_count + 1;
                
                // 计算当前输出像素的坐标 (窗口中心位置)
                if (m_axis_tuser) begin // SOF信号，重置坐标
                    output_x_coord = 0;
                    output_y_coord = 0;
                end else if (m_axis_tlast) begin // EOL信号，换行
                    output_x_coord = 0;
                    output_y_coord = output_y_coord + 1;
                end else begin
                    output_x_coord = output_x_coord + 1;
                end
                
                // 显示窗口信息，特别关注坏点位置
                if (output_pixel_count <= 20 || auto_bp_valid || 
                    output_pixel_count > (FRAME_HEIGHT*FRAME_WIDTH - 20)) begin
                    
                    $display("=== Output Pixel %0d at Center Position (%0d,%0d) ===", 
                             output_pixel_count, output_x_coord, output_y_coord);
                    $display("Center Pixel Value: %0d, SOF=%b, EOL=%b", 
                             m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    
                    // 显示3x3像素窗口
                    $display("3x3 Pixel Window:");
                    $display("  [%4d %4d %4d]", w11, w12, w13);
                    $display("  [%4d %4d %4d]", w21, m_axis_tdata, w23);
                    $display("  [%4d %4d %4d]", w31, w32, w33);
                    
                    // 显示k值有效标志窗口
                    $display("3x3 K Valid Flags:");
                    $display("  [%4b %4b %4b]", k11_vld, k12_vld, k13_vld);
                    $display("  [%4b %4s %4b]", k21_vld, "CTR", k23_vld);
                    $display("  [%4b %4b %4b]", k31_vld, k32_vld, k33_vld);
                    
                    // 显示k值输出信息
                    if (k_out_tvalid) begin
                        $display("K Output - Bad Flag: %b, K Value: %0d", 
                                k_out_tdata[K_WIDTH], k_out_tdata[K_WIDTH-1:0]);
                        if (k_out_tdata[K_WIDTH]) begin
                            $display("*** BAD PIXEL DETECTED AT CENTER ***");
                        end
                    end
                    $display("");
                end
            end
        end
    end
    
    // 验证检测结果 - 改进版本，考虑手动坏点和自动坏点
    task verify_detection_results();
        integer i, j;
        integer found;
        integer total_expected_auto;
        integer total_expected_manual;
        integer total_expected;
        integer correct_auto_detections;
        integer correct_manual_detections;
        integer false_positives;
        integer detected_manual_count;
        integer detected_auto_count;
    begin
        total_expected_auto = 3;
        total_expected_manual = 4;
        total_expected = total_expected_auto + total_expected_manual;
        correct_auto_detections = 0;
        correct_manual_detections = 0;
        false_positives = 0;
        detected_manual_count = 0;
        detected_auto_count = 0;

        $display("=== Verification Results ===");
        $display("Expected Auto-Detected Bad Pixels: %0d", total_expected_auto);
        $display("Expected Manual Bad Pixels: %0d", total_expected_manual);
        $display("Total Expected Bad Pixels: %0d", total_expected);
        $display("Actually Detected Bad Pixels: %0d", detected_count);
        $display("");
        
        // 显示所有预期的自动坏点
        $display("Expected Auto Bad Pixel Coordinates:");
        for (i = 0; i < 3; i = i + 1) begin
            $display("  Auto Bad Pixel %0d: (%0d,%0d)", i+1, bad_pixel_x[i], bad_pixel_y[i]);
        end
        $display("");
        
        // 显示所有预期的手动坏点
        $display("Expected Manual Bad Pixel Coordinates:");
        for (i = 0; i < 4; i = i + 1) begin
            $display("  Manual Bad Pixel %0d: (%0d,%0d)", i+1, manual_pixel_x[i], manual_pixel_y[i]);
        end
        $display("");
        
        // 显示所有实际检测到的坏点
        $display("Actually Detected Bad Pixel Coordinates:");
        for (i = 0; i < detected_count; i = i + 1) begin
            $display("  Detected %0d: (%0d,%0d)", i+1, 
                     detected_bp_list_x[i], detected_bp_list_y[i]);
        end
        $display("");
        
        // 检查每个预设自动坏点是否被检测到
        $display("Auto Detection Verification:");
        for (i = 0; i < 3; i = i + 1) begin
            found = 0;
            for (j = 0; j < detected_count; j = j + 1) begin
                if (detected_bp_list_x[j] == bad_pixel_x[i] && 
                    detected_bp_list_y[j] == bad_pixel_y[i]) begin
                    found = 1;
                    correct_auto_detections = correct_auto_detections + 1;
                    detected_auto_count = detected_auto_count + 1;
                    break;
                end
            end
            
            if (found) begin
                $display("  Auto Bad Pixel %0d at (%0d,%0d) - Successfully Detected", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
            end else begin
                $display("  Auto Bad Pixel %0d at (%0d,%0d) - NOT Detected", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
            end
        end
        $display("");
        
        // 检查每个预设手动坏点是否被检测到
        $display("Manual Bad Pixel Detection Verification:");
        for (i = 0; i < 4; i = i + 1) begin
            found = 0;
            for (j = 0; j < detected_count; j = j + 1) begin
                if (detected_bp_list_x[j] == manual_pixel_x[i] && 
                    detected_bp_list_y[j] == manual_pixel_y[i]) begin
                    found = 1;
                    correct_manual_detections = correct_manual_detections + 1;
                    detected_manual_count = detected_manual_count + 1;
                    break;
                end
            end
            
            if (found) begin
                $display(" Manual Bad Pixel %0d at (%0d,%0d) - Successfully Detected", 
                         i+1, manual_pixel_x[i], manual_pixel_y[i]);
            end else begin
                $display(" Manual Bad Pixel %0d at (%0d,%0d) - NOT Detected", 
                         i+1, manual_pixel_x[i], manual_pixel_y[i]);
            end
        end
        
        // 检查是否有误检 (false positives)
        false_positives = detected_count - correct_auto_detections - correct_manual_detections;
        if (false_positives > 0) begin
            $display("");
            $display("  ⚠ Warning: %0d False Positive(s) detected", false_positives);
            $display("  These coordinates were detected but not in expected list:");
            for (i = 0; i < detected_count; i = i + 1) begin
                found = 0;
                // 检查是否在自动坏点列表中
                for (j = 0; j < 3; j = j + 1) begin
                    if (detected_bp_list_x[i] == bad_pixel_x[j] && 
                        detected_bp_list_y[i] == bad_pixel_y[j]) begin
                        found = 1;
                        break;
                    end
                end
                // 检查是否在手动坏点列表中
                if (!found) begin
                    for (j = 0; j < 4; j = j + 1) begin
                        if (detected_bp_list_x[i] == manual_pixel_x[j] && 
                            detected_bp_list_y[i] == manual_pixel_y[j]) begin
                            found = 1;
                            break;
                        end
                    end
                end
                if (!found) begin
                    $display("    False Positive: (%0d,%0d)", 
                             detected_bp_list_x[i], detected_bp_list_y[i]);
                end
            end
        end
        
        $display("");
        $display("=== Final Summary ===");
        $display("Auto Bad Pixels Detected: %0d/%0d", correct_auto_detections, total_expected_auto);
        $display("Manual Bad Pixels Detected: %0d/%0d", correct_manual_detections, total_expected_manual);
        $display("Total Correct Detections: %0d/%0d", 
                 correct_auto_detections + correct_manual_detections, total_expected);
        $display("False Positives: %0d", false_positives);
        $display("Overall Detection Accuracy: %0.1f%%", 
                 ((correct_auto_detections + correct_manual_detections) * 100.0) / total_expected);
        
        if ((correct_auto_detections + correct_manual_detections) == total_expected && false_positives == 0) begin
            $display("All bad pixels detected correctly with no false positives.");
        end else if ((correct_auto_detections + correct_manual_detections) == total_expected) begin
            $display("All expected bad pixels detected, but with some false positives.");
        end else begin
            $display("Some expected bad pixels were missed or falsely detected.");
        end
        
        $display("Detection Process Verification Completed");
        $display("");
    end
    endtask
    
    // 读取BRAM中存储的坏点列表
    task read_bp_list_from_bram();
    begin
        integer i;
        reg [31:0] bp_data;
        reg [CNT_WIDTH-1:0] bp_x_read, bp_y_read;
        
        $display("=== 读取BRAM中的坏点列表 ===");
        
        for (i = 0; i < detected_bp_count; i = i + 1) begin
            auto_bp_read_addr = i;
            @(posedge aclk);
            @(posedge aclk); // 等待BRAM读延迟
            
            bp_data = auto_bp_read_data;
            bp_x_read = bp_data[15:0];
            bp_y_read = bp_data[31:16];
            
            $display("BRAM[%0d]: 位置(%0d,%0d)", i, bp_x_read, bp_y_read);
        end
    end
    endtask
    
    // 主测试流程
    initial begin
        $display("========================================");
        $display("DPC_Detector Testbench Starts");
        $display("Frame Size: %0dx%0d", FRAME_WIDTH, FRAME_HEIGHT);
        $display("Detecting Threshold: %0d", THRESHOLD);
        $display("Main Clock Period: %0d ns", CLK_PERIOD);
        $display("AXI Clock Period: %0d ns (2x frequency)", AXI_CLK_PERIOD);
        $display("Manual Bad Pixels: 4 (1 individual + 3 column-adjacent)");
        $display("Auto Bad Pixels: 3 (for detection testing)");
        $display("========================================");
        
        // 初始化信号
        aresetn = 1'b0;
        s_axis_tvalid = 1'b0;
        k_axis_tvalid = 1'b0;
        s_axis_tdata = 16'b0;
        k_axis_tdata = 16'b0;
        s_axis_tuser = 1'b0;
        s_axis_tlast = 1'b0;
        m_axis_tready = 1'b1;
        enable = 1'b1;
        k_threshold = THRESHOLD;

        // 手动坏点表初始化
        manual_bp_num = 7'b0;
        manual_wen = 1'b0;
        manual_waddr = 7'b0;
        manual_wdata = 32'b0;
        auto_bp_read_addr = 8'b0;
        
        frame_count = 0;
        
        // 复位
        #(CLK_PERIOD * 10);
        aresetn = 1'b1;
        #(CLK_PERIOD * 5);
        
        // 配置手动坏点（在帧输入开始前）
        setup_manual_bad_pixels();
        
        // 生成测试数据（包含自动检测用的坏点）
        generate_test_data();
        
        // 等待稳定
        #(CLK_PERIOD * 10);
        
        // 发送测试帧
        send_frame();
        
        // 等待处理完成
        $display("Waiting for detection to complete...");
        wait(frame_detection_done);
        #(CLK_PERIOD * 100);
        
        // 验证结果（考虑手动坏点和自动坏点）
        verify_detection_results();
        
        // 读取BRAM数据
        // read_bp_list_from_bram();
        
        $display("========================================");
        $display("Testbench Verification Completed");
        $display("Total Expected Bad Pixels: %0d (4 manual + 3 auto)", 7);
        $display("========================================");
        
        #(CLK_PERIOD * 50);
        $finish;
    end
    
    // VCD波形文件生成
    initial begin
        $dumpfile("tb_DPC_Detector.vcd");
        $dumpvars(0, tb_DPC_Detector);
    end

endmodule
