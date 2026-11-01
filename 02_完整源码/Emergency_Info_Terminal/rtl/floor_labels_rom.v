`timescale 1ns/1ps

module floor_labels_rom(input wire clk,input wire [10:0] pre_x,pre_y,output wire ink);
 wire [10:0] xx=pre_x-64;wire [15:0] address={pre_y[8:1],xx[8:1]};
 reg in_bounds;always @(posedge clk)in_bounds<=pre_x>=64&&pre_x<576&&pre_y<480;
 wire q;
`ifdef __ICARUS__
 reg memory[0:65535];reg qr;initial $readmemh("../../rtl/floor_labels.mem",memory);
 always @(posedge clk)qr<=memory[address];assign q=qr;
`else
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(1),.DATA_WIDTH_B(1),.ADDR_WIDTH_A(16),.ADDR_WIDTH_B(16),
 .DATA_DEPTH_A(65536),.DATA_DEPTH_B(65536),.MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
 .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.INIT_FILE("../rtl/floor_labels.mif"),.IMPLEMENT("9K")) rom(
 .dia(1'b0),.addra(address),.cea(1'b1),.ocea(1'b1),.clka(clk),.wea(1'b0),.rsta(1'b0),.bea(1'b1),
 .dib(1'b0),.addrb(16'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),.web(1'b0),.rstb(1'b0),.beb(1'b1),.doa(q),.dob());
`endif
 assign ink=in_bounds&&q;
endmodule
