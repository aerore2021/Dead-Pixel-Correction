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
    parameter FRAME_HEIGHT = 20;     // 测试图像尺寸20x20（小尺寸用于调试）
    parameter FRAME_WIDTH = 20;      // 注意：这里WIDTH是行长度，HEIGHT是列数
    parameter THRESHOLD_AUTO = 300;  // 自动检测阈值（较大，不敏感）
    parameter THRESHOLD_MANUAL = 150; // 手动检测阈值（较小，更敏感）
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
    wire delayed;  // 添加delayed信号监控
    
    // 测试数据存储
    reg [WIDTH-1:0] test_image [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    reg [K_WIDTH-1:0] test_k_values [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    reg [4:0] bad_pixel_x [0:2]; // 3个自动坏点的x坐标 (5位支持0-19)
    reg [4:0] bad_pixel_y [0:2]; // 3个自动坏点的y坐标
    
    // 手动坏点信息存储 (现在是区域中心坐标)
    reg [4:0] manual_pixel_x [0:2]; // 3个手动区域的x中心坐标 (5位支持0-19)
    reg [4:0] manual_pixel_y [0:2]; // 3个手动区域的y中心坐标
    integer manual_pixel_count;
    
    // 控制信号
    integer row, col;
    integer frame_count;
    integer pixel_count;
    reg [15:0] detected_bp_list_x [0:255]; // 存储检测到的坏点x坐标
    reg [15:0] detected_bp_list_y [0:255]; // 存储检测到的坏点y坐标
    integer detected_count;
    
    // 用于监控输出像素流的计数器
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
        .THRESHOLD_AUTO(THRESHOLD_AUTO),
        .THRESHOLD_MANUAL(THRESHOLD_MANUAL),
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
        .detected_bp_count(detected_bp_count),
        .delayed(delayed)  // 连接delayed信号用于监控
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
        $display("新逻辑：手动标记坐标的5x5范围内使用更小阈值定位坏点");
        $display("检测原理：k值与邻域k值差异");
        $display("自动阈值=%0d (k vs neighbors), 手动阈值=%0d (k vs neighbors)", THRESHOLD_AUTO, THRESHOLD_MANUAL);
        $display("按照32位数值从小到大顺序配置手动区域坐标");
        
        // 手动区域按32位数值从小到大排序:
        // 1. {16'd5, 16'd15} = 32'h0005000F (y=5, x=15)
        // 2. {16'd8, 16'd8}  = 32'h00080008 (y=8, x=8) 
        // 3. {16'd12, 16'd3} = 32'h000C0003 (y=12, x=3)
        
        // 手动区域1: 中心坐标(15,5)，5x5范围[13:17][3:7]  
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h00;
        manual_wdata = {16'd5, 16'd15}; // y=5, x=15 (32'h0005000F)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        $display("Manual Region 1: center(x=%0d,y=%0d), 5x5 area[13:17][3:7], data=32'h%08h", 15, 5, {16'd5, 16'd15});
        
        // 手动区域2: 中心坐标(8,8)，5x5范围[6:10][6:10]
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h01;
        manual_wdata = {16'd8, 16'd8}; // y=8, x=8 (32'h00080008)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        $display("Manual Region 2: center(x=%0d,y=%0d), 5x5 area[6:10][6:10], data=32'h%08h", 8, 8, {16'd8, 16'd8});
        
        // 手动区域3: 中心坐标(3,12)，5x5范围[1:5][10:14]
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b1;
        manual_waddr = 7'h02;
        manual_wdata = {16'd12, 16'd3}; // y=12, x=3 (32'h000C0003)
        @(posedge S_AXI_ACLK);
        manual_wen = 1'b0;
        $display("Manual Region 3: center(x=%0d,y=%0d), 5x5 area[1:5][10:14], data=32'h%08h", 3, 12, {16'd12, 16'd3});
        
        // 设置手动坏点总数
        manual_bp_count = 3;
        manual_bp_num = manual_bp_count;
        
        $display("Manual regions setup completed. Total: %0d", manual_bp_count);
        $display("");
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
                base_value = 2000 + i * 50 + j * 10; // 基础渐变值
                test_image[i][j] = base_value;
                test_k_values[i][j] = base_value + $random % 40 - 20; // 正常k值，少量随机噪声
            end
        end
        
        // 在手动区域1 [6:10][6:10] 中心(8,8)设置微弱坏点
        // 设计k值与邻域k值的差异：手动阈值(150) < 差值 < 自动阈值(300)
        
        // 微弱坏点1: (9,7) - k值异常偏高
        test_image[7][9] = 2000 + 7 * 50 + 9 * 10;  // 正常的data值
        // 邻域的正常k值大约在2000+7*50+9*10±20 = 2440±20范围
        // 设计该点k值比邻域k值高200，满足150<200<300
        test_k_values[7][9] = (2000 + 7 * 50 + 9 * 10) + 200; 
        $display("微弱坏点1: (x=%0d,y=%0d), data=%0d, k=%0d", 
                 9, 7, test_image[7][9], test_k_values[7][9]);
        $display("  预期邻域k值约为%0d±20，k值比邻域高约%0d", 
                 2000 + 7 * 50 + 9 * 10, 200);
        
        // 微弱坏点2: (7,9) - k值异常偏低  
        test_image[9][7] = 2000 + 9 * 50 + 7 * 10;  // 正常的data值
        // 邻域的正常k值大约在2000+9*50+7*10±20 = 2520±20范围
        // 设计该点k值比邻域k值低240，满足150<240<300
        test_k_values[9][7] = (2000 + 9 * 50 + 7 * 10) - 240;
        $display("微弱坏点2: (x=%0d,y=%0d), data=%0d, k=%0d", 
                 7, 9, test_image[9][7], test_k_values[9][7]);
        $display("  预期邻域k值约为%0d±20，k值比邻域低约%0d", 
                 2000 + 9 * 50 + 7 * 10, 240);
        
        // 在手动区域2 [13:17][3:7] 中心(15,5)设置微弱坏点群
        // 微弱坏点3: (14,4) - k值异常偏高
        test_image[4][14] = 2000 + 4 * 50 + 14 * 10;  // 正常data值
        test_k_values[4][14] = (2000 + 4 * 50 + 14 * 10) + 180; // k值比邻域k值高180
        $display("微弱坏点3: (x=%0d,y=%0d), data=%0d, k=%0d, k值比邻域高%0d", 
                 14, 4, test_image[4][14], test_k_values[4][14], 180);
        
        // 微弱坏点4: (16,6) - k值异常偏低
        test_image[6][16] = 2000 + 6 * 50 + 16 * 10;  // 正常data值  
        test_k_values[6][16] = (2000 + 6 * 50 + 16 * 10) - 220; // k值比邻域k值低220
        $display("微弱坏点4: (x=%0d,y=%0d), data=%0d, k=%0d, k值比邻域低%0d", 
                 16, 6, test_image[6][16], test_k_values[6][16], 220);
        
        // 在手动区域3 [1:5][10:14] 中心(3,12)设置边界微弱坏点
        // 微弱坏点5: (2,11) - k值异常偏高
        test_image[11][2] = 2000 + 11 * 50 + 2 * 10;  // 正常data值
        test_k_values[11][2] = (2000 + 11 * 50 + 2 * 10) + 170; // k值比邻域k值高170
        $display("边界微弱坏点: (x=%0d,y=%0d), data=%0d, k=%0d, k值比邻域高%0d", 
                 2, 11, test_image[11][2], test_k_values[11][2], 170);
        
        // 设置手动区域坐标记录（按照setup_manual_bad_pixels()中的新顺序）
        manual_pixel_count = 3;
        manual_pixel_x[0] = 15; manual_pixel_y[0] = 5;  // 区域1中心 (32'h0005000F)
        manual_pixel_x[1] = 8; manual_pixel_y[1] = 8;   // 区域2中心 (32'h00080008)
        manual_pixel_x[2] = 3; manual_pixel_y[2] = 12;  // 区域3中心 (32'h000C0003)
        
        // 设置自动检测坏点（明显坏点，差值>300）
        // 注意：x=列坐标，y=行坐标
        bad_pixel_x[0] = 3; bad_pixel_y[0] = 4; // 第一个自动坏点 (x=3,y=4)
        bad_pixel_x[1] = 12; bad_pixel_y[1] = 8; // 第二个自动坏点 (x=12,y=8)
        bad_pixel_x[2] = 18; bad_pixel_y[2] = 15; // 第三个自动坏点 (x=18,y=15)
        
        // 设置自动检测坏点数据（明显坏点）
        for (i = 0; i < 3; i = i + 1) begin
            case (i)
                0: begin // 死点 (k=0)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 0;
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 0;
                    $display("Auto Bad Point %0d: Dead point, (x=%0d,y=%0d), data=0, k=0", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i]);
                end
                1: begin // 盲点 (k值异常大) - k值比邻域k值高350以上
                    reg [15:0] expected_neighbor_k;
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 2000 + bad_pixel_y[i] * 50 + bad_pixel_x[i] * 10;
                    expected_neighbor_k = test_image[bad_pixel_y[i]][bad_pixel_x[i]]; // 邻域k值约等于邻域图像值
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = expected_neighbor_k + THRESHOLD_AUTO + 50; // 比邻域k值高350
                    $display("Auto Bad Point %0d: Stuck point, (x=%0d,y=%0d), data=%0d, k=%0d, k vs neighbor_k diff=+%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i],
                             test_image[bad_pixel_y[i]][bad_pixel_x[i]],
                             test_k_values[bad_pixel_y[i]][bad_pixel_x[i]], THRESHOLD_AUTO + 50);
                end
                2: begin // 盲点 (k值异常小) - k值比邻域k值低350以上
                    reg [15:0] expected_neighbor_k;
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 2000 + bad_pixel_y[i] * 50 + bad_pixel_x[i] * 10;
                    expected_neighbor_k = test_image[bad_pixel_y[i]][bad_pixel_x[i]]; // 邻域k值约等于邻域图像值
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = expected_neighbor_k - THRESHOLD_AUTO - 50; // 比邻域k值低350
                    $display("Auto Bad Point %0d: Stuck point, (x=%0d,y=%0d), data=%0d, k=%0d, k vs neighbor_k diff=-%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i],
                             test_image[bad_pixel_y[i]][bad_pixel_x[i]],
                             test_k_values[bad_pixel_y[i]][bad_pixel_x[i]], THRESHOLD_AUTO + 50);
                end
            endcase
        end
        
        $display("Test data generated:");
        $display("- 3 auto bad pixels for automatic detection (k vs neighbor_k > %0d)", THRESHOLD_AUTO);
        $display("- 5 weak bad pixels in manual regions (%0d < k vs neighbor_k < %0d)", THRESHOLD_MANUAL, THRESHOLD_AUTO);
        $display("- Manual regions will be processed with smaller threshold");
        $display("- Weak bad pixels designed with k vs neighborhood k differences in range [150,300]");
        $display("- Auto bad pixels designed with k vs neighborhood k differences > 350");
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
            if (auto_bp_valid && delayed) begin
                detected_bp_list_x[detected_count] = auto_bp_x;
                detected_bp_list_y[detected_count] = auto_bp_y;
                detected_count = detected_count + 1;
                $display("[Time %0t] Detected Bad Pixel %0d: (%0d,%0d)", 
                         $time, detected_count, auto_bp_x, auto_bp_y);
            end
        end
    end
    
    // 用于监控输出像素流的计数器（简化版本）
    integer output_pixel_count;
    
    initial begin
        output_pixel_count = 0;
        forever begin
            @(posedge aclk);
            if (m_axis_tvalid && m_axis_tready) begin
                output_pixel_count = output_pixel_count + 1;
                
                // 只显示关键信息
                if (output_pixel_count == 1) begin
                    $display("=== Output Stream Started ===");
                end
                else if (output_pixel_count % 1000 == 0) begin
                    $display("Processed %0d pixels...", output_pixel_count);
                end
            end
        end
    end
    
    // 验证检测结果 - 简化版本，专注于结果对比
    task verify_detection_results();
        integer i, j;
        integer found;
        integer total_expected_auto;
        integer total_expected_manual;
        integer correct_auto_detections;
        integer correct_manual_detections;
        integer false_positives;
    begin
        total_expected_auto = 3;
        total_expected_manual = 5;  // 5个微弱坏点在手动区域内
        correct_auto_detections = 0;
        correct_manual_detections = 0;

        $display("");
        $display("========================================");
        $display("=== DETECTION VERIFICATION RESULTS ===");
        $display("========================================");
        $display("Expected Auto-Detected Bad Pixels: %0d", total_expected_auto);
        $display("Expected Manual Bad Pixels: %0d", total_expected_manual);
        $display("Actually Detected Bad Pixels: %0d", detected_count);
        $display("");
        
        // 显示预期的自动坏点
        $display("=== Expected Auto Bad Pixels ===");
        for (i = 0; i < 3; i = i + 1) begin
            $display("  Auto BP %0d: (%0d,%0d)", i+1, bad_pixel_x[i], bad_pixel_y[i]);
        end
        $display("");
        
        // 显示预期的手动区域坏点
        $display("=== Expected Manual Region Weak Bad Pixels ===");
        $display("  Weak BP 1: (9,7) in manual region [6:10][6:10]");
        $display("  Weak BP 2: (7,9) in manual region [6:10][6:10]");
        $display("  Weak BP 3: (14,4) in manual region [13:17][3:7]");
        $display("  Weak BP 4: (16,6) in manual region [13:17][3:7]");
        $display("  Weak BP 5: (2,11) in manual region [1:5][10:14]");
        $display("");
        
        // 显示实际检测结果
        $display("=== Actually Detected Bad Pixels ===");
        for (i = 0; i < detected_count; i = i + 1) begin
            $display("  Detected %0d: (%0d,%0d)", i+1, 
                     detected_bp_list_x[i], detected_bp_list_y[i]);
        end
        $display("");
        
        // 检查自动坏点检测
        $display("=== Auto Detection Verification ===");
        for (i = 0; i < 3; i = i + 1) begin
            found = 0;
            for (j = 0; j < detected_count; j = j + 1) begin
                if (detected_bp_list_x[j] == bad_pixel_x[i] && 
                    detected_bp_list_y[j] == bad_pixel_y[i]) begin
                    found = 1;
                    correct_auto_detections = correct_auto_detections + 1;
                    break;
                end
            end
            
            if (found) begin
                $display("  ✓ Auto BP %0d at (%0d,%0d) - DETECTED", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
            end else begin
                $display("  ✗ Auto BP %0d at (%0d,%0d) - MISSED", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
            end
        end
        $display("");
        
        // 检查手动区域内的微弱坏点
        $display("=== Manual Region Detection Verification ===");
        
        // 手动区域1内的微弱坏点
        found = 0;
        for (j = 0; j < detected_count; j = j + 1) begin
            if ((detected_bp_list_x[j] == 9 && detected_bp_list_y[j] == 7) ||
                (detected_bp_list_x[j] == 7 && detected_bp_list_y[j] == 9)) begin
                found = found + 1;
                correct_manual_detections = correct_manual_detections + 1;
            end
        end
        $display("  Region 1 [6:10][6:10]: %0d/2 weak bad pixels detected", found);
        
        // 手动区域2内的微弱坏点
        found = 0;
        for (j = 0; j < detected_count; j = j + 1) begin
            if ((detected_bp_list_x[j] == 14 && detected_bp_list_y[j] == 4) ||
                (detected_bp_list_x[j] == 16 && detected_bp_list_y[j] == 6)) begin
                found = found + 1;
                correct_manual_detections = correct_manual_detections + 1;
            end
        end
        $display("  Region 2 [13:17][3:7]: %0d/2 weak bad pixels detected", found);
        
        // 手动区域3内的微弱坏点
        found = 0;
        for (j = 0; j < detected_count; j = j + 1) begin
            if (detected_bp_list_x[j] == 2 && detected_bp_list_y[j] == 11) begin
                found = found + 1;
                correct_manual_detections = correct_manual_detections + 1;
            end
        end
        $display("  Region 3 [1:5][10:14]: %0d/1 weak bad pixels detected", found);
        $display("");
        
        // 检查误检
        false_positives = detected_count - correct_auto_detections - correct_manual_detections;
        
        $display("=== FINAL SUMMARY ===");
        $display("Auto Bad Pixels: %0d/%0d detected", correct_auto_detections, total_expected_auto);
        $display("Manual Bad Pixels: %0d/%0d detected", correct_manual_detections, total_expected_manual);
        $display("False Positives: %0d", false_positives);
        $display("Overall Accuracy: %0.1f%%", 
                 ((correct_auto_detections + correct_manual_detections) * 100.0) / 
                 (total_expected_auto + total_expected_manual));
        
        if ((correct_auto_detections == total_expected_auto) && 
            (correct_manual_detections == total_expected_manual) && 
            (false_positives == 0)) begin
            $display("🎉 PERFECT: All bad pixels detected correctly!");
        end else if ((correct_auto_detections + correct_manual_detections) >= 6) begin
            $display("✅ GOOD: Most bad pixels detected successfully");
        end else begin
            $display("⚠️  NEEDS IMPROVEMENT: Some expected bad pixels missed");
        end
        
        $display("========================================");
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
        $display("Auto Detection Threshold: %0d", THRESHOLD_AUTO);
        $display("Manual Detection Threshold: %0d", THRESHOLD_MANUAL);
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
        k_threshold = THRESHOLD_AUTO;

        // 手动坏点表初始化
        manual_bp_num = 7'b0;
        manual_wen = 1'b0;
        manual_waddr = 7'b0;
        manual_wdata = 32'b0;
        auto_bp_read_addr = 8'b0;
        
        frame_count = 0;
        
        // 复位
        $display("=== System Reset ===");
        #(CLK_PERIOD * 10);
        aresetn = 1'b1;
        #(CLK_PERIOD * 5);
        
        // 配置手动坏点
        $display("=== Configuring Manual Bad Pixels ===");
        setup_manual_bad_pixels();
        
        // 为手动坏点预处理预留充足时间
        $display("=== Waiting for Manual Bad Pixel Preprocessing ===");
        $display("Allowing time for line cache initialization...");
        #(CLK_PERIOD * 200);  // 增加等待时间，确保手动坏点配置生效
        
        // 生成测试数据
        $display("=== Generating Test Data ===");
        generate_test_data();
        
        // 再次等待稳定
        $display("=== System Stabilization ===");
        #(CLK_PERIOD * 100);
        
        // 发送测试帧
        $display("=== Sending Test Frame ===");
        send_frame();
        
        // 等待处理完成
        $display("=== Waiting for Detection Completion ===");
        wait(frame_detection_done);
        
        // 额外等待确保所有检测完成
        $display("=== Final Processing Wait ===");
        #(CLK_PERIOD * 200);
        
        // 验证结果
        verify_detection_results();
        
        $display("========================================");
        $display("Testbench Completed Successfully");
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
