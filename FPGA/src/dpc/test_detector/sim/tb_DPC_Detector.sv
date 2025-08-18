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
    parameter THRESHOLD = 50;
    parameter CLK_PERIOD = 10; // 10ns时钟周期
    
    // 测试信号定义
    reg aclk;
    reg aresetn;
    
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
    reg [2:0] bad_pixel_x [0:2]; // 3个坏点的x坐标
    reg [2:0] bad_pixel_y [0:2]; // 3个坏点的y坐标
    
    // 控制信号
    integer row, col;
    integer frame_count;
    integer pixel_count;
    reg [7:0] detected_bp_list [0:255]; // 存储检测到的坏点
    integer detected_count;
    
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
        
        // 随机生成3个坏点位置（避免边界）
        bad_pixel_x[0] = 2; bad_pixel_y[0] = 3; // 第一个坏点
        bad_pixel_x[1] = 6; bad_pixel_y[1] = 4; // 第二个坏点  
        bad_pixel_x[2] = 8; bad_pixel_y[2] = 7; // 第三个坏点
        
        // 设置坏点数据
        for (i = 0; i < 3; i = i + 1) begin
            case (i)
                0: begin // 死点 (k=0)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 0;
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 0;
                    $display("Bad Point %0d: Dead point, (%0d,%0d), data=0, k=0", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i]);
                end
                1: begin // 盲点 (k值异常大)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 2000;
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 
                        test_image[bad_pixel_y[i]][bad_pixel_x[i]] + THRESHOLD + 30;
                    $display("Bad Point %0d: Stuck point, (%0d,%0d), data=%0d, k=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i],
                             test_image[bad_pixel_y[i]][bad_pixel_x[i]],
                             test_k_values[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
                2: begin // 盲点 (k值异常小)
                    test_image[bad_pixel_y[i]][bad_pixel_x[i]] = 500;
                    test_k_values[bad_pixel_y[i]][bad_pixel_x[i]] = 
                        test_image[bad_pixel_y[i]][bad_pixel_x[i]] - THRESHOLD - 30;
                    $display("Bad Point %0d: Stuck point, (%0d,%0d), data=%0d, k=%0d", 
                             i+1, bad_pixel_x[i], bad_pixel_y[i],
                             test_image[bad_pixel_y[i]][bad_pixel_x[i]],
                             test_k_values[bad_pixel_y[i]][bad_pixel_x[i]]);
                end
            endcase
        end
        
        $display("Test data generated. ");
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
            if (s_axis_tvalid && auto_bp_valid) begin
                detected_bp_list[detected_count*2] = auto_bp_x;
                detected_bp_list[detected_count*2+1] = auto_bp_y;
                detected_count = detected_count + 1;
                $display("Detected Bad Pixel %0d: (%0d,%0d)", detected_count, auto_bp_x, auto_bp_y);
            end
        end
    end
    
    // 监控输出像素流
    integer output_count = 0;
    initial begin
        forever begin
            @(posedge aclk);
            if (m_axis_tvalid && m_axis_tready) begin
                output_count = output_count + 1;
                if (output_count <= 10 || output_count > (FRAME_HEIGHT*FRAME_WIDTH - 10)) begin
                    $display("Output Pixel %0d: data=%0d, SOF=%b, EOL=%b, in the middle of the window", 
                             output_count, m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    $display("  3x3 Window: [%4d %4d %4d]", w11, w12, w13);
                    $display("           [%4d %4s %4d]", w21, "CTR", w23);
                    $display("           [%4d %4d %4d]", w31, w32, w33);
                    $display("  k is valid: [%b %b %b]", k11_vld, k12_vld, k13_vld);
                    $display("           [%b %s %b]", k21_vld, "X", k23_vld);
                    $display("           [%b %b %b]", k31_vld, k32_vld, k33_vld);
                    if (k_out_tvalid) begin
                        $display("  k output: Bad point flag=%b, k=%0d", 
                                k_out_tdata[K_WIDTH], k_out_tdata[K_WIDTH-1:0]);
                    end
                end
            end
        end
    end
    
    // 验证检测结果
    task verify_detection_results();
    begin
        integer i, j;
        integer found;
        integer total_expected = 3;

        $display("=== Verification Results ===");
        $display("Expected Number: %0d", total_expected);
        $display("Actual Number: %0d", detected_bp_count);
        
        // 检查每个预设坏点是否被检测到
        for (i = 0; i < 3; i = i + 1) begin
            found = 0;
            for (j = 0; j < detected_count; j = j + 1) begin
                if (detected_bp_list[j*2] == bad_pixel_x[i] && 
                    detected_bp_list[j*2+1] == bad_pixel_y[i]) begin
                    found = 1;
                    break;
                end
            end
            
            if (found) begin
                $display("✓ Bad Point %0d (%0d,%0d) Success", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
            end else begin
                $display("✗ Bad Point %0d (%0d,%0d) Not Detected", 
                         i+1, bad_pixel_x[i], bad_pixel_y[i]);
            end
        end
        
        // 检查是否有误检
        if (detected_count > total_expected) begin
            $display("Warning: Detected extra bad points, possible false positives");
        end
        
        $display("Detect Process Verified");
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
    
        
        frame_count = 0;
        
        // 复位
        #(CLK_PERIOD * 10);
        aresetn = 1'b1;
        #(CLK_PERIOD * 5);
        
        // 生成测试数据
        generate_test_data();
        
        // 等待稳定
        #(CLK_PERIOD * 10);
        
        // 发送测试帧
        send_frame();
        
        // 等待处理完成
        $display("Waiting detection to end...");
        wait(frame_detection_done);
        #(CLK_PERIOD * 100);
        
        // 验证结果
        verify_detection_results();
        
        // 读取BRAM数据
        // read_bp_list_from_bram();
        
        $display("========================================");
        $display("Verification Ends");
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
