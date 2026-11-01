`timescale 1ns/1ps

module packed_line_bank(
    input wire write_clk,write_enable,
    input wire [8:0] write_addr,
    input wire [23:0] write_data,
    input wire read_clk,
    input wire [8:0] read_addr,
    output wire [23:0] read_data
);
    reg [23:0] memory [0:511];
    reg [23:0] read_q;
    always @(posedge write_clk)if(write_enable)memory[write_addr]<=write_data;
    always @(posedge read_clk)read_q<=memory[read_addr];
    assign read_data=read_q;
endmodule
