`timescale 1ns/1ps
module gamma_curve_rom(input wire clk,input wire [7:0] address,output wire [15:0] value);
`ifdef __ICARUS__
    reg [15:0] memory[0:255];
    reg [15:0] q;
    initial $readmemh("../../rtl/gamma_curve.mem",memory);
    always @(posedge clk)q<=memory[address];
    assign value=q;
`else
    EG_LOGIC_BRAM #(.DATA_WIDTH_A(16),.DATA_WIDTH_B(16),
        .ADDR_WIDTH_A(8),.ADDR_WIDTH_B(8),.DATA_DEPTH_A(256),.DATA_DEPTH_B(256),
        .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
        .INIT_FILE("../rtl/gamma_curve.mif"),.IMPLEMENT("9K")) rom(
        .dia(16'd0),.addra(address),.cea(1'b1),.ocea(1'b1),.clka(clk),
        .wea(1'b0),.rsta(1'b0),.bea(2'b11),
        .dib(16'd0),.addrb(8'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),
        .web(1'b0),.rstb(1'b0),.beb(2'b11),.doa(value),.dob());
`endif
endmodule
