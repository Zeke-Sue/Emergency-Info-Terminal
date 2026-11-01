`timescale 1ns/1ps
module tb_scaler_downsample;
    tb_scaler #(.WIDTH(4),.HEIGHT(3),.SOURCE_WIDTH(8),.SOURCE_HEIGHT(6)) downsample();
endmodule
