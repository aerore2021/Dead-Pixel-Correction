/*
 * 分离式DPC顶层模块
 * 
 * 架构：
 * 1. DPC_Detector：检测模块，输出自动检测到的坏点给上位机
 * 2. DPC_Corrector：校正模块，根据上位机提供的合并坏点列表进行校正
 * 3. 上位机负责合并手动坏点表和自动检测结果
 */

module DpcTop_Separated #(
    parameter FRAME_HEIGHT     = 512,
    parameter FRAME_WIDTH      = 640,
    parameter PIXEL_WIDTH = 14,
    parameter AXI_DATA_WIDTH   = 32,
    parameter AXI_ADDR_WIDTH   = 32,
    parameter K_THRESHOLD_DEFAULT = 100,
    parameter MAX_MANUAL_BP   = 128,
    parameter MAX_ALL_BP      = 128
  ) (
    input  wire                            axis_aclk,
    input  wire                            axis_aresetn,

    // Ports of Axi Master Bus Interface M_AXIS
    input  wire                            m_axis_tready,
    output wire                            m_axis_tvalid,
    output wire [  PIXEL_WIDTH-1 : 0] m_axis_tdata,
    output wire                            m_axis_tuser,
    output wire                            m_axis_tlast,

    // Ports of Axi Slave Bus Interface S_AXIS
    output wire                            s_axis_tready,
    input  wire                            s_axis_tvalid,
    input  wire [  PIXEL_WIDTH-1 : 0] s_axis_tdata,
    input  wire                            s_axis_tuser,
    input  wire                            s_axis_tlast,

    // k值输入流接口
    input  wire                            k_axis_tvalid,
    input  wire [  PIXEL_WIDTH-1 : 0] k_axis_tdata,

    // 坏点检测输出接口 (连接到上位机)
    output wire                            auto_bp_valid,
    output wire [                    9:0]  auto_bp_x,
    output wire [                    9:0]  auto_bp_y,
    output wire                            auto_bp_type,
    input  wire                            auto_bp_ready,
    output wire                            frame_detection_done,
    output wire [                    8:0]  detected_bp_count,

    // 调试输出接口
    output wire                            debug_detector_manual_skip,
    output wire                            debug_detector_dead_pixel,
    output wire                            debug_detector_stuck_pixel,
    output wire                            debug_corrector_bp_corrected,
    output wire [  PIXEL_WIDTH-1:0]   debug_corrector_original,
    output wire [  PIXEL_WIDTH-1:0]   debug_corrector_corrected,

    // Ports of Axi Slave Bus Interface S00_AXI (检测器配置)
    input  wire                            s00_axi_aclk,
    input  wire                            s00_axi_aresetn,
    input  wire [    AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input  wire [                   2 : 0] s00_axi_awprot,
    input  wire                            s00_axi_awvalid,
    output wire                            s00_axi_awready,
    input  wire [    AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input  wire                            s00_axi_wvalid,
    output wire                            s00_axi_wready,
    output wire [                   1 : 0] s00_axi_bresp,
    output wire                            s00_axi_bvalid,
    input  wire                            s00_axi_bready,
    input  wire [    AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input  wire [                   2 : 0] s00_axi_arprot,
    input  wire                            s00_axi_arvalid,
    output wire                            s00_axi_arready,
    output wire [    AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [                   1 : 0] s00_axi_rresp,
    output wire                            s00_axi_rvalid,
    input  wire                            s00_axi_rready,

    // Ports of Axi Slave Bus Interface S01_AXI (校正器配置)
    input  wire                            s01_axi_aclk,
    input  wire                            s01_axi_aresetn,
    input  wire [    AXI_ADDR_WIDTH-1 : 0] s01_axi_awaddr,
    input  wire [                   2 : 0] s01_axi_awprot,
    input  wire                            s01_axi_awvalid,
    output wire                            s01_axi_awready,
    input  wire [    AXI_DATA_WIDTH-1 : 0] s01_axi_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1 : 0] s01_axi_wstrb,
    input  wire                            s01_axi_wvalid,
    output wire                            s01_axi_wready,
    output wire [                   1 : 0] s01_axi_bresp,
    output wire                            s01_axi_bvalid,
    input  wire                            s01_axi_bready,
    input  wire [    AXI_ADDR_WIDTH-1 : 0] s01_axi_araddr,
    input  wire [                   2 : 0] s01_axi_arprot,
    input  wire                            s01_axi_arvalid,
    output wire                            s01_axi_arready,
    output wire [    AXI_DATA_WIDTH-1 : 0] s01_axi_rdata,
    output wire [                   1 : 0] s01_axi_rresp,
    output wire                            s01_axi_rvalid,
    input  wire                            s01_axi_rready
  );

  // 检测器配置信号
  wire                          detector_go;
  wire [6:0]                    manual_bp_num;
  wire [PIXEL_WIDTH-1:0]   k_threshold;
  wire [AXI_ADDR_WIDTH-1:0]     manual_waddr_lut;
  wire [AXI_DATA_WIDTH-1:0]     manual_wdata_lut;
  wire [AXI_ADDR_WIDTH-1:0]     manual_raddr_lut;
  wire [AXI_DATA_WIDTH-1:0]     manual_rdata_lut;
  wire                          manual_wen_lut;

  // 校正器配置信号
  wire                          corrector_go;
  wire [8:0]                    all_bp_num;
  wire [AXI_ADDR_WIDTH-1:0]     all_waddr_lut;
  wire [AXI_DATA_WIDTH-1:0]     all_wdata_lut;
  wire [AXI_ADDR_WIDTH-1:0]     all_raddr_lut;
  wire [AXI_DATA_WIDTH-1:0]     all_rdata_lut;
  wire                          all_wen_lut;
  wire                          bp_table_ready;

  // 中间数据流信号
  wire                          det_to_corr_tvalid;
  wire                          det_to_corr_tready;
  wire [PIXEL_WIDTH-1:0]   det_to_corr_tdata;
  wire                          det_to_corr_tuser;
  wire                          det_to_corr_tlast;

  // ================================================================
  // 检测器AXI4-Lite配置接口
  // ================================================================

  Axi4LiteSlave_Detector #(
                           .C_S_AXI_DATA_WIDTH(AXI_DATA_WIDTH),
                           .C_S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
                           .PIXEL_WIDTH  (PIXEL_WIDTH)
                         ) detector_axi_inst (
                           .S_AXI_ACLK        (s00_axi_aclk),
                           .S_AXI_ARESETN     (s00_axi_aresetn),
                           .S_AXI_AWADDR      (s00_axi_awaddr),
                           .S_AXI_AWPROT      (s00_axi_awprot),
                           .S_AXI_AWVALID     (s00_axi_awvalid),
                           .S_AXI_AWREADY     (s00_axi_awready),
                           .S_AXI_WDATA       (s00_axi_wdata),
                           .S_AXI_WSTRB       (s00_axi_wstrb),
                           .S_AXI_WVALID      (s00_axi_wvalid),
                           .S_AXI_WREADY      (s00_axi_wready),
                           .S_AXI_BRESP       (s00_axi_bresp),
                           .S_AXI_BVALID      (s00_axi_bvalid),
                           .S_AXI_BREADY      (s00_axi_bready),
                           .S_AXI_ARADDR      (s00_axi_araddr),
                           .S_AXI_ARPROT      (s00_axi_arprot),
                           .S_AXI_ARVALID     (s00_axi_arvalid),
                           .S_AXI_ARREADY     (s00_axi_arready),
                           .S_AXI_RDATA       (s00_axi_rdata),
                           .S_AXI_RRESP       (s00_axi_rresp),
                           .S_AXI_RVALID      (s00_axi_rvalid),
                           .S_AXI_RREADY      (s00_axi_rready),

                           .go                (detector_go),
                           .manual_bp_num     (manual_bp_num),
                           .k_threshold       (k_threshold),
                           .wdata_lut         (manual_wdata_lut),
                           .wen_lut           (manual_wen_lut),
                           .waddr_lut         (manual_waddr_lut),
                           .rdata_lut         (manual_rdata_lut),
                           .raddr_lut         (manual_raddr_lut)
                         );

  // ================================================================
  // 校正器AXI4-Lite配置接口
  // ================================================================

  Axi4LiteSlave_Corrector #(
                            .C_S_AXI_DATA_WIDTH(AXI_DATA_WIDTH),
                            .C_S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
                            .PIXEL_WIDTH  (PIXEL_WIDTH)
                          ) corrector_axi_inst (
                            .S_AXI_ACLK        (s01_axi_aclk),
                            .S_AXI_ARESETN     (s01_axi_aresetn),
                            .S_AXI_AWADDR      (s01_axi_awaddr),
                            .S_AXI_AWPROT      (s01_axi_awprot),
                            .S_AXI_AWVALID     (s01_axi_awvalid),
                            .S_AXI_AWREADY     (s01_axi_awready),
                            .S_AXI_WDATA       (s01_axi_wdata),
                            .S_AXI_WSTRB       (s01_axi_wstrb),
                            .S_AXI_WVALID      (s01_axi_wvalid),
                            .S_AXI_WREADY      (s01_axi_wready),
                            .S_AXI_BRESP       (s01_axi_bresp),
                            .S_AXI_BVALID      (s01_axi_bvalid),
                            .S_AXI_BREADY      (s01_axi_bready),
                            .S_AXI_ARADDR      (s01_axi_araddr),
                            .S_AXI_ARPROT      (s01_axi_arprot),
                            .S_AXI_ARVALID     (s01_axi_arvalid),
                            .S_AXI_ARREADY     (s01_axi_arready),
                            .S_AXI_RDATA       (s01_axi_rdata),
                            .S_AXI_RRESP       (s01_axi_rresp),
                            .S_AXI_RVALID      (s01_axi_rvalid),
                            .S_AXI_RREADY      (s01_axi_rready),

                            .go                (corrector_go),
                            .all_bp_num        (all_bp_num),
                            .bp_table_ready    (bp_table_ready),
                            .wdata_lut         (all_wdata_lut),
                            .wen_lut           (all_wen_lut),
                            .waddr_lut         (all_waddr_lut),
                            .rdata_lut         (all_rdata_lut),
                            .raddr_lut         (all_raddr_lut)
                          );

  // ================================================================
  // 跨时钟域信号同步
  // ================================================================

  // 检测器控制信号同步
  (* async_reg = "true" *) reg [1:0] detector_go_r;
  (* async_reg = "true" *) reg [6:0] manual_bp_num_r [1:0];
  (* async_reg = "true" *) reg [PIXEL_WIDTH-1:0] k_threshold_r [1:0];

  always @(posedge axis_aclk or negedge axis_aresetn)
    if (!axis_aresetn)
    begin
      detector_go_r <= 'd0;
      manual_bp_num_r[0] <= 'd0;
      manual_bp_num_r[1] <= 'd0;
      k_threshold_r[0] <= 'd0;
      k_threshold_r[1] <= 'd0;
    end
    else
    begin
      detector_go_r[0] <= detector_go;
      detector_go_r[1] <= detector_go_r[0];
      manual_bp_num_r[0] <= manual_bp_num;
      manual_bp_num_r[1] <= manual_bp_num_r[0];
      k_threshold_r[0] <= k_threshold;
      k_threshold_r[1] <= k_threshold_r[0];
    end

  // 校正器控制信号同步
  (* async_reg = "true" *) reg [1:0] corrector_go_r;
  (* async_reg = "true" *) reg [8:0] all_bp_num_r [1:0];
  (* async_reg = "true" *) reg [1:0] bp_table_ready_r;

  always @(posedge axis_aclk or negedge axis_aresetn)
    if (!axis_aresetn)
    begin
      corrector_go_r <= 'd0;
      all_bp_num_r[0] <= 'd0;
      all_bp_num_r[1] <= 'd0;
      bp_table_ready_r <= 'd0;
    end
    else
    begin
      corrector_go_r[0] <= corrector_go;
      corrector_go_r[1] <= corrector_go_r[0];
      all_bp_num_r[0] <= all_bp_num;
      all_bp_num_r[1] <= all_bp_num_r[0];
      bp_table_ready_r[0] <= bp_table_ready;
      bp_table_ready_r[1] <= bp_table_ready_r[0];
    end

  // ================================================================
  // DPC检测器例化
  // ================================================================

  DPC_Detector #(
                 .WIDTH(PIXEL_WIDTH),
                 .K_WIDTH(PIXEL_WIDTH),
                 .CNT_WIDTH(10),
                 .MANUAL_BP_NUM(MAX_MANUAL_BP),
                 .MANUAL_BP_BIT(7),
                 .AUTO_BP_NUM(MAX_ALL_BP),
                 .AUTO_BP_BIT(7),
                 .THRESHOLD(K_THRESHOLD_DEFAULT),
                 .FRAME_HEIGHT(FRAME_HEIGHT),
                 .FRAME_WIDTH(FRAME_WIDTH)
               ) detector_inst (
                 .aclk                       (axis_aclk),
                 .aresetn                    (axis_aresetn),

                 // 输入像素流
                 .s_axis_tvalid              (s_axis_tvalid),
                 .s_axis_tready              (s_axis_tready),
                 .s_axis_tdata               (s_axis_tdata),
                 .s_axis_tuser               (s_axis_tuser),
                 .s_axis_tlast               (s_axis_tlast),

                 // k值输入流
                 .k_axis_tvalid              (k_axis_tvalid),
                 .k_axis_tdata               (k_axis_tdata),

                 // 输出像素流 (透传给校正器)
                 .m_axis_tready              (det_to_corr_tready),
                 .m_axis_tvalid              (det_to_corr_tvalid),
                 .m_axis_tdata               (det_to_corr_tdata),
                 .m_axis_tuser               (det_to_corr_tuser),
                 .m_axis_tlast               (det_to_corr_tlast),

                 // 配置接口
                 .enable                     (detector_go_r[1]),
                 .k_threshold                (k_threshold_r[1]),

                 // 手动坏点表接口
                 .S_AXI_ACLK                 (s00_axi_aclk),
                 .manual_bp_num              (manual_bp_num_r[1]),
                 .manual_wen                 (manual_wen_lut),
                 .manual_waddr               (manual_waddr_lut[6:0]),
                 .manual_wdata               (manual_wdata_lut),

                 // 自动检测坏点输出接口
                 .auto_bp_valid              (auto_bp_valid),
                 .auto_bp_x                  (auto_bp_x),
                 .auto_bp_y                  (auto_bp_y),

                 // 检测状态
                 .frame_detection_done       (frame_detection_done),
                 .detected_bp_count          (detected_bp_count)
               );

  // ================================================================
  // DPC校正器例化
  // ================================================================

  DPC_Corrector #(
                  .WIDTH(PIXEL_WIDTH),
                  .CNT_WIDTH(10),
                  .ALL_BP_NUM(MAX_ALL_BP),
                  .ALL_BP_BIT(7),
                  .LATENCY(5)
                ) corrector_inst (
                  .aclk                       (axis_aclk),
                  .aresetn                    (axis_aresetn),

                  // 输入像素流 (来自检测器)
                  .s_axis_tvalid              (det_to_corr_tvalid),
                  .s_axis_tready              (det_to_corr_tready),
                  .s_axis_tdata               (det_to_corr_tdata),
                  .s_axis_tuser               (det_to_corr_tuser),
                  .s_axis_tlast               (det_to_corr_tlast),

                  // 输出像素流
                  .m_axis_tready              (m_axis_tready),
                  .m_axis_tvalid              (m_axis_tvalid),
                  .m_axis_tdata               (m_axis_tdata),
                  .m_axis_tuser               (m_axis_tuser),
                  .m_axis_tlast               (m_axis_tlast),

                  // 配置接口
                  .enable                     (corrector_go_r[1]),

                  // 坏点列表接口
                  .S_AXI_ACLK                 (s01_axi_aclk),
                  .all_bp_num                 (all_bp_num_r[1]),
                  .all_bp_wen                 (all_wen_lut),
                  .all_bp_waddr               (all_waddr_lut[8:0]),
                  .all_bp_wdata               (all_wdata_lut),
                  .bp_table_ready             (bp_table_ready_r[1]),

                  // 调试输出
                  .debug_bp_corrected         (debug_corrector_bp_corrected),
                  .debug_original_pixel       (debug_corrector_original),
                  .debug_corrected_pixel      (debug_corrector_corrected)
                );

endmodule
