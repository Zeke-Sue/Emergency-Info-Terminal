`timescale 1ns/1ps
module tb_scaler_crop_bilinear;
    tb_scaler #(.WIDTH(8),.HEIGHT(6),.SOURCE_WIDTH(9),.SOURCE_HEIGHT(7),
        .VIEW_SHIFT(1),.PAN_X(4),.PAN_Y(3)) crop();
endmodule
