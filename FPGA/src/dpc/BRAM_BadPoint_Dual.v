/*
 * 双端口BRAM模块，用于手动坏点表存储
 * 端口A：配置端口（写入）
 * 端口B：读取端口（查询）
 */

module BRAM_BadPoint_Dual #(
    parameter ADDR_WIDTH = 7,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 128
)(
    // 端口A - 配置端口
    input wire                  clka,
    input wire                  ena,
    input wire                  wea,
    input wire [ADDR_WIDTH-1:0] addra,
    input wire [DATA_WIDTH-1:0] dina,
    
    // 端口B - 读取端口
    input wire                  clkb,
    input wire                  enb,
    input wire                  web,        // 通常为0（只读）
    input wire [ADDR_WIDTH-1:0] addrb,
    input wire [DATA_WIDTH-1:0] dinb,       // 通常未使用
    output reg [DATA_WIDTH-1:0] doutb
);

    // 双端口BRAM存储器
    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    // 端口A - 写操作
    always @(posedge clka) begin
        if (ena && wea) begin
            memory[addra] <= dina;
        end
    end
    
    // 端口B - 读操作  
    always @(posedge clkb) begin
        if (enb) begin
            doutb <= memory[addrb];
        end
    end

endmodule
