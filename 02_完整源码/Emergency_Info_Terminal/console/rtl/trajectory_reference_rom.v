`timescale 1ns/1ps

module trajectory_reference_rom(input wire clk,input wire [8:0] address,
    output wire [35:0] value);
`ifdef __ICARUS__
    reg [35:0] memory[0:511];
    reg [35:0] q;
    initial $readmemh("../../console/rtl/trajectory.mem",memory);
    always @(posedge clk)q<=memory[address];
    assign value=q;
`else
    EG_LOGIC_BRAM #(.DATA_WIDTH_A(36),.DATA_WIDTH_B(36),
        .ADDR_WIDTH_A(9),.ADDR_WIDTH_B(9),.DATA_DEPTH_A(512),.DATA_DEPTH_B(512),
        .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
        .INIT_FILE("../rtl/trajectory.mif"),.IMPLEMENT("9K")) rom(
        .dia(36'd0),.addra(address),.cea(1'b1),.ocea(1'b1),.clka(clk),
        .wea(1'b0),.rsta(1'b0),.bea(4'b1111),
        .dib(36'd0),.addrb(9'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),
        .web(1'b0),.rstb(1'b0),.beb(4'b1111),.doa(value),.dob());
`endif
endmodule
