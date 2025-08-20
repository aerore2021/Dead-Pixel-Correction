
module lpm_divide
(
  aclr,
  clken,
  clock,
  denom,
  numer,
  quotient,
  remain
);

  parameter lpm_drepresentation = "UNSIGNED";
  parameter lpm_hint            = "";
  parameter lpm_nrepresentation = "UNSIGNED";
  parameter lpm_pipeline        = 16;
  parameter lpm_type            = "LPM_DIVIDE";
  parameter lpm_widthd          = 8;
  parameter lpm_widthn          = 16;

  localparam iterat_num         = (lpm_pipeline <= lpm_widthn) ? lpm_widthn/lpm_pipeline : 1;
  localparam extra_num          = (lpm_pipeline <= lpm_widthn) ? lpm_widthn % lpm_pipeline : 0;
  localparam iterat_adj         = (extra_num > 0) ? 1 : 0;


  input                       aclr;
  input                       clock;
  input                       clken;
  input  [(lpm_widthn-1):0]   numer;
  input  [(lpm_widthd-1):0]   denom;
  output [(lpm_widthn-1):0]   quotient;
  output [(lpm_widthd-1):0]   remain;


  wire [(lpm_widthn-1):0]     numer_wire[lpm_pipeline-1:0];
  wire [(lpm_widthd-1):0]     denom_wire[lpm_pipeline-1:0];
  wire [(lpm_widthn-1):0]     quotient_wire[lpm_pipeline-1:0];
  wire [(lpm_widthd-1):0]     remain_wire[lpm_pipeline-1:0];

  reg  [(lpm_widthn-1):0]     numer_reg[lpm_pipeline-1:0];
  reg  [(lpm_widthd-1):0]     denom_reg[lpm_pipeline-1:0];
  reg  [(lpm_widthn-1):0]     quotient_reg[lpm_pipeline-1:0];
  reg  [(lpm_widthd-1):0]     remain_reg[lpm_pipeline-1:0];

  reg                         quotient_sign[lpm_pipeline-1:0]; 
  reg                         remain_sign[lpm_pipeline-1:0];

  wire [lpm_widthn-1:0] numer_unsig = (lpm_nrepresentation == "UNSIGNED") ? numer :
                                      (numer[lpm_widthn-1] == 1'b0)       ? numer : ~numer + 1'b1;

  wire [lpm_widthd-1:0] denom_unsig = (lpm_drepresentation == "UNSIGNED") ? denom :
                                      (denom[lpm_widthd-1] == 1'b0)       ? denom : ~denom + 1'b1;

  integer k;

  generate
  genvar i;
  begin
  	
  	if((lpm_nrepresentation == "SIGNED") || (lpm_drepresentation == "UNSIGNED"))
  	begin
      always @(posedge aclr or posedge clock)
      begin
        if (aclr)
        begin
        	for(k=0;k<lpm_pipeline;k=k+1)
        	begin
            quotient_sign[k] <= 0;
            remain_sign[k]   <= 0;
        	end
        end
        else if(clken)
        begin
        	for(k=0;k<lpm_pipeline;k=k+1)
        	begin
        		if(k==0)
        		begin
              quotient_sign[0] <= ((lpm_nrepresentation == "UNSIGNED") ? 1'b0 : numer[lpm_widthn-1]) ^ ((lpm_drepresentation == "UNSIGNED") ? 1'b0 : denom[lpm_widthd-1]);
              remain_sign[0]   <= (lpm_nrepresentation == "UNSIGNED") ? 1'b0 : numer[lpm_widthn-1];
        		end
        		else
        		begin
              quotient_sign[k] <= quotient_sign[k-1];
              remain_sign[k]   <= remain_sign[k-1];
            end
        	end
        end
  	  end
    end
    else
    begin
      always @*
      begin
      	for(k=0;k<lpm_pipeline;k=k+1)
      	begin
          quotient_sign[k] <= 0;
          remain_sign[k]   <= 0;
      	end
      end
    end

    for(i=0;i<lpm_pipeline;i=i+1)
    begin: iterat

      if(i==0)
      begin
        div_primitives#(
          .widthn (lpm_widthn),
          .widthd (lpm_widthd),
          .iterat_num (iterat_num+iterat_adj)
        ) u_div_primitives
        (
          .denom_in    (denom_unsig),
          .numer_in    (numer_unsig),
          .quotient_in ({lpm_widthn{1'b0}}),
          .remain_in   ({lpm_widthd{1'b0}}),
          .denom_out   (denom_wire[0]),
          .numer_out   (numer_wire[0]),
          .quotient_out(quotient_wire[0]),
          .remain_out  (remain_wire[0])
        );
      end
      else if(i<extra_num)
      begin
        div_primitives#(
          .widthn (lpm_widthn),
          .widthd (lpm_widthd),
          .iterat_num (iterat_num+iterat_adj)
        ) u_div_primitives
        (
          .denom_in    (denom_reg[i-1]),
          .numer_in    (numer_reg[i-1]),
          .quotient_in (quotient_reg[i-1]),
          .remain_in   (remain_reg[i-1]),
          .denom_out   (denom_wire[i]),
          .numer_out   (numer_wire[i]),
          .quotient_out(quotient_wire[i]),
          .remain_out  (remain_wire[i])
        );
      end
      else if(i<lpm_widthn)
      begin
        div_primitives#(
          .widthn (lpm_widthn),
          .widthd (lpm_widthd),
          .iterat_num (iterat_num)
        ) u_div_primitives
        (
          .denom_in    (denom_reg[i-1]),
          .numer_in    (numer_reg[i-1]),
          .quotient_in (quotient_reg[i-1]),
          .remain_in   (remain_reg[i-1]),
          .denom_out   (denom_wire[i]),
          .numer_out   (numer_wire[i]),
          .quotient_out(quotient_wire[i]),
          .remain_out  (remain_wire[i])
        );
      end
      else
      begin
        assign denom_wire[i]    = denom_reg[i-1];
        assign numer_wire[i]    = numer_reg[i-1];
        assign quotient_wire[i] = quotient_reg[i-1];
        assign remain_wire[i]   = remain_reg[i-1];
      end

      always @(posedge aclr or posedge clock)
      begin
        if (aclr)
        begin
          denom_reg[i]    <= 0;
          numer_reg[i]    <= 0;
          quotient_reg[i] <= 0;
          remain_reg[i]   <= 0;
        end
        else if(clken)
        begin
          denom_reg[i]    <= denom_wire[i];
          numer_reg[i]    <= numer_wire[i];
          quotient_reg[i] <= quotient_wire[i];
          remain_reg[i]   <= remain_wire[i];
        end
      end

    end
  end
  endgenerate

  assign quotient = (quotient_sign[lpm_pipeline-1] == 1'b1) ? ~quotient_reg[lpm_pipeline-1] + 1'b1  : quotient_reg[lpm_pipeline-1];
  assign remain   = (remain_sign[lpm_pipeline-1] == 1'b1)   ? ~remain_reg[lpm_pipeline-1] + 1'b1    : remain_reg[lpm_pipeline-1];

endmodule


module div_primitives
(
  denom_in,
  numer_in,
  quotient_in,
  remain_in,

  denom_out,
  numer_out,
  quotient_out,
  remain_out
);

  parameter widthn     = 8;
  parameter widthd     = 8;
  parameter iterat_num = 8;

  input  [widthn-1:0] numer_in;
  input  [widthd-1:0] denom_in;
  input  [widthn-1:0] quotient_in;
  input  [widthd-1:0] remain_in;

  output [widthn-1:0] numer_out;
  output [widthd-1:0] denom_out;
  output [widthn-1:0] quotient_out;
  output [widthd-1:0] remain_out;

  reg [widthd:0]   numer_cur;
  reg [widthn-1:0] quotient_cur;
  reg [widthd-1:0] remain_cur;

  integer i;

  always @*
  begin
    remain_cur   = remain_in;
    quotient_cur = quotient_in;   //初始化商

    for (i = 0; i < iterat_num; i = i + 1)
    begin
      numer_cur = {remain_cur, numer_in[widthn-1-i]};
      if (numer_cur >= denom_in)
      begin
        quotient_cur = (quotient_cur<<1) + 1'b1;  // 商为1
        remain_cur = numer_cur - denom_in;        // 求余
      end
      else
      begin
        quotient_cur = quotient_cur<<1;           // 商为0
        remain_cur = numer_cur[widthd-1:0];
      end
    end
  end

  assign denom_out    = denom_in;
  assign quotient_out = quotient_cur;
  assign remain_out   = remain_cur;

  generate
  begin
    if(iterat_num < widthn)
      assign numer_out = {numer_in[widthn-1-iterat_num:0],{iterat_num{1'b0}}};
    else
      assign numer_out =  {widthn{1'b0}};
  end
  endgenerate

endmodule
