`timescale 1ns/1ps

module subtitle_bitmap_rom(
    input wire clk,
    input wire [3:0] subtitle_slot,
    input wire [3:0] row,
    input wire [6:0] pixel_x,
    output wire pixel
);
    wire [11:0] address={subtitle_slot,row,pixel_x[6:3]};
    reg [2:0] pixel_select;
`ifdef __ICARUS__
    reg [7:0] memory [0:4095];
    reg [7:0] read_q;
    initial $readmemh("../../rtl/subtitle_bitmap.packed.mem",memory);
    always @(posedge clk) begin
        read_q<=memory[address];pixel_select<=pixel_x[2:0];
    end
    assign pixel=read_q[~pixel_select];
`else
    wire [7:0] read_q;
    always @(posedge clk) pixel_select<=pixel_x[2:0];
    EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(12),.ADDR_WIDTH_B(12),
        .DATA_DEPTH_A(4096),.DATA_DEPTH_B(4096),
        .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
        .INIT_FILE("../rtl/subtitle_bitmap.packed.mif"),.IMPLEMENT("32K")) rom(
        .dia(8'b0),.addra(address),.cea(1'b1),.ocea(1'b1),.clka(clk),
        .wea(1'b0),.rsta(1'b0),.bea(1'b1),
        .dib(8'b0),.addrb(12'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),
        .web(1'b0),.rstb(1'b0),.beb(1'b1),.doa(read_q),.dob());
    assign pixel=read_q[~pixel_select];
`endif
endmodule
