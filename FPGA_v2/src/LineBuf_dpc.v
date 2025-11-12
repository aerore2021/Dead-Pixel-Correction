module LineBuf_dpc #(
  parameter WIDTH   = 32,
  parameter LATENCY = 640
) (
  input                reset,
  input                clk,
  input                in_valid,
  input  [WIDTH-1 : 0] data_in,
  output [WIDTH-1 : 0] data_out
);

  localparam MAX_WIDTH = 32;
  localparam MAX_DEPTH = 1024;

  initial begin
    // TODO abort synthesis if error
    if (WIDTH > MAX_WIDTH) $display("error: WIDTH exceeds MAX_WIDTH!!");
    if (LATENCY > MAX_DEPTH) $display("error: LATENCY exceeds MAX_DEPTH!!");
    if (LATENCY < 1) $display("error: LATENCY at least !!");
  end

  reg [9:0] waddr = LATENCY - 1;
  reg [9:0] raddr = 0;

  always @(posedge clk) begin
    if (reset) begin
      raddr <= 'd0;
      waddr <= LATENCY - 1;
    end else if (in_valid) begin
      // overflow is needed
      raddr <= raddr + 'd1;
      waddr <= waddr + 'd1;
    end
  end

  BRAM_32x1024 h_lut (
    .clka    (clk),
    .clkb    (clk),
    .wea     (in_valid),
    .addra  (waddr),
    .dina(data_in),
    .enb     (in_valid),
    .addrb  (raddr),
    .doutb(data_out)
  );

endmodule
