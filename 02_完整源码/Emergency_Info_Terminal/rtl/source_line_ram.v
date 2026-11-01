`timescale 1ns/1ps

module source_line_ram(
    input wire clk,
    input wire write_enable,
    input wire [10:0] write_addr,
    input wire [23:0] write_data,
    input wire [10:0] read_addr,
    output wire [23:0] read_data
);
    wire [15:0] low_q;
    wire [7:0] high_q;
    buffer_ram_32k #(.DATA_WIDTH(16),.ADDR_WIDTH(11)) low_bytes(
        .clk(clk),.we(write_enable),.wa(write_addr),.ra(read_addr),
        .d(write_data[15:0]),.q(low_q));
    buffer_ram_32k #(.DATA_WIDTH(8),.ADDR_WIDTH(11)) high_byte(
        .clk(clk),.we(write_enable),.wa(write_addr),.ra(read_addr),
        .d(write_data[23:16]),.q(high_q));
    assign read_data={high_q,low_q};
endmodule
