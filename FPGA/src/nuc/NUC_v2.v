
`timescale 1 ns / 1 ps

	module NUC_v2 #
	(
		// Users to add parameters here
        parameter FRAME_WIDTH = 384,    
        parameter FRAME_HEIGHT = 288,   
		parameter BPS                = 14,
		parameter BUFFER_NUM         = 1,
		parameter ADDRESSWIDTH       = 32,
		parameter DATAWIDTH_MM       = 128,
		parameter MAXBURSTCOUNT      = 8,
		parameter FIFODEPTH_BYTE     = 2048,
		parameter BASEADDR_MASK_K	 = 32'h10800000,
		parameter BASEADDR_MASK_B	 = 32'h10900000,
		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
        input   wire                                        aclk,
        input   wire                                        aresetn,
		input	wire										go_nuc,
		input	wire										clk_axi,
		input 	wire 	[13 : 0]							mean_b_out,
		input 	wire 	[13 : 0]							Tempera,
		input 	wire 										shutter_en,
        // ---------------------------  axi-stream-slave  ---------- start ------------
        input   wire    [13 : 0]                            s_axis_tdata,
        input   wire                                        s_axis_tlast,
        input   wire                                        s_axis_tvalid,
        input   wire                                        s_axis_tuser,
        output  wire                                        s_axis_tready,
        // ---------------------------  axi-stream-slave  ---------- end ------------
        
        // ---------------------------  axi-stream-master  ---------- start ------------
        
        output  wire    [13 : 0]                            m_axis_tdata,
        output  wire                                        m_axis_tlast,
        output  wire                                        m_axis_tvalid,
        input   wire                                        m_axis_tready,
        output  wire                                        m_axis_tuser,
        
        // ---------------------------  axi-stream-master  ---------- end ------------
        
		// ---------------------------  axi-stream-master_b  ---------- start ------------
        
        output wire		[31 : 0] 							m_axi_araddr_b,
		output wire 	[1 : 0] 							m_axi_arburst_b,
		output wire 	[3 : 0] 							m_axi_arcache_b,
		output wire 	[7 : 0] 							m_axi_arlen_b,
		output wire 	[2 : 0] 							m_axi_arprot_b,
		input  wire 										m_axi_arready_b,
		output wire 	[2 : 0] 							m_axi_arsize_b,
		output wire 	[3 : 0] 							m_axi_aruser_b,
		output wire 										m_axi_arvalid_b,
		input  wire 	[127 : 0] 							m_axi_rdata_b,
		input  wire 										m_axi_rlast_b,
		output wire 										m_axi_rready_b,
		input  wire 	[1 : 0] 							m_axi_rresp_b,
		input  wire 										m_axi_rvalid_b,
    
        // ---------------------------  axi-stream-master_b  ---------- end ------------

		// ---------------------------  axi-stream-master_k  ---------- start ------------
        
        output wire		[31 : 0] 							m_axi_araddr_k,
		output wire 	[1 : 0] 							m_axi_arburst_k,
		output wire 	[3 : 0] 							m_axi_arcache_k,
		output wire 	[7 : 0] 							m_axi_arlen_k,
		output wire 	[2 : 0] 							m_axi_arprot_k,
		input  wire 										m_axi_arready_k,
		output wire 	[2 : 0] 							m_axi_arsize_k,
		output wire 	[3 : 0] 							m_axi_aruser_k,
		output wire 										m_axi_arvalid_k,
		input  wire 	[127 : 0] 							m_axi_rdata_k,
		input  wire 										m_axi_rlast_k,
		output wire 										m_axi_rready_k,
		input  wire 	[1 : 0] 							m_axi_rresp_k,
		input  wire 										m_axi_rvalid_k,
    
        // ---------------------------  axi-stream-master_k  ---------- end ------------

		// ---------------------------  axi-stream-master_low  ---------- start ------------
        
        output wire		[31 : 0] 							m_axi_araddr_mask_k,
		output wire 	[1 : 0] 							m_axi_arburst_mask_k,
		output wire 	[3 : 0] 							m_axi_arcache_mask_k,
		output wire 	[7 : 0] 							m_axi_arlen_mask_k,
		output wire 	[2 : 0] 							m_axi_arprot_mask_k,
		input  wire 										m_axi_arready_mask_k,
		output wire 	[2 : 0] 							m_axi_arsize_mask_k,
		output wire 	[3 : 0] 							m_axi_aruser_mask_k,
		output wire 										m_axi_arvalid_mask_k,
		input  wire 	[127 : 0] 							m_axi_rdata_mask_k,
		input  wire 										m_axi_rlast_mask_k,
		output wire 										m_axi_rready_mask_k,
		input  wire 	[1 : 0] 							m_axi_rresp_mask_k,
		input  wire 										m_axi_rvalid_mask_k,

        output wire		[31 : 0] 							m_axi_araddr_mask_b,
		output wire 	[1 : 0] 							m_axi_arburst_mask_b,
		output wire 	[3 : 0] 							m_axi_arcache_mask_b,
		output wire 	[7 : 0] 							m_axi_arlen_mask_b,
		output wire 	[2 : 0] 							m_axi_arprot_mask_b,
		input  wire 										m_axi_arready_mask_b,
		output wire 	[2 : 0] 							m_axi_arsize_mask_b,
		output wire 	[3 : 0] 							m_axi_aruser_mask_b,
		output wire 										m_axi_arvalid_mask_b,
		input  wire 	[127 : 0] 							m_axi_rdata_mask_b,
		input  wire 										m_axi_rlast_mask_b,
		output wire 										m_axi_rready_mask_b,
		input  wire 	[1 : 0] 							m_axi_rresp_mask_b,
		input  wire 										m_axi_rvalid_mask_b,
    
        // ---------------------------  axi-stream-master_k  ---------- end ------------

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);

	localparam FRACTION_BIT = 8;
	localparam LATENCY = 5;

	function integer clogb2 (input integer bit_depth);
	  begin
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
	      bit_depth = bit_depth >> 1;
	  end
	endfunction

	function [BPS-1:0] min;
		input [BPS-1:0] a, b, c;
		begin
			min = (a < b) ? ((a < c) ? a : c) : ((b < c) ? b : c);
		end
	endfunction

	function [BPS-1:0] med;
		input [BPS-1:0] a, b, c;
		begin
			med = (a < b) ? ((b < c) ? b : (a < c ? c : a)) : ((b > c) ? b : (a > c ? c : a));
		end
	endfunction

	function [BPS-1:0] max;
		input [BPS-1:0] a, b, c;
		begin
			max = (a > b) ? ((a > c) ? a : c) : ((b > c) ? b : c);
		end
	endfunction


    wire [13:0] mean_b;
	wire [13:0] mean_b_low;

    wire [13:0] Tempera_high;
    wire [13:0] Tempera_low;

	reg [13:0] mean_b_r[0:1];
	reg [13:0] mean_b_low_r[0:1];
	reg [13:0] Tempera_low_r[0:1];
	reg [13:0] Tempera_high_r[0:1];

    wire [31:0] read_base_b;
    wire [31:0] read_base_k;

// Instantiation of Axi Bus Interface S00_AXI
	NUC_v2_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) NUC_v2_S00_AXI_inst (
	    // .set_go(set_go),
		.Tempera_high(Tempera_high),
		.Tempera_low(Tempera_low),
	    .mean_b(mean_b),
	    .read_base_b(read_base_b),
	    .read_base_k(read_base_k),
		.mean_b_low(mean_b_low),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);


	always @(posedge aclk or negedge aresetn)begin
		if(!aresetn)begin
			mean_b_r[0] <= 'd0;
			mean_b_r[1] <= 'd0;
			mean_b_low_r[0] <= 'd0; 
			mean_b_low_r[1] <= 'd0; 
			Tempera_low_r[0] <= 'd0;
			Tempera_low_r[1] <= 'd0;
			Tempera_high_r[0] <= 'd0;
			Tempera_high_r[1] <= 'd0;
		end
		else begin
			mean_b_r[0] <= mean_b;
			mean_b_r[1] <= mean_b_r[0];
			mean_b_low_r[0] <= mean_b_low; 
			mean_b_low_r[1] <= mean_b_low_r[0]; 	
			Tempera_low_r[0] <= Tempera_low;
			Tempera_low_r[1] <= Tempera_low_r[0];
			Tempera_high_r[0] <= Tempera_high;
			Tempera_high_r[1] <= Tempera_high_r[0];
		end
		
	end

	// Add user logic here
	wire [3 : 0] writer_base_index;
	wire [3 : 0] reader_base_index;
    wire [3 : 0] writer_base_index_1;
	wire [3 : 0] reader_base_index_1;
	wire go;
	reg go_r;
	wire [1 : 0] mode;
	wire [15 : 0] width;
	wire [15 : 0] height;
	wire [31 : 0] baseaddr_b;
	wire [31 : 0] baseaddr_k;
	wire [31:0]baseaddr_mask_k;
	wire [31:0]baseaddr_mask_b;
	assign writer_base_index = 4'b1;
    assign writer_base_index_1 = 4'b1;
	assign go = go_r;
	assign mode = 2'b0;
	assign width = FRAME_WIDTH;
	assign height = FRAME_HEIGHT;
	assign baseaddr_k = read_base_k;
	assign baseaddr_b = read_base_b;
	assign baseaddr_mask_k = BASEADDR_MASK_K;
	assign baseaddr_mask_b = BASEADDR_MASK_B;
	
	assign set_go = go_nuc;
	
	reg [clogb2(FRAME_WIDTH * FRAME_HEIGHT)-1 : 0] cnt_din;
	always @(posedge aclk or negedge aresetn)
    if (!aresetn) begin
		cnt_din <= 0;
		go_r <= 0;
	end
	else begin
		if (s_axis_tvalid & s_axis_tready) begin
			if (cnt_din >= FRAME_WIDTH * FRAME_HEIGHT - 1) begin
				cnt_din <= 0;
				go_r <= set_go;
			end
			else begin
				cnt_din <= cnt_din + 1;
			end
		end

	end


	reg [31:0]clk_freq;
	always @(posedge aclk or negedge aresetn)begin
    	if (!aresetn) begin
			clk_freq <= 'd0;
		end
		else begin
			if((cnt_din >= FRAME_WIDTH * FRAME_HEIGHT - 1) && s_axis_tvalid && s_axis_tready)
				clk_freq <= 'd0;
			else 
				clk_freq <= clk_freq + 1;
		end
	end


	
	wire 	[13 : 0] m_axis_tdata_b;
	wire 	m_axis_tlast_b;
	wire 	m_axis_tvalid_b;
	wire 	m_axis_tready_b;
	wire 	m_axis_tuser_b;

	wire 	[15 : 0] m_axis_tdata_k;
	wire 	m_axis_tlast_k;
	wire 	m_axis_tvalid_k;
	wire 	m_axis_tready_k;
	wire 	m_axis_tuser_k;

	wire 	[15 : 0] m_axis_tdata_mask_k;
	wire 	m_axis_tlast_mask_k;
	wire 	m_axis_tvalid_mask_k;
	wire 	m_axis_tready_mask_k;
	wire 	m_axis_tuser_mask_k;

	wire 	[15 : 0] m_axis_tdata_mask_b;
	wire 	m_axis_tlast_mask_b;
	wire 	m_axis_tvalid_mask_b;
	wire 	m_axis_tready_mask_b;
	wire 	m_axis_tuser_mask_b;




    axi_video_frame_reader_top_nuc # (
		.BPS								(BPS							),	                	
		.MAX_WIDTH	          				(FRAME_WIDTH	          			),
		.MAX_HEIGHT	         				(FRAME_HEIGHT	         			),
		.BUFFER_NUM	         				(BUFFER_NUM	         			),
		.ADDRESSWIDTH	       				(ADDRESSWIDTH	       			),
		.DATAWIDTH_MM	       				(DATAWIDTH_MM	       			),
		.MAXBURSTCOUNT	      				(MAXBURSTCOUNT	      			),
		.FIFODEPTH_BYTE	     				(FIFODEPTH_BYTE	     			)
	)
	reader_b (
      .clk(clk_axi),                              // input wire clk
      .reset_n(aresetn),                      // input wire reset_n
	  .axis_aclk(aclk),
      .writer_base_index(writer_base_index),  // input wire [3 : 0] writer_base_index
      .reader_base_index(reader_base_index),  // output wire [3 : 0] reader_base_index
      .m_axi_araddr(m_axi_araddr_b),            // output wire [31 : 0] m_axi_araddr
      .m_axi_arburst(m_axi_arburst_b),          // output wire [1 : 0] m_axi_arburst
      .m_axi_arcache(m_axi_arcache_b),          // output wire [3 : 0] m_axi_arcache
      .m_axi_arlen(m_axi_arlen_b),              // output wire [7 : 0] m_axi_arlen
      .m_axi_arprot(m_axi_arprot_b),            // output wire [2 : 0] m_axi_arprot
      .m_axi_arready(m_axi_arready_b),          // input wire m_axi_arready
      .m_axi_arsize(m_axi_arsize_b),            // output wire [2 : 0] m_axi_arsize
      .m_axi_aruser(m_axi_aruser_b),            // output wire [3 : 0] m_axi_aruser
      .m_axi_arvalid(m_axi_arvalid_b),          // output wire m_axi_arvalid
      .m_axi_rdata(m_axi_rdata_b),              // input wire [127 : 0] m_axi_rdata
      .m_axi_rlast(m_axi_rlast_b),              // input wire m_axi_rlast
      .m_axi_rready(m_axi_rready_b),            // output wire m_axi_rready
      .m_axi_rresp(m_axi_rresp_b),              // input wire [1 : 0] m_axi_rresp
      .m_axi_rvalid(m_axi_rvalid_b),            // input wire m_axi_rvalid
      .m_axis_tdata(m_axis_tdata_b),            // output wire [15 : 0] m_axis_tdata
      .m_axis_tlast(m_axis_tlast_b),            // output wire m_axis_tlast
      .m_axis_tvalid(m_axis_tvalid_b),          // output wire m_axis_tvalid
      .m_axis_tready(m_axis_tready_b),          // input wire m_axis_tready
      .m_axis_tuser(m_axis_tuser_b),            // output wire m_axis_tuser
      .go(go),                                // input wire go
      .mode(mode),                            // input wire [1 : 0] mode
      .width(width),                          // input wire [15 : 0] width
      .height(height),                        // input wire [15 : 0] height
      .baseaddr(baseaddr_b)                    // input wire [31 : 0] baseaddr
    );
	axi_video_frame_reader_top_nuc # (
		.BPS								(16							),	                	
		.MAX_WIDTH	          				(FRAME_WIDTH	          			),
		.MAX_HEIGHT	         				(FRAME_HEIGHT	         			),
		.BUFFER_NUM	         				(BUFFER_NUM	         			),
		.ADDRESSWIDTH	       				(ADDRESSWIDTH	       			),
		.DATAWIDTH_MM	       				(DATAWIDTH_MM	       			),
		.MAXBURSTCOUNT	      				(MAXBURSTCOUNT	      			),
		.FIFODEPTH_BYTE	     				(FIFODEPTH_BYTE	     			)
	)
	 reader_k (
      .clk(clk_axi),                              // input wire clk
      .reset_n(aresetn),                      // input wire reset_n
	  .axis_aclk(aclk),
      .writer_base_index(writer_base_index_1),  // input wire [3 : 0] writer_base_index
      .reader_base_index(reader_base_index_1),  // output wire [3 : 0] reader_base_index
      .m_axi_araddr(m_axi_araddr_k),            // output wire [31 : 0] m_axi_araddr
      .m_axi_arburst(m_axi_arburst_k),          // output wire [1 : 0] m_axi_arburst
      .m_axi_arcache(m_axi_arcache_k),          // output wire [3 : 0] m_axi_arcache
      .m_axi_arlen(m_axi_arlen_k),              // output wire [7 : 0] m_axi_arlen
      .m_axi_arprot(m_axi_arprot_k),            // output wire [2 : 0] m_axi_arprot
      .m_axi_arready(m_axi_arready_k),          // input wire m_axi_arready
      .m_axi_arsize(m_axi_arsize_k),            // output wire [2 : 0] m_axi_arsize
      .m_axi_aruser(m_axi_aruser_k),            // output wire [3 : 0] m_axi_aruser
      .m_axi_arvalid(m_axi_arvalid_k),          // output wire m_axi_arvalid
      .m_axi_rdata(m_axi_rdata_k),              // input wire [127 : 0] m_axi_rdata
      .m_axi_rlast(m_axi_rlast_k),              // input wire m_axi_rlast
      .m_axi_rready(m_axi_rready_k),            // output wire m_axi_rready
      .m_axi_rresp(m_axi_rresp_k),              // input wire [1 : 0] m_axi_rresp
      .m_axi_rvalid(m_axi_rvalid_k),            // input wire m_axi_rvalid

      .m_axis_tdata(m_axis_tdata_k),            // output wire [15 : 0] m_axis_tdata
      .m_axis_tlast(m_axis_tlast_k),            // output wire m_axis_tlast
      .m_axis_tvalid(m_axis_tvalid_k),          // output wire m_axis_tvalid
      .m_axis_tready(m_axis_tready_k),          // input wire m_axis_tready
      .m_axis_tuser(m_axis_tuser_k),            // output wire m_axis_tuser
      .go(go),                                // input wire go
      .mode(mode),                            // input wire [1 : 0] mode
      .width(width),                          // input wire [15 : 0] width
      .height(height),                        // input wire [15 : 0] height
      .baseaddr(baseaddr_k)                    // input wire [31 : 0] baseaddr
    );

	axi_video_frame_reader_top_nuc # (
		.BPS								(16							),	                	
		.MAX_WIDTH	          				(FRAME_WIDTH	          			),
		.MAX_HEIGHT	         				(FRAME_HEIGHT	         			),
		.BUFFER_NUM	         				(BUFFER_NUM	         			),
		.ADDRESSWIDTH	       				(ADDRESSWIDTH	       			),
		.DATAWIDTH_MM	       				(DATAWIDTH_MM	       			),
		.MAXBURSTCOUNT	      				(MAXBURSTCOUNT	      			),
		.FIFODEPTH_BYTE	     				(FIFODEPTH_BYTE	     			)
	)
	reader_mask_k (
      .clk(clk_axi),                              // input wire clk
      .reset_n(aresetn),                      // input wire reset_n
	  .axis_aclk(aclk),
      .writer_base_index(writer_base_index_1),  // input wire [3 : 0] writer_base_index
      .reader_base_index(),  // output wire [3 : 0] reader_base_index
      .m_axi_araddr(m_axi_araddr_mask_k),            // output wire [31 : 0] m_axi_araddr
      .m_axi_arburst(m_axi_arburst_mask_k),          // output wire [1 : 0] m_axi_arburst
      .m_axi_arcache(m_axi_arcache_mask_k),          // output wire [3 : 0] m_axi_arcache
      .m_axi_arlen(m_axi_arlen_mask_k),              // output wire [7 : 0] m_axi_arlen
      .m_axi_arprot(m_axi_arprot_mask_k),            // output wire [2 : 0] m_axi_arprot
      .m_axi_arready(m_axi_arready_mask_k),          // input wire m_axi_arready
      .m_axi_arsize(m_axi_arsize_mask_k),            // output wire [2 : 0] m_axi_arsize
      .m_axi_aruser(m_axi_aruser_mask_k),            // output wire [3 : 0] m_axi_aruser
      .m_axi_arvalid(m_axi_arvalid_mask_k),          // output wire m_axi_arvalid
      .m_axi_rdata(m_axi_rdata_mask_k),              // input wire [127 : 0] m_axi_rdata
      .m_axi_rlast(m_axi_rlast_mask_k),              // input wire m_axi_rlast
      .m_axi_rready(m_axi_rready_mask_k),            // output wire m_axi_rready
      .m_axi_rresp(m_axi_rresp_mask_k),              // input wire [1 : 0] m_axi_rresp
      .m_axi_rvalid(m_axi_rvalid_mask_k),            // input wire m_axi_rvalid

      .m_axis_tdata(m_axis_tdata_mask_k),            // output wire [15 : 0] m_axis_tdata
      .m_axis_tlast(m_axis_tlast_mask_k),            // output wire m_axis_tlast
      .m_axis_tvalid(m_axis_tvalid_mask_k),          // output wire m_axis_tvalid
      .m_axis_tready(m_axis_tready_mask_k),          // input wire m_axis_tready
      .m_axis_tuser(m_axis_tuser_mask_k),            // output wire m_axis_tuser
      .go(go),                                // input wire go
      .mode(mode),                            // input wire [1 : 0] mode
      .width(width),                          // input wire [15 : 0] width
      .height(height),                        // input wire [15 : 0] height
      .baseaddr(baseaddr_mask_k)                    // input wire [31 : 0] baseaddr
    );

	axi_video_frame_reader_top_nuc # (
		.BPS								(16							),	                	
		.MAX_WIDTH	          				(FRAME_WIDTH	          			),
		.MAX_HEIGHT	         				(FRAME_HEIGHT	         			),
		.BUFFER_NUM	         				(BUFFER_NUM	         			),
		.ADDRESSWIDTH	       				(ADDRESSWIDTH	       			),
		.DATAWIDTH_MM	       				(DATAWIDTH_MM	       			),
		.MAXBURSTCOUNT	      				(MAXBURSTCOUNT	      			),
		.FIFODEPTH_BYTE	     				(FIFODEPTH_BYTE	     			)
	)
	reader_mask_b (
      .clk(clk_axi),                              // input wire clk
      .reset_n(aresetn),                      // input wire reset_n
	  .axis_aclk(aclk),
      .writer_base_index(writer_base_index_1),  // input wire [3 : 0] writer_base_index
      .reader_base_index(),  // output wire [3 : 0] reader_base_index
      .m_axi_araddr(m_axi_araddr_mask_b),            // output wire [31 : 0] m_axi_araddr
      .m_axi_arburst(m_axi_arburst_mask_b),          // output wire [1 : 0] m_axi_arburst
      .m_axi_arcache(m_axi_arcache_mask_b),          // output wire [3 : 0] m_axi_arcache
      .m_axi_arlen(m_axi_arlen_mask_b),              // output wire [7 : 0] m_axi_arlen
      .m_axi_arprot(m_axi_arprot_mask_b),            // output wire [2 : 0] m_axi_arprot
      .m_axi_arready(m_axi_arready_mask_b),          // input wire m_axi_arready
      .m_axi_arsize(m_axi_arsize_mask_b),            // output wire [2 : 0] m_axi_arsize
      .m_axi_aruser(m_axi_aruser_mask_b),            // output wire [3 : 0] m_axi_aruser
      .m_axi_arvalid(m_axi_arvalid_mask_b),          // output wire m_axi_arvalid
      .m_axi_rdata(m_axi_rdata_mask_b),              // input wire [127 : 0] m_axi_rdata
      .m_axi_rlast(m_axi_rlast_mask_b),              // input wire m_axi_rlast
      .m_axi_rready(m_axi_rready_mask_b),            // output wire m_axi_rready
      .m_axi_rresp(m_axi_rresp_mask_b),              // input wire [1 : 0] m_axi_rresp
      .m_axi_rvalid(m_axi_rvalid_mask_b),            // input wire m_axi_rvalid

      .m_axis_tdata(m_axis_tdata_mask_b),            // output wire [15 : 0] m_axis_tdata
      .m_axis_tlast(m_axis_tlast_mask_b),            // output wire m_axis_tlast
      .m_axis_tvalid(m_axis_tvalid_mask_b),          // output wire m_axis_tvalid
      .m_axis_tready(m_axis_tready_mask_b),          // input wire m_axis_tready
      .m_axis_tuser(m_axis_tuser_mask_b),            // output wire m_axis_tuser
      .go(go),                                // input wire go
      .mode(mode),                            // input wire [1 : 0] mode
      .width(width),                          // input wire [15 : 0] width
      .height(height),                        // input wire [15 : 0] height
      .baseaddr(baseaddr_mask_b)                    // input wire [31 : 0] baseaddr
    );

	assign s_axis_tready = go ? (m_axis_tready & m_axis_tvalid_k & m_axis_tvalid_b & m_axis_tvalid_mask_k & m_axis_tvalid_mask_b) : m_axis_tready;
    assign m_axis_tready_b = go ? (m_axis_tready & s_axis_tvalid & m_axis_tvalid_k & m_axis_tvalid_mask_k & m_axis_tvalid_mask_b) : 0;
    assign m_axis_tready_k = go ? (m_axis_tready & s_axis_tvalid & m_axis_tvalid_b & m_axis_tvalid_mask_k & m_axis_tvalid_mask_b) : 0;
    assign m_axis_tready_mask_k = go ? (m_axis_tready & s_axis_tvalid & m_axis_tvalid_b & m_axis_tvalid_k & m_axis_tvalid_mask_b) : 0;
    assign m_axis_tready_mask_b = go ? (m_axis_tready & s_axis_tvalid & m_axis_tvalid_b & m_axis_tvalid_k & m_axis_tvalid_mask_k) : 0;
    
	wire din_en;
	assign din_en = s_axis_tready & s_axis_tvalid & m_axis_tvalid_k & m_axis_tvalid_b & m_axis_tvalid_mask_k & m_axis_tvalid_mask_b;


	reg [13:0]Tempera_r[0:1];
	reg [13:0]Temp,Temp_cur;

	always @(posedge aclk or negedge aresetn)
    if (!aresetn) begin
        Tempera_r[0] <= 'd6700;
        Tempera_r[1] <= 'd6700;
    end
    else begin
        Tempera_r[0] <= (Tempera == 0) ? Tempera_r[0] : Tempera;
        Tempera_r[1] <= Tempera_r[0];
	end


	always @(posedge aclk or negedge aresetn)begin
		if (!aresetn) begin
			Temp <= 'd6700;
		end
		else begin
			if((Tempera_r[1] > 'd7000) || (Tempera_r[1] < 'd6000))
				Temp <= Temp;
			else
				Temp <= Tempera_r[1];
		end
	end

	localparam TF_NUM = 9;
	integer i;
	reg [11:0]cnt_user;
	reg [1:0]shutter_en_r;
	reg [13:0]Temp_cur_tf[0:TF_NUM-1];


	always @(posedge aclk or negedge aresetn)begin
		if (!aresetn) begin
			cnt_user <= 'd0;
			shutter_en_r[0] <= 1'b1;
			shutter_en_r[1] <= 1'b1;
			for(i = 0;i<TF_NUM;i=i+1)begin
				Temp_cur_tf[i] <= 'd6700;
			end
		end
		else begin
			shutter_en_r[0] <= shutter_en;
			shutter_en_r[1] <= shutter_en_r[0];
			if((cnt_din >= FRAME_WIDTH * FRAME_HEIGHT - 1) && s_axis_tvalid && s_axis_tready)begin
				cnt_user <= cnt_user + 1;
				Temp_cur_tf[0] <= Temp;
				for(i = 1;i<TF_NUM;i=i+1)begin
					Temp_cur_tf[i] <= Temp_cur_tf[i-1];
				end
			end

		end
	end

	reg [BPS-1:0] t2_min1, t2_med1, t2_max1;
	reg [BPS-1:0] t2_min2, t2_med2, t2_max2;
	reg [BPS-1:0] t2_min3, t2_med3, t2_max3;

	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t2_min1 <= 0; t2_med1 <= 0; t2_max1 <= 0;
			t2_min2 <= 0; t2_med2 <= 0; t2_max2 <= 0;
			t2_min3 <= 0; t2_med3 <= 0; t2_max3 <= 0;
		end
		else begin
			t2_min1 <= min(Temp_cur_tf[0], Temp_cur_tf[1], Temp_cur_tf[2]);
			t2_med1 <= med(Temp_cur_tf[0], Temp_cur_tf[1], Temp_cur_tf[2]);
			t2_max1 <= max(Temp_cur_tf[0], Temp_cur_tf[1], Temp_cur_tf[2]);
			t2_min2 <= min(Temp_cur_tf[3], Temp_cur_tf[4], Temp_cur_tf[5]);
			t2_med2 <= med(Temp_cur_tf[3], Temp_cur_tf[4], Temp_cur_tf[5]);
			t2_max2 <= max(Temp_cur_tf[3], Temp_cur_tf[4], Temp_cur_tf[5]);
			t2_min3 <= min(Temp_cur_tf[6], Temp_cur_tf[7], Temp_cur_tf[8]);
			t2_med3 <= med(Temp_cur_tf[6], Temp_cur_tf[7], Temp_cur_tf[8]);
			t2_max3 <= max(Temp_cur_tf[6], Temp_cur_tf[7], Temp_cur_tf[8]);
		end
	end

	reg [BPS-1:0] t3_max_of_min, t3_med_of_med, t3_min_of_max;

	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t3_max_of_min <= 0; t3_med_of_med <= 0; t3_min_of_max <= 0;
		end
		else begin
			t3_max_of_min <= max(t2_min1, t2_min2, t2_min3);
			t3_med_of_med <= med(t2_med1, t2_med2, t2_med3);
			t3_min_of_max <= min(t2_max1, t2_max2, t2_max3);
		end
	end

	reg [BPS-1:0] t4_medium;
	always @ (posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			t4_medium <= 0;
		end
		else begin
			t4_medium <= med(t3_max_of_min, t3_med_of_med, t3_min_of_max);
		end
	end


	reg [13:0]temp_mean;
	always @(posedge aclk or negedge aresetn)begin
		if (!aresetn) begin
			temp_mean <= 'd6700;
		end
		else begin
			if(((cnt_din == FRAME_WIDTH * FRAME_HEIGHT - 1) && s_axis_tvalid && s_axis_tready && (cnt_user == 'd4095)) || ~go)
				temp_mean <= t4_medium;
			else
				temp_mean <= temp_mean;
		end

	end


	wire signed [15:0]mask_k,mask_b,temp_cur,temp_high;

	assign mask_k = m_axis_tdata_mask_k;
	assign mask_b = m_axis_tdata_mask_b;
	assign temp_cur = {2'b00,temp_mean};
	assign temp_high = {2'b00,Tempera_high_r[1]};


	reg signed [15:0]Tempera_diff;
	reg signed [15:0]mask_k_r;
	reg signed [15:0]mask_b_r;
	reg signed [15:0]offset;
	wire signed [31:0]offset_temp;

	assign offset_temp = (Tempera_diff * mask_k_r) >>> FRACTION_BIT;


	always @(posedge aclk or negedge aresetn)begin
		if (!aresetn) begin
			Tempera_diff <= 'd0;
			mask_k_r <= 'd0;
			mask_b_r <= 'd0;
		end
		else begin
			if (din_en) begin
				Tempera_diff <= temp_cur - temp_high;
				mask_k_r <= mask_k;
				mask_b_r <= mask_b;
				offset <= mask_b_r - offset_temp[15:0];
			end
		end
		
	end

	wire [15:0]offset_unsigned;
	wire offset_flag;
	assign offset_flag = offset[15];
	assign offset_unsigned = shutter_en_r[1] ? (offset_flag ? (~offset + 1) : offset) : 'd0;


	wire [15 : 0]minuend,meiosis;
	wire Flag_p;
    assign minuend = s_axis_tdata + mean_b_out;
    assign meiosis = m_axis_tdata_b + mean_b_low_r[1];


	reg [15:0]minuend_r[0:1];
	reg [15:0]meiosis_r[0:1];
	reg Flag_p_r[0:1];
	reg [15:0]m_axis_tdata_k_r[0:1];
	reg [15:0]m_axis_tdata_b_r[0:1];
	reg [13:0]s_axis_tdata_r[0:4];
	always @(posedge aclk or negedge aresetn)begin
		if (!aresetn) begin
			minuend_r[0] <= 'd0;
			minuend_r[1] <= 'd0;
			meiosis_r[0] <= 'd0;
			meiosis_r[1] <= 'd0;
			Flag_p_r[0] <= 1'b0;
			Flag_p_r[1] <= 1'b0;
			m_axis_tdata_k_r[0] <= 'd0;
			m_axis_tdata_k_r[1] <= 'd0;
			m_axis_tdata_b_r[0] <= 'd0;
			m_axis_tdata_b_r[1] <= 'd0;
			s_axis_tdata_r[0] <= 'd0;
			s_axis_tdata_r[1] <= 'd0;
			s_axis_tdata_r[2] <= 'd0;
			s_axis_tdata_r[3] <= 'd0;
			s_axis_tdata_r[4] <= 'd0;

		end
		else begin
			if(din_en)begin
				minuend_r[0] <= minuend;
				minuend_r[1] <= minuend_r[0];
				meiosis_r[0] <= meiosis;
				meiosis_r[1] <= meiosis_r[0];
				Flag_p_r[0] <= Flag_p;
				Flag_p_r[1] <= Flag_p_r[0];
				m_axis_tdata_k_r[0] <= m_axis_tdata_k;
				m_axis_tdata_k_r[1] <= m_axis_tdata_k_r[0];
				m_axis_tdata_b_r[0] <= m_axis_tdata_b;
				m_axis_tdata_b_r[1] <= m_axis_tdata_b_r[0];
				s_axis_tdata_r[0] <= s_axis_tdata;
				s_axis_tdata_r[1] <= s_axis_tdata_r[0];
				s_axis_tdata_r[2] <= s_axis_tdata_r[1];
				s_axis_tdata_r[3] <= s_axis_tdata_r[2];
				s_axis_tdata_r[4] <= s_axis_tdata_r[3];
			end
		end
		
	end

	wire [15:0]meiosis_final;
	assign meiosis_final = offset_flag ? (meiosis_r[1] - offset_unsigned) : (meiosis_r[1] + offset_unsigned);

	assign Flag_p = (minuend_r[1] > meiosis_final) ? 1'b1 : 1'b0;


	reg [13:0] m_axis_tdata_r;
	reg [31:0] m_axis_tdata_r2;
	reg [13:0] m_axis_tdata_r2_limit;

	always @(posedge aclk or negedge aresetn)
    if (!aresetn) begin
        m_axis_tdata_r <= 'd0;
		m_axis_tdata_r2 <= 'd0;
		m_axis_tdata_r2_limit <= 'd0;
    end
    else if (din_en) begin
		
		m_axis_tdata_r2 <= Flag_p ? ((minuend_r[1] - meiosis_final)*m_axis_tdata_k_r[1]) : ((meiosis_final - minuend_r[1])*m_axis_tdata_k_r[1]);
		
		m_axis_tdata_r2_limit <= ((m_axis_tdata_r2[25:12]) > 14'd8191) ? 14'd8191 : (m_axis_tdata_r2[25:12]);

        m_axis_tdata_r <= Flag_p_r[1] ? (m_axis_tdata_r2_limit + mean_b_r[1])  : (mean_b_r[1] - m_axis_tdata_r2_limit);

	end


    reg [31 : 0] cnt_out; 
    always @(posedge aclk or negedge aresetn)
    if (!aresetn) begin
        cnt_out <= 0;
    end
    else begin
        if (m_axis_tready & m_axis_tvalid) begin
            if (cnt_out >= FRAME_WIDTH * FRAME_HEIGHT - 1)
                cnt_out <= 0;
            else 
                cnt_out <= cnt_out + 1'b1;
        end
        else
            cnt_out <= cnt_out;
    end

	wire initial_delayed;
	reg  [2:0] initial_delay_cnt;
	always @(posedge aclk or negedge aresetn)
    if (!aresetn) begin
        initial_delay_cnt <= 0;
    end
    else if (s_axis_tready & s_axis_tvalid & m_axis_tvalid_k & m_axis_tvalid_b & m_axis_tvalid_mask_k & m_axis_tvalid_mask_b) begin			
		if(initial_delay_cnt >= LATENCY)
		    initial_delay_cnt <= initial_delay_cnt;
		else
			initial_delay_cnt <= initial_delay_cnt + 'd1;
	end

	assign initial_delayed = initial_delay_cnt >= LATENCY;

	assign m_axis_tdata = go ? m_axis_tdata_r : s_axis_tdata_r[4];
    assign m_axis_tuser = m_axis_tvalid & (cnt_out == 0);
    assign m_axis_tlast = m_axis_tvalid & ( (cnt_out + 1) % FRAME_WIDTH == 0);
	assign m_axis_tvalid = (go ? (s_axis_tvalid & m_axis_tready & m_axis_tvalid_k & m_axis_tvalid_b & m_axis_tvalid_mask_b & m_axis_tvalid_mask_k) : s_axis_tvalid) & initial_delayed;


	endmodule
