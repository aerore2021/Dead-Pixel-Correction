module video_out_test_top(

    // clk rst
    input my_pll_refclk,
    input systemClk_locked,
    input io_systemClk,
    input my_ddr_pll_CLKOUT0,
    input io_memoryClk,
    input clk_65m,
    input clk_10m,
    input rst_n_27m,
    input mclkin,
    input mclk,
    input clk_dvp,
    input OLED_CLK,

    input PWR_KEY_STATE,
    output PWR_CTRL,

    // jtag for riscv soc
    input jtag_inst1_CAPTURE,
    input jtag_inst1_DRCK,
    input jtag_inst1_RESET,
    input jtag_inst1_RUNTEST,
    input jtag_inst1_SEL,
    input jtag_inst1_SHIFT,
    input jtag_inst1_TCK,
    input jtag_inst1_TDI,
    input jtag_inst1_TMS,
    input jtag_inst1_UPDATE,
    output jtag_inst1_TDO,



    // debug
    input jtag_inst2_CAPTURE,
    input jtag_inst2_DRCK,
    input jtag_inst2_RESET,
    input jtag_inst2_RUNTEST,
    input jtag_inst2_SEL,
    input jtag_inst2_SHIFT,
    input jtag_inst2_TCK,
    input jtag_inst2_TDI,
    input jtag_inst2_TMS,
    input jtag_inst2_UPDATE,
    output jtag_inst2_TDO,

    // oled
    output          OLED_RST,
    output          HS,         
    output          VS,         
    output          DE,         
    output  [4:0]   OLED_R,      
    output  [5:0]   OLED_G,    
    output  [4:0]   OLED_B,      
    output          PCLK,   

    // SPI FLASH
    output        CFG_nCSO,
    output        CFG_DCLK,
    input         CFG_D0_IN,
    output        CFG_D0_OUT,
    output        CFG_D0_OE,
    input         CFG_D1_IN,
    output        CFG_D1_OUT,
    output        CFG_D1_OE,
    input         CFG_D2_IN,
    output        CFG_D2_OUT,
    output        CFG_D2_OE,
    input         CFG_D3_IN,
    output        CFG_D3_OUT,
    output        CFG_D3_OE,

    // LCD from X2000
    input LCD_CLK,
    input LCD_DE,
    input [15:0] LCD_D,
    input LCD_HSYNC,
    input LCD_RST,
    input LCD_VSYNC,


    // sensor
    input       sensor_DO0,
    input       sensor_DO1,
    input       sensor_DO2,
    input       sensor_DO3,
    output      sensor_MCK,
    output      sensor_SD0,
    output      sensor_SD1,

    output      IR_5V_ON,

    // shutter
    output      SHUTTER_DIR,
    output      SHUTTER_EN,
    
    // uart
    input       uart_rx,
    output      uart_tx,

    // i2c TMP101
    input       TMP_SCL_IN,
    input       TMP_SDA_IN,    
    output      TMP_SCL_OUT,
    output      TMP_SCL_OE,
    output      TMP_SDA_OUT,
    output      TMP_SDA_OE,
    
    output [15:0] sensor_temp,


    // ddr3
    input io_ddrA_arw_ready_0,
    input io_ddrA_arw_ready,
    input [7:0] io_ddrA_b_payload_id_0,
    input [7:0] io_ddrA_b_payload_id,
    input io_ddrA_b_valid_0,
    input io_ddrA_b_valid,
    input [255:0] io_ddrA_r_payload_data_0,
    input [127:0] io_ddrA_r_payload_data,
    input [7:0] io_ddrA_r_payload_id_0,
    input [7:0] io_ddrA_r_payload_id,
    input io_ddrA_r_payload_last_0,
    input io_ddrA_r_payload_last,
    input [1:0] io_ddrA_r_payload_resp_0,
    input [1:0] io_ddrA_r_payload_resp,
    input io_ddrA_r_valid_0,
    input io_ddrA_r_valid,
    input io_ddrA_w_ready_0,
    input io_ddrA_w_ready,

    output [31:0] io_ddrA_arw_payload_addr_0,
    output [31:0] io_ddrA_arw_payload_addr,
    output [1:0] io_ddrA_arw_payload_burst_0,
    output [1:0] io_ddrA_arw_payload_burst,
    output [7:0] io_ddrA_arw_payload_id_0,
    output [7:0] io_ddrA_arw_payload_id,
    output [7:0] io_ddrA_arw_payload_len_0,
    output [7:0] io_ddrA_arw_payload_len,
    output [1:0] io_ddrA_arw_payload_lock_0,
    output [1:0] io_ddrA_arw_payload_lock,
    output [2:0] io_ddrA_arw_payload_size_0,
    output [2:0] io_ddrA_arw_payload_size,
    output io_ddrA_arw_payload_write_0,
    output io_ddrA_arw_payload_write,
    output io_ddrA_arw_valid_0,
    output io_ddrA_arw_valid,
    output io_ddrA_b_ready_0,
    output io_ddrA_b_ready,
    output ddr_inst1_CFG_SEQ_RST,
    output ddr_inst1_CFG_SEQ_START,
    output io_ddrA_r_ready_0,
    output io_ddrA_r_ready,
    output ddr_inst1_CFG_RST_N,
    output [255:0] io_ddrA_w_payload_data_0,
    output [127:0] io_ddrA_w_payload_data,
    output [7:0] io_ddrA_w_payload_id_0,
    output [7:0] io_ddrA_w_payload_id,
    output io_ddrA_w_payload_last_0,
    output io_ddrA_w_payload_last,
    output [31:0] io_ddrA_w_payload_strb_0,
    output [15:0] io_ddrA_w_payload_strb,
    output io_ddrA_w_valid_0,
    output io_ddrA_w_valid,
    output HREF,
    output VSYNC,
    output [7:0] DVP_DATA
);

    
    wire 		reset;
    wire		io_systemReset;

    wire		io_ddrMasterReset;
    wire 	    io_memoryReset;

    wire                read_arvalid;
    wire                read_arready;
    wire    [31:0]      read_araddr;
    wire    [3:0]       read_arregion;
    wire    [7:0]       read_arlen;
    wire    [2:0]       read_arsize;
    wire    [1:0]       read_arburst;
    wire    [0:0]       read_arlock;
    wire    [3:0]       read_arcache;
    wire    [3:0]       read_arqos;
    wire    [2:0]       read_arprot;
    wire                read_rvalid;
    wire                read_rready;
    wire    [127:0]      read_rdata;
    wire    [1:0]       read_rresp;
    wire                read_rlast;
    wire                write_awvalid;
    wire                write_awready;
    wire    [31:0]      write_awaddr;
    wire    [3:0]       write_awregion;
    wire    [7:0]       write_awlen;
    wire    [2:0]       write_awsize;
    wire    [1:0]       write_awburst;
    wire    [0:0]       write_awlock;
    wire    [3:0]       write_awcache;
    wire    [3:0]       write_awqos;
    wire    [2:0]       write_awprot;
    wire                write_wvalid;
    wire                write_wready;
    wire    [127:0]      write_wdata;
    wire    [15:0]       write_wstrb;
    wire                write_wlast;
    wire                write_bvalid;
    wire                write_bready;
    wire    [1:0]       write_bresp;

    

    wire    [3:0]       writer_base_index_0;
    wire    [3:0]       reader_base_index_0;
    wire    [3:0]       writer_base_index_1;
    wire    [3:0]       reader_base_index_1;
    wire    [3:0]       writer_base_index_2;
    wire    [3:0]       reader_base_index_2;
    wire    [3:0]       writer_base_index_pause;
    wire    [3:0]       reader_base_index_pause;
    wire    [3:0]       writer_base_index_pause_1;
    wire    [3:0]       reader_base_index_pause_1;

    wire    [13:0]      m_axis_tdata_reader_0;
    wire                m_axis_tlast_reader_0; 
    wire                m_axis_tvalid_reader_0;
    wire                m_axis_tready_reader_0;
    wire                m_axis_tuser_reader_0; 

    wire    [7:0]       m_axis_tdata_reader_1;
    wire                m_axis_tlast_reader_1; 
    wire                m_axis_tvalid_reader_1;
    wire                m_axis_tready_reader_1;
    wire                m_axis_tuser_reader_1; 

    wire    [7:0]       m_axis_tdata_reader_2;
    wire                m_axis_tlast_reader_2; 
    wire                m_axis_tvalid_reader_2;
    wire                m_axis_tready_reader_2;
    wire                m_axis_tuser_reader_2;


    wire                go_v;



    wire    [31:0]      m_axi_araddr_0;
    wire    [1:0]       m_axi_arburst_0;
    wire    [3:0]       m_axi_arcache_0;
    wire    [7:0]       m_axi_arlen_0;
    wire    [2:0]       m_axi_arprot_0;
    wire                m_axi_arready_0;
    wire    [2:0]       m_axi_arsize_0;
    wire    [3:0]       m_axi_aruser_0;
    wire                m_axi_arvalid_0;
    wire    [127:0]     m_axi_rdata_0;
    wire                m_axi_rlast_0;
    wire                m_axi_rready_0;
    wire    [1:0]       m_axi_rresp_0;
    wire                m_axi_rvalid_0;


    wire    [31:0]      m_axi_araddr_1;
    wire    [1:0]       m_axi_arburst_1;
    wire    [3:0]       m_axi_arcache_1;
    wire    [7:0]       m_axi_arlen_1;
    wire    [2:0]       m_axi_arprot_1;
    wire                m_axi_arready_1;
    wire    [2:0]       m_axi_arsize_1;
    wire    [3:0]       m_axi_aruser_1;
    wire                m_axi_arvalid_1;
    wire    [127:0]     m_axi_rdata_1;
    wire                m_axi_rlast_1;
    wire                m_axi_rready_1;
    wire    [1:0]       m_axi_rresp_1;
    wire                m_axi_rvalid_1;


    wire    [31:0]      m_axi_araddr_2;
    wire    [1:0]       m_axi_arburst_2;
    wire    [3:0]       m_axi_arcache_2;
    wire    [7:0]       m_axi_arlen_2;
    wire    [2:0]       m_axi_arprot_2;
    wire                m_axi_arready_2;
    wire    [2:0]       m_axi_arsize_2;
    wire    [3:0]       m_axi_aruser_2;
    wire                m_axi_arvalid_2;
    wire    [127:0]     m_axi_rdata_2;
    wire                m_axi_rlast_2;
    wire                m_axi_rready_2;
    wire    [1:0]       m_axi_rresp_2;
    wire                m_axi_rvalid_2;

    wire    [31:0]      m_axi_araddr_2_0;
    wire    [1:0]       m_axi_arburst_2_0;
    wire    [3:0]       m_axi_arcache_2_0;
    wire    [7:0]       m_axi_arlen_2_0;
    wire    [2:0]       m_axi_arprot_2_0;
    wire                m_axi_arready_2_0;
    wire    [2:0]       m_axi_arsize_2_0;
    wire    [3:0]       m_axi_aruser_2_0;
    wire                m_axi_arvalid_2_0;
    wire    [127:0]     m_axi_rdata_2_0;
    wire                m_axi_rlast_2_0;
    wire                m_axi_rready_2_0;
    wire    [1:0]       m_axi_rresp_2_0;
    wire                m_axi_rvalid_2_0;

    wire    [31:0]      m_axi_araddr_7;
    wire    [1:0]       m_axi_arburst_7;
    wire    [3:0]       m_axi_arcache_7;
    wire    [7:0]       m_axi_arlen_7;
    wire    [2:0]       m_axi_arprot_7;
    wire                m_axi_arready_7;
    wire    [2:0]       m_axi_arsize_7;
    wire    [3:0]       m_axi_aruser_7;
    wire                m_axi_arvalid_7;
    wire    [127:0]     m_axi_rdata_7;
    wire                m_axi_rlast_7;
    wire                m_axi_rready_7;
    wire    [1:0]       m_axi_rresp_7;
    wire                m_axi_rvalid_7;

    wire    [31:0]      m_axi_araddr_tfilter;
    wire    [1:0]       m_axi_arburst_tfilter;
    wire    [3:0]       m_axi_arcache_tfilter;
    wire    [7:0]       m_axi_arlen_tfilter;
    wire    [2:0]       m_axi_arprot_tfilter;
    wire                m_axi_arready_tfilter;
    wire    [2:0]       m_axi_arsize_tfilter;
    wire    [3:0]       m_axi_aruser_tfilter;
    wire                m_axi_arvalid_tfilter;
    wire    [127:0]     m_axi_rdata_tfilter;
    wire                m_axi_rlast_tfilter;
    wire                m_axi_rready_tfilter;
    wire    [1:0]       m_axi_rresp_tfilter;
    wire                m_axi_rvalid_tfilter;



    wire    [31:0]      m_axi_awaddr_0;  
    wire    [1:0]       m_axi_awburst_0; 
    wire    [3:0]       m_axi_awcache_0; 
    wire    [7:0]       m_axi_awlen_0;   
    wire    [2:0]       m_axi_awprot_0;  
    wire                m_axi_awready_0; 
    wire    [2:0]       m_axi_awsize_0;  
    wire    [3:0]       m_axi_awuser_0;  
    wire                m_axi_awvalid_0; 
    wire                m_axi_bready_0;  
    wire    [1:0]       m_axi_bresp_0;   
    wire                m_axi_bvalid_0;  
    wire    [127:0]     m_axi_wdata_0;   
    wire                m_axi_wlast_0;   
    wire                m_axi_wready_0;  
    wire    [15:0]      m_axi_wstrb_0;   
    wire                m_axi_wvalid_0;  

    wire    [31:0]      m_axi_awaddr_0_0;  
    wire    [1:0]       m_axi_awburst_0_0; 
    wire    [3:0]       m_axi_awcache_0_0; 
    wire    [7:0]       m_axi_awlen_0_0;   
    wire    [2:0]       m_axi_awprot_0_0;  
    wire                m_axi_awready_0_0; 
    wire    [2:0]       m_axi_awsize_0_0;  
    wire    [3:0]       m_axi_awuser_0_0;  
    wire                m_axi_awvalid_0_0; 
    wire                m_axi_bready_0_0;  
    wire    [1:0]       m_axi_bresp_0_0;   
    wire                m_axi_bvalid_0_0;  
    wire    [127:0]     m_axi_wdata_0_0;   
    wire                m_axi_wlast_0_0;   
    wire                m_axi_wready_0_0;  
    wire    [15:0]      m_axi_wstrb_0_0;   
    wire                m_axi_wvalid_0_0;  



    wire    [31:0]      m_axi_awaddr_1;  
    wire    [1:0]       m_axi_awburst_1; 
    wire    [3:0]       m_axi_awcache_1; 
    wire    [7:0]       m_axi_awlen_1;   
    wire    [2:0]       m_axi_awprot_1;  
    wire                m_axi_awready_1; 
    wire    [2:0]       m_axi_awsize_1;  
    wire    [3:0]       m_axi_awuser_1;  
    wire                m_axi_awvalid_1; 
    wire                m_axi_bready_1;  
    wire    [1:0]       m_axi_bresp_1;   
    wire                m_axi_bvalid_1;  
    wire    [127:0]     m_axi_wdata_1;   
    wire                m_axi_wlast_1;   
    wire                m_axi_wready_1;  
    wire    [15:0]      m_axi_wstrb_1;   
    wire                m_axi_wvalid_1;   

    wire    [31:0]      m_axi_awaddr_2;  
    wire    [1:0]       m_axi_awburst_2; 
    wire    [3:0]       m_axi_awcache_2; 
    wire    [7:0]       m_axi_awlen_2;   
    wire    [2:0]       m_axi_awprot_2;  
    wire                m_axi_awready_2; 
    wire    [2:0]       m_axi_awsize_2;  
    wire    [3:0]       m_axi_awuser_2;  
    wire                m_axi_awvalid_2; 
    wire                m_axi_bready_2;  
    wire    [1:0]       m_axi_bresp_2;   
    wire                m_axi_bvalid_2;  
    wire    [127:0]     m_axi_wdata_2;   
    wire                m_axi_wlast_2;   
    wire                m_axi_wready_2;  
    wire    [15:0]      m_axi_wstrb_2;   
    wire                m_axi_wvalid_2;   

    wire    [31:0]      m_axi_awaddr_7;  
    wire    [1:0]       m_axi_awburst_7; 
    wire    [3:0]       m_axi_awcache_7; 
    wire    [7:0]       m_axi_awlen_7;   
    wire    [2:0]       m_axi_awprot_7;  
    wire                m_axi_awready_7; 
    wire    [2:0]       m_axi_awsize_7;  
    wire    [3:0]       m_axi_awuser_7;  
    wire                m_axi_awvalid_7; 
    wire                m_axi_bready_7;  
    wire    [1:0]       m_axi_bresp_7;   
    wire                m_axi_bvalid_7;  
    wire    [127:0]     m_axi_wdata_7;   
    wire                m_axi_wlast_7;   
    wire                m_axi_wready_7;  
    wire    [15:0]      m_axi_wstrb_7;   
    wire                m_axi_wvalid_7;  

    wire    [31:0]      m_axi_awaddr_tfilter;  
    wire    [1:0]       m_axi_awburst_tfilter; 
    wire    [3:0]       m_axi_awcache_tfilter; 
    wire    [7:0]       m_axi_awlen_tfilter;   
    wire    [2:0]       m_axi_awprot_tfilter;  
    wire                m_axi_awready_tfilter; 
    wire    [2:0]       m_axi_awsize_tfilter;  
    wire    [3:0]       m_axi_awuser_tfilter;  
    wire                m_axi_awvalid_tfilter; 
    wire                m_axi_bready_tfilter;  
    wire    [1:0]       m_axi_bresp_tfilter;   
    wire                m_axi_bvalid_tfilter;  
    wire    [127:0]     m_axi_wdata_tfilter;   
    wire                m_axi_wlast_tfilter;   
    wire                m_axi_wready_tfilter;  
    wire    [15:0]      m_axi_wstrb_tfilter;   
    wire                m_axi_wvalid_tfilter;  
  

    wire    [31:0]      m_axi_araddr;
    wire    [1:0]       m_axi_arburst;
    wire    [3:0]       m_axi_arcache;
    wire    [7:0]       m_axi_arlen;
    wire    [2:0]       m_axi_arprot;
    wire                m_axi_arready;
    wire    [2:0]       m_axi_arsize;
    wire    [3:0]       m_axi_aruser;
    wire                m_axi_arvalid;
    wire    [127:0]     m_axi_rdata;
    wire                m_axi_rlast;
    wire                m_axi_rready;
    wire    [1:0]       m_axi_rresp;
    wire                m_axi_rvalid;
    wire    [3:0]       m_axi_arid;
    wire    [3:0]       m_axi_arregion;
    wire                m_axi_arlock;
    wire    [3:0]       m_axi_arqos;
    wire    [3:0]       m_axi_bid;



    wire    [31:0]      m_axi_awaddr;  
    wire    [1:0]       m_axi_awburst; 
    wire    [3:0]       m_axi_awcache; 
    wire    [7:0]       m_axi_awlen;   
    wire    [2:0]       m_axi_awprot;  
    wire                m_axi_awready; 
    wire    [2:0]       m_axi_awsize;  
    wire    [3:0]       m_axi_awuser;  
    wire                m_axi_awvalid; 
    wire                m_axi_bready;  
    wire    [1:0]       m_axi_bresp;   
    wire                m_axi_bvalid;  
    wire    [127:0]     m_axi_wdata;   
    wire                m_axi_wlast;   
    wire                m_axi_wready;  
    wire    [15:0]      m_axi_wstrb;   
    wire                m_axi_wvalid;  
    wire    [3:0]       m_axi_awid;
    wire    [3:0]       m_axi_awregion;
    wire                m_axi_awlock;
    wire    [3:0]       m_axi_awqos;
    wire    [3:0]       m_axi_rid;




    wire    [13:0]      rtd6122_data;
    wire                FS_Data;
    wire                LS_Data;
    wire    [9:0]       cnt_h;
    wire    [9:0]       cnt_l;

    wire    [13:0]      sensor_data;
    wire                sensor_last;
    wire                sensor_valid;
    wire                sensor_ready;
    wire                sensor_user; 



    (* keep , syn_keep *)assign reset 	= ~(systemClk_locked);

    reg systemClk_locked_delay = 1'b0;
    reg [31:0] cnt_delay;
    always @(posedge clk_10m or negedge systemClk_locked)begin
        if (!systemClk_locked) begin
            cnt_delay <= 0;
            systemClk_locked_delay <= 1'b0;
        end
        else begin
            if (cnt_delay >= 32'd5000)begin
                cnt_delay <= cnt_delay;
                systemClk_locked_delay <= 1'b1;
            end
            else begin
                cnt_delay <= cnt_delay + 1;
                systemClk_locked_delay <= systemClk_locked_delay;
            end
        end
    end

   
    // ---------------------------- sensor begin -----------------------
    wire go;
    wire go_sample_background;
    wire rw_pause;

    wire sensor_rst;
    wire sensor_go;
    reg sensor_flag;
    wire [13:0] mean_out;
    wire [13:0] Tempera;
    wire go_b;
    wire go_nuc;
    wire finish_b;

    wire fsync;     
    wire ooc_finish;
    wire go_ooc;   

    wire    [31:0]      m_axi_araddr_ooc;
    wire    [1:0]       m_axi_arburst_ooc;
    wire    [3:0]       m_axi_arcache_ooc;
    wire    [7:0]       m_axi_arlen_ooc;
    wire    [2:0]       m_axi_arprot_ooc;
    wire                m_axi_arready_ooc;
    wire    [2:0]       m_axi_arsize_ooc;
    wire    [3:0]       m_axi_aruser_ooc;
    wire                m_axi_arvalid_ooc;
    wire    [127:0]     m_axi_rdata_ooc;
    wire                m_axi_rlast_ooc;
    wire                m_axi_rready_ooc;
    wire    [1:0]       m_axi_rresp_ooc;
    wire                m_axi_rvalid_ooc;


    wire    [31:0]      m_axi_awaddr_ooc;  
    wire    [1:0]       m_axi_awburst_ooc; 
    wire    [3:0]       m_axi_awcache_ooc; 
    wire    [7:0]       m_axi_awlen_ooc;   
    wire    [2:0]       m_axi_awprot_ooc;  
    wire                m_axi_awready_ooc; 
    wire    [2:0]       m_axi_awsize_ooc;  
    wire    [3:0]       m_axi_awuser_ooc;  
    wire                m_axi_awvalid_ooc; 
    wire                m_axi_bready_ooc;  
    wire    [1:0]       m_axi_bresp_ooc;   
    wire                m_axi_bvalid_ooc;  
    wire    [127:0]     m_axi_wdata_ooc;   
    wire                m_axi_wlast_ooc;   
    wire                m_axi_wready_ooc;  
    wire    [15:0]      m_axi_wstrb_ooc;   
    wire                m_axi_wvalid_ooc;  
    wire    [31 : 0]    workpoint;
    
    wire [  31:0] s24_axi_awaddr;
    wire [   2:0] s24_axi_awprot;
    wire          s24_axi_awvalid;
    wire          s24_axi_awready;
    wire [  31:0] s24_axi_wdata;
    wire [   3:0] s24_axi_wstrb;
    wire          s24_axi_wvalid;
    wire          s24_axi_wready;
    wire [   1:0] s24_axi_bresp;
    wire          s24_axi_bvalid;
    wire          s24_axi_bready;
    wire [  31:0] s24_axi_araddr;
    wire [   2:0] s24_axi_arprot;
    wire          s24_axi_arvalid;
    wire          s24_axi_arready;
    wire [  31:0] s24_axi_rdata;
    wire [   1:0] s24_axi_rresp;
    wire          s24_axi_rvalid;
    wire          s24_axi_rready;
    
    sensor sensor(
        .mclkin             (mclkin),
        .mclk               (mclk),
        .reset              (systemClk_locked_delay),

        .sensor_DO0         (sensor_DO0 ),
        .sensor_DO1         (sensor_DO1 ),
        .sensor_DO2         (sensor_DO2 ),
        .sensor_DO3         (sensor_DO3 ),
        .sensor_MCK         (sensor_MCK ),
        .sensor_SD0         (sensor_SD0 ),
        .sensor_SD1         (sensor_SD1 ),

        .IR_5V_ON           (IR_5V_ON),
        .go                 (go          ),
        .rtd6122_data       (rtd6122_data),
        .FS_Data            (FS_Data     ),
        .LS_Data            (LS_Data     ),
        .cnt_h              (cnt_h       ),
        .cnt_l              (cnt_l       ),
        .temp               (Tempera    ),

        .fsync              (fsync     ),
        .ooc_finish         (ooc_finish),
        .go_ooc             (go_ooc    ),


        .axi_clk                            (io_memoryClk),
        // reader AXI master inputs and outputs
        .m_axi_araddr                       (m_axi_araddr_ooc  ),
        .m_axi_arburst                      (m_axi_arburst_ooc ),
        .m_axi_arcache                      (m_axi_arcache_ooc ),
        .m_axi_arlen                        (m_axi_arlen_ooc   ),
        .m_axi_arprot                       (m_axi_arprot_ooc  ),
        .m_axi_arready                      (m_axi_arready_ooc ),
        .m_axi_arsize                       (m_axi_arsize_ooc  ),
        .m_axi_aruser                       (m_axi_aruser_ooc  ),
        .m_axi_arvalid                      (m_axi_arvalid_ooc ),
        .m_axi_rdata                        (m_axi_rdata_ooc   ),
        .m_axi_rlast                        (m_axi_rlast_ooc   ),
        .m_axi_rready                       (m_axi_rready_ooc  ),
        .m_axi_rresp                        (m_axi_rresp_ooc   ),
        .m_axi_rvalid                       (m_axi_rvalid_ooc  ),


        // writer AXI master inputs and outputs
        .m_axi_awaddr                       (m_axi_awaddr_ooc  ),
        .m_axi_awburst                      (m_axi_awburst_ooc ),
        .m_axi_awcache                      (m_axi_awcache_ooc ),
        .m_axi_awlen                        (m_axi_awlen_ooc   ),
        .m_axi_awprot                       (m_axi_awprot_ooc  ),
        .m_axi_awready                      (m_axi_awready_ooc ),
        .m_axi_awsize                       (m_axi_awsize_ooc  ),
        .m_axi_awuser                       (m_axi_awuser_ooc  ),
        .m_axi_awvalid                      (m_axi_awvalid_ooc ),
        .m_axi_bready                       (m_axi_bready_ooc  ),
        .m_axi_bresp                        (m_axi_bresp_ooc   ),
        .m_axi_bvalid                       (m_axi_bvalid_ooc  ),
        .m_axi_wdata                        (m_axi_wdata_ooc   ),
        .m_axi_wlast                        (m_axi_wlast_ooc   ),
        .m_axi_wready                       (m_axi_wready_ooc  ),
        .m_axi_wstrb                        (m_axi_wstrb_ooc   ),
        .m_axi_wvalid                       (m_axi_wvalid_ooc  ),

        .axi_aclk                           (io_systemClk),
        .axi_aresetn                        (systemClk_locked_delay),
        .s00_axi_awaddr                     (s24_axi_awaddr ),
        .s00_axi_awprot                     (s24_axi_awprot ),
        .s00_axi_awvalid                    (s24_axi_awvalid),
        .s00_axi_awready                    (s24_axi_awready),
        .s00_axi_wdata                      (s24_axi_wdata  ),
        .s00_axi_wstrb                      (s24_axi_wstrb  ),
        .s00_axi_wvalid                     (s24_axi_wvalid ),
        .s00_axi_wready                     (s24_axi_wready ),
        .s00_axi_bresp                      (s24_axi_bresp  ),
        .s00_axi_bvalid                     (s24_axi_bvalid ),
        .s00_axi_bready                     (s24_axi_bready ),
        .s00_axi_araddr                     (s24_axi_araddr ),
        .s00_axi_arprot                     (s24_axi_arprot ),
        .s00_axi_arvalid                    (s24_axi_arvalid),
        .s00_axi_arready                    (s24_axi_arready),
        .s00_axi_rdata                      (s24_axi_rdata  ),
        .s00_axi_rresp                      (s24_axi_rresp  ),
        .s00_axi_rvalid                     (s24_axi_rvalid ),
        .s00_axi_rready                     (s24_axi_rready )           


    );

    assign sensor_data = rtd6122_data;
    assign sensor_valid =       (cnt_h >= 10) & (cnt_h <= 649) 
                            &   (cnt_l >= 8) & (cnt_l <= 519)  
                            &   LS_Data
                            // &   sensor_flag;
                            &   sensor_ready;

    assign sensor_last = (cnt_h == 649) & sensor_valid;
    assign sensor_user = (cnt_h == 10) & (cnt_l == 8) & sensor_valid;


    // ---------------------------- sensor end -----------------------

     // ---------------------------- shutter begin -----------------------


    wire do_shutter_cfpn;
    wire shutter_en;
    //wire [13 : 0]   max_14bits;
    //wire [13 : 0]   min_14bits;   

    wire [  31:0] s16_axi_awaddr;
    wire [   2:0] s16_axi_awprot;
    wire          s16_axi_awvalid;
    wire          s16_axi_awready;
    wire [  31:0] s16_axi_wdata;
    wire [   3:0] s16_axi_wstrb;
    wire          s16_axi_wvalid;
    wire          s16_axi_wready;
    wire [   1:0] s16_axi_bresp;
    wire          s16_axi_bvalid;
    wire          s16_axi_bready;
    wire [  31:0] s16_axi_araddr;
    wire [   2:0] s16_axi_arprot;
    wire          s16_axi_arvalid;
    wire          s16_axi_arready;
    wire [  31:0] s16_axi_rdata;
    wire [   1:0] s16_axi_rresp;
    wire          s16_axi_rvalid;
    wire          s16_axi_rready;

    shutter_ctrl shutter_ctrl(
        .clk                    (clk_10m),
        .rst_n                  (systemClk_locked_delay),
        .clk_isp                (clk_10m),

        .go                     (go     ),
        .go_b                   (go_b   ),
        .go_nuc                 (go_nuc ),
        .finish_b               (finish_b),
        .rw_pause               (rw_pause),

        .do_shutter_cfpn        (1'b0),//do_shutter_cfpn),
        .max_14bits             (0),
        .min_14bits             (0),

        .fsync                  (fsync),
        .ooc_finish             (ooc_finish),
        

        .SHUTTER_DIR            (SHUTTER_DIR),
        .SHUTTER_EN             (SHUTTER_EN),
        .go_ooc                 (go_ooc),
        .shutter_en_1           (shutter_en),

        .s00_axi_aclk   (io_systemClk),
        .s00_axi_aresetn(systemClk_locked_delay),
        .s00_axi_awaddr (s16_axi_awaddr),
        .s00_axi_awprot (s16_axi_awprot),
        .s00_axi_awvalid(s16_axi_awvalid),
        .s00_axi_awready(s16_axi_awready),
        .s00_axi_wdata  (s16_axi_wdata),
        .s00_axi_wstrb  (s16_axi_wstrb),
        .s00_axi_wvalid (s16_axi_wvalid),
        .s00_axi_wready (s16_axi_wready),
        .s00_axi_bresp  (s16_axi_bresp),
        .s00_axi_bvalid (s16_axi_bvalid),
        .s00_axi_bready (s16_axi_bready),
        .s00_axi_araddr (s16_axi_araddr),
        .s00_axi_arprot (s16_axi_arprot),
        .s00_axi_arvalid(s16_axi_arvalid),
        .s00_axi_arready(s16_axi_arready),
        .s00_axi_rdata  (s16_axi_rdata),
        .s00_axi_rresp  (s16_axi_rresp),
        .s00_axi_rvalid (s16_axi_rvalid),
        .s00_axi_rready (s16_axi_rready)

    );

    // ---------------------------- shutter end -----------------------


    // ---------------------------- data generator begin -----------------------

    reg [13:0]  data;
    wire        m_ready;
    wire        m_valid;
    wire        m_last;
    wire        m_user;


    reg [31:0] cnt_width;
    reg [31:0] cnt_height;
    always @(posedge mclk or negedge systemClk_locked_delay)
    if (!systemClk_locked_delay) begin
        cnt_width <= 0;
        cnt_height <= 0;
        data <= 0;
    end
    else begin
        if (m_ready & m_valid) begin
            if (cnt_width == 639) begin
                cnt_width <= 0;
                data <= 0;
                if (cnt_height == 511) begin
                    cnt_height <= 0;
                end
                else begin
                    cnt_height <= cnt_height + 1;
                end
            end
            else begin
                cnt_width <= cnt_width + 1;
                cnt_height <= cnt_height;
                data <= data + 1;
            end
        end

    end


    assign m_valid = 1;
    assign m_last = (cnt_width == 639) ? 1'b1 : 1'b0;
    assign m_user = ((cnt_width == 0) & (cnt_height == 0)) ? 1'b1 : 1'b0;




    // ---------------------------- data generator end -----------------------

    
    // ---------------------------- first frame writer begin -----------------------

    wire [    31 : 0]               s04_axi_awaddr;
    wire [                   2 : 0] s04_axi_awprot;
    wire                            s04_axi_awvalid;
    wire                            s04_axi_awready;
    wire [    31 : 0]               s04_axi_wdata;
    wire [3 : 0]                    s04_axi_wstrb;
    wire                            s04_axi_wvalid;
    wire                            s04_axi_wready;
    wire [                   1 : 0] s04_axi_bresp;
    wire                            s04_axi_bvalid;
    wire                            s04_axi_bready;
    wire [    31 : 0]               s04_axi_araddr;
    wire [                   2 : 0] s04_axi_arprot;
    wire                            s04_axi_arvalid;
    wire                            s04_axi_arready;
    wire [    31 : 0]               s04_axi_rdata;
    wire [                   1 : 0] s04_axi_rresp;
    wire                            s04_axi_rvalid;
    wire                            s04_axi_rready;

    axi_frame_writer_v1_0 #(
        .BPS                (14),   
		.MAX_WIDTH          (640),
		.MAX_HEIGHT         (512),
		.BUFFER_NUM         (3),
		.ADDRESSWIDTH       (32),
		.DATAWIDTH_MM       (128),
		.MAXBURSTCOUNT      (8),
		.FIFODEPTH_BYTE     (2048)
    )
    writer_0
    (
        .clk                    (io_memoryClk  ),
        .rst_n                  (systemClk_locked_delay),

        .writer_base_index      (writer_base_index_0),
        .reader_base_index      (reader_base_index_0),

        .go                     (go),

        // .go                     (go_v),		
        // .mode                   (0),		
        // .width                  (640),
        // .height                 (512),
        // .baseaddr               (32'h1000_0000),	

        .m_axi_awaddr           (m_axi_awaddr_0  ),
        .m_axi_awburst          (m_axi_awburst_0 ),
        .m_axi_awcache          (m_axi_awcache_0 ),
        .m_axi_awlen            (m_axi_awlen_0   ),
        .m_axi_awprot           (m_axi_awprot_0  ),
        .m_axi_awready          (m_axi_awready_0|m_axi_awready_0_0 ),
        .m_axi_awsize           (m_axi_awsize_0  ),
        .m_axi_awuser           (m_axi_awuser_0  ),
        .m_axi_awvalid          (m_axi_awvalid_0 ),
        .m_axi_bready           (m_axi_bready_0  ),
        .m_axi_bresp            (m_axi_bresp_0|m_axi_bresp_0_0   ),
        .m_axi_bvalid           (m_axi_bvalid_0|m_axi_bvalid_0_0  ),
        .m_axi_wdata            (m_axi_wdata_0   ),
        .m_axi_wlast            (m_axi_wlast_0   ),
        .m_axi_wready           (m_axi_wready_0|m_axi_wready_0_0  ),
        .m_axi_wstrb            (m_axi_wstrb_0   ),
        .m_axi_wvalid           (m_axi_wvalid_0  ),

        .axis_aclk              (mclk),
        .s_axis_tdata           ( sensor_data  ),
        .s_axis_tlast           ( sensor_last  ),
        .s_axis_tvalid          ( sensor_valid  ),
        .s_axis_tready          ( sensor_ready  ),
        .s_axis_tuser           ( sensor_user   ),

        // .s_axis_tdata           ( data  ),
        // .s_axis_tlast           ( m_last  ),
        // .s_axis_tvalid          ( m_valid  ),
        // .s_axis_tready          ( m_ready  ),
        // .s_axis_tuser           ( m_user   ),   

        // Ports of Axi Slave Bus Interface S00_AXI
        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s04_axi_awaddr ),
        .s00_axi_awprot     (s04_axi_awprot ),
        .s00_axi_awvalid    (s04_axi_awvalid),
        .s00_axi_awready    (s04_axi_awready),
        .s00_axi_wdata      (s04_axi_wdata  ),
        .s00_axi_wstrb      (s04_axi_wstrb  ),
        .s00_axi_wvalid     (s04_axi_wvalid ),
        .s00_axi_wready     (s04_axi_wready ),
        .s00_axi_bresp      (s04_axi_bresp  ),
        .s00_axi_bvalid     (s04_axi_bvalid ),
        .s00_axi_bready     (s04_axi_bready ),
        .s00_axi_araddr     (s04_axi_araddr ),
        .s00_axi_arprot     (s04_axi_arprot ),
        .s00_axi_arvalid    (s04_axi_arvalid),
        .s00_axi_arready    (s04_axi_arready),
        .s00_axi_rdata      (s04_axi_rdata  ),
        .s00_axi_rresp      (s04_axi_rresp  ),
        .s00_axi_rvalid     (s04_axi_rvalid ),
        .s00_axi_rready     (s04_axi_rready )        
         
    );

    // ---------------------------- first frame writer end -----------------------


    // ---------------------------- first frame reader begin -----------------------


    wire [    31 : 0]               s02_axi_awaddr;
    wire [                   2 : 0] s02_axi_awprot;
    wire                            s02_axi_awvalid;
    wire                            s02_axi_awready;
    wire [    31 : 0]               s02_axi_wdata;
    wire [3 : 0]                    s02_axi_wstrb;
    wire                            s02_axi_wvalid;
    wire                            s02_axi_wready;
    wire [                   1 : 0] s02_axi_bresp;
    wire                            s02_axi_bvalid;
    wire                            s02_axi_bready;
    wire [    31 : 0]               s02_axi_araddr;
    wire [                   2 : 0] s02_axi_arprot;
    wire                            s02_axi_arvalid;
    wire                            s02_axi_arready;
    wire [    31 : 0]               s02_axi_rdata;
    wire [                   1 : 0] s02_axi_rresp;
    wire                            s02_axi_rvalid;
    wire                            s02_axi_rready;

    axi_frame_reader_v1_0 #(
        .BPS                (14),
		.MAX_WIDTH          (640),
		.MAX_HEIGHT         (512),
		.BUFFER_NUM         (3),
		.ADDRESSWIDTH       (32),
		.DATAWIDTH_MM       (128),
		.MAXBURSTCOUNT      (8),
		.FIFODEPTH_BYTE     (2048)
    )
    reader_0
    (
        .clk                                (io_memoryClk),
		.axis_aresetn                       (systemClk_locked_delay),
        // .reset_n                       (systemClk_locked_delay),
		.writer_base_index                  (writer_base_index_0),
		.reader_base_index                  (reader_base_index_0),

		.m_axi_araddr                       (m_axi_araddr_0   ),
		.m_axi_arburst                      (m_axi_arburst_0  ),
		.m_axi_arcache                      (m_axi_arcache_0  ),
		.m_axi_arlen                        (m_axi_arlen_0    ),
		.m_axi_arprot                       (m_axi_arprot_0   ),
		.m_axi_arready                      (m_axi_arready_0  ),
		.m_axi_arsize                       (m_axi_arsize_0   ),
		.m_axi_aruser                       (m_axi_aruser_0   ),
		.m_axi_arvalid                      (m_axi_arvalid_0  ),
		.m_axi_rdata                        (m_axi_rdata_0    ),
		.m_axi_rlast                        (m_axi_rlast_0    ),
		.m_axi_rready                       (m_axi_rready_0   ),
		.m_axi_rresp                        (m_axi_rresp_0    ),
		.m_axi_rvalid                       (m_axi_rvalid_0   ),


		.axis_aclk                          (clk_10m),
		.m_axis_tdata                       (m_axis_tdata_reader_0  ),
		.m_axis_tlast                       (m_axis_tlast_reader_0   ),
		.m_axis_tvalid                      (m_axis_tvalid_reader_0   ),
		.m_axis_tready                      (m_axis_tready_reader_0   ),
		.m_axis_tuser                       (m_axis_tuser_reader_0   ),

        // Ports of Axi Slave Bus Interface S00_AXI
        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s02_axi_awaddr ),
        .s00_axi_awprot     (s02_axi_awprot ),
        .s00_axi_awvalid    (s02_axi_awvalid),
        .s00_axi_awready    (s02_axi_awready),
        .s00_axi_wdata      (s02_axi_wdata  ),
        .s00_axi_wstrb      (s02_axi_wstrb  ),
        .s00_axi_wvalid     (s02_axi_wvalid ),
        .s00_axi_wready     (s02_axi_wready ),
        .s00_axi_bresp      (s02_axi_bresp  ),
        .s00_axi_bvalid     (s02_axi_bvalid ),
        .s00_axi_bready     (s02_axi_bready ),
        .s00_axi_araddr     (s02_axi_araddr ),
        .s00_axi_arprot     (s02_axi_arprot ),
        .s00_axi_arvalid    (s02_axi_arvalid),
        .s00_axi_arready    (s02_axi_arready),
        .s00_axi_rdata      (s02_axi_rdata  ),
        .s00_axi_rresp      (s02_axi_rresp  ),
        .s00_axi_rvalid     (s02_axi_rvalid ),
        .s00_axi_rready     (s02_axi_rready )

                
    );

    // ---------------------------- first frame reader end -----------------------


    wire    [13:0]      m_axis_tdata_same_judge;
    wire                m_axis_tlast_same_judge; 
    wire                m_axis_tvalid_same_judge;
    wire                m_axis_tready_same_judge;
    wire                m_axis_tuser_same_judge; 

    // ---------------------------- first frame reader end -----------------------
    wire same_flag;

    same_judge #(
        .DATA_WIDTH     (14),
        .HEIGHT         (512),
        .WIDTH          (640)
    )u_same_judge(
        .clk            (clk_10m),
        .rst_n          (systemClk_locked_delay),

        .s_axis_tdata   (m_axis_tdata_reader_0),
        .s_axis_tlast   (m_axis_tlast_reader_0),
        .s_axis_tvalid  (m_axis_tvalid_reader_0),
        .s_axis_tuser   (m_axis_tuser_reader_0),
        .s_axis_tready  (m_axis_tready_reader_0),
        
        .m_axis_tdata   (m_axis_tdata_same_judge),
        .m_axis_tlast   (m_axis_tlast_same_judge),
        .m_axis_tvalid  (m_axis_tvalid_same_judge),
        .m_axis_tready  (m_axis_tready_same_judge),
        .m_axis_tuser   (m_axis_tuser_same_judge),
        .same_flag      (same_flag)
    );


//-----------------------------------------------------------------------------------sample_background begin----------------------------------------------------------------------------------------------------------------------

    // axi
    wire [    31 : 0]               s00_axi_awaddr;
    wire [                   2 : 0] s00_axi_awprot;
    wire                            s00_axi_awvalid;
    wire                            s00_axi_awready;
    wire [    31 : 0]               s00_axi_wdata;
    wire [3 : 0]                    s00_axi_wstrb;
    wire                            s00_axi_wvalid;
    wire                            s00_axi_wready;
    wire [                   1 : 0] s00_axi_bresp;
    wire                            s00_axi_bvalid;
    wire                            s00_axi_bready;
    wire [    31 : 0]               s00_axi_araddr;
    wire [                   2 : 0] s00_axi_arprot;
    wire                            s00_axi_arvalid;
    wire                            s00_axi_arready;
    wire [    31 : 0]               s00_axi_rdata;
    wire [                   1 : 0] s00_axi_rresp;
    wire                            s00_axi_rvalid;
    wire                            s00_axi_rready;


    wire    [13:0]      m_axis_tdata_reader_sample_background;
    wire                m_axis_tlast_reader_sample_background; 
    wire                m_axis_tvalid_reader_sample_background;
    wire                m_axis_tready_reader_sample_background;
    wire                m_axis_tuser_reader_sample_background; 


    wire    [31:0]      m_axi_araddr_r8 ;
    wire    [1:0]       m_axi_arburst_r8;
    wire    [3:0]       m_axi_arcache_r8;
    wire    [7:0]       m_axi_arlen_r8  ;
    wire    [2:0]       m_axi_arprot_r8 ;
    wire                m_axi_arready_r8;
    wire    [2:0]       m_axi_arsize_r8 ;
    wire    [3:0]       m_axi_aruser_r8 ;
    wire                m_axi_arvalid_r8;
    wire    [127:0]     m_axi_rdata_r8  ;
    wire                m_axi_rlast_r8  ;
    wire                m_axi_rready_r8 ;
    wire    [1:0]       m_axi_rresp_r8  ;
    wire                m_axi_rvalid_r8 ;


    wire    [31:0]      m_axi_awaddr_w8    ;
    wire    [1:0]       m_axi_awburst_w8   ;
    wire    [3:0]       m_axi_awcache_w8   ;
    wire    [7:0]       m_axi_awlen_w8     ;
    wire    [2:0]       m_axi_awprot_w8    ;
    wire                m_axi_awready_w8   ;
    wire    [2:0]       m_axi_awsize_w8    ;
    wire    [3:0]       m_axi_awuser_w8    ;
    wire                m_axi_awvalid_w8   ;
    wire                m_axi_bready_w8    ;
    wire    [1:0]       m_axi_bresp_w8     ;
    wire                m_axi_bvalid_w8    ;
    wire    [127:0]     m_axi_wdata_w8     ; 
    wire                m_axi_wlast_w8     ;
    wire                m_axi_wready_w8    ;
    wire    [15:0]      m_axi_wstrb_w8     ; 
    wire                m_axi_wvalid_w8    ;

    wire    [31:0]      m_axi_awaddr_w1    ;
    wire    [1:0]       m_axi_awburst_w1   ;
    wire    [3:0]       m_axi_awcache_w1   ;
    wire    [7:0]       m_axi_awlen_w1     ;
    wire    [2:0]       m_axi_awprot_w1    ;
    wire                m_axi_awready_w1   ;
    wire    [2:0]       m_axi_awsize_w1    ;
    wire    [3:0]       m_axi_awuser_w1    ;
    wire                m_axi_awvalid_w1   ;
    wire                m_axi_bready_w1    ;
    wire    [1:0]       m_axi_bresp_w1     ;
    wire                m_axi_bvalid_w1    ;
    wire    [127:0]     m_axi_wdata_w1     ; 
    wire                m_axi_wlast_w1     ;
    wire                m_axi_wready_w1    ;
    wire    [15:0]      m_axi_wstrb_w1     ; 
    wire                m_axi_wvalid_w1    ;

    wire [13:0]mean_b_out;

    sample_background_v1 #(
        .FRAME_WIDTH                (640),
		.FRAME_HEIGHT          (512)
    ) sample_background
    	(
		// Users to add ports here
        .clk                (io_memoryClk),
		.aclk               (clk_10m),
        .aresetn            (systemClk_locked_delay),
		.error_flag         (1'b0),
        .finish_b           (finish_b),
        .go_b               (go_b),
        .mean_b_out          (mean_b_out),
        .same_flag          (same_flag),
        // ---------------------------  axi-stream-slave  ---------- start ------------
        .s_axis_tdata       (m_axis_tdata_same_judge  ),
        .s_axis_tlast       (m_axis_tlast_same_judge  ),
        .s_axis_tvalid      (m_axis_tvalid_same_judge ),
        .s_axis_tuser       (m_axis_tuser_same_judge),
        .s_axis_tready      (m_axis_tready_same_judge  ),
        // ---------------------------  axi-stream-slave  ---------- end ------------
        
        // ---------------------------  axi-stream-master  ---------- start ------------
        .m_axis_tdata       (m_axis_tdata_reader_sample_background  ),
        .m_axis_tlast       (m_axis_tlast_reader_sample_background  ),
        .m_axis_tvalid      (m_axis_tvalid_reader_sample_background ),
        .m_axis_tready      (m_axis_tready_reader_sample_background ),
        .m_axis_tuser       (m_axis_tuser_reader_sample_background  ),
        // ---------------------------  axi-stream-master  ---------- end ------------
		        
		// ---------------------------  axi-stream-master_b  ---------- start ------------
        
        .m_axi_araddr_b     (m_axi_araddr_r8 ),
		.m_axi_arburst_b    (m_axi_arburst_r8),
		.m_axi_arcache_b    (m_axi_arcache_r8),
		.m_axi_arlen_b      (m_axi_arlen_r8  ),
		.m_axi_arprot_b     (m_axi_arprot_r8 ),
		.m_axi_arready_b    (m_axi_arready_r8),
		.m_axi_arsize_b     (m_axi_arsize_r8 ),
		.m_axi_aruser_b     (m_axi_aruser_r8 ),
		.m_axi_arvalid_b    (m_axi_arvalid_r8),
		.m_axi_rdata_b      (m_axi_rdata_r8  ),
		.m_axi_rlast_b      (m_axi_rlast_r8  ),
		.m_axi_rready_b     (m_axi_rready_r8 ),
		.m_axi_rresp_b      (m_axi_rresp_r8  ),
		.m_axi_rvalid_b     (m_axi_rvalid_r8 ),
    
        // ---------------------------  axi-stream-master_b  ---------- end ------------

		// ---------------------------  axi-stream-master_w8  ---------- start ------------
        
        .m_axi_awaddr       (m_axi_awaddr_w8    ),
		.m_axi_awburst      (m_axi_awburst_w8   ),
		.m_axi_awcache      (m_axi_awcache_w8   ),
		.m_axi_awlen        (m_axi_awlen_w8     ),
		.m_axi_awprot       (m_axi_awprot_w8    ),
		.m_axi_awready      (m_axi_awready_w8   ),
		.m_axi_awsize       (m_axi_awsize_w8    ),
		.m_axi_awuser       (m_axi_awuser_w8    ),
		.m_axi_awvalid      (m_axi_awvalid_w8   ),
		.m_axi_bready       (m_axi_bready_w8    ),
        .m_axi_bresp        (m_axi_bresp_w8     ),
        .m_axi_bvalid       (m_axi_bvalid_w8    ),
		.m_axi_wdata        (m_axi_wdata_w8     ),
		.m_axi_wlast        (m_axi_wlast_w8     ),
		.m_axi_wready       (m_axi_wready_w8    ),
		.m_axi_wstrb        (m_axi_wstrb_w8     ),
		.m_axi_wvalid       (m_axi_wvalid_w8    ),
    
        // ---------------------------  axi-stream-master_w8  ---------- end ------------

		// ---------------------------  axi-stream-master_w1  ---------- start ------------
        
        .m_axi_awaddr_1     (m_axi_awaddr_w1    ),
		.m_axi_awburst_1    (m_axi_awburst_w1   ),
		.m_axi_awcache_1    (m_axi_awcache_w1   ),
		.m_axi_awlen_1      (m_axi_awlen_w1     ),
		.m_axi_awprot_1     (m_axi_awprot_w1    ),
		.m_axi_awready_1    (m_axi_awready_w1   ),
		.m_axi_awsize_1     (m_axi_awsize_w1    ),
		.m_axi_awuser_1     (m_axi_awuser_w1    ),
		.m_axi_awvalid_1    (m_axi_awvalid_w1   ),
		.m_axi_bready_1     (m_axi_bready_w1    ),
        .m_axi_bresp_1      (m_axi_bresp_w1     ),
        .m_axi_bvalid_1     (m_axi_bvalid_w1    ),
		.m_axi_wdata_1      (m_axi_wdata_w1     ),
		.m_axi_wlast_1      (m_axi_wlast_w1     ),
		.m_axi_wready_1     (m_axi_wready_w1    ),
		.m_axi_wstrb_1      (m_axi_wstrb_w1     ),
		.m_axi_wvalid_1     (m_axi_wvalid_w1    ),
    
        // ---------------------------  axi-stream-master_w1  ---------- end ------------
	
		// Ports of Axi Slave Bus Interface S00_AXI
		.s00_axi_aclk       (io_systemClk),
		.s00_axi_aresetn    (systemClk_locked_delay),
		.s00_axi_awaddr     (s00_axi_awaddr ),
		.s00_axi_awprot     (s00_axi_awprot ),
		.s00_axi_awvalid    (s00_axi_awvalid),
		.s00_axi_awready    (s00_axi_awready),
		.s00_axi_wdata      (s00_axi_wdata  ),
		.s00_axi_wstrb      (s00_axi_wstrb  ),
		.s00_axi_wvalid     (s00_axi_wvalid ),
		.s00_axi_wready     (s00_axi_wready ),
		.s00_axi_bresp      (s00_axi_bresp  ),
		.s00_axi_bvalid     (s00_axi_bvalid ),
		.s00_axi_bready     (s00_axi_bready ),
		.s00_axi_araddr     (s00_axi_araddr ),
		.s00_axi_arprot     (s00_axi_arprot ),
		.s00_axi_arvalid    (s00_axi_arvalid),
		.s00_axi_arready    (s00_axi_arready),
		.s00_axi_rdata      (s00_axi_rdata  ),
		.s00_axi_rresp      (s00_axi_rresp  ),
		.s00_axi_rvalid     (s00_axi_rvalid ),
		.s00_axi_rready     (s00_axi_rready )
	);


//-----------------------------------------------------------------------------------sample_background end------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------NUC begin------------------------------------------------------------------------------------------------------------------------

    // ?????axi
    wire [    31 : 0]               s01_axi_awaddr;
    wire [                   2 : 0] s01_axi_awprot;
    wire                            s01_axi_awvalid;
    wire                            s01_axi_awready;
    wire [    31 : 0]               s01_axi_wdata;
    wire [3 : 0]                    s01_axi_wstrb;
    wire                            s01_axi_wvalid;
    wire                            s01_axi_wready;
    wire [                   1 : 0] s01_axi_bresp;
    wire                            s01_axi_bvalid;
    wire                            s01_axi_bready;
    wire [    31 : 0]               s01_axi_araddr;
    wire [                   2 : 0] s01_axi_arprot;
    wire                            s01_axi_arvalid;
    wire                            s01_axi_arready;
    wire [    31 : 0]               s01_axi_rdata;
    wire [                   1 : 0] s01_axi_rresp;
    wire                            s01_axi_rvalid;
    wire                            s01_axi_rready;

    wire    [13:0]      m_axis_tdata_nuc;
    wire                m_axis_tlast_nuc; 
    wire                m_axis_tvalid_nuc;
    wire                m_axis_tready_nuc;
    wire                m_axis_tuser_nuc; 

    wire    [31:0]      m_axi_araddr_nuc_b ;
    wire    [1:0]       m_axi_arburst_nuc_b;
    wire    [3:0]       m_axi_arcache_nuc_b;
    wire    [7:0]       m_axi_arlen_nuc_b  ;
    wire    [2:0]       m_axi_arprot_nuc_b ;
    wire                m_axi_arready_nuc_b;
    wire    [2:0]       m_axi_arsize_nuc_b ;
    wire    [3:0]       m_axi_aruser_nuc_b ;
    wire                m_axi_arvalid_nuc_b;
    wire    [127:0]     m_axi_rdata_nuc_b  ;
    wire                m_axi_rlast_nuc_b  ;
    wire                m_axi_rready_nuc_b ;
    wire    [1:0]       m_axi_rresp_nuc_b  ;
    wire                m_axi_rvalid_nuc_b ;

    wire    [31:0]      m_axi_araddr_nuc_k ;
    wire    [1:0]       m_axi_arburst_nuc_k;
    wire    [3:0]       m_axi_arcache_nuc_k;
    wire    [7:0]       m_axi_arlen_nuc_k  ;
    wire    [2:0]       m_axi_arprot_nuc_k ;
    wire                m_axi_arready_nuc_k;
    wire    [2:0]       m_axi_arsize_nuc_k ;
    wire    [3:0]       m_axi_aruser_nuc_k ;
    wire                m_axi_arvalid_nuc_k;
    wire    [127:0]     m_axi_rdata_nuc_k  ;
    wire                m_axi_rlast_nuc_k  ;
    wire                m_axi_rready_nuc_k ;
    wire    [1:0]       m_axi_rresp_nuc_k  ;
    wire                m_axi_rvalid_nuc_k ;
    
    wire    [31:0]      m_axi_araddr_mask_k ;
    wire    [1:0]       m_axi_arburst_mask_k;
    wire    [3:0]       m_axi_arcache_mask_k;
    wire    [7:0]       m_axi_arlen_mask_k  ;
    wire    [2:0]       m_axi_arprot_mask_k ;
    wire                m_axi_arready_mask_k;
    wire    [2:0]       m_axi_arsize_mask_k ;
    wire    [3:0]       m_axi_aruser_mask_k ;
    wire                m_axi_arvalid_mask_k;
    wire    [127:0]     m_axi_rdata_mask_k  ;
    wire                m_axi_rlast_mask_k  ;
    wire                m_axi_rready_mask_k ;
    wire    [1:0]       m_axi_rresp_mask_k  ;
    wire                m_axi_rvalid_mask_k ;


    wire    [31:0]      m_axi_araddr_mask_b ;
    wire    [1:0]       m_axi_arburst_mask_b;
    wire    [3:0]       m_axi_arcache_mask_b;
    wire    [7:0]       m_axi_arlen_mask_b  ;
    wire    [2:0]       m_axi_arprot_mask_b ;
    wire                m_axi_arready_mask_b;
    wire    [2:0]       m_axi_arsize_mask_b ;
    wire    [3:0]       m_axi_aruser_mask_b ;
    wire                m_axi_arvalid_mask_b;
    wire    [127:0]     m_axi_rdata_mask_b  ;
    wire                m_axi_rlast_mask_b  ;
    wire                m_axi_rready_mask_b ;
    wire    [1:0]       m_axi_rresp_mask_b  ;
    wire                m_axi_rvalid_mask_b ;

NUC_v2 #(
        .FRAME_WIDTH                (640),
		.FRAME_HEIGHT          (512)
    ) nuc(
    // Users to add ports here
		.aclk               (clk_10m),
        .aresetn            (systemClk_locked_delay),
        .clk_axi            (io_memoryClk),
        .go_nuc             (go_nuc),
        .mean_b_out          (mean_b_out),
        .Tempera            (Tempera),
        .shutter_en         (shutter_en),
        // ---------------------------  axi-stream-slave  ---------- start ------------
        .s_axis_tdata       (m_axis_tdata_reader_sample_background  ),
        .s_axis_tlast       (m_axis_tlast_reader_sample_background  ),
        .s_axis_tvalid      (m_axis_tvalid_reader_sample_background ),
        .s_axis_tready      (m_axis_tready_reader_sample_background  ),
        .s_axis_tuser       (m_axis_tuser_reader_sample_background),
        // ---------------------------  axi-stream-slave  ---------- end ------------
        
        // ---------------------------  axi-stream-master  ---------- start ------------
        .m_axis_tdata       (m_axis_tdata_nuc  ),
        .m_axis_tlast       (m_axis_tlast_nuc  ),
        .m_axis_tvalid      (m_axis_tvalid_nuc ),
        .m_axis_tready      (m_axis_tready_nuc ),
        .m_axis_tuser       (m_axis_tuser_nuc  ),
        // ---------------------------  axi-stream-master  ---------- end ------------
		        
		// ---------------------------  axi-stream-master_b  ---------- start ------------
        
        .m_axi_araddr_b     (m_axi_araddr_nuc_b ),
		.m_axi_arburst_b    (m_axi_arburst_nuc_b),
		.m_axi_arcache_b    (m_axi_arcache_nuc_b),
		.m_axi_arlen_b      (m_axi_arlen_nuc_b  ),
		.m_axi_arprot_b     (m_axi_arprot_nuc_b ),
		.m_axi_arready_b    (m_axi_arready_nuc_b),
		.m_axi_arsize_b     (m_axi_arsize_nuc_b ),
		.m_axi_aruser_b     (m_axi_aruser_nuc_b ),
		.m_axi_arvalid_b    (m_axi_arvalid_nuc_b),
		.m_axi_rdata_b      (m_axi_rdata_nuc_b  ),
		.m_axi_rlast_b      (m_axi_rlast_nuc_b  ),
		.m_axi_rready_b     (m_axi_rready_nuc_b ),
		.m_axi_rresp_b      (m_axi_rresp_nuc_b  ),
		.m_axi_rvalid_b     (m_axi_rvalid_nuc_b ),
    
        // ---------------------------  axi-stream-master_b  ---------- end ------------

		// ---------------------------  axi-stream-master_k  ---------- start ------------
        
        .m_axi_araddr_k     (m_axi_araddr_nuc_k ),
		.m_axi_arburst_k    (m_axi_arburst_nuc_k),
		.m_axi_arcache_k    (m_axi_arcache_nuc_k),
		.m_axi_arlen_k      (m_axi_arlen_nuc_k  ),
		.m_axi_arprot_k     (m_axi_arprot_nuc_k ),
		.m_axi_arready_k    (m_axi_arready_nuc_k),
		.m_axi_arsize_k     (m_axi_arsize_nuc_k ),
		.m_axi_aruser_k     (m_axi_aruser_nuc_k ),
		.m_axi_arvalid_k    (m_axi_arvalid_nuc_k),
		.m_axi_rdata_k      (m_axi_rdata_nuc_k  ),
		.m_axi_rlast_k      (m_axi_rlast_nuc_k  ),
		.m_axi_rready_k     (m_axi_rready_nuc_k ),
		.m_axi_rresp_k      (m_axi_rresp_nuc_k  ),
		.m_axi_rvalid_k     (m_axi_rvalid_nuc_k ),
    
        // ---------------------------  axi-stream-master_k  ---------- end ------------

		// ---------------------------  axi-stream-master_k  ---------- start ------------
        
        .m_axi_araddr_mask_k     (m_axi_araddr_mask_k ),
		.m_axi_arburst_mask_k    (m_axi_arburst_mask_k),
		.m_axi_arcache_mask_k    (m_axi_arcache_mask_k),
		.m_axi_arlen_mask_k      (m_axi_arlen_mask_k  ),
		.m_axi_arprot_mask_k     (m_axi_arprot_mask_k ),
		.m_axi_arready_mask_k    (m_axi_arready_mask_k),
		.m_axi_arsize_mask_k     (m_axi_arsize_mask_k ),
		.m_axi_aruser_mask_k     (m_axi_aruser_mask_k ),
		.m_axi_arvalid_mask_k    (m_axi_arvalid_mask_k),
		.m_axi_rdata_mask_k      (m_axi_rdata_mask_k  ),
		.m_axi_rlast_mask_k      (m_axi_rlast_mask_k  ),
		.m_axi_rready_mask_k     (m_axi_rready_mask_k ),
		.m_axi_rresp_mask_k      (m_axi_rresp_mask_k  ),
		.m_axi_rvalid_mask_k     (m_axi_rvalid_mask_k ),

        .m_axi_araddr_mask_b     (m_axi_araddr_mask_b ),
		.m_axi_arburst_mask_b    (m_axi_arburst_mask_b),
		.m_axi_arcache_mask_b    (m_axi_arcache_mask_b),
		.m_axi_arlen_mask_b      (m_axi_arlen_mask_b  ),
		.m_axi_arprot_mask_b     (m_axi_arprot_mask_b ),
		.m_axi_arready_mask_b    (m_axi_arready_mask_b),
		.m_axi_arsize_mask_b     (m_axi_arsize_mask_b ),
		.m_axi_aruser_mask_b     (m_axi_aruser_mask_b ),
		.m_axi_arvalid_mask_b    (m_axi_arvalid_mask_b),
		.m_axi_rdata_mask_b      (m_axi_rdata_mask_b  ),
		.m_axi_rlast_mask_b      (m_axi_rlast_mask_b  ),
		.m_axi_rready_mask_b     (m_axi_rready_mask_b ),
		.m_axi_rresp_mask_b      (m_axi_rresp_mask_b  ),
		.m_axi_rvalid_mask_b     (m_axi_rvalid_mask_b ),
    
        // ---------------------------  axi-stream-master_k  ---------- end ------------

        // Ports of Axi Slave Bus Interface S00_AXI
		.s00_axi_aclk       (io_systemClk),
		.s00_axi_aresetn    (systemClk_locked_delay),
		.s00_axi_awaddr     (s01_axi_awaddr ),
		.s00_axi_awprot     (s01_axi_awprot ),
		.s00_axi_awvalid    (s01_axi_awvalid),
		.s00_axi_awready    (s01_axi_awready),
		.s00_axi_wdata      (s01_axi_wdata  ),
		.s00_axi_wstrb      (s01_axi_wstrb  ),
		.s00_axi_wvalid     (s01_axi_wvalid ),
		.s00_axi_wready     (s01_axi_wready ),
		.s00_axi_bresp      (s01_axi_bresp  ),
		.s00_axi_bvalid     (s01_axi_bvalid ),
		.s00_axi_bready     (s01_axi_bready ),
		.s00_axi_araddr     (s01_axi_araddr ),
		.s00_axi_arprot     (s01_axi_arprot ),
		.s00_axi_arvalid    (s01_axi_arvalid),
		.s00_axi_arready    (s01_axi_arready),
		.s00_axi_rdata      (s01_axi_rdata  ),
		.s00_axi_rresp      (s01_axi_rresp  ),
		.s00_axi_rvalid     (s01_axi_rvalid ),
		.s00_axi_rready     (s01_axi_rready )
);


//-----------------------------------------------------------------------------------NUC end------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------dpc separated begin------------------------------------------------------------------------------------------------------------------------

  // DPC检测器AXI接口信号
  wire [  31:0] s07_detector_axi_awaddr;
  wire [   2:0] s07_detector_axi_awprot;
  wire          s07_detector_axi_awvalid;
  wire          s07_detector_axi_awready;
  wire [  31:0] s07_detector_axi_wdata;
  wire [   3:0] s07_detector_axi_wstrb;
  wire          s07_detector_axi_wvalid;
  wire          s07_detector_axi_wready;
  wire [   1:0] s07_detector_axi_bresp;
  wire          s07_detector_axi_bvalid;
  wire          s07_detector_axi_bready;
  wire [  31:0] s07_detector_axi_araddr;
  wire [   2:0] s07_detector_axi_arprot;
  wire          s07_detector_axi_arvalid;
  wire          s07_detector_axi_arready;
  wire [  31:0] s07_detector_axi_rdata;
  wire [   1:0] s07_detector_axi_rresp;
  wire          s07_detector_axi_rvalid;
  wire          s07_detector_axi_rready;

  // DPC校正器AXI接口信号  
  wire [  31:0] s08_corrector_axi_awaddr;
  wire [   2:0] s08_corrector_axi_awprot;
  wire          s08_corrector_axi_awvalid;
  wire          s08_corrector_axi_awready;
  wire [  31:0] s08_corrector_axi_wdata;
  wire [   3:0] s08_corrector_axi_wstrb;
  wire          s08_corrector_axi_wvalid;
  wire          s08_corrector_axi_wready;
  wire [   1:0] s08_corrector_axi_bresp;
  wire          s08_corrector_axi_bvalid;
  wire          s08_corrector_axi_bready;
  wire [  31:0] s08_corrector_axi_araddr;
  wire [   2:0] s08_corrector_axi_arprot;
  wire          s08_corrector_axi_arvalid;
  wire          s08_corrector_axi_arready;
  wire [  31:0] s08_corrector_axi_rdata;
  wire [   1:0] s08_corrector_axi_rresp;
  wire          s08_corrector_axi_rvalid;
  wire          s08_corrector_axi_rready;

  // DPC输出数据流信号
  wire [  13:0] m_axis_tdata_dpc;
  wire          m_axis_tlast_dpc;
  wire          m_axis_tready_dpc;
  wire          m_axis_tuser_dpc;
  wire          m_axis_tvalid_dpc;

  // DPC分离架构顶层模块
  // 将检测器信号映射到s07_axi
  assign s07_axi_awaddr  = s07_detector_axi_awaddr;
  assign s07_axi_awprot  = s07_detector_axi_awprot;
  assign s07_axi_awvalid = s07_detector_axi_awvalid;
  assign s07_detector_axi_awready = s07_axi_awready;
  assign s07_axi_wdata   = s07_detector_axi_wdata;
  assign s07_axi_wstrb   = s07_detector_axi_wstrb;
  assign s07_axi_wvalid  = s07_detector_axi_wvalid;
  assign s07_detector_axi_wready = s07_axi_wready;
  assign s07_detector_axi_bresp = s07_axi_bresp;
  assign s07_detector_axi_bvalid = s07_axi_bvalid;
  assign s07_axi_bready  = s07_detector_axi_bready;
  assign s07_axi_araddr  = s07_detector_axi_araddr;
  assign s07_axi_arprot  = s07_detector_axi_arprot;
  assign s07_axi_arvalid = s07_detector_axi_arvalid;
  assign s07_detector_axi_arready = s07_axi_arready;
  assign s07_detector_axi_rdata = s07_axi_rdata;
  assign s07_detector_axi_rresp = s07_axi_rresp;
  assign s07_detector_axi_rvalid = s07_axi_rvalid;
  assign s07_axi_rready  = s07_detector_axi_rready;

  // 将校正器信号映射到s06_axi (避免与usm冲突)
  assign s06_axi_awaddr  = s06_corrector_axi_awaddr;
  assign s06_axi_awprot  = s06_corrector_axi_awprot;
  assign s06_axi_awvalid = s06_corrector_axi_awvalid;
  assign s06_corrector_axi_awready = s06_axi_awready;
  assign s06_axi_wdata   = s06_corrector_axi_wdata;
  assign s06_axi_wstrb   = s06_corrector_axi_wstrb;
  assign s06_axi_wvalid  = s06_corrector_axi_wvalid;
  assign s06_corrector_axi_wready = s06_axi_wready;
  assign s06_corrector_axi_bresp = s06_axi_bresp;
  assign s06_corrector_axi_bvalid = s06_axi_bvalid;
  assign s06_axi_bready  = s06_corrector_axi_bready;
  assign s06_axi_araddr  = s06_corrector_axi_araddr;
  assign s06_axi_arprot  = s06_corrector_axi_arprot;
  assign s06_axi_arvalid = s06_corrector_axi_arvalid;
  assign s06_corrector_axi_arready = s06_axi_arready;
  assign s06_corrector_axi_rdata = s06_axi_rdata;
  assign s06_corrector_axi_rresp = s06_axi_rresp;
  assign s06_corrector_axi_rvalid = s06_axi_rvalid;
  assign s06_axi_rready  = s06_corrector_axi_rready;

  // DPC分离架构实例
  DpcTop_Separated #(
    .FRAME_WIDTH     (640),
    .FRAME_HEIGHT    (512),
    .PIXEL_WIDTH     (14),
    .AXI_DATA_WIDTH  (32),
    .AXI_ADDR_WIDTH  (32),
    .K_THRESHOLD_DEFAULT(100),
    .MAX_MANUAL_BP   (128),
    .MAX_ALL_BP      (512)
  ) DpcTop_Separated_inst (
    // 时钟和复位
    .axis_aclk   (clk_10m),
    .axis_aresetn(systemClk_locked_delay),
    .axi_aclk    (io_systemClk),
    .axi_aresetn (systemClk_locked_delay),

    // 输入图像数据流 (来自NUC)
    .s_axis_tdata (m_axis_tdata_nuc),
    .s_axis_tvalid(m_axis_tvalid_nuc),
    .s_axis_tready(m_axis_tready_nuc),
    .s_axis_tlast (m_axis_tlast_nuc),
    .s_axis_tuser (m_axis_tuser_nuc),

    // 输出图像数据流 (到CFPN)
    .m_axis_tdata (m_axis_tdata_dpc),
    .m_axis_tvalid(m_axis_tvalid_dpc),
    .m_axis_tready(m_axis_tready_dpc),
    .m_axis_tlast (m_axis_tlast_dpc),
    .m_axis_tuser (m_axis_tuser_dpc),

    // 检测器AXI4-Lite配置接口
    .s_detector_axi_awaddr (s07_detector_axi_awaddr),
    .s_detector_axi_awprot (s07_detector_axi_awprot),
    .s_detector_axi_awvalid(s07_detector_axi_awvalid),
    .s_detector_axi_awready(s07_detector_axi_awready),
    .s_detector_axi_wdata  (s07_detector_axi_wdata),
    .s_detector_axi_wstrb  (s07_detector_axi_wstrb),
    .s_detector_axi_wvalid (s07_detector_axi_wvalid),
    .s_detector_axi_wready (s07_detector_axi_wready),
    .s_detector_axi_bresp  (s07_detector_axi_bresp),
    .s_detector_axi_bvalid (s07_detector_axi_bvalid),
    .s_detector_axi_bready (s07_detector_axi_bready),
    .s_detector_axi_araddr (s07_detector_axi_araddr),
    .s_detector_axi_arprot (s07_detector_axi_arprot),
    .s_detector_axi_arvalid(s07_detector_axi_arvalid),
    .s_detector_axi_arready(s07_detector_axi_arready),
    .s_detector_axi_rdata  (s07_detector_axi_rdata),
    .s_detector_axi_rresp  (s07_detector_axi_rresp),
    .s_detector_axi_rvalid (s07_detector_axi_rvalid),
    .s_detector_axi_rready (s07_detector_axi_rready),

    // 校正器AXI4-Lite配置接口
    .s_corrector_axi_awaddr (s06_corrector_axi_awaddr),
    .s_corrector_axi_awprot (s06_corrector_axi_awprot),
    .s_corrector_axi_awvalid(s06_corrector_axi_awvalid),
    .s_corrector_axi_awready(s06_corrector_axi_awready),
    .s_corrector_axi_wdata  (s06_corrector_axi_wdata),
    .s_corrector_axi_wstrb  (s06_corrector_axi_wstrb),
    .s_corrector_axi_wvalid (s06_corrector_axi_wvalid),
    .s_corrector_axi_wready (s06_corrector_axi_wready),
    .s_corrector_axi_bresp  (s06_corrector_axi_bresp),
    .s_corrector_axi_bvalid (s06_corrector_axi_bvalid),
    .s_corrector_axi_bready (s06_corrector_axi_bready),
    .s_corrector_axi_araddr (s06_corrector_axi_araddr),
    .s_corrector_axi_arprot (s06_corrector_axi_arprot),
    .s_corrector_axi_arvalid(s06_corrector_axi_arvalid),
    .s_corrector_axi_arready(s06_corrector_axi_arready),
    .s_corrector_axi_rdata  (s06_corrector_axi_rdata),
    .s_corrector_axi_rresp  (s06_corrector_axi_rresp),
    .s_corrector_axi_rvalid (s06_corrector_axi_rvalid),
    .s_corrector_axi_rready (s06_corrector_axi_rready),

    // 自动坏点检测接口 (连接到RISC-V GPIO)
    .auto_bp_valid (/* 连接到GPIO */),
    .auto_bp_data  (/* 连接到GPIO */),
    .auto_bp_ready (/* 连接到GPIO */),
    .frame_done    (/* 连接到GPIO */),

    // 调试接口
    .debug_manual_bp_count(),
    .debug_auto_bp_count  (),
    .debug_detector_busy  (),
    .debug_corrector_busy ()
  );

//-----------------------------------------------------------------------------------dpc separated end------------------------------------------------------------------------------------------------------------------------


// ---------------------------- cfpn begin -----------------------


  wire [  31:0] s11_axi_awaddr;
  wire [   2:0] s11_axi_awprot;
  wire          s11_axi_awvalid;
  wire          s11_axi_awready;
  wire [  31:0] s11_axi_wdata;
  wire [   3:0] s11_axi_wstrb;
  wire          s11_axi_wvalid;
  wire          s11_axi_wready;
  wire [   1:0] s11_axi_bresp;
  wire          s11_axi_bvalid;
  wire          s11_axi_bready;
  wire [  31:0] s11_axi_araddr;
  wire [   2:0] s11_axi_arprot;
  wire          s11_axi_arvalid;
  wire          s11_axi_arready;
  wire [  31:0] s11_axi_rdata;
  wire [   1:0] s11_axi_rresp;
  wire          s11_axi_rvalid;
  wire          s11_axi_rready;

  wire [  13:0] m_axis_tdata_cfpn;
  wire          m_axis_tlast_cfpn;
  wire          m_axis_tready_cfpn;
  wire          m_axis_tuser_cfpn;
  wire          m_axis_tvalid_cfpn;

  CfpnTop #(
    .ROW             (512),
    .COL             (640),
    .AXIS_TDATA_WIDTH(14),
    .AXI_DATA_WIDTH  (32),
    .AXI_ADDR_WIDTH  (32),
    .CNT_WIDTH       (11)
  ) CfpnTop_inst (
    .axis_aclk    (clk_10m),
    .axis_aresetn (systemClk_locked_delay),

    .m_axis_tready(m_axis_tready_cfpn),
    .m_axis_tvalid(m_axis_tvalid_cfpn),
    .m_axis_tdata (m_axis_tdata_cfpn),
    .m_axis_tuser (m_axis_tuser_cfpn),
    .m_axis_tlast (m_axis_tlast_cfpn),

    .s_axis_tready(m_axis_tready_dpc),
    .s_axis_tvalid(m_axis_tvalid_dpc),
    .s_axis_tdata (m_axis_tdata_dpc),
    .s_axis_tuser (m_axis_tuser_dpc),
    .s_axis_tlast (m_axis_tlast_dpc),

    .s00_axi_aclk   (io_systemClk),
    .s00_axi_aresetn(systemClk_locked_delay),
    .s00_axi_awaddr (s11_axi_awaddr),
    .s00_axi_awprot (s11_axi_awprot),
    .s00_axi_awvalid(s11_axi_awvalid),
    .s00_axi_awready(s11_axi_awready),
    .s00_axi_wdata  (s11_axi_wdata),
    .s00_axi_wstrb  (s11_axi_wstrb),
    .s00_axi_wvalid (s11_axi_wvalid),
    .s00_axi_wready (s11_axi_wready),
    .s00_axi_bresp  (s11_axi_bresp),
    .s00_axi_bvalid (s11_axi_bvalid),
    .s00_axi_bready (s11_axi_bready),
    .s00_axi_araddr (s11_axi_araddr),
    .s00_axi_arprot (s11_axi_arprot),
    .s00_axi_arvalid(s11_axi_arvalid),
    .s00_axi_arready(s11_axi_arready),
    .s00_axi_rdata  (s11_axi_rdata),
    .s00_axi_rresp  (s11_axi_rresp),
    .s00_axi_rvalid (s11_axi_rvalid),
    .s00_axi_rready (s11_axi_rready)
  );


// ---------------------------- cfpn end -----------------------

// insert a skid buffer
  wire [  13:0] m_axis_tdata_sk1;
  wire          m_axis_tlast_sk1;
  wire          m_axis_tready_sk1;
  wire          m_axis_tuser_sk1;
  wire          m_axis_tvalid_sk1;

   skidbuffer #(
		.DW      (14+1+1)
   ) skidbuffer1 (
        .i_clk   (clk_10m),
        .i_reset (~systemClk_locked_delay),
        .i_valid (m_axis_tvalid_cfpn),
        .o_ready (m_axis_tready_cfpn),
        .i_data  ({m_axis_tdata_cfpn,m_axis_tuser_cfpn,m_axis_tlast_cfpn}),
        .o_valid (m_axis_tvalid_sk1),
        .i_ready (m_axis_tready_sk1),
        .o_data  ({m_axis_tdata_sk1,m_axis_tuser_sk1,m_axis_tlast_sk1})
	);
// end

//-----------------------------------------------------------------------------------tfliter begin------------------------------------------------------------------------------------------------------------------------
  wire [  13:0] m_axis_tdata_tfilter;
  wire          m_axis_tlast_tfilter;
  wire          m_axis_tready_tfilter;
  wire          m_axis_tuser_tfilter;
  wire          m_axis_tvalid_tfilter;

  wire [  31:0] s15_axi_awaddr;
  wire [   2:0] s15_axi_awprot;
  wire          s15_axi_awvalid;
  wire          s15_axi_awready;
  wire [  31:0] s15_axi_wdata;
  wire [   3:0] s15_axi_wstrb;
  wire          s15_axi_wvalid;
  wire          s15_axi_wready;
  wire [   1:0] s15_axi_bresp;
  wire          s15_axi_bvalid;
  wire          s15_axi_bready;
  wire [  31:0] s15_axi_araddr;
  wire [   2:0] s15_axi_arprot;
  wire          s15_axi_arvalid;
  wire          s15_axi_arready;
  wire [  31:0] s15_axi_rdata;
  wire [   1:0] s15_axi_rresp;
  wire          s15_axi_rvalid;
  wire          s15_axi_rready;

tfilter_v1_0 # (
	
		.BPS               (14),
        .FRAME_WIDTH       (640),
        .FRAME_HEIGHT      (512),
        .BASEADDR          ('h13000000),
        .DATAWIDTH_MM      (128),
        .ADDRESSWIDTH      (32),
        .MAXBURSTCOUNT     (8),
        .FIFODEPTH_BYTE    (2048),

		.C_S00_AXI_DATA_WIDTH	(32),
		.C_S00_AXI_ADDR_WIDTH	(11)
	)
	tfilter_init(
		.axi_clk    (io_memoryClk),
        .axis_aclk   (clk_10m),
        .axis_aresetn(systemClk_locked_delay),

        .go_rw                              (go),
        
		.m_axi_araddr                       (m_axi_araddr_tfilter   ),
		.m_axi_arburst                      (m_axi_arburst_tfilter  ),
		.m_axi_arcache                      (m_axi_arcache_tfilter  ),
		.m_axi_arlen                        (m_axi_arlen_tfilter    ),
		.m_axi_arprot                       (m_axi_arprot_tfilter   ),
		.m_axi_arready                      (m_axi_arready_tfilter  ),
		.m_axi_arsize                       (m_axi_arsize_tfilter   ),
		.m_axi_aruser                       (m_axi_aruser_tfilter   ),
		.m_axi_arvalid                      (m_axi_arvalid_tfilter  ),
		.m_axi_rdata                        (m_axi_rdata_tfilter    ),
		.m_axi_rlast                        (m_axi_rlast_tfilter    ),
		.m_axi_rready                       (m_axi_rready_tfilter   ),
		.m_axi_rresp                        (m_axi_rresp_tfilter    ),
		.m_axi_rvalid                       (m_axi_rvalid_tfilter   ),

        .m_axi_awaddr           (m_axi_awaddr_tfilter  ),
        .m_axi_awburst          (m_axi_awburst_tfilter ),
        .m_axi_awcache          (m_axi_awcache_tfilter ),
        .m_axi_awlen            (m_axi_awlen_tfilter   ),
        .m_axi_awprot           (m_axi_awprot_tfilter  ),
        .m_axi_awready          (m_axi_awready_tfilter ),
        .m_axi_awsize           (m_axi_awsize_tfilter  ),
        .m_axi_awuser           (m_axi_awuser_tfilter  ),
        .m_axi_awvalid          (m_axi_awvalid_tfilter ),
        .m_axi_bready           (m_axi_bready_tfilter  ),
        .m_axi_bresp            (m_axi_bresp_tfilter   ),
        .m_axi_bvalid           (m_axi_bvalid_tfilter  ),
        .m_axi_wdata            (m_axi_wdata_tfilter   ),
        .m_axi_wlast            (m_axi_wlast_tfilter   ),
        .m_axi_wready           (m_axi_wready_tfilter  ),
        .m_axi_wstrb            (m_axi_wstrb_tfilter   ),
        .m_axi_wvalid           (m_axi_wvalid_tfilter  ),

        
        .m_axis_tready(m_axis_tready_tfilter),
        .m_axis_tvalid(m_axis_tvalid_tfilter),
        .m_axis_tdata (m_axis_tdata_tfilter),
        .m_axis_tuser (m_axis_tuser_tfilter),
        .m_axis_tlast (m_axis_tlast_tfilter),

        .s_axis_tready(m_axis_tready_sk1),
        .s_axis_tvalid(m_axis_tvalid_sk1),
        .s_axis_tdata (m_axis_tdata_sk1),
        .s_axis_tuser (m_axis_tuser_sk1),
        .s_axis_tlast (m_axis_tlast_sk1),

        .s00_axi_aclk   (io_systemClk),
        .s00_axi_aresetn(systemClk_locked_delay),
        .s00_axi_awaddr (s15_axi_awaddr),
        .s00_axi_awprot (s15_axi_awprot),
        .s00_axi_awvalid(s15_axi_awvalid),
        .s00_axi_awready(s15_axi_awready),
        .s00_axi_wdata  (s15_axi_wdata),
        .s00_axi_wstrb  (s15_axi_wstrb),
        .s00_axi_wvalid (s15_axi_wvalid),
        .s00_axi_wready (s15_axi_wready),
        .s00_axi_bresp  (s15_axi_bresp),
        .s00_axi_bvalid (s15_axi_bvalid),
        .s00_axi_bready (s15_axi_bready),
        .s00_axi_araddr (s15_axi_araddr),
        .s00_axi_arprot (s15_axi_arprot),
        .s00_axi_arvalid(s15_axi_arvalid),
        .s00_axi_arready(s15_axi_arready),
        .s00_axi_rdata  (s15_axi_rdata),
        .s00_axi_rresp  (s15_axi_rresp),
        .s00_axi_rvalid (s15_axi_rvalid),
        .s00_axi_rready (s15_axi_rready)
	);
 //-----------------------------------------------------------------------------------tfliter end------------------------------------------------------------------------------------------------------------------------
   

   // insert a skid buffer
  wire [  13:0] m_axis_tdata_sk0;
  wire          m_axis_tlast_sk0;
  wire          m_axis_tready_sk0;
  wire          m_axis_tuser_sk0;
  wire          m_axis_tvalid_sk0;

   skidbuffer #(
		.DW      (14+1+1)
   ) skidbuffer0 (
        .i_clk   (clk_10m),
        .i_reset (~systemClk_locked_delay),
        .i_valid (m_axis_tvalid_tfilter),
        .o_ready (m_axis_tready_tfilter),
        .i_data  ({m_axis_tdata_tfilter,m_axis_tuser_tfilter,m_axis_tlast_tfilter}),
        .o_valid (m_axis_tvalid_sk0),
        .i_ready (m_axis_tready_sk0),
        .o_data  ({m_axis_tdata_sk0,m_axis_tuser_sk0,m_axis_tlast_sk0})
	);
   // end


// ---------------------------- nlm begin -----------------------

    wire [31:0] s09_axi_awaddr;
    wire [ 2:0] s09_axi_awprot;
    wire        s09_axi_awvalid;
    wire        s09_axi_awready;
    wire [31:0] s09_axi_wdata;
    wire [ 3:0] s09_axi_wstrb;
    wire        s09_axi_wvalid;
    wire        s09_axi_wready;
    wire [ 1:0] s09_axi_bresp;
    wire        s09_axi_bvalid;
    wire        s09_axi_bready;
    wire [31:0] s09_axi_araddr;
    wire [ 2:0] s09_axi_arprot;
    wire        s09_axi_arvalid;
    wire        s09_axi_arready;
    wire [31:0] s09_axi_rdata;
    wire [ 1:0] s09_axi_rresp;
    wire        s09_axi_rvalid;
    wire        s09_axi_rready;

    wire [13:0] m_axis_tdata_nlm;
    wire        m_axis_tlast_nlm;
    wire        m_axis_tready_nlm;
    wire        m_axis_tuser_nlm;
    wire        m_axis_tvalid_nlm;


 NlmTop_nlm #(
    .COL                   (640),
    .ROW                   (512),
    .WINDOW_SIZE           (7),
    .SIMILARITY_WINDOW_SIZE(3),
    .AXIS_TDATA_WIDTH      (14),
    .AXI_DATA_WIDTH        (32),
    .AXI_ADDR_WIDTH        (32),
    .EXP_LUT_INDEX_NUM     (512),
    .EXP_LUT_INDEX_WIDTH   (10),
    .EXP_LUT_DATA_WIDTH    (16),
    .CNT_WIDTH             (11)
  ) NlmTop_nlm_inst (
    .axis_aclk      (clk_10m),
    .axis_aresetn   (systemClk_locked_delay),

    .m_axis_tready(m_axis_tready_nlm),
    .m_axis_tvalid(m_axis_tvalid_nlm),
    .m_axis_tdata (m_axis_tdata_nlm),
    .m_axis_tuser (m_axis_tuser_nlm),
    .m_axis_tlast (m_axis_tlast_nlm),

    .s_axis_tready(m_axis_tready_sk0),
    .s_axis_tvalid(m_axis_tvalid_sk0),
    .s_axis_tdata (m_axis_tdata_sk0),
    .s_axis_tuser (m_axis_tuser_sk0),
    .s_axis_tlast (m_axis_tlast_sk0),

    .s00_axi_aclk   (io_systemClk),
    .s00_axi_aresetn(systemClk_locked_delay),
    .s00_axi_awaddr (s09_axi_awaddr),
    .s00_axi_awprot (s09_axi_awprot),
    .s00_axi_awvalid(s09_axi_awvalid),
    .s00_axi_awready(s09_axi_awready),
    .s00_axi_wdata  (s09_axi_wdata),
    .s00_axi_wstrb  (s09_axi_wstrb),
    .s00_axi_wvalid (s09_axi_wvalid),
    .s00_axi_wready (s09_axi_wready),
    .s00_axi_bresp  (s09_axi_bresp),
    .s00_axi_bvalid (s09_axi_bvalid),
    .s00_axi_bready (s09_axi_bready),
    .s00_axi_araddr (s09_axi_araddr),
    .s00_axi_arprot (s09_axi_arprot),
    .s00_axi_arvalid(s09_axi_arvalid),
    .s00_axi_arready(s09_axi_arready),
    .s00_axi_rdata  (s09_axi_rdata),
    .s00_axi_rresp  (s09_axi_rresp),
    .s00_axi_rvalid (s09_axi_rvalid),
    .s00_axi_rready (s09_axi_rready)
  );

  // ---------------------------- nlm end -----------------------

  // ---------------------------- nlm end -----------------------

   // insert a skid buffer
  wire [  13:0] m_axis_tdata_sk2;
  wire          m_axis_tlast_sk2;
  wire          m_axis_tready_sk2;
  wire          m_axis_tuser_sk2;
  wire          m_axis_tvalid_sk2;

   skidbuffer #(
		.DW      (14+1+1)
   ) skidbuffer2 (
        .i_clk   (clk_10m),
        .i_reset (~systemClk_locked_delay),
        .i_valid (m_axis_tvalid_nlm),
        .o_ready (m_axis_tready_nlm),
        .i_data  ({m_axis_tdata_nlm,m_axis_tuser_nlm,m_axis_tlast_nlm}),
        .o_valid (m_axis_tvalid_sk2),
        .i_ready (m_axis_tready_sk2),
        .o_data  ({m_axis_tdata_sk2,m_axis_tuser_sk2,m_axis_tlast_sk2})
	);
   // end

    // reg [10:0] dde_in_hcnt;
    // reg [9:0] dde_in_vcnt;
    // wire [13:0] m_axis_tdata_sk2_test;

    // always @(posedge clk_10m or negedge systemClk_locked_delay) begin
    //     if (!systemClk_locked_delay) begin
    //         dde_in_hcnt <= 0;
    //         dde_in_vcnt <= 0;
    //     end else begin
    //         if (m_axis_tvalid_sk2 && m_axis_tready_sk2) begin
    //             if ((dde_in_hcnt == 639) && (dde_in_vcnt == 511)) begin
    //                 dde_in_hcnt <= 0;
    //                 dde_in_vcnt <= 0;
    //             end 
    //             else if (dde_in_hcnt == 639) begin
    //                 dde_in_hcnt <= 0;
    //                 dde_in_vcnt <= dde_in_vcnt + 1;
    //             end 
    //             else begin
    //                 dde_in_hcnt <= dde_in_hcnt + 1;
    //                 dde_in_vcnt <= dde_in_vcnt;
    //             end
    //         end
    //     end
    // end

    // assign m_axis_tdata_sk2_test = 'd7168 + dde_in_hcnt;
//-----------------------------------------------------------------------------------dde begin------------------------------------------------------------------------------------------------------------------------
 
    wire [31:0] s47_axi_awaddr;
    wire [ 2:0] s47_axi_awprot;
    wire        s47_axi_awvalid;
    wire        s47_axi_awready;
    wire [31:0] s47_axi_wdata;
    wire [ 3:0] s47_axi_wstrb;
    wire        s47_axi_wvalid;
    wire        s47_axi_wready;
    wire [ 1:0] s47_axi_bresp;
    wire        s47_axi_bvalid;
    wire        s47_axi_bready;
    wire [31:0] s47_axi_araddr;
    wire [ 2:0] s47_axi_arprot;
    wire        s47_axi_arvalid;
    wire        s47_axi_arready;
    wire [31:0] s47_axi_rdata;
    wire [ 1:0] s47_axi_rresp;
    wire        s47_axi_rvalid;
    wire        s47_axi_rready;

    wire    [7:0]       m_axis_tdata_8bits; 
    wire                m_axis_tlast_8bits; 
    wire                m_axis_tvalid_8bits;
    wire                m_axis_tready_8bits;
    wire                m_axis_tuser_8bits; 

    dde # (
        .FRAME_WIDTH            (640),
        .FRAME_HEIGHT           (512),
        .DATA_WIDTH_IN          (14), 
        .DATA_WIDTH_OUT         (8),
        .FRAME_WIDTH_BIT        (10),
        .FRAME_HEIGHT_BIT       (9) 
    )
    dde_inst
    (
        .clk          (clk_10m),
        .rst_n        (systemClk_locked_delay),


        // .s_axis_tdata      ( m_axis_tdata_sk2 ),
        .s_axis_tdata      ( m_axis_tdata_sk2 ),
        .s_axis_tlast      ( m_axis_tlast_sk2 ),
        .s_axis_tvalid     ( m_axis_tvalid_sk2 ),
        .s_axis_tuser      ( m_axis_tuser_sk2 ),
        .s_axis_tready     ( m_axis_tready_sk2 ),

        
        .m_axis_tdata      (m_axis_tdata_8bits ),
        .m_axis_tlast      (m_axis_tlast_8bits ),
        .m_axis_tvalid     (m_axis_tvalid_8bits),
        .m_axis_tready     (m_axis_tready_8bits),
        .m_axis_tuser      (m_axis_tuser_8bits ),
        
        .axi_aclk          (io_systemClk       ),
        .axi_aresetn       (systemClk_locked_delay    ),    
        .s00_axi_awaddr    (s47_axi_awaddr ),    
        .s00_axi_awprot    (s47_axi_awprot ),    
        .s00_axi_awvalid   (s47_axi_awvalid),    
        .s00_axi_awready   (s47_axi_awready),    
        .s00_axi_wdata     (s47_axi_wdata  ),    
        .s00_axi_wstrb     (s47_axi_wstrb  ),    
        .s00_axi_wvalid    (s47_axi_wvalid ),    
        .s00_axi_wready    (s47_axi_wready ),    
        .s00_axi_bresp     (s47_axi_bresp  ),    
        .s00_axi_bvalid    (s47_axi_bvalid ),    
        .s00_axi_bready    (s47_axi_bready ),    
        .s00_axi_araddr    (s47_axi_araddr ),    
        .s00_axi_arprot    (s47_axi_arprot ),    
        .s00_axi_arvalid   (s47_axi_arvalid),    
        .s00_axi_arready   (s47_axi_arready),    
        .s00_axi_rdata     (s47_axi_rdata  ),    
        .s00_axi_rresp     (s47_axi_rresp  ),    
        .s00_axi_rvalid    (s47_axi_rvalid ),    
        .s00_axi_rready    (s47_axi_rready )    

    );
//-----------------------------------------------------------------------------------dde end------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------dde's gamma begin------------------------------------------------------------------------------------------------------------------------


    wire [31:0] s63_axi_awaddr;
    wire [ 2:0] s63_axi_awprot;
    wire        s63_axi_awvalid;
    wire        s63_axi_awready;
    wire [31:0] s63_axi_wdata;
    wire [ 3:0] s63_axi_wstrb;
    wire        s63_axi_wvalid;
    wire        s63_axi_wready;
    wire [ 1:0] s63_axi_bresp;
    wire        s63_axi_bvalid;
    wire        s63_axi_bready;
    wire [31:0] s63_axi_araddr;
    wire [ 2:0] s63_axi_arprot;
    wire        s63_axi_arvalid;
    wire        s63_axi_arready;
    wire [31:0] s63_axi_rdata;
    wire [ 1:0] s63_axi_rresp;
    wire        s63_axi_rvalid;
    wire        s63_axi_rready;

    wire    [7:0]       m_axis_tdata_gamma; 
    wire                m_axis_tlast_gamma; 
    wire                m_axis_tvalid_gamma;
    wire                m_axis_tready_gamma;
    wire                m_axis_tuser_gamma; 

    LUT_v1_0 # (
        .FRAME_WIDTH            (640),
        .FRAME_HEIGHT           (512),
        .BPS         (8),
        .C_S00_AXI_DATA_WIDTH(32),
        .C_S00_AXI_ADDR_WIDTH(10)
    )
    LUT_inst
    (
        .axis_aclk          (clk_10m),
        .axis_aresetn        (systemClk_locked_delay),

        .s_axis_tdata      ( m_axis_tdata_8bits ),
        .s_axis_tlast      ( m_axis_tlast_8bits ),
        .s_axis_tvalid     ( m_axis_tvalid_8bits ),
        .s_axis_tuser      ( m_axis_tuser_8bits ),
        .s_axis_tready     ( m_axis_tready_8bits ),
        
        .m_axis_tdata      (m_axis_tdata_gamma ),
        .m_axis_tlast      (m_axis_tlast_gamma ),
        .m_axis_tvalid     (m_axis_tvalid_gamma),
        .m_axis_tready     (m_axis_tready_gamma),
        .m_axis_tuser      (m_axis_tuser_gamma ),
        
        .s00_axi_aclk      (io_systemClk       ),
        .s00_axi_aresetn   (systemClk_locked_delay    ),    
        .s00_axi_awaddr    (s63_axi_awaddr ),    
        .s00_axi_awprot    (s63_axi_awprot ),    
        .s00_axi_awvalid   (s63_axi_awvalid),    
        .s00_axi_awready   (s63_axi_awready),    
        .s00_axi_wdata     (s63_axi_wdata  ),    
        .s00_axi_wstrb     (s63_axi_wstrb  ),    
        .s00_axi_wvalid    (s63_axi_wvalid ),    
        .s00_axi_wready    (s63_axi_wready ),    
        .s00_axi_bresp     (s63_axi_bresp  ),    
        .s00_axi_bvalid    (s63_axi_bvalid ),    
        .s00_axi_bready    (s63_axi_bready ),    
        .s00_axi_araddr    (s63_axi_araddr ),    
        .s00_axi_arprot    (s63_axi_arprot ),    
        .s00_axi_arvalid   (s63_axi_arvalid),    
        .s00_axi_arready   (s63_axi_arready),    
        .s00_axi_rdata     (s63_axi_rdata  ),    
        .s00_axi_rresp     (s63_axi_rresp  ),    
        .s00_axi_rvalid    (s63_axi_rvalid ),    
        .s00_axi_rready    (s63_axi_rready )    

    );

//-----------------------------------------------------------------------------------dde's gamma end------------------------------------------------------------------------------------------------------------------------


//-----------------------------------------------------------------------------------CONTRAST STRETCH begin------------------------------------------------------------------------------------------------------------------------

    wire [    31 : 0]               s22_axi_awaddr;
    wire [                   2 : 0] s22_axi_awprot;
    wire                            s22_axi_awvalid;
    wire                            s22_axi_awready;
    wire [    31 : 0]               s22_axi_wdata;
    wire [3 : 0]                    s22_axi_wstrb;
    wire                            s22_axi_wvalid;
    wire                            s22_axi_wready;
    wire [                   1 : 0] s22_axi_bresp;
    wire                            s22_axi_bvalid;
    wire                            s22_axi_bready;
    wire [    31 : 0]               s22_axi_araddr;
    wire [                   2 : 0] s22_axi_arprot;
    wire                            s22_axi_arvalid;
    wire                            s22_axi_arready;
    wire [    31 : 0]               s22_axi_rdata;
    wire [                   1 : 0] s22_axi_rresp;
    wire                            s22_axi_rvalid;
    wire                            s22_axi_rready;
    
    wire    [7:0]       m_axis_tdata_contrast;
    wire                m_axis_tlast_contrast;
    wire                m_axis_tvalid_contrast;
    wire                m_axis_tready_contrast;
    wire                m_axis_tuser_contrast;

    contrast_stretch_top #(
        .DATA_WIDTH            (8 ),         
        .FRAME_WIDTH           (640),     
        .FRAME_HEIGHT          (512),      
        .AXIS_TDATA_WIDTH      (8),
        .AXI_DATA_WIDTH        (32),
        .AXI_ADDR_WIDTH        (32)
    )contrast_stretch_top_inst(
        .axis_aclk               (clk_10m),
        .axis_aresetn            (systemClk_locked_delay),

        // ---------------------------  axi-stream-slave  ---------- start ------------
        .s_axis_tdata       (m_axis_tdata_gamma  ),
        .s_axis_tlast       (m_axis_tlast_gamma  ),
        .s_axis_tvalid      (m_axis_tvalid_gamma ),
        .s_axis_tready      (m_axis_tready_gamma ),
        .s_axis_tuser       (m_axis_tuser_gamma  ),
        // ---------------------------  axi-stream-slave  ---------- end ------------
        
        // ---------------------------  axi-stream-master  ---------- start ------------
        .m_axis_tdata       (m_axis_tdata_contrast  ),
        .m_axis_tlast       (m_axis_tlast_contrast  ),
        .m_axis_tvalid      (m_axis_tvalid_contrast ),
        .m_axis_tready      (m_axis_tready_contrast ),
        .m_axis_tuser       (m_axis_tuser_contrast  ),
        // ---------------------------  axi-stream-master  ---------- end ------------

        // Ports of Axi Slave Bus Interface S00_AXI
        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s22_axi_awaddr ),
        .s00_axi_awprot     (s22_axi_awprot ),
        .s00_axi_awvalid    (s22_axi_awvalid),
        .s00_axi_awready    (s22_axi_awready),
        .s00_axi_wdata      (s22_axi_wdata  ),
        .s00_axi_wstrb      (s22_axi_wstrb  ),
        .s00_axi_wvalid     (s22_axi_wvalid ),
        .s00_axi_wready     (s22_axi_wready ),
        .s00_axi_bresp      (s22_axi_bresp  ),
        .s00_axi_bvalid     (s22_axi_bvalid ),
        .s00_axi_bready     (s22_axi_bready ),
        .s00_axi_araddr     (s22_axi_araddr),
        .s00_axi_arprot     (s22_axi_arprot ),
        .s00_axi_arvalid    (s22_axi_arvalid),
        .s00_axi_arready    (s22_axi_arready),
        .s00_axi_rdata      (s22_axi_rdata  ),
        .s00_axi_rresp      (s22_axi_rresp  ),
        .s00_axi_rvalid     (s22_axi_rvalid ),
        .s00_axi_rready     (s22_axi_rready )
    );

  //-----------------------------------------------------------------------------------CONTRAST STRETCH end------------------------------------------------------------------------------------------------------------------------



//-----------------------------------------------------------------------------------BRIGHTNESS begin------------------------------------------------------------------------------------------------------------------------

    wire [    31 : 0]               s23_axi_awaddr;
    wire [                   2 : 0] s23_axi_awprot;
    wire                            s23_axi_awvalid;
    wire                            s23_axi_awready;
    wire [    31 : 0]               s23_axi_wdata;
    wire [3 : 0]                    s23_axi_wstrb;
    wire                            s23_axi_wvalid;
    wire                            s23_axi_wready;
    wire [                   1 : 0] s23_axi_bresp;
    wire                            s23_axi_bvalid;
    wire                            s23_axi_bready;
    wire [    31 : 0]               s23_axi_araddr;
    wire [                   2 : 0] s23_axi_arprot;
    wire                            s23_axi_arvalid;
    wire                            s23_axi_arready;
    wire [    31 : 0]               s23_axi_rdata;
    wire [                   1 : 0] s23_axi_rresp;
    wire                            s23_axi_rvalid;
    wire                            s23_axi_rready;
    
    wire    [7:0]       m_axis_tdata_brightness;
    wire                m_axis_tlast_brightness;
    wire                m_axis_tvalid_brightness;
    wire                m_axis_tready_brightness;
    wire                m_axis_tuser_brightness;

    brightness_top #(
        .DATA_WIDTH            (8 ),         
        .FRAME_WIDTH           (640),     
        .FRAME_HEIGHT          (512),      
        .AXIS_TDATA_WIDTH      (8),
        .AXI_DATA_WIDTH        (32),
        .AXI_ADDR_WIDTH        (32)
    )brightness_top_inst(
        .axis_aclk               (clk_10m),
        .axis_aresetn            (systemClk_locked_delay),

        // ---------------------------  axi-stream-slave  ---------- start ------------
        .s_axis_tdata       (m_axis_tdata_contrast  ),
        .s_axis_tlast       (m_axis_tlast_contrast  ),
        .s_axis_tvalid      (m_axis_tvalid_contrast ),
        .s_axis_tready      (m_axis_tready_contrast ),
        .s_axis_tuser       (m_axis_tuser_contrast  ),
        // ---------------------------  axi-stream-slave  ---------- end ------------
        
        // ---------------------------  axi-stream-master  ---------- start ------------
        .m_axis_tdata       (m_axis_tdata_brightness  ),
        .m_axis_tlast       (m_axis_tlast_brightness  ),
        .m_axis_tvalid      (m_axis_tvalid_brightness ),
        .m_axis_tready      (m_axis_tready_brightness ),
        .m_axis_tuser       (m_axis_tuser_brightness  ),
        // ---------------------------  axi-stream-master  ---------- end ------------

        // Ports of Axi Slave Bus Interface S00_AXI
        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s23_axi_awaddr ),
        .s00_axi_awprot     (s23_axi_awprot ),
        .s00_axi_awvalid    (s23_axi_awvalid),
        .s00_axi_awready    (s23_axi_awready),
        .s00_axi_wdata      (s23_axi_wdata  ),
        .s00_axi_wstrb      (s23_axi_wstrb  ),
        .s00_axi_wvalid     (s23_axi_wvalid ),
        .s00_axi_wready     (s23_axi_wready ),
        .s00_axi_bresp      (s23_axi_bresp  ),
        .s00_axi_bvalid     (s23_axi_bvalid ),
        .s00_axi_bready     (s23_axi_bready ),
        .s00_axi_araddr     (s23_axi_araddr),
        .s00_axi_arprot     (s23_axi_arprot ),
        .s00_axi_arvalid    (s23_axi_arvalid),
        .s00_axi_arready    (s23_axi_arready),
        .s00_axi_rdata      (s23_axi_rdata  ),
        .s00_axi_rresp      (s23_axi_rresp  ),
        .s00_axi_rvalid     (s23_axi_rvalid ),
        .s00_axi_rready     (s23_axi_rready )
    );

  //-----------------------------------------------------------------------------------BRIGHTNESS end------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------another gamma begin------------------------------------------------------------------------------------------------------------------------


    wire [31:0] s64_axi_awaddr;
    wire [ 2:0] s64_axi_awprot;
    wire        s64_axi_awvalid;
    wire        s64_axi_awready;
    wire [31:0] s64_axi_wdata;
    wire [ 3:0] s64_axi_wstrb;
    wire        s64_axi_wvalid;
    wire        s64_axi_wready;
    wire [ 1:0] s64_axi_bresp;
    wire        s64_axi_bvalid;
    wire        s64_axi_bready;
    wire [31:0] s64_axi_araddr;
    wire [ 2:0] s64_axi_arprot;
    wire        s64_axi_arvalid;
    wire        s64_axi_arready;
    wire [31:0] s64_axi_rdata;
    wire [ 1:0] s64_axi_rresp;
    wire        s64_axi_rvalid;
    wire        s64_axi_rready;

    wire    [7:0]       m_axis_tdata_gamma2; 
    wire                m_axis_tlast_gamma2; 
    wire                m_axis_tvalid_gamma2;
    wire                m_axis_tready_gamma2;
    wire                m_axis_tuser_gamma2; 

    LUT_v1_0 # (
        .FRAME_WIDTH            (640),
        .FRAME_HEIGHT           (512),
        .BPS         (8),
        .C_S00_AXI_DATA_WIDTH(32),
        .C_S00_AXI_ADDR_WIDTH(10)
    )
    LUT_inst2
    (
        .axis_aclk          (clk_10m),
        .axis_aresetn        (systemClk_locked_delay),

        .s_axis_tdata      ( m_axis_tdata_brightness ),
        .s_axis_tlast      ( m_axis_tlast_brightness ),
        .s_axis_tvalid     ( m_axis_tvalid_brightness ),
        .s_axis_tuser      ( m_axis_tuser_brightness ),
        .s_axis_tready     ( m_axis_tready_brightness ),
        
        .m_axis_tdata      (m_axis_tdata_gamma2 ),
        .m_axis_tlast      (m_axis_tlast_gamma2 ),
        .m_axis_tvalid     (m_axis_tvalid_gamma2),
        .m_axis_tready     (m_axis_tready_gamma2),
        .m_axis_tuser      (m_axis_tuser_gamma2 ),
        
        .s00_axi_aclk      (io_systemClk       ),
        .s00_axi_aresetn   (systemClk_locked_delay    ),    
        .s00_axi_awaddr    (s64_axi_awaddr ),    
        .s00_axi_awprot    (s64_axi_awprot ),    
        .s00_axi_awvalid   (s64_axi_awvalid),    
        .s00_axi_awready   (s64_axi_awready),    
        .s00_axi_wdata     (s64_axi_wdata  ),    
        .s00_axi_wstrb     (s64_axi_wstrb  ),    
        .s00_axi_wvalid    (s64_axi_wvalid ),    
        .s00_axi_wready    (s64_axi_wready ),    
        .s00_axi_bresp     (s64_axi_bresp  ),    
        .s00_axi_bvalid    (s64_axi_bvalid ),    
        .s00_axi_bready    (s64_axi_bready ),    
        .s00_axi_araddr    (s64_axi_araddr ),    
        .s00_axi_arprot    (s64_axi_arprot ),    
        .s00_axi_arvalid   (s64_axi_arvalid),    
        .s00_axi_arready   (s64_axi_arready),    
        .s00_axi_rdata     (s64_axi_rdata  ),    
        .s00_axi_rresp     (s64_axi_rresp  ),    
        .s00_axi_rvalid    (s64_axi_rvalid ),    
        .s00_axi_rready    (s64_axi_rready )    

    );

//-----------------------------------------------------------------------------------another gamma end------------------------------------------------------------------------------------------------------------------------

// ---------------------------- usm begin -----------------------

    wire [ 7:0] m_axis_tdata_usm;
    wire        m_axis_tlast_usm;
    wire        m_axis_tready_usm;
    wire        m_axis_tuser_usm;
    wire        m_axis_tvalid_usm;

    UsmTop #(
        .COL             (640),
        .ROW             (512),
        .AXIS_TDATA_WIDTH(8),
        .AXI_DATA_WIDTH  (32),
        .AXI_ADDR_WIDTH  (6)
    ) UsmTop_inst (
        .axis_aclk   (clk_10m),
        .axis_aresetn(systemClk_locked_delay),

        .m_axis_tready(m_axis_tready_usm),
        .m_axis_tvalid(m_axis_tvalid_usm),
        .m_axis_tdata (m_axis_tdata_usm),
        .m_axis_tuser (m_axis_tuser_usm),
        .m_axis_tlast (m_axis_tlast_usm),

        .s_axis_tready(m_axis_tready_gamma2),
        .s_axis_tvalid(m_axis_tvalid_gamma2),
        .s_axis_tdata (m_axis_tdata_gamma2),
        .s_axis_tuser (m_axis_tuser_gamma2),
        .s_axis_tlast (m_axis_tlast_gamma2),

        .s00_axi_aclk   (io_systemClk),
        .s00_axi_aresetn(systemClk_locked_delay),
        .s00_axi_awaddr (s08_axi_awaddr),
        .s00_axi_awprot (s08_axi_awprot),
        .s00_axi_awvalid(s08_axi_awvalid),
        .s00_axi_awready(s08_axi_awready),
        .s00_axi_wdata  (s08_axi_wdata),
        .s00_axi_wstrb  (s08_axi_wstrb),
        .s00_axi_wvalid (s08_axi_wvalid),
        .s00_axi_wready (s08_axi_wready),
        .s00_axi_bresp  (s08_axi_bresp),
        .s00_axi_bvalid (s08_axi_bvalid),
        .s00_axi_bready (s08_axi_bready),
        .s00_axi_araddr (s08_axi_araddr),
        .s00_axi_arprot (s08_axi_arprot),
        .s00_axi_arvalid(s08_axi_arvalid),
        .s00_axi_arready(s08_axi_arready),
        .s00_axi_rdata  (s08_axi_rdata),
        .s00_axi_rresp  (s08_axi_rresp),
        .s00_axi_rvalid (s08_axi_rvalid),
        .s00_axi_rready (s08_axi_rready)
    );

// ---------------------------- usm end -----------------------


   // insert a skid buffer
  wire [  7:0] m_axis_tdata_sk3;
  wire          m_axis_tlast_sk3;
  wire          m_axis_tready_sk3;
  wire          m_axis_tuser_sk3;
  wire          m_axis_tvalid_sk3;

   skidbuffer #(
		.DW      (8+1+1)
   ) skidbuffer3 (
        .i_clk   (clk_10m),
        .i_reset (~systemClk_locked_delay),
        .i_valid (m_axis_tvalid_usm),
        .o_ready (m_axis_tready_usm),
        .i_data  ({m_axis_tdata_usm,m_axis_tuser_usm,m_axis_tlast_usm}),
        .o_valid (m_axis_tvalid_sk3),
        .i_ready (m_axis_tready_sk3),
        .o_data  ({m_axis_tdata_sk3,m_axis_tuser_sk3,m_axis_tlast_sk3})
	);
   // end

    // ---------------------------- misc begin -----------------------

    wire    [7:0]       m_axis_tdata_misc; 
    wire                m_axis_tlast_misc; 
    wire                m_axis_tvalid_misc;
    wire                m_axis_tready_misc;
    wire                m_axis_tuser_misc; 


    wire                pip_go;
    wire                pip_position;


    wire [    31 : 0]               s19_axi_awaddr;
    wire [                   2 : 0] s19_axi_awprot;
    wire                            s19_axi_awvalid;
    wire                            s19_axi_awready;
    wire [    31 : 0]               s19_axi_wdata;
    wire [3 : 0]                    s19_axi_wstrb;
    wire                            s19_axi_wvalid;
    wire                            s19_axi_wready;
    wire [                   1 : 0] s19_axi_bresp;
    wire                            s19_axi_bvalid;
    wire                            s19_axi_bready;
    wire [    31 : 0]               s19_axi_araddr;
    wire [                   2 : 0] s19_axi_arprot;
    wire                            s19_axi_arvalid;
    wire                            s19_axi_arready;
    wire [    31 : 0]               s19_axi_rdata;
    wire [                   1 : 0] s19_axi_rresp;
    wire                            s19_axi_rvalid;
    wire                            s19_axi_rready;

    Misc_IP_Top #(
        .ROW              (512),
        .COL              (640),
        .AXIS_TDATA_WIDTH (8),
        .AXI_DATA_WIDTH   (32),
        .AXI_ADDR_WIDTH   (4)
    ) u_Misc_IP_Top(
        .axis_aclk          (clk_10m),
        .axis_aresetn       (systemClk_locked_delay),

        .m_axis_tready      (m_axis_tready_misc),
        .m_axis_tvalid      (m_axis_tvalid_misc),
        .m_axis_tdata       (m_axis_tdata_misc),
        .m_axis_tuser       (m_axis_tuser_misc),
        .m_axis_tlast       (m_axis_tlast_misc),

        .s_axis_tready      (m_axis_tready_sk3),
        .s_axis_tvalid      (m_axis_tvalid_sk3),
        .s_axis_tdata       (m_axis_tdata_sk3),
        .s_axis_tuser       (m_axis_tuser_sk3),
        .s_axis_tlast       (m_axis_tlast_sk3),

        .pip_go             (pip_go),
        .pip_position       (pip_position),

        .axi_aclk           (io_systemClk),
        .axi_aresetn        (systemClk_locked_delay),
        .s00_axi_awaddr     (s19_axi_awaddr ),
        .s00_axi_awprot     (s19_axi_awprot ),
        .s00_axi_awvalid    (s19_axi_awvalid),
        .s00_axi_awready    (s19_axi_awready),
        .s00_axi_wdata      (s19_axi_wdata  ),
        .s00_axi_wstrb      (s19_axi_wstrb  ),
        .s00_axi_wvalid     (s19_axi_wvalid ),
        .s00_axi_wready     (s19_axi_wready ),
        .s00_axi_bresp      (s19_axi_bresp  ),
        .s00_axi_bvalid     (s19_axi_bvalid ),
        .s00_axi_bready     (s19_axi_bready ),
        .s00_axi_araddr     (s19_axi_araddr ),
        .s00_axi_arprot     (s19_axi_arprot ),
        .s00_axi_arvalid    (s19_axi_arvalid),
        .s00_axi_arready    (s19_axi_arready),
        .s00_axi_rdata      (s19_axi_rdata  ),
        .s00_axi_rresp      (s19_axi_rresp  ),
        .s00_axi_rvalid     (s19_axi_rvalid ),
        .s00_axi_rready     (s19_axi_rready )   
    );


    // ---------------------------- misc end -----------------------


    // ---------------------------- scaler begin -----------------------

    wire    [7:0]       m_axis_tdata_scaler; 
    wire                m_axis_tlast_scaler; 
    wire                m_axis_tvalid_scaler;
    wire                m_axis_tready_scaler;
    wire                m_axis_tuser_scaler;     

    wire [    31 : 0]               s18_axi_awaddr;
    wire [                   2 : 0] s18_axi_awprot;
    wire                            s18_axi_awvalid;
    wire                            s18_axi_awready;
    wire [    31 : 0]               s18_axi_wdata;
    wire [3 : 0]                    s18_axi_wstrb;
    wire                            s18_axi_wvalid;
    wire                            s18_axi_wready;
    wire [                   1 : 0] s18_axi_bresp;
    wire                            s18_axi_bvalid;
    wire                            s18_axi_bready;
    wire [    31 : 0]               s18_axi_araddr;
    wire [                   2 : 0] s18_axi_arprot;
    wire                            s18_axi_arvalid;
    wire                            s18_axi_arready;
    wire [    31 : 0]               s18_axi_rdata;
    wire [                   1 : 0] s18_axi_rresp;
    wire                            s18_axi_rvalid;
    wire                            s18_axi_rready;
     
    scaler #(
        .DATA_WIDTH        (8),   
        .FRAME_WIDTH       (640), 
        .FRAME_HEIGHT      (512),
        .OUT_FRAME_WIDTH   (640),
        .OUT_FRAME_HEIGHT  (512)
        
    )
    u_scaler_top(
        .clk                (clk_10m),
        .rst_n              (systemClk_locked_delay),

        .s_axis_tdata       (m_axis_tdata_misc),
        .s_axis_tlast       (m_axis_tlast_misc),
        .s_axis_tvalid      (m_axis_tvalid_misc),
        .s_axis_tuser       (m_axis_tuser_misc),
        .s_axis_tready      (m_axis_tready_misc),

        .m_axis_tdata       (m_axis_tdata_scaler),
        .m_axis_tlast       (m_axis_tlast_scaler),
        .m_axis_tvalid      (m_axis_tvalid_scaler),
        .m_axis_tuser       (m_axis_tuser_scaler),
        .m_axis_tready      (m_axis_tready_scaler),

        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s18_axi_awaddr ),
        .s00_axi_awprot     (s18_axi_awprot ),
        .s00_axi_awvalid    (s18_axi_awvalid),
        .s00_axi_awready    (s18_axi_awready),
        .s00_axi_wdata      (s18_axi_wdata  ),
        .s00_axi_wstrb      (s18_axi_wstrb  ),
        .s00_axi_wvalid     (s18_axi_wvalid ),
        .s00_axi_wready     (s18_axi_wready ),
        .s00_axi_bresp      (s18_axi_bresp  ),
        .s00_axi_bvalid     (s18_axi_bvalid ),
        .s00_axi_bready     (s18_axi_bready ),
        .s00_axi_araddr     (s18_axi_araddr ),
        .s00_axi_arprot     (s18_axi_arprot ),
        .s00_axi_arvalid    (s18_axi_arvalid),
        .s00_axi_arready    (s18_axi_arready),
        .s00_axi_rdata      (s18_axi_rdata  ),
        .s00_axi_rresp      (s18_axi_rresp  ),
        .s00_axi_rvalid     (s18_axi_rvalid ),
        .s00_axi_rready     (s18_axi_rready )   
    );



    // ---------------------------- scaler end -----------------------


  // ---------------------------- pip begin -----------------------


    wire    [7:0]       m_axis_tdata_pip; 
    wire                m_axis_tlast_pip; 
    wire                m_axis_tvalid_pip;
    wire                m_axis_tready_pip;
    wire                m_axis_tuser_pip; 


    pip#(
        .DATA_WIDTH            (8),   
        .FRAME_WIDTH           (640), 
        .FRAME_HEIGHT          (512)

    )
    pip_inst(
        
        .aclk                   (clk_10m),
        .aresetn                (systemClk_locked_delay),

        .s_axis_tdata           (m_axis_tdata_scaler),
        .s_axis_tlast           (m_axis_tlast_scaler),
        .s_axis_tvalid          (m_axis_tvalid_scaler),
        .s_axis_tuser           (m_axis_tuser_scaler),
        .s_axis_tready          (m_axis_tready_scaler),

        .m_axis_tdata           (m_axis_tdata_pip),
        .m_axis_tlast           (m_axis_tlast_pip),
        .m_axis_tvalid          (m_axis_tvalid_pip),
        .m_axis_tuser           (m_axis_tuser_pip),
        .m_axis_tready          (m_axis_tready_pip),


        .width                  (640),
        .height                 (512),

        
        .pip_go                 (pip_go),
        .pip_position           (pip_position)
    );


    // ---------------------------- pip end -----------------------



    wire [    31 : 0]               s03_axi_awaddr;
    wire [                   2 : 0] s03_axi_awprot;
    wire                            s03_axi_awvalid;
    wire                            s03_axi_awready;
    wire [    31 : 0]               s03_axi_wdata;
    wire [3 : 0]                    s03_axi_wstrb;
    wire                            s03_axi_wvalid;
    wire                            s03_axi_wready;
    wire [                   1 : 0] s03_axi_bresp;
    wire                            s03_axi_bvalid;
    wire                            s03_axi_bready;
    wire [    31 : 0]               s03_axi_araddr;
    wire [                   2 : 0] s03_axi_arprot;
    wire                            s03_axi_arvalid;
    wire                            s03_axi_arready;
    wire [    31 : 0]               s03_axi_rdata;
    wire [                   1 : 0] s03_axi_rresp;
    wire                            s03_axi_rvalid;
    wire                            s03_axi_rready;

    // 当rw_pause拉高时，
    // 将输给reader的写指针设为reader_base_index_1+1，使得�?�指针不��??，达到画面暂停的效果
    // 并将输给writer的�?�指针�?�为writer_base_index_pause+1，使得写指针不动
    (* async_reg = "true" *) reg [1:0] rw_pause_r;
    
    always @(posedge io_memoryClk or negedge systemClk_locked_delay)
    if (!systemClk_locked_delay) begin
        rw_pause_r <= 0;
    end
    else begin
        rw_pause_r[0] <= rw_pause;
        rw_pause_r[1] <= rw_pause_r[0];
    end

    assign writer_base_index_pause =    rw_pause_r[1] ?
                                        (reader_base_index_1 == 2) ?
                                        0 :
                                        (reader_base_index_1 + 1) :
                                        writer_base_index_1;

    assign reader_base_index_pause =    rw_pause_r[1] ?
                                        (writer_base_index_pause == 2) ?
                                        0 :
                                        (writer_base_index_pause + 1) :
                                        reader_base_index_1;

    assign writer_base_index_pause_1 =    rw_pause_r[1] ?
                                        (reader_base_index_2 == 2) ?
                                        0 :
                                        (reader_base_index_2 + 1) :
                                        writer_base_index_2;

    assign reader_base_index_pause_1 =    rw_pause_r[1] ?
                                        (writer_base_index_pause_1 == 2) ?
                                        0 :
                                        (writer_base_index_pause_1 + 1) :
                                        reader_base_index_2;




// ---------------------------- 3 frame writer begin -----------------------


    wire [    31 : 0]               s12_axi_awaddr;
    wire [                   2 : 0] s12_axi_awprot;
    wire                            s12_axi_awvalid;
    wire                            s12_axi_awready;
    wire [    31 : 0]               s12_axi_wdata;
    wire [3 : 0]                    s12_axi_wstrb;
    wire                            s12_axi_wvalid;
    wire                            s12_axi_wready;
    wire [                   1 : 0] s12_axi_bresp;
    wire                            s12_axi_bvalid;
    wire                            s12_axi_bready;
    wire [    31 : 0]               s12_axi_araddr;
    wire [                   2 : 0] s12_axi_arprot;
    wire                            s12_axi_arvalid;
    wire                            s12_axi_arready;
    wire [    31 : 0]               s12_axi_rdata;
    wire [                   1 : 0] s12_axi_rresp;
    wire                            s12_axi_rvalid;
    wire                            s12_axi_rready;


    axi_frame_writer_v1_0 #(
        .BPS                (8),   
		.MAX_WIDTH          (640),
		.MAX_HEIGHT         (512),
		.BUFFER_NUM         (3),
		.ADDRESSWIDTH       (32),
		.DATAWIDTH_MM       (128),
		.MAXBURSTCOUNT      (8),
		.FIFODEPTH_BYTE     (2048)
    )
    writer_2
    (
        .clk                    (io_memoryClk  ),
        .rst_n                  (systemClk_locked_delay),

        .writer_base_index      (writer_base_index_2),
        .reader_base_index      (reader_base_index_pause_1),


        .m_axi_awaddr           (m_axi_awaddr_2  ),
        .m_axi_awburst          (m_axi_awburst_2 ),
        .m_axi_awcache          (m_axi_awcache_2 ),
        .m_axi_awlen            (m_axi_awlen_2   ),
        .m_axi_awprot           (m_axi_awprot_2  ),
        .m_axi_awready          (m_axi_awready_2 ),
        .m_axi_awsize           (m_axi_awsize_2  ),
        .m_axi_awuser           (m_axi_awuser_2  ),
        .m_axi_awvalid          (m_axi_awvalid_2 ),
        .m_axi_bready           (m_axi_bready_2  ),
        .m_axi_bresp            (m_axi_bresp_2   ),
        .m_axi_bvalid           (m_axi_bvalid_2  ),
        .m_axi_wdata            (m_axi_wdata_2   ),
        .m_axi_wlast            (m_axi_wlast_2   ),
        .m_axi_wready           (m_axi_wready_2  ),
        .m_axi_wstrb            (m_axi_wstrb_2   ),
        .m_axi_wvalid           (m_axi_wvalid_2  ),

        .axis_aclk              (clk_10m),
        .s_axis_tdata           (m_axis_tdata_pip),
        .s_axis_tlast           (m_axis_tlast_pip),
        .s_axis_tvalid          (m_axis_tvalid_pip),
        .s_axis_tready          (m_axis_tready_pip),
        .s_axis_tuser           (m_axis_tuser_pip),
        
        // Ports of Axi Slave Bus Interface S00_AXI
        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s12_axi_awaddr ),
        .s00_axi_awprot     (s12_axi_awprot ),
        .s00_axi_awvalid    (s12_axi_awvalid),
        .s00_axi_awready    (s12_axi_awready),
        .s00_axi_wdata      (s12_axi_wdata  ),
        .s00_axi_wstrb      (s12_axi_wstrb  ),
        .s00_axi_wvalid     (s12_axi_wvalid ),
        .s00_axi_wready     (s12_axi_wready ),
        .s00_axi_bresp      (s12_axi_bresp  ),
        .s00_axi_bvalid     (s12_axi_bvalid ),
        .s00_axi_bready     (s12_axi_bready ),
        .s00_axi_araddr     (s12_axi_araddr ),
        .s00_axi_arprot     (s12_axi_arprot ),
        .s00_axi_arvalid    (s12_axi_arvalid),
        .s00_axi_arready    (s12_axi_arready),
        .s00_axi_rdata      (s12_axi_rdata  ),
        .s00_axi_rresp      (s12_axi_rresp  ),
        .s00_axi_rvalid     (s12_axi_rvalid ),
        .s00_axi_rready     (s12_axi_rready )        

    );

    // ---------------------------- 3 frame writer end -----------------------




    // ---------------------------- 3 frame reader begin -----------------------

    wire [    31 : 0]               s13_axi_awaddr;
    wire [                   2 : 0] s13_axi_awprot;
    wire                            s13_axi_awvalid;
    wire                            s13_axi_awready;
    wire [    31 : 0]               s13_axi_wdata;
    wire [3 : 0]                    s13_axi_wstrb;
    wire                            s13_axi_wvalid;
    wire                            s13_axi_wready;
    wire [                   1 : 0] s13_axi_bresp;
    wire                            s13_axi_bvalid;
    wire                            s13_axi_bready;
    wire [    31 : 0]               s13_axi_araddr;
    wire [                   2 : 0] s13_axi_arprot;
    wire                            s13_axi_arvalid;
    wire                            s13_axi_arready;
    wire [    31 : 0]               s13_axi_rdata;
    wire [                   1 : 0] s13_axi_rresp;
    wire                            s13_axi_rvalid;
    wire                            s13_axi_rready;

    wire [3:0] tmp;
    assign tmp = (reader_base_index_2 == 0) ? 2 : (reader_base_index_2 - 1);
    
    axi_frame_reader_v1_0 #(
        .BPS                (8),
		.MAX_WIDTH          (640),
		.MAX_HEIGHT         (512),
		.BUFFER_NUM         (3),
		.ADDRESSWIDTH       (32),
		.DATAWIDTH_MM       (128),
		.MAXBURSTCOUNT      (8),
		.FIFODEPTH_BYTE     (2048)
    )
    reader_2
    (
        .clk                                (io_memoryClk),
		.axis_aresetn                       (systemClk_locked_delay),
		.writer_base_index                  (writer_base_index_pause_1),
		.reader_base_index                  (reader_base_index_2),

		.m_axi_araddr                       (m_axi_araddr_2   ),
		.m_axi_arburst                      (m_axi_arburst_2  ),
		.m_axi_arcache                      (m_axi_arcache_2  ),
		.m_axi_arlen                        (m_axi_arlen_2    ),
		.m_axi_arprot                       (m_axi_arprot_2   ),
		.m_axi_arready                      (m_axi_arready_2|m_axi_arready_2_0  ),
		.m_axi_arsize                       (m_axi_arsize_2   ),
		.m_axi_aruser                       (m_axi_aruser_2   ),
		.m_axi_arvalid                      (m_axi_arvalid_2  ),
		.m_axi_rdata                        (m_axi_rdata_2|m_axi_rdata_2_0    ),
		.m_axi_rlast                        (m_axi_rlast_2|m_axi_rlast_2_0    ),
		.m_axi_rready                       (m_axi_rready_2   ),
		.m_axi_rresp                        (m_axi_rresp_2|m_axi_rresp_2_0    ),
		.m_axi_rvalid                       (m_axi_rvalid_2|m_axi_rvalid_2_0   ),


		.axis_aclk                          (clk_65m),
		.m_axis_tdata                       (m_axis_tdata_reader_2  ),
		.m_axis_tlast                       (m_axis_tlast_reader_2   ),
		.m_axis_tvalid                      (m_axis_tvalid_reader_2   ),
		.m_axis_tready                      (m_axis_tready_reader_2   ),
		.m_axis_tuser                       (m_axis_tuser_reader_2   ),

        // Ports of Axi Slave Bus Interface S00_AXI
        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s13_axi_awaddr ),
        .s00_axi_awprot     (s13_axi_awprot ),
        .s00_axi_awvalid    (s13_axi_awvalid),
        .s00_axi_awready    (s13_axi_awready),
        .s00_axi_wdata      (s13_axi_wdata  ),
        .s00_axi_wstrb      (s13_axi_wstrb  ),
        .s00_axi_wvalid     (s13_axi_wvalid ),
        .s00_axi_wready     (s13_axi_wready ),
        .s00_axi_bresp      (s13_axi_bresp  ),
        .s00_axi_bvalid     (s13_axi_bvalid ),
        .s00_axi_bready     (s13_axi_bready ),
        .s00_axi_araddr     (s13_axi_araddr ),
        .s00_axi_arprot     (s13_axi_arprot ),
        .s00_axi_arvalid    (s13_axi_arvalid),
        .s00_axi_arready    (s13_axi_arready),
        .s00_axi_rdata      (s13_axi_rdata  ),
        .s00_axi_rresp      (s13_axi_rresp  ),
        .s00_axi_rvalid     (s13_axi_rvalid ),
        .s00_axi_rready     (s13_axi_rready )

        // .go                                 (go_v),
        // .mode                               (2),
        // .width                              (720),
        // .height                             (576),
        // .baseaddr                           (32'h1050_0000)                        
    );

    // ---------------------------- 3 frame reader end -----------------------

// ---------------------------- LUT-COLOR begin -----------------------

    wire    [23:0]      m_axis_tdata_lut_color; 
    wire                m_axis_tlast_lut_color; 
    wire                m_axis_tvalid_lut_color;
    wire                m_axis_tready_lut_color;
    wire                m_axis_tuser_lut_color; 

    wire                lut_color_changing;


    wire [    31 : 0]               s14_axi_awaddr;
    wire [                   2 : 0] s14_axi_awprot;
    wire                            s14_axi_awvalid;
    wire                            s14_axi_awready;
    wire [    31 : 0]               s14_axi_wdata;
    wire [3 : 0]                    s14_axi_wstrb;
    wire                            s14_axi_wvalid;
    wire                            s14_axi_wready;
    wire [                   1 : 0] s14_axi_bresp;
    wire                            s14_axi_bvalid;
    wire                            s14_axi_bready;
    wire [    31 : 0]               s14_axi_araddr;
    wire [                   2 : 0] s14_axi_arprot;
    wire                            s14_axi_arvalid;
    wire                            s14_axi_arready;
    wire [    31 : 0]               s14_axi_rdata;
    wire [                   1 : 0] s14_axi_rresp;
    wire                            s14_axi_rvalid;
    wire                            s14_axi_rready;

    LUT_v1_0_color #(
        .BPS             (8),
        .FRAME_WIDTH     (640),
        .FRAME_HEIGHT    (512)
    ) u_LUT_v1_0_color (
        .axis_aclk   (clk_65m),
        .axis_aresetn(systemClk_locked_delay),



        .m_axis_tready(m_axis_tready_lut_color),
        .m_axis_tvalid(m_axis_tvalid_lut_color),
        .m_axis_tdata (m_axis_tdata_lut_color),
        .m_axis_tuser (m_axis_tuser_lut_color),
        .m_axis_tlast (m_axis_tlast_lut_color),

        .s_axis_tdata(m_axis_tdata_reader_2),
        .s_axis_tlast(m_axis_tlast_reader_2),
        .s_axis_tvalid (m_axis_tvalid_reader_2),
        .s_axis_tready (m_axis_tready_reader_2),
        .s_axis_tuser (m_axis_tuser_reader_2),

        .lut_color_changing (lut_color_changing),

        .s00_axi_aclk   (io_systemClk),
        .s00_axi_aresetn(systemClk_locked_delay),
        .s00_axi_awaddr (s14_axi_awaddr),
        .s00_axi_awprot (s14_axi_awprot),
        .s00_axi_awvalid(s14_axi_awvalid),
        .s00_axi_awready(s14_axi_awready),
        .s00_axi_wdata  (s14_axi_wdata),
        .s00_axi_wstrb  (s14_axi_wstrb),
        .s00_axi_wvalid (s14_axi_wvalid),
        .s00_axi_wready (s14_axi_wready),
        .s00_axi_bresp  (s14_axi_bresp),
        .s00_axi_bvalid (s14_axi_bvalid),
        .s00_axi_bready (s14_axi_bready),
        .s00_axi_araddr (s14_axi_araddr),
        .s00_axi_arprot (s14_axi_arprot),
        .s00_axi_arvalid(s14_axi_arvalid),
        .s00_axi_arready(s14_axi_arready),
        .s00_axi_rdata  (s14_axi_rdata),
        .s00_axi_rresp  (s14_axi_rresp),
        .s00_axi_rvalid (s14_axi_rvalid),
        .s00_axi_rready (s14_axi_rready)
    );

      // ---------------------------- LUT-COLOR end -----------------------



    // ---------------------------- translation begin -----------------------
    
    wire    [23:0]      m_axis_tdata_trans; 
    wire                m_axis_tlast_trans; 
    wire                m_axis_tvalid_trans;
    wire                m_axis_tready_trans;
    wire                m_axis_tuser_trans; 


    wire [    31 : 0]               s21_axi_awaddr;
    wire [                   2 : 0] s21_axi_awprot;
    wire                            s21_axi_awvalid;
    wire                            s21_axi_awready;
    wire [    31 : 0]               s21_axi_wdata;
    wire [3 : 0]                    s21_axi_wstrb;
    wire                            s21_axi_wvalid;
    wire                            s21_axi_wready;
    wire [                   1 : 0] s21_axi_bresp;
    wire                            s21_axi_bvalid;
    wire                            s21_axi_bready;
    wire [    31 : 0]               s21_axi_araddr;
    wire [                   2 : 0] s21_axi_arprot;
    wire                            s21_axi_arvalid;
    wire                            s21_axi_arready;
    wire [    31 : 0]               s21_axi_rdata;
    wire [                   1 : 0] s21_axi_rresp;
    wire                            s21_axi_rvalid;
    wire                            s21_axi_rready;

    translation_top #(
        .FRAME_HEIGHT               (512),
        .FRAME_WIDTH                (640),
        .DATA_WIDTH                 (8),
        .AXIS_TDATA_WIDTH           (24),
        .AXI_DATA_WIDTH             (32),
        .AXI_ADDR_WIDTH             (32)
    ) 
    translation_top_inst(
        .axis_aclk          (clk_65m),
        .axis_aresetn       (systemClk_locked_delay),

        .m_axis_tready      (m_axis_tready_trans),
        .m_axis_tvalid      (m_axis_tvalid_trans),
        .m_axis_tdata       (m_axis_tdata_trans),
        .m_axis_tuser       (m_axis_tuser_trans),
        .m_axis_tlast       (m_axis_tlast_trans),

        .s_axis_tready      (m_axis_tready_lut_color),
        .s_axis_tvalid      (m_axis_tvalid_lut_color),
        .s_axis_tdata       (m_axis_tdata_lut_color),
        .s_axis_tuser       (m_axis_tuser_lut_color),
        .s_axis_tlast       (m_axis_tlast_lut_color),

        .lut_color_changing (lut_color_changing),

        .s00_axi_aclk       (io_systemClk),
        .s00_axi_aresetn    (systemClk_locked_delay),
        .s00_axi_awaddr     (s21_axi_awaddr ),
        .s00_axi_awprot     (s21_axi_awprot ),
        .s00_axi_awvalid    (s21_axi_awvalid),
        .s00_axi_awready    (s21_axi_awready),
        .s00_axi_wdata      (s21_axi_wdata  ),
        .s00_axi_wstrb      (s21_axi_wstrb  ),
        .s00_axi_wvalid     (s21_axi_wvalid ),
        .s00_axi_wready     (s21_axi_wready ),
        .s00_axi_bresp      (s21_axi_bresp  ),
        .s00_axi_bvalid     (s21_axi_bvalid ),
        .s00_axi_bready     (s21_axi_bready ),
        .s00_axi_araddr     (s21_axi_araddr ),
        .s00_axi_arprot     (s21_axi_arprot ),
        .s00_axi_arvalid    (s21_axi_arvalid),
        .s00_axi_arready    (s21_axi_arready),
        .s00_axi_rdata      (s21_axi_rdata  ),
        .s00_axi_rresp      (s21_axi_rresp  ),
        .s00_axi_rvalid     (s21_axi_rvalid ),
        .s00_axi_rready     (s21_axi_rready )   
    );


    // ---------------------------- translation end -----------------------


// ---------------------------- dvp begin -----------------------


    dvp_yuv #(
        .FRAME_WIDTH            (640),             
        .FRAME_HEIGHT           (512) ,  
        .BPS_IN                 (24),
        .BPS_OUT                (8),
        .VSYNC_KEEP             (3),
        .VSYNC_DELAY_BEFORE     (13),       
        .VSYNC_DELAY_AFTER      (97) ,      
        .HREF_DELAY_AFTER       (320)
                     
    )u_dvp
    (
        .rst_n(systemClk_locked_delay),
        .clk_dvp(clk_dvp),
        .axi_clk(clk_65m),
        .s_axis_tdata(m_axis_tdata_trans),
        .s_axis_tlast(m_axis_tlast_trans),
        .s_axis_tvalid(m_axis_tvalid_trans),
        .s_axis_tuser(m_axis_tuser_trans),
        .s_axis_tready(m_axis_tready_trans),
        .data(DVP_DATA),
        .VSYNC(VSYNC),
        .HREF(HREF)              
    );

    //  ---------------------------- dvp end -----------------------


    // ---------------------------- PwrCtrl start -----------------------

  wire [31:0] s31_axi_awaddr;
  wire [ 2:0] s31_axi_awprot;
  wire        s31_axi_awvalid;
  wire        s31_axi_awready;
  wire [31:0] s31_axi_wdata;
  wire [ 3:0] s31_axi_wstrb;
  wire        s31_axi_wvalid;
  wire        s31_axi_wready;
  wire [ 1:0] s31_axi_bresp;
  wire        s31_axi_bvalid;
  wire        s31_axi_bready;
  wire [31:0] s31_axi_araddr;
  wire [ 2:0] s31_axi_arprot;
  wire        s31_axi_arvalid;
  wire        s31_axi_arready;
  wire [31:0] s31_axi_rdata;
  wire [ 1:0] s31_axi_rresp;
  wire        s31_axi_rvalid;
  wire        s31_axi_rready;

  PwrCtrl PwrCtrl_inst (
    .s00_axi_awvalid      (s31_axi_awvalid),           // input               s00_axi_awvalid,
    .s00_axi_awready      (s31_axi_awready),           // output reg          s00_axi_awready,
    .s00_axi_awaddr       (s31_axi_awaddr),            // input      [31:0]   s00_axi_awaddr,
    .s00_axi_awprot       (s31_axi_awprot),            // input      [2:0]    s00_axi_awprot,
    .s00_axi_wvalid       (s31_axi_wvalid),            // input               s00_axi_wvalid,
    .s00_axi_wready       (s31_axi_wready),            // output reg          s00_axi_wready,
    .s00_axi_wdata        (s31_axi_wdata),             // input      [31:0]   s00_axi_wdata,
    .s00_axi_wstrb        (s31_axi_wstrb),             // input      [3:0]    s00_axi_wstrb,
    .s00_axi_bvalid       (s31_axi_bvalid),            // output              s00_axi_bvalid,
    .s00_axi_bready       (s31_axi_bready),            // input               s00_axi_bready,
    .s00_axi_bresp        (s31_axi_bresp),             // output     [1:0]    s00_axi_bresp,
    .s00_axi_arvalid      (s31_axi_arvalid),           // input               s00_axi_arvalid,
    .s00_axi_arready      (s31_axi_arready),           // output reg          s00_axi_arready,
    .s00_axi_araddr       (s31_axi_araddr),            // input      [31:0]   s00_axi_araddr,
    .s00_axi_arprot       (s31_axi_arprot),            // input      [2:0]    s00_axi_arprot,
    .s00_axi_rvalid       (s31_axi_rvalid),            // output              s00_axi_rvalid,
    .s00_axi_rready       (s31_axi_rready),            // input               s00_axi_rready,
    .s00_axi_rdata        (s31_axi_rdata),             // output     [31:0]   s00_axi_rdata,
    .s00_axi_rresp        (s31_axi_rresp),             // output     [1:0]    s00_axi_rresp,
    .io_ctrl_PWR_KEY_STATE(PWR_KEY_STATE),     // input               io_ctrl_PWR_KEY_STATE,
    .io_ctrl_PWR_CTRL     (PWR_CTRL),          // output              io_ctrl_PWR_CTRL,
    .clk                  (io_systemClk),              // input               clk,
    .reset                (~systemClk_locked_delay)          // input               reset
  );

    // ---------------------------- PwrCtrl end -----------------------

// ---------------------------- TMP101 begin -----------------------
  wire [  31:0] s20_axi_awaddr;
  wire [   2:0] s20_axi_awprot;
  wire          s20_axi_awvalid;
  wire          s20_axi_awready;
  wire [  31:0] s20_axi_wdata;
  wire [   3:0] s20_axi_wstrb;
  wire          s20_axi_wvalid;
  wire          s20_axi_wready;
  wire [   1:0] s20_axi_bresp;
  wire          s20_axi_bvalid;
  wire          s20_axi_bready;
  wire [  31:0] s20_axi_araddr;
  wire [   2:0] s20_axi_arprot;
  wire          s20_axi_arvalid;
  wire          s20_axi_arready;
  wire [  31:0] s20_axi_rdata;
  wire [   1:0] s20_axi_rresp;
  wire          s20_axi_rvalid;
  wire          s20_axi_rready;

    // 该模块通过i2c协�??读取探测器温��??
    tmp101_top #(
        .AXIS_TDATA_WIDTH(14),
        .AXI_DATA_WIDTH  (32),
        .AXI_ADDR_WIDTH  (4)
    ) u_tmp101_top (
     .clk               (io_memoryClk),
     .rst_n             (systemClk_locked_delay),
     .TMP_SCL_IN        (TMP_SCL_IN),
     .TMP_SDA_IN        (TMP_SDA_IN),
     .TMP_SCL_OUT       (TMP_SCL_OUT),
     .TMP_SCL_OE        (TMP_SCL_OE),
     .TMP_SDA_OUT       (TMP_SDA_OUT),
     .TMP_SDA_OE        (TMP_SDA_OE),
     .IR_5V_ON          (),
     .sensor_temp       (),
     .s00_axi_aclk      (io_systemClk),
     .s00_axi_aresetn   (systemClk_locked_delay),
     .s00_axi_awaddr    (s20_axi_awaddr),
     .s00_axi_awprot    (s20_axi_awprot),
     .s00_axi_awvalid   (s20_axi_awvalid),
     .s00_axi_awready   (s20_axi_awready),
     .s00_axi_wdata     (s20_axi_wdata),
     .s00_axi_wstrb     (s20_axi_wstrb),
     .s00_axi_wvalid    (s20_axi_wvalid),
     .s00_axi_wready    (s20_axi_wready),
     .s00_axi_bresp     (s20_axi_bresp),
     .s00_axi_bvalid    (s20_axi_bvalid),
     .s00_axi_bready    (s20_axi_bready),
     .s00_axi_araddr    (s20_axi_araddr),
     .s00_axi_arprot    (s20_axi_arprot),
     .s00_axi_arvalid   (s20_axi_arvalid),
     .s00_axi_arready   (s20_axi_arready),
     .s00_axi_rdata     (s20_axi_rdata),
     .s00_axi_rresp     (s20_axi_rresp),
     .s00_axi_rvalid    (s20_axi_rvalid),
     .s00_axi_rready    (s20_axi_rready)
    );

// ---------------------------- TMP101 end -----------------------

    // ---------------------------- bt656 end -----------------------



    wire [7:0] bid_0=0, bid_1=1, awid_0=0, awid_1=1, arid_0=0, arid_1=1, rid_0=0, rid_1=1;

  
    axi_interconnect #(
        .S_COUNT        (7),
        .M_COUNT        (1),
        .DATA_WIDTH     (128),
        .ADDR_WIDTH     (32),
        .STRB_WIDTH     (16),
        // .M_BASE_ADDR    (32'h10000000),
        // .M_ADDR_WIDTH   (32'd32),
        .ID_WIDTH       (8)
    )axi_interconnect_0(
        .rst ( !systemClk_locked_delay ),
        .clk ( io_memoryClk ),
        


        .s_axi_awvalid      ({m_axi_awvalid_0, m_axi_awvalid_ooc, m_axi_awvalid_w8, m_axi_awvalid_w1, m_axi_awvalid_0, m_axi_awvalid_2, m_axi_awvalid_tfilter}),
        .s_axi_awaddr       ({m_axi_awaddr_0, m_axi_awaddr_ooc, m_axi_awaddr_w8, m_axi_awaddr_w1, m_axi_awaddr_0, m_axi_awaddr_2, m_axi_awaddr_tfilter}),
        .s_axi_awburst      ({m_axi_awburst_0, m_axi_awburst_ooc, m_axi_awburst_w8, m_axi_awburst_w1, m_axi_awburst_0, m_axi_awburst_2, m_axi_awburst_tfilter}),
        .s_axi_awlen        ({m_axi_awlen_0, m_axi_awlen_ooc, m_axi_awlen_w8, m_axi_awlen_w1, m_axi_awlen_0, m_axi_awlen_2, m_axi_awlen_tfilter}),
        .s_axi_awsize       ({m_axi_awsize_0, m_axi_awsize_ooc, m_axi_awsize_w8, m_axi_awsize_w1, m_axi_awsize_0, m_axi_awsize_2, m_axi_awsize_tfilter}),
        .s_axi_awready      ({m_axi_awready_0_0, m_axi_awready_ooc, m_axi_awready_w8, m_axi_awready_w1, m_axi_awready_0, m_axi_awready_2, m_axi_awready_tfilter}),
        .s_axi_wvalid       ({m_axi_wvalid_0, m_axi_wvalid_ooc, m_axi_wvalid_w8, m_axi_wvalid_w1, m_axi_wvalid_0, m_axi_wvalid_2, m_axi_wvalid_tfilter}),
        .s_axi_wlast        ({m_axi_wlast_0, m_axi_wlast_ooc, m_axi_wlast_w8, m_axi_wlast_w1, m_axi_wlast_0, m_axi_wlast_2, m_axi_wlast_tfilter}),
        .s_axi_bready       ({m_axi_bready_0, m_axi_bready_ooc, m_axi_bready_w8, m_axi_bready_w1, m_axi_bready_0, m_axi_bready_2, m_axi_bready_tfilter}),
        .s_axi_bresp        ({m_axi_bresp_0_0, m_axi_bresp_ooc, m_axi_bresp_w8, m_axi_bresp_w1, m_axi_bresp_0, m_axi_bresp_2, m_axi_bresp_tfilter}),
        .s_axi_wready       ({m_axi_wready_0_0, m_axi_wready_ooc, m_axi_wready_w8, m_axi_wready_w1, m_axi_wready_0, m_axi_wready_2, m_axi_wready_tfilter}),
        .s_axi_awprot       ({m_axi_awprot_0, m_axi_awprot_ooc, m_axi_awprot_w8, m_axi_awprot_w1, m_axi_awprot_0, m_axi_awprot_2, m_axi_awprot_tfilter}),
        .s_axi_awcache      ({m_axi_awcache_0, m_axi_awcache_ooc, m_axi_awcache_w8, m_axi_awcache_w1, m_axi_awcache_0, m_axi_awcache_2, m_axi_awcache_tfilter}),
        .s_axi_awuser       ({m_axi_awuser_0, m_axi_awuser_ooc, m_axi_awuser_w8, m_axi_awuser_w1, m_axi_awuser_0, m_axi_awuser_2, m_axi_awuser_tfilter}),
        .s_axi_bvalid       ({m_axi_bvalid_0_0, m_axi_bvalid_ooc, m_axi_bvalid_w8, m_axi_bvalid_w1, m_axi_bvalid_0, m_axi_bvalid_2, m_axi_bvalid_tfilter}), 
        .s_axi_wdata        ({m_axi_wdata_0, m_axi_wdata_ooc, m_axi_wdata_w8, m_axi_wdata_w1, m_axi_wdata_0, m_axi_wdata_2, m_axi_wdata_tfilter}),
        .s_axi_awlock       (),
        .s_axi_awqos        (),
        .s_axi_arvalid      (),
        .s_axi_araddr       (),
        .s_axi_arlock       (),
        .s_axi_arready      (),
        .s_axi_rready       (),
        .s_axi_bid          (),
        .s_axi_rid          (),
        .s_axi_rdata        (),
        .s_axi_rresp        (),
        .s_axi_rvalid       (),
        .s_axi_rlast        (),
        .s_axi_wstrb        ({7{16'hffff}}),
        .s_axi_arqos        (),
        .s_axi_arcache      (),
        .s_axi_arid         (),
        .s_axi_arsize       (),
        .s_axi_arlen        (),
        .s_axi_arburst      (),
        .s_axi_arprot       (),
        .s_axi_awid         ({7{8'hff}}),
        .s_axi_aruser       (),
        .s_axi_wuser        (),
        .s_axi_buser        (),
        .s_axi_ruser        (),


        
        .m_axi_awvalid          (m_axi_awvalid  ),
        .m_axi_awaddr           (m_axi_awaddr   ),
        .m_axi_awlock           (m_axi_awlock   ),
        .m_axi_awready          (m_axi_awready  ),
        .m_axi_arvalid          (  ),
        .m_axi_araddr           (   ),
        .m_axi_arlock           (   ),
        .m_axi_arready          (  ),
        .m_axi_wvalid           (m_axi_wvalid   ),
        .m_axi_wlast            (m_axi_wlast    ),
        .m_axi_bready           (m_axi_bready   ),
        .m_axi_bresp            (m_axi_bresp    ),
        .m_axi_rready           (   ),
        .m_axi_bid              (m_axi_bid      ),
        .m_axi_rid              (      ),
        .m_axi_wdata            (m_axi_wdata    ),
        .m_axi_rdata            (    ),
        .m_axi_rresp            (    ),
        .m_axi_bvalid           (m_axi_bvalid   ),
        .m_axi_rvalid           (   ),
        .m_axi_rlast            (    ),
        .m_axi_wstrb            (m_axi_wstrb    ),
        .m_axi_wready           (m_axi_wready   ),
        .m_axi_awprot           (m_axi_awprot   ),
        .m_axi_awid             (m_axi_awid     ),
        .m_axi_awburst          (m_axi_awburst  ),
        .m_axi_awlen            (m_axi_awlen    ),
        .m_axi_awsize           (m_axi_awsize   ),
        .m_axi_awcache          (m_axi_awcache  ),
        .m_axi_awqos            (m_axi_awqos    ),
        .m_axi_awuser           (m_axi_awuser   ),
        .m_axi_arprot           (   ),
        .m_axi_arburst          (  ),
        .m_axi_arlen            (    ),
        .m_axi_arsize           (   ),
        .m_axi_arcache          (  ),
        .m_axi_arqos            (    ),
        .m_axi_aruser           (   ),
        .m_axi_awregion         (m_axi_awregion ),
        .m_axi_arregion         ( ),
        .m_axi_arid             (     ),
        .m_axi_wuser            (m_axi_wuser    ),
        .m_axi_ruser            (    ),
        .m_axi_buser            (m_axi_buser    )
    );

    axi_interconnect #(
        .S_COUNT        (10),
        .M_COUNT        (1),
        .DATA_WIDTH     (128),
        .ADDR_WIDTH     (32),
        .STRB_WIDTH     (16),
        // .M_BASE_ADDR    (32'h10000000),
        // .M_ADDR_WIDTH   (32'd32),
        .ID_WIDTH       (8)
    )axi_interconnect_1(
        .rst ( !systemClk_locked_delay ),
        .clk ( io_memoryClk ),
        


        .s_axi_arvalid      ({m_axi_arvalid_2, m_axi_arvalid_ooc, m_axi_arvalid_nuc_b, m_axi_arvalid_nuc_k, m_axi_arvalid_r8,m_axi_arvalid_0, m_axi_arvalid_2, m_axi_arvalid_tfilter, m_axi_arvalid_mask_k, m_axi_arvalid_mask_b}),
        .s_axi_araddr       ({m_axi_araddr_2, m_axi_araddr_ooc, m_axi_araddr_nuc_b, m_axi_araddr_nuc_k, m_axi_araddr_r8,m_axi_araddr_0, m_axi_araddr_2, m_axi_araddr_tfilter, m_axi_araddr_mask_k, m_axi_araddr_mask_b}),
        .s_axi_aruser       ({m_axi_aruser_2, m_axi_aruser_ooc, m_axi_aruser_nuc_b, m_axi_aruser_nuc_k, m_axi_aruser_r8,m_axi_aruser_0, m_axi_aruser_2, m_axi_aruser_tfilter, m_axi_aruser_mask_k, m_axi_aruser_mask_b}),
        .s_axi_arcache      ({m_axi_arcache_2, m_axi_arcache_ooc, m_axi_arcache_nuc_b, m_axi_arcache_nuc_k, m_axi_arcache_r8,m_axi_arcache_0, m_axi_arcache_2, m_axi_arcache_tfilter, m_axi_arcache_mask_k, m_axi_arcache_mask_b}),
        .s_axi_arsize       ({m_axi_arsize_2, m_axi_arsize_ooc, m_axi_arsize_nuc_b, m_axi_arsize_nuc_k, m_axi_arsize_r8,m_axi_arsize_0, m_axi_arsize_2, m_axi_arsize_tfilter, m_axi_arsize_mask_k, m_axi_arsize_mask_b}),
        .s_axi_arlen        ({m_axi_arlen_2, m_axi_arlen_ooc, m_axi_arlen_nuc_b, m_axi_arlen_nuc_k, m_axi_arlen_r8,m_axi_arlen_0, m_axi_arlen_2, m_axi_arlen_tfilter, m_axi_arlen_mask_k, m_axi_arlen_mask_b}),
        .s_axi_arburst      ({m_axi_arburst_2, m_axi_arburst_ooc, m_axi_arburst_nuc_b, m_axi_arburst_nuc_k, m_axi_arburst_r8,m_axi_arburst_0, m_axi_arburst_2, m_axi_arburst_tfilter, m_axi_arburst_mask_k, m_axi_arburst_mask_b}),
        .s_axi_arprot       ({m_axi_arprot_2, m_axi_arprot_ooc, m_axi_arprot_nuc_b, m_axi_arprot_nuc_k, m_axi_arprot_r8,m_axi_arprot_0, m_axi_arprot_2, m_axi_arprot_tfilter, m_axi_arprot_mask_k, m_axi_arprot_mask_b}),
        .s_axi_rdata        ({m_axi_rdata_2_0, m_axi_rdata_ooc, m_axi_rdata_nuc_b, m_axi_rdata_nuc_k, m_axi_rdata_r8,m_axi_rdata_0, m_axi_rdata_2, m_axi_rdata_tfilter, m_axi_rdata_mask_k, m_axi_rdata_mask_b}),
        .s_axi_rresp        ({m_axi_rresp_2_0, m_axi_rresp_ooc, m_axi_rresp_nuc_b, m_axi_rresp_nuc_k, m_axi_rresp_r8,m_axi_rresp_0, m_axi_rresp_2, m_axi_rresp_tfilter, m_axi_rresp_mask_k, m_axi_rresp_mask_b}),
        .s_axi_rvalid       ({m_axi_rvalid_2_0, m_axi_rvalid_ooc, m_axi_rvalid_nuc_b, m_axi_rvalid_nuc_k, m_axi_rvalid_r8,m_axi_rvalid_0, m_axi_rvalid_2, m_axi_rvalid_tfilter, m_axi_rvalid_mask_k, m_axi_rvalid_mask_b}),
        .s_axi_rlast        ({m_axi_rlast_2_0, m_axi_rlast_ooc, m_axi_rlast_nuc_b, m_axi_rlast_nuc_k, m_axi_rlast_r8,m_axi_rlast_0, m_axi_rlast_2, m_axi_rlast_tfilter, m_axi_rlast_mask_k, m_axi_rlast_mask_b}),
        .s_axi_rready       ({m_axi_rready_2, m_axi_rready_ooc, m_axi_rready_nuc_b, m_axi_rready_nuc_k, m_axi_rready_r8,m_axi_rready_0, m_axi_rready_2, m_axi_rready_tfilter, m_axi_rready_mask_k, m_axi_rready_mask_b}),
        .s_axi_arready      ({m_axi_arready_2_0, m_axi_arready_ooc, m_axi_arready_nuc_b, m_axi_arready_nuc_k, m_axi_arready_r8,m_axi_arready_0, m_axi_arready_2, m_axi_arready_tfilter, m_axi_arready_mask_k, m_axi_arready_mask_b}),
        .s_axi_wvalid       (),
        .s_axi_wlast        (),
        .s_axi_bready       (),
        .s_axi_bresp        (),
        .s_axi_arlock       (),
        .s_axi_bid          (),
        .s_axi_rid          (),
        .s_axi_wdata        (),
        .s_axi_bvalid       (), 
        .s_axi_wstrb        (),
        .s_axi_wready       (),
        .s_axi_awvalid      (),
        .s_axi_awaddr       (),
        .s_axi_awlock       (),
        .s_axi_awready      (),
        .s_axi_arid         ({10{8'hfe}}),
        .s_axi_awprot       (),
        .s_axi_awcache      (),
        .s_axi_awqos        (),
        .s_axi_awuser       (),
        .s_axi_arqos        (),
        .s_axi_awid         (),
        .s_axi_awburst      (),
        .s_axi_awlen        (),
        .s_axi_awsize       (),
        .s_axi_wuser        (),
        .s_axi_buser        (),
        .s_axi_ruser        (),


        
        .m_axi_awvalid          (  ),
        .m_axi_awaddr           (   ),
        .m_axi_awlock           (   ),
        .m_axi_awready          (  ),
        .m_axi_arvalid          (m_axi_arvalid  ),
        .m_axi_araddr           (m_axi_araddr   ),
        .m_axi_arlock           (m_axi_arlock   ),
        .m_axi_arready          (m_axi_arready  ),
        .m_axi_wvalid           (   ),
        .m_axi_wlast            (    ),
        .m_axi_bready           (   ),
        .m_axi_bresp            (    ),
        .m_axi_rready           (m_axi_rready   ),
        .m_axi_bid              (      ),
        .m_axi_rid              (m_axi_rid      ),
        .m_axi_wdata            (    ),
        .m_axi_rdata            (m_axi_rdata    ),
        .m_axi_rresp            (m_axi_rresp    ),
        .m_axi_bvalid           (   ),
        .m_axi_rvalid           (m_axi_rvalid   ),
        .m_axi_rlast            (m_axi_rlast    ),
        .m_axi_wstrb            (    ),
        .m_axi_wready           (   ),
        .m_axi_awprot           (   ),
        .m_axi_awid             (     ),
        .m_axi_awburst          (  ),
        .m_axi_awlen            (    ),
        .m_axi_awsize           (   ),
        .m_axi_awcache          (  ),
        .m_axi_awqos            (    ),
        .m_axi_awuser           (   ),
        .m_axi_arprot           (m_axi_arprot   ),
        .m_axi_arburst          (m_axi_arburst  ),
        .m_axi_arlen            (m_axi_arlen    ),
        .m_axi_arsize           (m_axi_arsize   ),
        .m_axi_arcache          (m_axi_arcache  ),
        .m_axi_arqos            (m_axi_arqos    ),
        .m_axi_aruser           (m_axi_aruser   ),
        .m_axi_awregion         ( ),
        .m_axi_arregion         (m_axi_arregion ),
        .m_axi_arid             (m_axi_arid     ),
        .m_axi_wuser            (    ),
        .m_axi_ruser            (m_axi_ruser    ),
        .m_axi_buser            (    )
    );
    // ---------------------------- axi-interconnect end -----------------------


//-----------------------------------------------------------------------------------axi-interconnect ????? begin----------------------------------------------------------------------------------------------------------------------


    // risc??ip?????
    wire axiA_awready;
    wire  [7:0] axiA_awlen;
    wire  [2:0] axiA_awsize;
    wire  [1:0] axiA_arburst;
    wire  axiA_awlock;
    wire  [3:0] axiA_arcache;
    wire  [3:0] axiA_awqos;
    wire  [2:0] axiA_awprot;
    wire  [2:0] axiA_arsize;
    wire  [3:0] axiA_arregion;
    wire axiA_arready;
    wire  [3:0] axiA_arqos;
    wire  [2:0] axiA_arprot;
    wire  axiA_arlock;
    wire  [7:0] axiA_arlen;
    wire  [7:0] axiA_arid;
    wire  [3:0] axiA_awcache;
    wire  [1:0] axiA_awburst;
    wire  [31:0] axiA_awaddr;
    wire axiAInterrupt;
    wire axiA_rlast;
    wire  [31:0] axiA_araddr;
    wire  axiA_wvalid;
    wire axiA_wready;
    wire  [31:0] axiA_wdata;
    wire  [3:0] axiA_wstrb;
    wire  axiA_wlast;
    wire axiA_bvalid;
    wire  axiA_bready;
    wire [7:0] axiA_bid;
    wire [1:0] axiA_bresp;
    wire axiA_rvalid;
    wire  axiA_rready;
    wire [31:0] axiA_rdata;
    wire [7:0] axiA_rid;
    wire [1:0] axiA_rresp;
    wire  axiA_arvalid;
    wire  [7:0] axiA_awid;
    wire  [3:0] axiA_awregion;
    wire  axiA_awvalid;


    //???ip????????axi_interconnected
    axi_interconnect #(
        .S_COUNT        (1),
        .M_COUNT        (24),
        .M_BASE_ADDR    ({32'he1001000, 32'he1002000, 32'he1003000, 32'he1005000, 32'he1008000, 32'he1009000, 32'he100a000, 32'he100c000, 32'he100d000, 32'he100e000, 32'he100f000, 32'he1010000, 32'he1011000, 32'he1013000, 32'he1014000, 32'he1015000, 32'he1016000, 32'he1017000, 32'he1018000, 32'he1019000, 32'he1020000, 32'he1030000, 32'he1040000, 32'he1041000}),
        .M_ADDR_WIDTH   ({{21{32'd12}},32'd14,32'd12,32'd12})
    )risc2ip(
        .rst ( !systemClk_locked_delay ),
        .clk ( io_systemClk ),
        // ???riscV
        .s_axi_awvalid ( axiA_awvalid ),
        .s_axi_awaddr ( axiA_awaddr ),
        .s_axi_awlock ( axiA_awlock ),
        .s_axi_awready ( axiA_awready ),
        .s_axi_arvalid ( axiA_arvalid ),
        .s_axi_araddr ( axiA_araddr ),
        .s_axi_arlock ( axiA_arlock ),
        .s_axi_arready ( axiA_arready ),
        .s_axi_wvalid ( axiA_wvalid ),
        .s_axi_wlast ( axiA_wlast ),
        .s_axi_bready ( axiA_bready ),
        .s_axi_bresp ( axiA_bresp ),
        .s_axi_rready ( axiA_rready ),
        .s_axi_bid ( axiA_bid ),
        .s_axi_rid ( axiA_rid ),
        .s_axi_wdata ( axiA_wdata ),
        .s_axi_rdata ( axiA_rdata ),
        .s_axi_rresp ( axiA_rresp ),
        .s_axi_bvalid ( axiA_bvalid ),
        .s_axi_rvalid ( axiA_rvalid ),
        .s_axi_rlast ( axiA_rlast ),
        .s_axi_wstrb ( axiA_wstrb ),
        .s_axi_wready ( axiA_wready ),
        .s_axi_awprot ( axiA_awprot ),
        .s_axi_awcache ( axiA_awcache ),
        .s_axi_awqos ( axiA_awqos ),
        .s_axi_awuser ( axiA_awuser ),
        .s_axi_arqos ( axiA_arqos ),
        .s_axi_arcache ( axiA_arcache ),
        .s_axi_arid ( axiA_arid ),
        .s_axi_arsize ( axiA_arsize ),
        .s_axi_arlen ( axiA_arlen ),
        .s_axi_arburst ( axiA_arburst ),
        .s_axi_arprot ( axiA_arprot ),
        .s_axi_awid ( axiA_awid ),
        .s_axi_awburst ( axiA_awburst ),
        .s_axi_awlen ( axiA_awlen ),
        .s_axi_awsize ( axiA_awsize ),
        .s_axi_aruser ( axiA_aruser ),
        .s_axi_wuser ( axiA_wuser ),
        .s_axi_buser ( axiA_buser ),
        .s_axi_ruser ( axiA_ruser ),
        //???ip
        .m_axi_awvalid          ( {s00_axi_awvalid, s01_axi_awvalid, s02_axi_awvalid, s04_axi_awvalid, s06_axi_awvalid, s07_axi_awvalid,s08_axi_awvalid, s09_axi_awvalid, s11_axi_awvalid, s12_axi_awvalid, s13_axi_awvalid, s14_axi_awvalid, s15_axi_awvalid, s16_axi_awvalid, s18_axi_awvalid, s19_axi_awvalid, s20_axi_awvalid, s21_axi_awvalid, s22_axi_awvalid, s23_axi_awvalid, s24_axi_awvalid, s31_axi_awvalid, s47_axi_awvalid, s63_axi_awvalid, s64_axi_awvalid}),
        .m_axi_awaddr           ( {s00_axi_awaddr , s01_axi_awaddr , s02_axi_awaddr , s04_axi_awaddr , s06_axi_awaddr , s07_axi_awaddr ,s08_axi_awaddr , s09_axi_awaddr , s11_axi_awaddr , s12_axi_awaddr , s13_axi_awaddr , s14_axi_awaddr , s15_axi_awaddr , s16_axi_awaddr , s18_axi_awaddr , s19_axi_awaddr , s20_axi_awaddr , s21_axi_awaddr , s22_axi_awaddr , s23_axi_awaddr , s24_axi_awaddr , s31_axi_awaddr , s47_axi_awaddr , s63_axi_awaddr , s64_axi_awaddr }),
        .m_axi_awready          ( {s00_axi_awready, s01_axi_awready, s02_axi_awready, s04_axi_awready, s06_axi_awready, s07_axi_awready,s08_axi_awready, s09_axi_awready, s11_axi_awready, s12_axi_awready, s13_axi_awready, s14_axi_awready, s15_axi_awready, s16_axi_awready, s18_axi_awready, s19_axi_awready, s20_axi_awready, s21_axi_awready, s22_axi_awready, s23_axi_awready, s24_axi_awready, s31_axi_awready, s47_axi_awready, s63_axi_awready, s64_axi_awready}),
        .m_axi_arvalid          ( {s00_axi_arvalid, s01_axi_arvalid, s02_axi_arvalid, s04_axi_arvalid, s06_axi_arvalid, s07_axi_arvalid,s08_axi_arvalid, s09_axi_arvalid, s11_axi_arvalid, s12_axi_arvalid, s13_axi_arvalid, s14_axi_arvalid, s15_axi_arvalid, s16_axi_arvalid, s18_axi_arvalid, s19_axi_arvalid, s20_axi_arvalid, s21_axi_arvalid, s22_axi_arvalid, s23_axi_arvalid, s24_axi_arvalid, s31_axi_arvalid, s47_axi_arvalid, s63_axi_arvalid, s64_axi_arvalid}),
        .m_axi_araddr           ( {s00_axi_araddr , s01_axi_araddr , s02_axi_araddr , s04_axi_araddr , s06_axi_araddr , s07_axi_araddr ,s08_axi_araddr , s09_axi_araddr , s11_axi_araddr , s12_axi_araddr , s13_axi_araddr , s14_axi_araddr , s15_axi_araddr , s16_axi_araddr , s18_axi_araddr , s19_axi_araddr , s20_axi_araddr , s21_axi_araddr , s22_axi_araddr , s23_axi_araddr , s24_axi_araddr , s31_axi_araddr , s47_axi_araddr , s63_axi_araddr , s64_axi_araddr }),
        .m_axi_arready          ( {s00_axi_arready, s01_axi_arready, s02_axi_arready, s04_axi_arready, s06_axi_arready, s07_axi_arready,s08_axi_arready, s09_axi_arready, s11_axi_arready, s12_axi_arready, s13_axi_arready, s14_axi_arready, s15_axi_arready, s16_axi_arready, s18_axi_arready, s19_axi_arready, s20_axi_arready, s21_axi_arready, s22_axi_arready, s23_axi_arready, s24_axi_arready, s31_axi_arready, s47_axi_arready, s63_axi_arready, s64_axi_arready}),
        .m_axi_wvalid           ( {s00_axi_wvalid , s01_axi_wvalid , s02_axi_wvalid , s04_axi_wvalid , s06_axi_wvalid , s07_axi_wvalid ,s08_axi_wvalid , s09_axi_wvalid , s11_axi_wvalid , s12_axi_wvalid , s13_axi_wvalid , s14_axi_wvalid , s15_axi_wvalid , s16_axi_wvalid , s18_axi_wvalid , s19_axi_wvalid , s20_axi_wvalid , s21_axi_wvalid , s22_axi_wvalid , s23_axi_wvalid , s24_axi_wvalid , s31_axi_wvalid , s47_axi_wvalid , s63_axi_wvalid , s64_axi_wvalid }),
        .m_axi_bready           ( {s00_axi_bready , s01_axi_bready , s02_axi_bready , s04_axi_bready , s06_axi_bready , s07_axi_bready ,s08_axi_bready , s09_axi_bready , s11_axi_bready , s12_axi_bready , s13_axi_bready , s14_axi_bready , s15_axi_bready , s16_axi_bready , s18_axi_bready , s19_axi_bready , s20_axi_bready , s21_axi_bready , s22_axi_bready , s23_axi_bready , s24_axi_bready , s31_axi_bready , s47_axi_bready , s63_axi_bready , s64_axi_bready }),
        .m_axi_bresp            ( {s00_axi_bresp  , s01_axi_bresp  , s02_axi_bresp  , s04_axi_bresp  , s07_axi_bresp  ,s08_axi_bresp  , s09_axi_bresp  , s11_axi_bresp  , s12_axi_bresp  , s13_axi_bresp  , s14_axi_bresp  , s15_axi_bresp  , s16_axi_bresp  , s18_axi_bresp  , s19_axi_bresp  , s20_axi_bresp  , s21_axi_bresp  , s22_axi_bresp  , s23_axi_bresp  , s24_axi_bresp  , s31_axi_bresp  , s47_axi_bresp  , s63_axi_bresp  , s64_axi_bresp  }),
        .m_axi_rready           ( {s00_axi_rready , s01_axi_rready , s02_axi_rready , s04_axi_rready , s07_axi_rready ,s08_axi_rready , s09_axi_rready , s11_axi_rready , s12_axi_rready , s13_axi_rready , s14_axi_rready , s15_axi_rready , s16_axi_rready , s18_axi_rready , s19_axi_rready , s20_axi_rready , s21_axi_rready , s22_axi_rready , s23_axi_rready , s24_axi_rready , s31_axi_rready , s47_axi_rready , s63_axi_rready , s64_axi_rready }),
        .m_axi_wdata            ( {s00_axi_wdata  , s01_axi_wdata  , s02_axi_wdata  , s04_axi_wdata  , s06_axi_wdata  , s07_axi_wdata  ,s08_axi_wdata  , s09_axi_wdata  , s11_axi_wdata  , s12_axi_wdata  , s13_axi_wdata  , s14_axi_wdata  , s15_axi_wdata  , s16_axi_wdata  , s18_axi_wdata  , s19_axi_wdata  , s20_axi_wdata  , s21_axi_wdata  , s22_axi_wdata  , s23_axi_wdata  , s24_axi_wdata  , s31_axi_wdata  , s47_axi_wdata  , s63_axi_wdata  , s64_axi_wdata  }),
        .m_axi_bresp            ( {s00_axi_bresp  , s01_axi_bresp  , s02_axi_bresp  , s04_axi_bresp  , s06_axi_bresp  , s07_axi_bresp  ,s08_axi_bresp  , s09_axi_bresp  , s11_axi_bresp  , s12_axi_bresp  , s13_axi_bresp  , s14_axi_bresp  , s15_axi_bresp  , s16_axi_bresp  , s18_axi_bresp  , s19_axi_bresp  , s20_axi_bresp  , s21_axi_bresp  , s22_axi_bresp  , s23_axi_bresp  , s24_axi_bresp  , s31_axi_bresp  , s47_axi_bresp  , s63_axi_bresp  , s64_axi_bresp  }),
        .m_axi_rdata            ( {s00_axi_rdata  , s01_axi_rdata  , s02_axi_rdata  , s04_axi_rdata  , s06_axi_rdata  , s07_axi_rdata  ,s08_axi_rdata  , s09_axi_rdata  , s11_axi_rdata  , s12_axi_rdata  , s13_axi_rdata  , s14_axi_rdata  , s15_axi_rdata  , s16_axi_rdata  , s18_axi_rdata  , s19_axi_rdata  , s20_axi_rdata  , s21_axi_rdata  , s22_axi_rdata  , s23_axi_rdata  , s24_axi_rdata  , s31_axi_rdata  , s47_axi_rdata  , s63_axi_rdata  , s64_axi_rdata  }),
        .m_axi_rresp            ( {s00_axi_rresp  , s01_axi_rresp  , s02_axi_rresp  , s04_axi_rresp  , s06_axi_rresp  , s07_axi_rresp  ,s08_axi_rresp  , s09_axi_rresp  , s11_axi_rresp  , s12_axi_rresp  , s13_axi_rresp  , s14_axi_rresp  , s15_axi_rresp  , s16_axi_rresp  , s18_axi_rresp  , s19_axi_rresp  , s20_axi_rresp  , s21_axi_rresp  , s22_axi_rresp  , s23_axi_rresp  , s24_axi_rresp  , s31_axi_rresp  , s47_axi_rresp  , s63_axi_rresp  , s64_axi_rresp  }),
        .m_axi_bvalid           ( {s00_axi_bvalid , s01_axi_bvalid , s02_axi_bvalid , s04_axi_bvalid , s06_axi_bvalid , s07_axi_bvalid ,s08_axi_bvalid , s09_axi_bvalid , s11_axi_bvalid , s12_axi_bvalid , s13_axi_bvalid , s14_axi_bvalid , s15_axi_bvalid , s16_axi_bvalid , s18_axi_bvalid , s19_axi_bvalid , s20_axi_bvalid , s21_axi_bvalid , s22_axi_bvalid , s23_axi_bvalid , s24_axi_bvalid , s31_axi_bvalid , s47_axi_bvalid , s63_axi_bvalid , s64_axi_bvalid }),
        .m_axi_rvalid           ( {s00_axi_rvalid , s01_axi_rvalid , s02_axi_rvalid , s04_axi_rvalid , s06_axi_rvalid , s07_axi_rvalid ,s08_axi_rvalid , s09_axi_rvalid , s11_axi_rvalid , s12_axi_rvalid , s13_axi_rvalid , s14_axi_rvalid , s15_axi_rvalid , s16_axi_rvalid , s18_axi_rvalid , s19_axi_rvalid , s20_axi_rvalid , s21_axi_rvalid , s22_axi_rvalid , s23_axi_rvalid , s24_axi_rvalid , s31_axi_rvalid , s47_axi_rvalid , s63_axi_rvalid , s64_axi_rvalid }),
        .m_axi_wstrb            ( {s00_axi_wstrb  , s01_axi_wstrb  , s02_axi_wstrb  , s04_axi_wstrb  , s06_axi_wstrb  , s07_axi_wstrb  ,s08_axi_wstrb  , s09_axi_wstrb  , s11_axi_wstrb  , s12_axi_wstrb  , s13_axi_wstrb  , s14_axi_wstrb  , s15_axi_wstrb  , s16_axi_wstrb  , s18_axi_wstrb  , s19_axi_wstrb  , s20_axi_wstrb  , s21_axi_wstrb  , s22_axi_wstrb  , s23_axi_wstrb  , s24_axi_wstrb  , s31_axi_wstrb  , s47_axi_wstrb  , s63_axi_wstrb  , s64_axi_wstrb  }),
        .m_axi_wready           ( {s00_axi_wready , s01_axi_wready , s02_axi_wready , s04_axi_wready , s06_axi_wready , s07_axi_wready ,s08_axi_wready , s09_axi_wready , s11_axi_wready , s12_axi_wready , s13_axi_wready , s14_axi_wready , s15_axi_wready , s16_axi_wready , s18_axi_wready , s19_axi_wready , s20_axi_wready , s21_axi_wready , s22_axi_wready , s23_axi_wready , s24_axi_wready , s31_axi_wready , s47_axi_wready , s63_axi_wready , s64_axi_wready }),
        .m_axi_awprot           ( {s00_axi_awprot , s01_axi_awprot , s02_axi_awprot , s04_axi_awprot , s06_axi_awprot , s07_axi_awprot ,s08_axi_awprot , s09_axi_awprot , s11_axi_awprot , s12_axi_awprot , s13_axi_awprot , s14_axi_awprot , s15_axi_awprot , s16_axi_awprot , s18_axi_awprot , s19_axi_awprot , s20_axi_awprot , s21_axi_awprot , s22_axi_awprot , s23_axi_awprot , s24_axi_awprot , s31_axi_awprot , s47_axi_awprot , s63_axi_awprot , s64_axi_awprot }),
        .m_axi_arprot           ( {s00_axi_arprot , s01_axi_arprot , s02_axi_arprot , s04_axi_arprot , s06_axi_arprot , s07_axi_arprot ,s08_axi_arprot , s09_axi_arprot , s11_axi_arprot , s12_axi_arprot , s13_axi_arprot , s14_axi_arprot , s15_axi_arprot , s16_axi_arprot , s18_axi_arprot , s19_axi_arprot , s20_axi_arprot , s21_axi_arprot , s22_axi_arprot , s23_axi_arprot , s24_axi_arprot , s31_axi_arprot , s47_axi_arprot , s63_axi_arprot , s64_axi_arprot }),
        .m_axi_arlock           (  ),
        .m_axi_wlast            (  ),
        .m_axi_bid              (  ),
        .m_axi_rid              (  ),
        .m_axi_rlast            ( {24{1'b1}} ),
        .m_axi_awlock           (  ),
        .m_axi_awid             (  ),
        .m_axi_awburst          (  ),
        .m_axi_awlen            (  ),
        .m_axi_awsize           (  ),
        .m_axi_awcache          (  ),
        .m_axi_awqos            (  ),
        .m_axi_awuser           (  ),
        .m_axi_arburst          (  ),
        .m_axi_arlen            (  ),
        .m_axi_arsize           (  ),
        .m_axi_arcache          (  ),
        .m_axi_arqos            (  ),
        .m_axi_aruser           (  ),
        .m_axi_awregion         (  ),
        .m_axi_arregion         (  ),
        .m_axi_arid             (  ),
        .m_axi_wuser            (  ),
        .m_axi_ruser            (  ),
        .m_axi_buser            (  )
    );

//-----------------------------------------------------------------------------------axi-interconnect ????? end------------------------------------------------------------------------------------------------------------------------


//-----------------------------------------------------------------------------------axi-interconnect ????? end------------------------------------------------------------------------------------------------------------------------

    riscv soc_inst (
        .jtagCtrl_tck(jtag_inst1_TCK),
        .jtagCtrl_tdi(jtag_inst1_TDI),
        .jtagCtrl_tdo(jtag_inst1_TDO),
        .jtagCtrl_enable(jtag_inst1_SEL),
        .jtagCtrl_capture(jtag_inst1_CAPTURE),
        .jtagCtrl_shift(jtag_inst1_SHIFT),
        .jtagCtrl_update(jtag_inst1_UPDATE),
        .jtagCtrl_reset(jtag_inst1_RESET),

        .system_spi_0_io_ss                (CFG_nCSO),
        .system_spi_0_io_sclk_write        (CFG_DCLK),
        .system_spi_0_io_data_0_read       (CFG_D0_IN),
        .system_spi_0_io_data_0_write      (CFG_D0_OUT),
        .system_spi_0_io_data_0_writeEnable(CFG_D0_OE),
        .system_spi_0_io_data_1_read       (CFG_D1_IN),
        .system_spi_0_io_data_1_write      (CFG_D1_OUT),
        .system_spi_0_io_data_1_writeEnable(CFG_D1_OE),
        .system_spi_0_io_data_2_read       (CFG_D2_IN),
        .system_spi_0_io_data_2_write      (CFG_D2_OUT),
        .system_spi_0_io_data_2_writeEnable(CFG_D2_OE),
        .system_spi_0_io_data_3_read       (CFG_D3_IN),
        .system_spi_0_io_data_3_write      (CFG_D3_OUT),
        .system_spi_0_io_data_3_writeEnable(CFG_D3_OE),

        .system_uart_0_io_txd(uart_tx),
        .system_uart_0_io_rxd(uart_rx),
        .system_gpio_0_io_read(),
        .system_gpio_0_io_write(),
        .system_gpio_0_io_writeEnable(),
        .io_memoryClk(io_memoryClk),
        .io_memoryReset(io_memoryReset),
        .io_ddrA_arw_valid(io_ddrA_arw_valid_0),
        .io_ddrA_arw_ready(io_ddrA_arw_ready_0),
        .io_ddrA_arw_payload_addr(io_ddrA_arw_payload_addr_0),
        .io_ddrA_arw_payload_id(io_ddrA_arw_payload_id_0),
        .io_ddrA_arw_payload_len(io_ddrA_arw_payload_len_0),
        .io_ddrA_arw_payload_size(io_ddrA_arw_payload_size_0),
        .io_ddrA_arw_payload_burst(io_ddrA_arw_payload_burst_0),
        .io_ddrA_arw_payload_lock(io_ddrA_arw_payload_lock_0),
        .io_ddrA_arw_payload_write(io_ddrA_arw_payload_write_0),
        .io_ddrA_arw_payload_prot(),
        .io_ddrA_arw_payload_qos(),
        .io_ddrA_arw_payload_cache(),
        .io_ddrA_arw_payload_region(),
        .io_ddrA_w_payload_id(io_ddrA_w_payload_id_0),
        .io_ddrA_w_valid(io_ddrA_w_valid_0),
        .io_ddrA_w_ready(io_ddrA_w_ready_0),
        .io_ddrA_w_payload_data(io_ddrA_w_payload_data_0),
        .io_ddrA_w_payload_strb(io_ddrA_w_payload_strb_0),
        .io_ddrA_w_payload_last(io_ddrA_w_payload_last_0),
        .io_ddrA_b_valid(io_ddrA_b_valid_0),
        .io_ddrA_b_ready(io_ddrA_b_ready_0),
        .io_ddrA_b_payload_id(io_ddrA_b_payload_id_0),
        .io_ddrA_b_payload_resp(),
        .io_ddrA_r_valid(io_ddrA_r_valid_0),
        .io_ddrA_r_ready(io_ddrA_r_ready_0),
        .io_ddrA_r_payload_data(io_ddrA_r_payload_data_0),
        .io_ddrA_r_payload_id(io_ddrA_r_payload_id_0),
        .io_ddrA_r_payload_resp(io_ddrA_r_payload_resp_0),
        .io_ddrA_r_payload_last(io_ddrA_r_payload_last_0),
        .io_systemClk(io_systemClk),
        .io_asyncReset(reset),
        .io_systemReset(io_systemReset),
        .io_ddrMasters_0_clk(io_memoryClk), // fix synthesis error

        // ip?????
        .axiA_awready ( axiA_awready ),
        .axiA_awlen ( axiA_awlen ),
        .axiA_awsize ( axiA_awsize ),
        .axiA_arburst ( axiA_arburst ),
        .axiA_awlock ( axiA_awlock ),
        .axiA_arcache ( axiA_arcache ),
        .axiA_awqos ( axiA_awqos ),
        .axiA_awprot ( axiA_awprot ),
        .axiA_arsize ( axiA_arsize ),
        .axiA_arregion ( axiA_arregion ),
        .axiA_arready ( axiA_arready ),
        .axiA_arqos ( axiA_arqos ),
        .axiA_arprot ( axiA_arprot ),
        .axiA_arlock ( axiA_arlock ),
        .axiA_arlen ( axiA_arlen ),
        .axiA_arid ( axiA_arid ),
        .axiA_awcache ( axiA_awcache ),
        .axiA_awburst ( axiA_awburst ),
        .axiA_awaddr ( axiA_awaddr ),
        .axiAInterrupt ( axiAInterrupt ),
        .axiA_rlast ( axiA_rlast ),
        .axiA_araddr ( axiA_araddr ),
        .axiA_wvalid ( axiA_wvalid ),
        .axiA_wready ( axiA_wready ),
        .axiA_wdata ( axiA_wdata ),
        .axiA_wstrb ( axiA_wstrb ),
        .axiA_wlast ( axiA_wlast ),
        .axiA_bvalid ( axiA_bvalid ),
        .axiA_bready ( axiA_bready ),
        .axiA_bid ( axiA_bid ),
        .axiA_bresp ( axiA_bresp ),
        .axiA_rvalid ( axiA_rvalid ),
        .axiA_rready ( axiA_rready ),
        .axiA_rdata ( axiA_rdata ),
        .axiA_rid ( axiA_rid ),
        .axiA_rresp ( axiA_rresp ),
        .axiA_arvalid ( axiA_arvalid ),
        .axiA_awid ( axiA_awid ),
        .axiA_awregion ( axiA_awregion ),
        .axiA_awvalid ( axiA_awvalid )		
    );


    ddr_reset u_ddr_reset (
     .ddr_rstn_i (systemClk_locked_delay),
     .clk (io_memoryClk),
     .ddr_rstn (ddr_inst1_CFG_RST_N),
     .ddr_cfg_seq_rst (ddr_inst1_CFG_SEQ_RST),
     .ddr_cfg_seq_start(ddr_inst1_CFG_SEQ_START),
     .ddr_init_done()
    );

    Axi4FullDeplex #(
        .AXI_DATA_WIDTH     (128)
    )
    Axi4FullDeplex
    (
        //System Signal
        .SysClk    (io_memoryClk), //System Clock
        .Reset_N   (systemClk_locked_delay), //System Reset
        //Axi Slave Interfac Signal
        .AWID      (m_axi_awid), //(I)[WrAddr]Write address ID.
        .AWADDR    (m_axi_awaddr), //(I)[WrAddr]Write address.
        .AWLEN     (m_axi_awlen), //(I)[WrAddr]Burst length.
        .AWSIZE    (m_axi_awsize), //(I)[WrAddr]Burst size.
        .AWBURST   (m_axi_awburst), //(I)[WrAddr]Burst type.
        .AWLOCK    ('h0), //(I)[WrAddr]Lock type.
        .AWVALID   (m_axi_awvalid), //(I)[WrAddr]Write address valid.
        .AWREADY   (m_axi_awready), //(O)[WrAddr]Write address ready.
        ///////////
        .WID       ('h0), //(I)[WrData]Write ID tag.
        .WDATA     (m_axi_wdata), //(I)[WrData]Write data.
        .WSTRB     (m_axi_wstrb), //(I)[WrData]Write strobes.
        .WLAST     (m_axi_wlast), //(I)[WrData]Write last.
        .WVALID    (m_axi_wvalid), //(I)[WrData]Write valid.
        .WREADY    (m_axi_wready), //(O)[WrData]Write ready.
        ///////////
        .BID       (m_axi_bid), //(O)[WrResp]Response ID tag.
        .BVALID    (m_axi_bvalid), //(O)[WrResp]Write response valid.
        .BREADY    (m_axi_bready), //(I)[WrResp]Response ready.
        ///////////
        .ARID      (m_axi_arid), //(I)[RdAddr]Read address ID.
        .ARADDR    (m_axi_araddr), //(I)[RdAddr]Read address.
        .ARLEN     (m_axi_arlen), //(I)[RdAddr]Burst length.
        .ARSIZE    (m_axi_arsize), //(I)[RdAddr]Burst size.
        .ARBURST   (m_axi_arburst), //(I)[RdAddr]Burst type.
        .ARLOCK    ('h0), //(I)[RdAddr]Lock type.
        .ARVALID   (m_axi_arvalid), //(I)[RdAddr]Read address valid.
        .ARREADY   (m_axi_arready), //(O)[RdAddr]Read address ready.
        ///////////
        .RID       (m_axi_rid), //(O)[RdData]Read ID tag.
        .RDATA     (m_axi_rdata), //(O)[RdData]Read data.
        .RRESP     (m_axi_rresp), //(O)[RdData]Read response.
        .RLAST     (m_axi_rlast), //(O)[RdData]Read last.
        .RVALID    (m_axi_rvalid), //(O)[RdData]Read valid.
        .RREADY    (m_axi_rready), //(I)[RdData]Read ready.
        /////////////
        //DDR Controner AXI4 Signal
        .aid       (io_ddrA_arw_payload_id), //(O)[Addres] Address ID
        .aaddr     (io_ddrA_arw_payload_addr), //(O)[Addres] Address
        .alen      (io_ddrA_arw_payload_len), //(O)[Addres] Address Brust Length
        .asize     (io_ddrA_arw_payload_size), //(O)[Addres] Address Burst size
        .aburst    (io_ddrA_arw_payload_burst), //(O)[Addres] Address Burst type
        .alock     (io_ddrA_arw_payload_lock), //(O)[Addres] Address Lock type
        .avalid    (io_ddrA_arw_valid), //(O)[Addres] Address Valid
        .aready    (io_ddrA_arw_ready), //(I)[Addres] Address Ready
        .atype     (io_ddrA_arw_payload_write), //(O)[Addres] Operate Type 0=Read, 1=Write
        /////////////
        .wid       (io_ddrA_w_payload_id), //(O)[Write]  ID
        .wdata     (io_ddrA_w_payload_data), //(O)[Write]  Data
        .wstrb     (io_ddrA_w_payload_strb), //(O)[Write]  Data Strobes(Byte valid)
        .wlast     (io_ddrA_w_payload_last), //(O)[Write]  Data Last
        .wvalid    (io_ddrA_w_valid), //(O)[Write]  Data Valid
        .wready    (io_ddrA_w_ready), //(I)[Write]  Data Ready
        /////////////
        .rid       (io_ddrA_r_payload_id), //(I)[Read]   ID
        .rdata     (io_ddrA_r_payload_data), //(I)[Read]   Data
        .rlast     (io_ddrA_r_payload_last), //(I)[Read]   Data Last
        .rvalid    (io_ddrA_r_valid), //(I)[Read]   Data Valid
        .rready    (io_ddrA_r_ready), //(O)[Read]   Data Ready
        .rresp     (io_ddrA_r_payload_resp), //(I)[Read]   Response
        /////////////
        .bid       (io_ddrA_b_payload_id), //(I)[Answer] Response Write ID
        .bvalid    (io_ddrA_b_valid), //(I)[Answer] Response valid
        .bready    (io_ddrA_b_ready)  //(O)[Answer] Response Ready
    );



    assign DE                  = LCD_DE;
    assign OLED_RST            = LCD_RST;
    assign HS                  = LCD_HSYNC;
    assign VS                  = LCD_VSYNC;



  assign {OLED_R, OLED_G, OLED_B} = {LCD_D};



endmodule