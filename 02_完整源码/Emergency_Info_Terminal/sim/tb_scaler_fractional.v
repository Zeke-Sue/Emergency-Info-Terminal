`timescale 1ns/1ps
module tb_scaler_fractional;
 tb_scaler #(.WIDTH(8),.HEIGHT(6),.SOURCE_WIDTH(10),.SOURCE_HEIGHT(8)) test();
endmodule
module tb_scaler_portrait_down;
 tb_scaler #(.WIDTH(8),.HEIGHT(6),.SOURCE_WIDTH(6),.SOURCE_HEIGHT(9)) test();
endmodule

module tb_scaler_five_four;
 tb_scaler #(.WIDTH(8),.HEIGHT(4),.SOURCE_WIDTH(10),.SOURCE_HEIGHT(5)) test();
endmodule
module tb_scaler_three_two;
 tb_scaler #(.WIDTH(8),.HEIGHT(6),.SOURCE_WIDTH(12),.SOURCE_HEIGHT(9)) test();
endmodule
