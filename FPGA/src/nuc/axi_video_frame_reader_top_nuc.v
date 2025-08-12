`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/12/10 19:09:17
// Design Name: 
// Module Name: axi_video_frame_reader_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axi_video_frame_reader_top_nuc #(
        parameter BPS                = 8,
		parameter MAX_WIDTH          = 640,
		parameter MAX_HEIGHT         = 512,
		parameter BUFFER_NUM         = 3,
		parameter ADDRESSWIDTH       = 32,
		parameter DATAWIDTH_MM       = 64,
		parameter MAXBURSTCOUNT      = 8,
		parameter FIFODEPTH_BYTE     = 8192
    )
    (
        input                             		clk,
		input                             		reset_n,
		input  		[3:0]                      	writer_base_index,
		output 		[3:0]                      	reader_base_index,
		output      [ADDRESSWIDTH-1:0]          m_axi_araddr,
		output      [1:0]                       m_axi_arburst,
		output      [3:0]                       m_axi_arcache,
		output      [7:0]                       m_axi_arlen,
		output      [2:0]                       m_axi_arprot,
		input                                   m_axi_arready,
		output      [2:0]                       m_axi_arsize,
		output      [3:0]                       m_axi_aruser,
		output                                  m_axi_arvalid,
		input       [DATAWIDTH_MM-1:0]          m_axi_rdata,
		input                                   m_axi_rlast,
		output                                  m_axi_rready,
		input       [1:0]                       m_axi_rresp,
		input                                   m_axi_rvalid,
		input									axis_aclk,
		output      [BPS-1 : 0]        			m_axis_tdata,
		output                                  m_axis_tlast,
		output                                  m_axis_tvalid,
		input                                   m_axis_tready,
		output                                  m_axis_tuser,

        input                                   go,
        input       [1:0]                       mode,
        input       [15:0]                      width,
        input       [15:0]                      height,
        input       [ADDRESSWIDTH-1:0]          baseaddr
    );


    reg                             go_r;
    reg [1:0]                       mode_r;
    reg [15:0]                      width_r;
    reg [15:0]                      height_r;
    reg [ADDRESSWIDTH-1:0]          baseaddr_r;
    reg [31:0] cnt;

    always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      cnt <= 0;
    end
    else begin
      if (!go) begin
        cnt <= 0;
      end
      else begin
        if (cnt < 50) begin
          cnt <= cnt + 1;
        end
        else begin
          cnt <= cnt;
        end  
      end
    end


    always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      go_r <= 0;
      mode_r <= 0;
      width_r <= 0;
      height_r <= 0;
      baseaddr_r <= 0;
    end
    else begin
      if (!go) begin
        go_r <= 0;
      end
      else begin
        if (cnt == 50) begin
          go_r <= 1;
        end
        else begin
          go_r <= 0;
        end
      end

      mode_r <= mode;
      width_r <= width;
      height_r <= height;
      baseaddr_r <= baseaddr;
    end


    axi_video_frame_reader_nuc # (
		.BPS								(BPS							),	                	
		.MAX_WIDTH	          				(MAX_WIDTH	          			),
		.MAX_HEIGHT	         				(MAX_HEIGHT	         			),
		.NUMBER_OF_COLOUR_PLANES			(1		),
		.COLOUR_PLANES_ARE_IN_PARALLEL		(0	),
		.BUFFER_NUM	         				(BUFFER_NUM	         			),
		.ADDRESSWIDTH	       				(ADDRESSWIDTH	       			),
		.DATAWIDTH_MM	       				(DATAWIDTH_MM	       			),
		.MAXBURSTCOUNT	      				(MAXBURSTCOUNT	      			),
		.FIFODEPTH_BYTE	     				(FIFODEPTH_BYTE	     			)
	)
	axi_video_frame_reader(
		.clk				(clk),
		.reset_n			(reset_n),

		.writer_base_index	(writer_base_index),
		.reader_base_index	(reader_base_index),

		.go					(go_r),		
		.mode				(mode_r),		
		.width				(width_r),		
		.height				(height_r),		
		.baseaddr			(baseaddr_r),		

		.m_axi_araddr		(m_axi_araddr	),
		.m_axi_arburst		(m_axi_arburst	),
		.m_axi_arcache		(m_axi_arcache	),
		.m_axi_arlen		(m_axi_arlen	),
		.m_axi_arprot		(m_axi_arprot	),
		.m_axi_arready		(m_axi_arready	),
		.m_axi_arsize		(m_axi_arsize	),
		.m_axi_aruser		(m_axi_aruser	),
		.m_axi_arvalid		(m_axi_arvalid	),
		.m_axi_rdata		(m_axi_rdata	),
		.m_axi_rlast		(m_axi_rlast	),
		.m_axi_rready		(m_axi_rready	),
		.m_axi_rresp		(m_axi_rresp	),
		.m_axi_rvalid		(m_axi_rvalid	),
		.axis_aclk			(axis_aclk),
		.m_axis_tdata		(m_axis_tdata	),
		.m_axis_tlast		(m_axis_tlast	),
		.m_axis_tvalid		(m_axis_tvalid	),
		.m_axis_tready		(m_axis_tready	),
		.m_axis_tuser		(m_axis_tuser	)
	);
endmodule
