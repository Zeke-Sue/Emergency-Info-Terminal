`timescale 1ns/1ps

module packed_nibble_rom #(
    parameter MEM_FILE="../../rtl/demo_sprite0.packed.mem",
    parameter INIT_FILE="../rtl/demo_sprite0.packed.mif"
)(input wire clk,input wire [12:0] address,output wire [3:0] nibble);
    wire [7:0] byte_q;
    reg high_nibble;
    always @(posedge clk)high_nibble<=address[0];
    assign nibble=high_nibble ? byte_q[7:4] : byte_q[3:0];
`ifdef __ICARUS__
    reg [7:0] memory[0:4095];
    reg [7:0] read_q;
    initial $readmemh(MEM_FILE,memory);
    always @(posedge clk)read_q<=memory[address[12:1]];
    assign byte_q=read_q;
`else
    EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(12),.ADDR_WIDTH_B(12),.DATA_DEPTH_A(4096),.DATA_DEPTH_B(4096),
        .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
        .INIT_FILE(INIT_FILE),.IMPLEMENT("32K")) rom(
        .dia(8'd0),.addra(address[12:1]),.cea(1'b1),.ocea(1'b1),.clka(clk),
        .wea(1'b0),.rsta(1'b0),.bea(1'b1),
        .dib(8'd0),.addrb(12'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),
        .web(1'b0),.rstb(1'b0),.beb(1'b1),.doa(byte_q),.dob());
`endif
endmodule
