// 重排SDRAM读回数据位序，供图像与音频共享读取路径使用。
`timescale 1ns/1ps

module sdram_read_alignment(
    input wire clk,
    input wire [31:0] raw_data,
    output reg [31:0] aligned_data
);
    always @(posedge clk) aligned_data <= raw_data;
endmodule
