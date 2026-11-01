`timescale 1ns/1ps
module tb_scaler_crop_four;
    tb_scaler #(.WIDTH(8),.HEIGHT(4),.SOURCE_WIDTH(9),.SOURCE_HEIGHT(7),
        .VIEW_SHIFT(2),.PAN_X(0),.PAN_Y(4)) crop();
endmodule
