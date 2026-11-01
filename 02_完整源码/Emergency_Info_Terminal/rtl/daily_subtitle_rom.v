`timescale 1ns/1ps

module daily_subtitle_strip_rom(
    input wire clk,
    input wire [2:0] track,
    input wire [3:0] row,
    input wire [9:0] pixel_x,
    output wire pixel
);
    wire [13:0] address={track,row,pixel_x[9:3]};
    reg [2:0] bit_q;
    always @(posedge clk)bit_q<=pixel_x[2:0];
`ifdef __ICARUS__
    reg [7:0] memory[0:16383];
    reg [7:0] data_q;
    initial $readmemh("../../rtl/daily_subtitle_strip.mem",memory);
    always @(posedge clk)data_q<=memory[address];
`else
    wire [7:0] data_q;
    EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(14),.ADDR_WIDTH_B(14),.DATA_DEPTH_A(16384),.DATA_DEPTH_B(16384),
        .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
        .INIT_FILE("../rtl/daily_subtitle_strip.mif"),.IMPLEMENT("32K")) rom(
        .dia(8'd0),.addra(address),.cea(1'b1),.ocea(1'b1),.clka(clk),.wea(1'b0),.rsta(1'b0),.bea(1'b1),
        .dib(8'd0),.addrb(14'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),.web(1'b0),.rstb(1'b0),.beb(1'b1),
        .doa(data_q),.dob());
`endif
    assign pixel=data_q[~bit_q];
endmodule

module daily_subtitle_position_rom(
    input wire clk,
    input wire [10:0] address,
    output wire [10:0] position
);
`ifdef __ICARUS__
    reg [15:0] memory[0:2047];
    reg [15:0] data_q;
    initial $readmemh("../../rtl/daily_subtitle_position.mem",memory);
    always @(posedge clk)data_q<=memory[address];
`else
    wire [15:0] data_q;
    EG_LOGIC_BRAM #(.DATA_WIDTH_A(16),.DATA_WIDTH_B(16),
        .ADDR_WIDTH_A(11),.ADDR_WIDTH_B(11),.DATA_DEPTH_A(2048),.DATA_DEPTH_B(2048),
        .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
        .INIT_FILE("../rtl/daily_subtitle_position.mif"),.IMPLEMENT("32K")) rom(
        .dia(16'd0),.addra(address),.cea(1'b1),.ocea(1'b1),.clka(clk),.wea(1'b0),.rsta(1'b0),.bea(1'b1),
        .dib(16'd0),.addrb(11'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),.web(1'b0),.rstb(1'b0),.beb(1'b1),
        .doa(data_q),.dob());
`endif
    assign position=data_q[10:0];
endmodule
