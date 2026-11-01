`timescale 1ns/1ps

module tb_scaler_wide;
    tb_scaler #(.WIDTH(8),.HEIGHT(6),.SOURCE_WIDTH(5),.SOURCE_HEIGHT(2)) wide();
endmodule
