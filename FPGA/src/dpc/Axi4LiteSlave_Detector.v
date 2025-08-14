/*
 * DPC检测器AXI4-Lite配置接口
 * 
 * 寄存器映射：
 * REG0 (0x00): 使能控制 (go)
 * REG1 (0x04): 手动坏点数量 (manual_bp_num)  
 * REG2 (0x08): k值阈值 (k_threshold)
 * REG3 (0x0C): 状态寄存器 (frame_done, detected_bp_count)
 * REG4 (0x10): 自动检测坏点读取控制 (auto_bp_read_addr)
 * REG5 (0x14): 自动检测坏点数据 (auto_bp_x, auto_bp_y)
 * 地址0x20开始: 手动坏点表数据
 */

module Axi4LiteSlave_Detector #(
  parameter integer AXIS_TDATA_WIDTH = 24,
  parameter integer LUT_INDEX_WIDTH = 8,
  parameter integer LUT_INDEX_NUM  = 128,
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  parameter integer C_S_AXI_ADDR_WIDTH = 32
) (
  // AXI4-Lite接口
  input  wire                                S_AXI_ACLK,
  input  wire                                S_AXI_ARESETN,
  input  wire [    C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
  input  wire [                       2 : 0] S_AXI_AWPROT,
  input  wire                                S_AXI_AWVALID,
  output wire                                S_AXI_AWREADY,
  input  wire [    C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
  input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
  input  wire                                S_AXI_WVALID,
  output wire                                S_AXI_WREADY,
  output wire [                       1 : 0] S_AXI_BRESP,
  output wire                                S_AXI_BVALID,
  input  wire                                S_AXI_BREADY,
  input  wire [    C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
  input  wire [                       2 : 0] S_AXI_ARPROT,
  input  wire                                S_AXI_ARVALID,
  output wire                                S_AXI_ARREADY,
  output wire [    C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
  output wire [                       1 : 0] S_AXI_RRESP,
  output wire                                S_AXI_RVALID,
  input  wire                                S_AXI_RREADY,
  
  // 用户接口
  output  wire                        go,
  output  wire [LUT_INDEX_WIDTH-1:0]  manual_bp_num,
  output  wire [AXIS_TDATA_WIDTH-1:0] k_threshold,
  output  reg [C_S_AXI_DATA_WIDTH-1:0] wdata_lut,
  input   wire [C_S_AXI_DATA_WIDTH-1:0] rdata_lut,
  output  reg [C_S_AXI_ADDR_WIDTH-1:0] waddr_lut,
  output  wire  [C_S_AXI_ADDR_WIDTH-1:0] raddr_lut,
  output  reg                        wen_lut,
  
  // 自动检测坏点接口
  input   wire                        frame_detection_done,
  input   wire [LUT_INDEX_WIDTH:0]    detected_bp_count,
  input   wire [9:0]                  auto_bp_x,
  input   wire [9:0]                  auto_bp_y,
  output  wire [LUT_INDEX_WIDTH-1:0]  auto_bp_read_addr,
  input   wire [31:0]                 auto_bp_read_data   // 从检测器读取的坏点数据
);

  // AXI4LITE内部信号
  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
  reg                            axi_awready;
  reg                            axi_wready;
  reg [                   1 : 0] axi_bresp;
  reg                            axi_bvalid;
  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
  reg                            axi_arready;
  reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
  reg [                   1 : 0] axi_rresp;
  reg                            axi_rvalid;

  localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = LUT_INDEX_WIDTH;
  
  reg     [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
  reg     [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;
  reg     [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
  reg     [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;
  reg     [C_S_AXI_DATA_WIDTH-1:0] slv_reg4;
  reg     [C_S_AXI_DATA_WIDTH-1:0] slv_reg5;
  wire                             slv_reg_rden;
  wire                             slv_reg_wren;
  reg     [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
  integer                          byte_index;
  reg                              aw_en;

  // I/O连接
  assign S_AXI_AWREADY = axi_awready;
  assign S_AXI_WREADY  = axi_wready;
  assign S_AXI_BRESP   = axi_bresp;
  assign S_AXI_BVALID  = axi_bvalid;
  assign S_AXI_ARREADY = axi_arready;
  assign S_AXI_RDATA   = axi_rdata;
  assign S_AXI_RRESP   = axi_rresp;
  assign S_AXI_RVALID  = axi_rvalid;

  // AXI写地址准备信号
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_awready <= 1'b0;
      aw_en       <= 1'b1;
    end else begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        axi_awready <= 1'b1;
        aw_en       <= 1'b0;
      end else if (S_AXI_BREADY && axi_bvalid) begin
        aw_en       <= 1'b1;
        axi_awready <= 1'b0;
      end else begin
        axi_awready <= 1'b0;
      end
    end
  end

  // AXI写地址锁存
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_awaddr <= 0;
    end else begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        axi_awaddr <= S_AXI_AWADDR;
      end
    end
  end

  // AXI写数据准备信号
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_wready <= 1'b0;
    end else begin
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
        axi_wready <= 1'b1;
      end else begin
        axi_wready <= 1'b0;
      end
    end
  end

  // 寄存器写逻辑
  assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      slv_reg0 <= 0;
      slv_reg1 <= 0;
      slv_reg2 <= 0;
      slv_reg3 <= 0;
      slv_reg4 <= 0;
      slv_reg5 <= 0;
      wdata_lut <= 0;
      waddr_lut <= 0;
      wen_lut <= 0;
    end else begin
      // 自动更新状态寄存器
      slv_reg3 <= {15'b0, frame_detection_done, detected_bp_count[15:0]};
      
      if (slv_reg_wren) begin
        if (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 'd0) begin
          for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH / 8) - 1; byte_index = byte_index + 1)
            if (S_AXI_WSTRB[byte_index] == 1) begin
              slv_reg0[(byte_index*8)+:8] <= S_AXI_WDATA[(byte_index*8)+:8];
            end
        end
        else if (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 'd1) begin
          for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH / 8) - 1; byte_index = byte_index + 1)
            if (S_AXI_WSTRB[byte_index] == 1) begin
              slv_reg1[(byte_index*8)+:8] <= S_AXI_WDATA[(byte_index*8)+:8];
            end
        end
        else if (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 'd2) begin
          for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH / 8) - 1; byte_index = byte_index + 1)
            if (S_AXI_WSTRB[byte_index] == 1) begin
              slv_reg2[(byte_index*8)+:8] <= S_AXI_WDATA[(byte_index*8)+:8];
            end
        end
        else if (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 'd4) begin
          // REG4: 坏点读取地址控制寄存器，软件可写
          for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH / 8) - 1; byte_index = byte_index + 1)
            if (S_AXI_WSTRB[byte_index] == 1) begin
              slv_reg4[(byte_index*8)+:8] <= S_AXI_WDATA[(byte_index*8)+:8];
            end
        end
        else if (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] >= 'd8) begin
          wdata_lut  <= S_AXI_WDATA;
          waddr_lut  <= axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
          wen_lut <= 1'b1;          
        end
      end else begin
        wen_lut <= 1'b0;
      end
    end
  end

  // 写响应逻辑
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_bvalid <= 0;
      axi_bresp  <= 2'b0;
    end else begin
      if (S_AXI_AWVALID && ~axi_bvalid && S_AXI_WVALID) begin
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b0;
      end else begin
        if (S_AXI_BREADY && axi_bvalid) begin
          axi_bvalid <= 1'b0;
        end
      end
    end
  end

  // 读地址准备信号
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_arready <= 1'b0;
      axi_araddr  <= 32'b0;
    end else begin
      if (~axi_arready && S_AXI_ARVALID) begin
        axi_arready <= 1'b1;
        axi_araddr  <= S_AXI_ARADDR;
      end else begin
        axi_arready <= 1'b0;
      end
    end
  end

  // 读数据有效信号
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end else begin
      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b0;
      end else if (axi_rvalid && S_AXI_RREADY) begin
        axi_rvalid <= 1'b0;
      end
    end
  end

  // 寄存器读逻辑
  assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
  
  always @(*) begin
    case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
      'd0: reg_data_out <= slv_reg0;
      'd1: reg_data_out <= slv_reg1;
      'd2: reg_data_out <= slv_reg2;
      'd3: reg_data_out <= slv_reg3;  // 状态寄存器 (frame_done + detected_bp_count)
      'd4: reg_data_out <= slv_reg4;  // 坏点读取地址
      'd5: reg_data_out <= slv_reg5;  // 坏点坐标数据
      default: reg_data_out <= rdata_lut;  // 手动坏点表
    endcase
  end

  // 读数据输出
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_rdata <= 0;
    end else begin
      if (slv_reg_rden) begin
        axi_rdata <= reg_data_out;
      end
    end
  end

  // 坏点坐标读取逻辑
  // 当软件读取REG5时，根据REG4中的地址读取对应的坏点坐标
  always @(*) begin
    // REG5直接返回从检测器读取的坏点数据
    slv_reg5 <= auto_bp_read_data;
  end

  // 用户逻辑输出
  assign go = slv_reg0[0];
  assign manual_bp_num = slv_reg1[LUT_INDEX_WIDTH-1:0];
  assign k_threshold = slv_reg2[AXIS_TDATA_WIDTH-1:0];
  assign raddr_lut = axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] - 'd8; // 手动坏点表从地址8开始
  assign auto_bp_read_addr = slv_reg4[LUT_INDEX_WIDTH-1:0];

endmodule
