
//从内存中读取视频帧数据，通过ST流输出，流协议符合Avalon-ST Video Protocol。ST流readyLatency=1。
//数据访问采用burst模式，burst_read_master模块每次读取1行数据，然后自动产生control_go信号，继续访问下一行。
//多缓冲模式下，读内存基址索引为writer_base_index-1，writer_base_index为写线程输出的当前写内存基址索引。
//单缓冲模式下，writer_base_index必须为1。


//  输出模式定义：
//  mode--00 逐行输出；
//        01 逐行倒像输出；
//        10 隔行输出；
//        11 隔行倒像输出；

//数据宽度不是8的倍数时，按高位对齐。
//例如14位数据读取时，输出高位14数据，低2位数据舍弃。


// IP核参数说明：
//   BPS （bit per symbol)   --- 图像每一色彩分量的位宽，有效范围为4~16。位宽大于16可能出现数据宽度无法对齐的错误。
//   MAX_WIDTH               --- 图像的最大像素宽度。
//   MAX_HEIGHT              --- 图像的最大像素高度。
//   NUMBER_OF_COLOUR_PLANES --- 图像的色彩平面数量，有效范围为1~4。
//   COLOUR_PLANES_ARE_IN_PARALLEL --- 色彩平面排列方式，0-串行，1-并行。
//   BUFFER_NUM              --- 帧缓存数，有效范围1~4。
//   ADDRESSWIDTH            --- 读master地址位宽。
//   DATAWIDTH_MM            --- 读master数据位宽。DATAWIDTH_MM应为Avalon视频流数据位宽的2的整数次幂的倍数。
//   MAXBURSTCOUNT           --- 读master最大突发传输数。
//   FIFODEPTH_BYTE          --- 读master以字节为单位的FIFO深度。


//修改历史
//20-06-15  v0.1    初始版本。由video_frame_reader v0.3.7更改而来。 

// altera message_off 10034

module axi_video_frame_reader_nuc (
    clk,
    reset_n,

    //control
    writer_base_index,
    reader_base_index,

    // //avalon slave
    // slave_address,
    // slave_write,
    // slave_writedata,
    // slave_read,
    // slave_readdata,

    // //avalon master
    // master_address,
    // master_read,
    // master_byteenable,
    // master_readdata,
    // master_readdatavalid,
    // master_burstcount,
    // master_waitrequest,

    // //Avalon-ST Source
    // avalon_st_clk,
    // avalon_st_data,
    // avalon_st_ready,
    // avalon_st_valid,
    // avalon_st_sop,
    // avalon_st_eop

    go,
    mode,
    width,
    height,
    baseaddr,

    // AXI master inputs and outputs
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arprot,
    m_axi_arready,
    m_axi_arsize,
    m_axi_aruser,
    m_axi_arvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,

    // AXI-ST source
    axis_aclk,
    m_axis_tdata,
    m_axis_tlast,
    m_axis_tvalid,
    m_axis_tready,
    m_axis_tuser

);

  parameter BPS                = 8;
  parameter MAX_WIDTH          = 16'd720;
  parameter MAX_HEIGHT         = 16'd576;
  parameter NUMBER_OF_COLOUR_PLANES = 2;
  parameter COLOUR_PLANES_ARE_IN_PARALLEL = 0;
  
  parameter BUFFER_NUM         = 3;

  parameter ADDRESSWIDTH       = 32;
  parameter DATAWIDTH_MM       = 64;
  parameter MAXBURSTCOUNT      = 8;
  parameter FIFODEPTH_BYTE     = 8192;
  
  function integer clogb2 (input integer bit_depth);              
  begin                                                           
    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
      bit_depth = bit_depth >> 1;                                 
    end                                                           
  endfunction   
  
  localparam BYTEPERSYMBOL   = ((BPS % 8) == 0) ? BPS/8 : (BPS/8 + 1);
  localparam PADBIT          = BYTEPERSYMBOL*8 - BPS;
  localparam SYMBOLPERBEAT   = (COLOUR_PLANES_ARE_IN_PARALLEL == 1) ? NUMBER_OF_COLOUR_PLANES : 1;
  localparam DATAWIDTH_MM2ST = (SYMBOLPERBEAT == 3) ? BYTEPERSYMBOL * 8 : SYMBOLPERBEAT * BYTEPERSYMBOL * 8;
  localparam DATAWIDTH_ST    = SYMBOLPERBEAT * BPS;
  localparam ROW_LENGTH      = (COLOUR_PLANES_ARE_IN_PARALLEL == 1) ? 
                                ((SYMBOLPERBEAT == 3) ? 3*MAX_WIDTH : MAX_WIDTH ) :
                                NUMBER_OF_COLOUR_PLANES * MAX_WIDTH;
  localparam BURSTCOUNTWIDTH = clogb2(MAXBURSTCOUNT - 1);  
  localparam BYTEENABLEWIDTH = DATAWIDTH_MM/8;   
                              
  localparam SERIAL_COLOUR_PLANE_NUM = (COLOUR_PLANES_ARE_IN_PARALLEL == 1) ? 1 : NUMBER_OF_COLOUR_PLANES;                                         

  input                             clk;
  input                             reset_n;
  
  input  [3:0]                      writer_base_index;
  output [3:0]                      reader_base_index;

  //avalon slave
//   input [3:0]                       slave_address;
//   input                             slave_write;
//   input [31:0]                      slave_writedata;
//   input                             slave_read;
//   output reg [31:0]                 slave_readdata;


//   //avalon master
//   output wire [ADDRESSWIDTH-1:0]    master_address;
//   output wire                       master_read;            
//   output wire [BYTEENABLEWIDTH-1:0] master_byteenable;
//   input  [DATAWIDTH_MM-1:0]         master_readdata;       
//   input                             master_readdatavalid;       
//   output wire [BURSTCOUNTWIDTH:0] master_burstcount;  
//   input                             master_waitrequest;
  
//   input                             avalon_st_clk;
//   output [DATAWIDTH_ST-1:0]         avalon_st_data;
//   input                             avalon_st_ready;
//   output                            avalon_st_valid;
//   output                            avalon_st_sop;
//   output                            avalon_st_eop;
  
    input                               go;
    input   [1:0]                       mode;
    input   [15:0]                      width;
    input   [15:0]                      height;
    input   [ADDRESSWIDTH-1:0]          baseaddr;
    // AXI master inputs and outputs
    output      [ADDRESSWIDTH-1:0]          m_axi_araddr;
    output      [1:0]                       m_axi_arburst;
    output      [3:0]                       m_axi_arcache;
    output      [7:0]                       m_axi_arlen;
    output      [2:0]                       m_axi_arprot;
    input                                   m_axi_arready;
    output      [2:0]                       m_axi_arsize;
    output      [3:0]                       m_axi_aruser;
    output                                  m_axi_arvalid;
    input       [DATAWIDTH_MM-1:0]          m_axi_rdata;
    input                                   m_axi_rlast;
    output                                  m_axi_rready;
    input       [1:0]                       m_axi_rresp;
    input                                   m_axi_rvalid;

    input                                   axis_aclk;
    output      [DATAWIDTH_ST-1 : 0]        m_axis_tdata;
    output                                  m_axis_tlast;
    output                                  m_axis_tvalid;
    input                                   m_axis_tready;
    output                                  m_axis_tuser;
  
//   wire  [DATAWIDTH_ST-1:0]          st_data;
//   wire                              st_ready;
//   wire                              st_valid;
//   wire                              st_sop;
//   wire                              st_eop;
                                    
//   wire                              st_clk_adapter;
//   wire  [DATAWIDTH_MM2ST-1:0]       st_data_adapter;
//   wire                              st_ready_adapter;
//   wire                              st_valid_adapter;
//   wire                              st_sop_adapter;
//   wire                              st_eop_adapter;
  
  wire [SYMBOLPERBEAT*BYTEPERSYMBOL*8-1:0] st_data_tmp;
  
//   always @(posedge clk or posedge reset)
//   if(reset)
//   begin 
//     go       <= 0;
//     mode     <= 0;
//     width    <= MAX_WIDTH;
//     height   <= MAX_HEIGHT;
//     baseaddr <= 0;
//   end
//   else
//   begin
//     if(slave_write)
//     begin
//       case(slave_address)
//         4'b0000 :
//           go  <= slave_writedata[0];
//         4'b0001 :
//         begin
//           mode <= slave_writedata[1:0];  
//         end
//         4'b0010 :
//         begin
//           width <= slave_writedata[15:0];
//         end
//         4'b0011 :
//         begin
//           height <= slave_writedata[15:0];
//         end
//         4'b0100 :
//         begin
//           baseaddr <= slave_writedata[ADDRESSWIDTH-1:0];
//         end
//       endcase
//     end
//     else if(slave_read)
//     begin
//       case(slave_address)
//         4'b0000 :
//           slave_readdata <= {31'h0,go};
//         4'b0001 :
//           slave_readdata <= {30'h0,mode};
//         4'b0010 :
//           slave_readdata <= {16'h0,width};
//         4'b0011 :
//           slave_readdata <= {16'h0,height};
//         4'b0100 :
//           slave_readdata <= {{(32-ADDRESSWIDTH){1'b0}},baseaddr};
//       endcase
//     end
//   end 

  wire [DATAWIDTH_MM2ST-1 : 0] m_axis_tdata_MM2ST;   
  assign m_axis_tdata = m_axis_tdata_MM2ST[(DATAWIDTH_MM2ST-1) -: DATAWIDTH_ST ];

  st_frame_readerII_nuc st_frame_reader_inst(
    .clk(clk),
    .reset_n(reset_n),
    .go(go),
    .writer_base_index(writer_base_index),
    .reader_base_index(reader_base_index),
    .mode(mode ),
    .baseaddr(baseaddr),
    .width(width  ),
    .height(height ),
    // .master_address(master_address),
    // .master_read(master_read),
    // .master_byteenable(master_byteenable),
    // .master_readdata(master_readdata),
    // .master_readdatavalid(master_readdatavalid),
    // .master_burstcount(master_burstcount),
    // .master_waitrequest(master_waitrequest),
    // .avalon_st_clk(st_clk_adapter),
    // .avalon_st_data(st_data_adapter),
    // .avalon_st_ready(st_ready_adapter),
    // .avalon_st_valid(st_valid_adapter),
    // .avalon_st_sop(st_sop_adapter),
    // .avalon_st_eop(st_eop_adapter)
    // AXI master inputs and outputs
    .m_axi_araddr   (m_axi_araddr ),
    .m_axi_arburst  (m_axi_arburst),
    .m_axi_arcache  (m_axi_arcache),
    .m_axi_arlen    (m_axi_arlen  ),
    .m_axi_arprot   (m_axi_arprot ),
    .m_axi_arready  (m_axi_arready),
    .m_axi_arsize   (m_axi_arsize ),
    .m_axi_aruser   (m_axi_aruser ),
    .m_axi_arvalid  (m_axi_arvalid),
    .m_axi_rdata    (m_axi_rdata  ),
    .m_axi_rlast    (m_axi_rlast  ),
    .m_axi_rready   (m_axi_rready ),
    .m_axi_rresp    (m_axi_rresp  ),
    .m_axi_rvalid   (m_axi_rvalid ),
    .axis_aclk      (axis_aclk    ),
    .m_axis_tdata   (m_axis_tdata_MM2ST ),
    .m_axis_tlast   (m_axis_tlast ),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (m_axis_tready),
    .m_axis_tuser   (m_axis_tuser )
  );
  defparam st_frame_reader_inst.MAX_WIDTH      = ROW_LENGTH;
  defparam st_frame_reader_inst.MAX_HEIGHT     = MAX_HEIGHT;
  defparam st_frame_reader_inst.COLOR_PLANE    = 1; 
  defparam st_frame_reader_inst.BUFFER_NUM     = BUFFER_NUM;
  defparam st_frame_reader_inst.ADDRESSWIDTH   = ADDRESSWIDTH;
  defparam st_frame_reader_inst.DATAWIDTH_MM   = DATAWIDTH_MM;
  defparam st_frame_reader_inst.DATAWIDTH_ST   = DATAWIDTH_MM2ST;
  defparam st_frame_reader_inst.MAXBURSTCOUNT  = MAXBURSTCOUNT;
  defparam st_frame_reader_inst.FIFODEPTH_BYTE = FIFODEPTH_BYTE;
  
//   generate 
//     case(SYMBOLPERBEAT)
//       1: 
//       begin: case1
//         assign st_clk_adapter = avalon_st_clk;
//         assign st_data = st_data_adapter[PADBIT+:BPS];
//         assign st_ready_adapter = st_ready; 
//         assign st_valid = st_valid_adapter;
//         assign st_sop = st_sop_adapter;
//         assign st_eop = st_eop_adapter;
//       end

//       2: 
//       begin: case2
//         assign st_clk_adapter = avalon_st_clk;
//         assign st_data[0+:BPS] = st_data_adapter[PADBIT+:BPS];
//         assign st_data[BPS+:BPS] = st_data_adapter[(BYTEPERSYMBOL*8+PADBIT)+:BPS];
//         assign st_ready_adapter = st_ready; 
//         assign st_valid = st_valid_adapter;
//         assign st_sop = st_sop_adapter;
//         assign st_eop = st_eop_adapter;
//       end

//       3:
//       begin: case3
//         // assign st_clk_adapter = clk;
//         // serial_to_parallel_adapter serial_to_parallel_adapter_inst(
//         //   .reset(reset),
//         //   .in_clk(clk),
//         //   .in_ready(st_ready_adapter),
//         //   .in_valid(st_valid_adapter),
//         //   .in_data(st_data_adapter),
//         //   .in_startofpacket(st_sop_adapter),
//         //   .in_endofpacket(st_eop_adapter),
//         //   .out_clk(avalon_st_clk),
//         //   .out_ready(st_ready),
//         //   .out_valid(st_valid),
//         //   .out_data(st_data_tmp),
//         //   .out_startofpacket(st_sop),
//         //   .out_endofpacket(st_eop)
//         // );
//         // defparam serial_to_parallel_adapter_inst.BYTEPERSYMBOL  = BYTEPERSYMBOL;
//         // defparam serial_to_parallel_adapter_inst.SYMBOLPERBEAT  = SYMBOLPERBEAT;
        
//         // assign st_data[0+:BPS] = st_data_tmp[PADBIT+:BPS];
//         // assign st_data[BPS+:BPS] = st_data_tmp[(BYTEPERSYMBOL*8+PADBIT)+:BPS];
//         // assign st_data[2*BPS+:BPS] = st_data_tmp[(2*BYTEPERSYMBOL*8+PADBIT)+:BPS];

//       end
      
//       4: 
//       begin: case4
//         assign st_clk_adapter = avalon_st_clk;
//         assign st_data[0+:BPS] = st_data_adapter[PADBIT+:BPS];
//         assign st_data[BPS+:BPS] = st_data_adapter[(BYTEPERSYMBOL*8+PADBIT)+:BPS];
//         assign st_data[2*BPS+:BPS] = st_data_adapter[(2*BYTEPERSYMBOL*8+PADBIT)+:BPS];
//         assign st_data[3*BPS+:BPS] = st_data_adapter[(3*BYTEPERSYMBOL*8+PADBIT)+:BPS];
//         assign st_ready = st_ready_adapter; 
//         assign st_valid = st_valid_adapter;
//         assign st_sop = st_sop_adapter;
//         assign st_eop = st_eop_adapter;
//       end
 
//     endcase
//   endgenerate


//   video_protocol_adapter_add video_protocol_adapter_add_inst(
//     .clk(avalon_st_clk),
//     .reset(reset),
//     .width(width),
//     .height(height),
//     .interlacing(4'b0011),
//     .st_sink_data(st_data),
//     .st_sink_ready(st_ready),
//     .st_sink_valid(st_valid),
//     .st_sink_sop(st_sop),
//     .st_sink_eop(st_eop),
//     .st_source_data(avalon_st_data),
//     .st_source_ready(avalon_st_ready),
//     .st_source_valid(avalon_st_valid),
//     .st_source_sop(avalon_st_sop),
//     .st_source_eop(avalon_st_eop)
//   );
//   defparam video_protocol_adapter_add_inst.BPS = BPS;
//   defparam video_protocol_adapter_add_inst.SYMBOLPERBEAT = SYMBOLPERBEAT;
//   defparam video_protocol_adapter_add_inst.SERIAL_COLOUR_PLANE_NUM = SERIAL_COLOUR_PLANE_NUM;
    
endmodule
