`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025
// Design Name: Dead Pixel Correction Testbench
// Module Name: tb_DPC_Detector
// Project Name: DPC
// Target Devices: 
// Tool Versions: 
// Description: Testbench for Dead Pixel Correction FPGA Implementation
//              - Loads bad pixel list via AXI4-Lite interface
//              - Reads test images from TXT files
//              - Writes corrected images to TXT files
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_DPC_Detector();

    // Parameters
    parameter ROW              = 288;
    parameter COL              = 384;
    parameter AXIS_TDATA_WIDTH = 14;
    parameter AXI_DATA_WIDTH   = 32;
    parameter AXI_ADDR_WIDTH   = 32;
    parameter CLK_PERIOD       = 20;  // 100MHz
    parameter AXI_CLK_PERIOD   = 5;  // 100MHz
    
    // Bad pixel list: [row, col]
    // [29, 156; 82, 132; 82, 133; 83, 132; 83, 133]
    parameter NUM_BAD_PIXELS   = 5;
    
    // Test image path (absolute path from project root)
    parameter IMAGE_INPUT_PATH  = "D:/feizhileng/Dead-Pixel-Correction/FPGA_v2/image_inputs/dpc_test_8/1.txt";
    parameter IMAGE_OUTPUT_PATH = "D:/feizhileng/Dead-Pixel-Correction/FPGA_v2/FPGA_outputs/8_out.txt";
    
    // Clock and Reset
    reg axis_aclk;
    reg axis_aresetn;
    reg s00_axi_aclk;
    reg s00_axi_aresetn;
    
    // AXI4-Stream Slave Interface (Input)
    reg                           s_axis_tvalid;
    reg  [AXIS_TDATA_WIDTH-1 : 0] s_axis_tdata;
    reg                           s_axis_tuser;
    reg                           s_axis_tlast;
    wire                          s_axis_tready;
    
    // AXI4-Stream Master Interface (Output)
    wire                          m_axis_tvalid;
    wire [AXIS_TDATA_WIDTH-1 : 0] m_axis_tdata;
    wire                          m_axis_tuser;
    wire                          m_axis_tlast;
    reg                           m_axis_tready;
    
    // AXI4-Lite Slave Interface
    reg  [AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr;
    reg  [              2 : 0] s00_axi_awprot;
    reg                        s00_axi_awvalid;
    wire                       s00_axi_awready;
    reg  [AXI_DATA_WIDTH-1 : 0] s00_axi_wdata;
    reg  [(AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb;
    reg                        s00_axi_wvalid;
    wire                       s00_axi_wready;
    wire [              1 : 0] s00_axi_bresp;
    wire                       s00_axi_bvalid;
    reg                        s00_axi_bready;
    reg  [AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr;
    reg  [              2 : 0] s00_axi_arprot;
    reg                        s00_axi_arvalid;
    wire                       s00_axi_arready;
    wire [AXI_DATA_WIDTH-1 : 0] s00_axi_rdata;
    wire [              1 : 0] s00_axi_rresp;
    wire                       s00_axi_rvalid;
    reg                        s00_axi_rready;
    
    // DUT Instance
    DpcTop #(
        .ROW             (ROW),
        .COL             (COL),
        .AXIS_TDATA_WIDTH(AXIS_TDATA_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH)
    ) dut (
        .axis_aclk       (axis_aclk),
        .axis_aresetn    (axis_aresetn),
        .m_axis_tready   (m_axis_tready),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tuser    (m_axis_tuser),
        .m_axis_tlast    (m_axis_tlast),
        .s_axis_tready   (s_axis_tready),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tuser    (s_axis_tuser),
        .s_axis_tlast    (s_axis_tlast),
        .s00_axi_aclk    (s00_axi_aclk),
        .s00_axi_aresetn (s00_axi_aresetn),
        .s00_axi_awaddr  (s00_axi_awaddr),
        .s00_axi_awprot  (s00_axi_awprot),
        .s00_axi_awvalid (s00_axi_awvalid),
        .s00_axi_awready (s00_axi_awready),
        .s00_axi_wdata   (s00_axi_wdata),
        .s00_axi_wstrb   (s00_axi_wstrb),
        .s00_axi_wvalid  (s00_axi_wvalid),
        .s00_axi_wready  (s00_axi_wready),
        .s00_axi_bresp   (s00_axi_bresp),
        .s00_axi_bvalid  (s00_axi_bvalid),
        .s00_axi_bready  (s00_axi_bready),
        .s00_axi_araddr  (s00_axi_araddr),
        .s00_axi_arprot  (s00_axi_arprot),
        .s00_axi_arvalid (s00_axi_arvalid),
        .s00_axi_arready (s00_axi_arready),
        .s00_axi_rdata   (s00_axi_rdata),
        .s00_axi_rresp   (s00_axi_rresp),
        .s00_axi_rvalid  (s00_axi_rvalid),
        .s00_axi_rready  (s00_axi_rready)
    );
    
    // Clock Generation
    initial begin
        axis_aclk = 0;
        forever #(CLK_PERIOD/2) axis_aclk = ~axis_aclk;
    end
    
    initial begin
        s00_axi_aclk = 0;
        forever #(AXI_CLK_PERIOD/2) s00_axi_aclk = ~s00_axi_aclk;
    end
    
    // File handles
    integer input_file;
    integer output_file;
    integer status;
    
    // Image data storage
    reg [AXIS_TDATA_WIDTH-1:0] image_data [0:ROW*COL-1];
    integer pixel_count;
    
    // Bad pixel list: [row, col]
    // Format: col[15:0], row[15:0]
    reg [31:0] bad_pixels [0:NUM_BAD_PIXELS-1];
    
    // Initialize bad pixel list
    initial begin
        // Bad pixel coordinates: [row, col]
        // [29, 156; 82, 132; 82, 133; 83, 132; 83, 133]
        // Format in manual.v: {width_bad[31:16], height_bad[15:0]} = {col, row}
        bad_pixels[0] = {16'd156, 16'd29};   // [29, 156] -> {col=156, row=29}
        bad_pixels[1] = {16'd132, 16'd82};   // [82, 132] -> {col=132, row=82}
        bad_pixels[2] = {16'd133, 16'd82};   // [82, 133] -> {col=133, row=82}
        bad_pixels[3] = {16'd132, 16'd83};   // [83, 132] -> {col=132, row=83}
        bad_pixels[4] = {16'd133, 16'd83};   // [83, 133] -> {col=133, row=83}
    end
    
    // Task: Load Image from File
    task load_image;
        integer i;
        reg [AXIS_TDATA_WIDTH-1:0] pixel_value;
        string line;
        begin
            $display("[%0t] Loading image from %s...", $time, IMAGE_INPUT_PATH);
            
            input_file = $fopen(IMAGE_INPUT_PATH, "r");
            if (input_file == 0) begin
                $display("ERROR: Cannot open input file: %s", IMAGE_INPUT_PATH);
                $finish;
            end
            
            pixel_count = 0;
            while (!$feof(input_file) && pixel_count < ROW*COL) begin
                status = $fscanf(input_file, "%h\n", pixel_value);
                if (status == 1) begin
                    image_data[pixel_count] = pixel_value;
                    pixel_count = pixel_count + 1;
                end
            end
            
            $fclose(input_file);
            $display("[%0t] Loaded %0d pixels", $time, pixel_count);
            
            if (pixel_count != ROW*COL) begin
                $display("WARNING: Expected %0d pixels, loaded %0d", ROW*COL, pixel_count);
            end
        end
    endtask
    
    // Task: Send Image via AXI4-Stream
    task send_image;
        integer row, col, idx;
        begin
            $display("[%0t] Sending image via AXI4-Stream...", $time);
            
            for (row = 0; row < ROW; row = row + 1) begin
                for (col = 0; col < COL; col = col + 1) begin
                    idx = row * COL + col;
                    
                    @(posedge axis_aclk);
                    s_axis_tvalid = 1'b1;
                    s_axis_tdata  = image_data[idx];
                    s_axis_tuser  = (row == 0 && col == 0) ? 1'b1 : 1'b0;
                    s_axis_tlast  = (col == COL - 1) ? 1'b1 : 1'b0;
                    
                    // Wait for ready
                    wait(s_axis_tready);
                end
            end
            
            @(posedge axis_aclk);
            s_axis_tvalid = 1'b1;
            s_axis_tuser  = 1'b0;
            s_axis_tlast  = 1'b0;
            
            $display("[%0t] Image sent successfully", $time);
        end
    endtask
    
    // Task: Receive and Save Output Image
    task receive_image;
        integer pixel_cnt;
        integer row_cnt, col_cnt;
        begin
            $display("[%0t] Receiving output image...", $time);
            
            output_file = $fopen(IMAGE_OUTPUT_PATH, "w");
            if (output_file == 0) begin
                $display("ERROR: Cannot open output file: %s", IMAGE_OUTPUT_PATH);
                $finish;
            end
            
            pixel_cnt = 0;
            row_cnt = 0;
            col_cnt = 0;
            
            while (pixel_cnt < ROW*COL) begin
                @(posedge axis_aclk);
                if (m_axis_tvalid && m_axis_tready) begin
                    $fwrite(output_file, "%04h\n", m_axis_tdata);
                    pixel_cnt = pixel_cnt + 1;
                    
                    if (m_axis_tlast) begin
                        col_cnt = 0;
                        row_cnt = row_cnt + 1;
                    end else begin
                        col_cnt = col_cnt + 1;
                    end
                end
            end
            
            $fclose(output_file);
            $display("[%0t] Output image saved to %s", $time, IMAGE_OUTPUT_PATH);
            $display("  Total pixels received: %0d", pixel_cnt);
        end
    endtask
    
    // Main Test Sequence
    integer i;
    initial begin
        // Initialize signals
        axis_aresetn     = 1'b0;
        s00_axi_aresetn  = 1'b0;
        s_axis_tvalid    = 1'b0;
        s_axis_tdata     = 'd0;
        s_axis_tuser     = 1'b0;
        s_axis_tlast     = 1'b0;
        m_axis_tready    = 1'b1;
        s00_axi_awaddr   = 'd0;
        s00_axi_awprot   = 3'b000;
        s00_axi_awvalid  = 1'b0;
        s00_axi_wdata    = 'd0;
        s00_axi_wstrb    = 4'h0;
        s00_axi_wvalid   = 1'b0;
        s00_axi_bready   = 1'b1;  // Always ready for response
        s00_axi_araddr   = 'd0;
        s00_axi_arprot   = 3'b000;
        s00_axi_arvalid  = 1'b0;
        s00_axi_rready   = 1'b0;
        
        // Reset sequence
        $display("========================================");
        $display("  Dead Pixel Correction Test Started");
        $display("========================================");
        $display("Image size: %0dx%0d", COL, ROW);
        $display("Number of bad pixels: %0d", NUM_BAD_PIXELS);
        
        #(CLK_PERIOD * 10);
        axis_aresetn    = 1'b1;
        s00_axi_aresetn = 1'b1;
        #(CLK_PERIOD * 10);
        
        // ============================================
        // Configure bad pixel list via AXI4-Lite
        // ============================================
        $display("[%0t] Configuring bad pixel list...", $time);
        
        // Write bad pixel count to register at address 0x04
        @(posedge s00_axi_aclk);
        s00_axi_awaddr  = 32'h00000004;
        s00_axi_awvalid = 1'b1;
        s00_axi_wdata   = NUM_BAD_PIXELS;
        s00_axi_wstrb   = 4'hF;
        s00_axi_wvalid  = 1'b1;
        @(posedge s00_axi_aclk);
        while (!s00_axi_awready || !s00_axi_wready) @(posedge s00_axi_aclk);
        s00_axi_awvalid = 1'b0;
        s00_axi_wvalid  = 1'b0;
        @(posedge s00_axi_aclk);
        $display("[%0t] Written bad_point_num = %0d", $time, NUM_BAD_PIXELS);
        
        // Write each bad pixel coordinate
        for (i = 0; i < NUM_BAD_PIXELS; i = i + 1) begin
            @(posedge s00_axi_aclk);
            s00_axi_awaddr  = 32'h00000010 + (i * 4);
            s00_axi_awvalid = 1'b1;
            s00_axi_wdata   = bad_pixels[i];
            s00_axi_wstrb   = 4'hF;
            s00_axi_wvalid  = 1'b1;
            @(posedge s00_axi_aclk);
            while (!s00_axi_awready || !s00_axi_wready) @(posedge s00_axi_aclk);
            s00_axi_awvalid = 1'b0;
            s00_axi_wvalid  = 1'b0;
            @(posedge s00_axi_aclk);
            $display("[%0t] Written bad pixel %0d: Row=%0d, Col=%0d (0x%08h) to addr 0x%08h", 
                     $time, i, bad_pixels[i][15:0], bad_pixels[i][31:16], bad_pixels[i], 32'h00000010 + (i * 4));
        end
        
        $display("[%0t] Bad pixel list configured.", $time);
        #(CLK_PERIOD * 10);
        
        // Start processing (set GO bit at address 0x00)
        @(posedge s00_axi_aclk);
        s00_axi_awaddr  = 32'h00000000;
        s00_axi_awvalid = 1'b1;
        s00_axi_wdata   = 32'h00000001;
        s00_axi_wstrb   = 4'hF;
        s00_axi_wvalid  = 1'b1;
        @(posedge s00_axi_aclk);
        while (!s00_axi_awready || !s00_axi_wready) @(posedge s00_axi_aclk);
        s00_axi_awvalid = 1'b0;
        s00_axi_wvalid  = 1'b0;
        @(posedge s00_axi_aclk);
        $display("[%0t] DPC processing started (GO=1)", $time);
        #(CLK_PERIOD * 10);
        
        // Load test image
        load_image();
        #(CLK_PERIOD * 10);
        
        // Fork two processes: send and receive
        fork
            send_image();
            receive_image();
        join
        
        // Wait for processing to complete
        #(CLK_PERIOD * 100);
        
        // Stop processing (clear GO bit)
        @(posedge s00_axi_aclk);
        s00_axi_awaddr  = 32'h00000000;
        s00_axi_awvalid = 1'b1;
        s00_axi_wdata   = 32'h00000000;
        s00_axi_wstrb   = 4'hF;
        s00_axi_wvalid  = 1'b1;
        @(posedge s00_axi_aclk);
        while (!s00_axi_awready || !s00_axi_wready) @(posedge s00_axi_aclk);
        s00_axi_awvalid = 1'b0;
        s00_axi_wvalid  = 1'b0;
        @(posedge s00_axi_aclk);
        $display("[%0t] DPC processing stopped (GO=0)", $time);
        
        #(CLK_PERIOD * 100);
        
        $display("========================================");
        $display("  Dead Pixel Correction Test Completed");
        $display("========================================");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000000;  // 100ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // Monitor output
    integer monitor_count = 0;
    always @(posedge axis_aclk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            monitor_count = monitor_count + 1;
            // Periodic progress report
            if (monitor_count % 1000 == 0) begin
                $display("[%0t] Processed %0d pixels", $time, monitor_count);
            end
            // When output pixel count reaches full image size, notify
            if (monitor_count == ROW * COL) begin
                $display("[%0t] All output pixels received: %0d (== ROW*COL)", $time, monitor_count);
            end
        end
    end

endmodule
