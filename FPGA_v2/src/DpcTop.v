module DpcTop #(
  parameter ROW              = 512,
  parameter COL              = 640,
  parameter AXIS_TDATA_WIDTH = 14,
  parameter AXI_DATA_WIDTH   = 32,
  parameter AXI_ADDR_WIDTH   = 32
) (
  input  wire                            axis_aclk,
  input  wire                            axis_aresetn,
  // Ports of Axi Master Bus Interface M_AXIS
  input  wire                            m_axis_tready,
  output wire                            m_axis_tvalid,
  output wire [  AXIS_TDATA_WIDTH-1 : 0] m_axis_tdata,
  output wire                            m_axis_tuser,
  output wire                            m_axis_tlast,
  // Ports of Axi Slave Bus Interface S_AXIS
  output wire                            s_axis_tready,
  input  wire                            s_axis_tvalid,
  input  wire [  AXIS_TDATA_WIDTH-1 : 0] s_axis_tdata,
  input  wire                            s_axis_tuser,
  input  wire                            s_axis_tlast,
  // Ports of Axi Slave Bus Interface S00_AXI
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
  input  wire                            s00_axi_rready
  // input                                     go,
  // input [  AXIS_TDATA_WIDTH-1:0]            threshold,
  // input                                     smooth
);

  wire                          go;
  wire [7:0]                    bad_point_num;
  wire [                  10:0] width;
  wire [                  10:0] height;
  wire                          last_pixel_in_frame;
  wire                          synced_go;

  wire                          usm_m_axis_tready;
  wire                          usm_m_axis_tvalid;
  wire [AXIS_TDATA_WIDTH-1 : 0] usm_m_axis_tdata;
  wire                          usm_m_axis_tuser;
  wire                          usm_m_axis_tlast;

  wire [AXI_ADDR_WIDTH-1:0] waddr_lut;
  wire [AXI_DATA_WIDTH-1:0] wdata_lut;
  wire [AXI_ADDR_WIDTH-1:0] raddr_lut;
  wire [AXI_DATA_WIDTH-1:0] rdata_lut;
  wire                       wen_lut;

  
  Axi4LiteSlave_dpc #(
    .C_S_AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXIS_TDATA_WIDTH  (AXIS_TDATA_WIDTH)
  ) Axi4LiteSlave_inst (
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
    .go                (go),
    .bad_point_num     (bad_point_num),
    .wdata_lut         (wdata_lut),
    .wen_lut           (wen_lut),
    .waddr_lut         (waddr_lut),
    .rdata_lut         (rdata_lut),
    .raddr_lut         (raddr_lut)   
  );

  // 跨时钟域 信号对齐(快时钟100MHZ->慢时钟10MHZ)
  (* async_reg = "true" *) reg [1:0] go_r;
  (* async_reg = "true" *) reg [7:0] bad_point_num_r [1:0];

  always @(posedge axis_aclk or negedge axis_aresetn)
    if (!axis_aresetn) begin
      go_r <= 'd0;
      bad_point_num_r[0] <= 'd0;
      bad_point_num_r[1] <= 'd0;
    end
    else begin
      go_r[0] <= go;
      go_r[1] <= go_r[0];
      bad_point_num_r[0] <= bad_point_num;
      bad_point_num_r[1] <= bad_point_num_r[0];
    end

  Kernel_dpc #(
    .WIDTH(AXIS_TDATA_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .ROW  (ROW),
    .COL  (COL)
  ) Kernel_inst (
    .axis_aclk          (axis_aclk),
    .axis_aresetn       (axis_aresetn),
    .s_axis_tready      (s_axis_tready),
    .s_axis_tvalid      (s_axis_tvalid),
    .s_axis_tdata       (s_axis_tdata),
    .s_axis_tuser       (s_axis_tuser),
    .s_axis_tlast       (s_axis_tlast),
    .m_axis_tready      (usm_m_axis_tready),
    .m_axis_tvalid      (usm_m_axis_tvalid),
    .m_axis_tdata       (usm_m_axis_tdata),
    .m_axis_tuser       (usm_m_axis_tuser),
    .m_axis_tlast       (usm_m_axis_tlast),
    .go                 (go_r[1]),
    .bad_point_num      (bad_point_num_r[1]),
    .S_AXI_ACLK         (s00_axi_aclk),
    .wen_lut            (wen_lut),
    .waddr_lut          (waddr_lut),
    .wdata_lut          (wdata_lut),
    .width              (width),
    .height             (height),
    .last_pixel_in_frame(last_pixel_in_frame),
    .synced_go          (synced_go)
  );
  
  // ����go������1�Ż�������ͼ, ������ȫ��ͼ��. ��go����Ϊ��ͣ�ı�־λ.
  assign usm_m_axis_tready = go_r[1] ? m_axis_tready : 1'b0;
  assign m_axis_tvalid     = go_r[1] ? usm_m_axis_tvalid : 1'b0;
  assign m_axis_tdata      = go_r[1] ? usm_m_axis_tdata : 'd0;
  assign m_axis_tuser      = go_r[1] ? usm_m_axis_tuser : 1'b0;
  assign m_axis_tlast      = go_r[1] ? usm_m_axis_tlast : 1'b0;

endmodule
