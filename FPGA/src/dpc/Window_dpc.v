module Window_dpc #(
  parameter WIDTH       = 8,
  parameter WINDOW_SIZE = 3
) (
  input                clk,
  input                in_valid,
  input  [WIDTH-1 : 0] w1_in,
  input  [WIDTH-1 : 0] w2_in,
  input  [WIDTH-1 : 0] w3_in,
  output [WIDTH-1 : 0] w11,
  output [WIDTH-1 : 0] w12,
  output [WIDTH-1 : 0] w13,
  output [WIDTH-1 : 0] w21,
  output [WIDTH-1 : 0] w22,
  output [WIDTH-1 : 0] w23,
  output [WIDTH-1 : 0] w31,
  output [WIDTH-1 : 0] w32,
  output [WIDTH-1 : 0] w33
);

  Window_line_dpc #(
    .WINDOW_SIZE(WINDOW_SIZE),
    .WIDTH      (WIDTH)
  ) l_1 (
    .clk (clk),
    .en  (in_valid),
    .w_in(w1_in),
    .w_1 (w33),
    .w_2 (w32),
    .w_3 (w31)
  );
  Window_line_dpc #(
    .WINDOW_SIZE(WINDOW_SIZE),
    .WIDTH      (WIDTH)
  ) l_2 (
    .clk (clk),
    .en  (in_valid),
    .w_in(w2_in),
    .w_1 (w23),
    .w_2 (w22),
    .w_3 (w21)
  );
  Window_line_dpc #(
    .WINDOW_SIZE(WINDOW_SIZE),
    .WIDTH      (WIDTH)
  ) l_3 (
    .clk (clk),
    .en  (in_valid),
    .w_in(w3_in),
    .w_1 (w13),
    .w_2 (w12),
    .w_3 (w11)
  );

endmodule

module Window_line_dpc #(
  parameter WINDOW_SIZE = 3,
  parameter WIDTH       = 8
) (
  input                clk,
  input                en,
  input  [WIDTH-1 : 0] w_in,
  output [WIDTH-1 : 0] w_1,
  output [WIDTH-1 : 0] w_2,
  output [WIDTH-1 : 0] w_3
);
  reg     [WIDTH-1 : 0] shift_reg[WINDOW_SIZE-1 : 0];
  integer               i;
  always @(posedge clk) begin
    if (en) begin
      for (i = 0; i < WINDOW_SIZE - 1; i = i + 1) shift_reg[i+1] <= shift_reg[i];
      shift_reg[0] <= w_in;
    end
  end

  assign w_1 = shift_reg[0];
  assign w_2 = shift_reg[1];
  assign w_3 = shift_reg[2];

endmodule
