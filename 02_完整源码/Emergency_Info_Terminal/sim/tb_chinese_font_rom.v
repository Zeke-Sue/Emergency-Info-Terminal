`timescale 1ns/1ps
module tb_chinese_font_rom;
 reg [15:0] codepoint;
 reg [3:0] row;
 wire [15:0] pixels;
 chinese_font_rom dut(.codepoint(codepoint),.row(row),.pixels(pixels));
 reg [255:0] golden;
 integer i;
 task fail;input [511:0] why;begin $display("TEST_FAIL tb_chinese_font_rom %0s",why);$finish;end endtask
 initial begin

 golden=256'h0180018001803FFC21842184218421843FFC2184018001800180018001800000;
 codepoint=16'h4e2d;
 for(i=0;i<16;i=i+1)begin row=i;#1;if(pixels!==(golden>>((15-i)*16)&16'hffff))fail("row order / glyph mismatch");end
 codepoint=16'h0020;for(i=0;i<16;i=i+1)begin row=i;#1;if(pixels!==0)fail("space");end
 codepoint=16'hffff;for(i=0;i<16;i=i+1)begin row=i;#1;if(pixels!==0)fail("unknown glyph");end
 $display("TEST_PASS tb_chinese_font_rom known Chinese bitmap, row orientation, blank and unknown glyph");$finish;
 end
endmodule
