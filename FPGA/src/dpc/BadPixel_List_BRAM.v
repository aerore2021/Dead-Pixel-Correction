/*
 * 坏点列表BRAM模块
 * 
 * 功能：
 * - 双端口BRAM，支持同时读写
 * - Port A: 用于写入坏点坐标
 * - Port B: 用于读取坏点坐标（AXI接口）
 * - 支持真双端口操作
 */

module BadPixel_List_BRAM #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter DEPTH = 256
)(
    // Port A (写端口)
    input  wire                    clka,
    input  wire                    ena,
    input  wire                    wea,
    input  wire [ADDR_WIDTH-1:0]   addra,
    input  wire [DATA_WIDTH-1:0]   dina,
    output reg  [DATA_WIDTH-1:0]   douta,
    
    // Port B (读端口)
    input  wire                    clkb,
    input  wire                    enb,
    input  wire                    web,
    input  wire [ADDR_WIDTH-1:0]   addrb,
    input  wire [DATA_WIDTH-1:0]   dinb,
    output reg  [DATA_WIDTH-1:0]   doutb
);

    // BRAM存储器
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    // 初始化BRAM内容
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            memory[i] = {DATA_WIDTH{1'b0}};
        end
    end

    // Port A操作
    always @(posedge clka) begin
        if (ena) begin
            if (wea) begin
                memory[addra] <= dina;
                douta <= dina;  // 写透模式
            end else begin
                douta <= memory[addra];  // 读模式
            end
        end
    end

    // Port B操作
    always @(posedge clkb) begin
        if (enb) begin
            if (web) begin
                memory[addrb] <= dinb;
                doutb <= dinb;  // 写透模式
            end else begin
                doutb <= memory[addrb];  // 读模式
            end
        end
    end

endmodule
