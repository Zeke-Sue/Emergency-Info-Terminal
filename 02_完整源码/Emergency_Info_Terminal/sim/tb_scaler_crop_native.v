`timescale 1ns/1ps
module tb_scaler_crop_native;

    tb_scaler #(.WIDTH(4),.HEIGHT(3),.SOURCE_WIDTH(9),.SOURCE_HEIGHT(6),
        .VIEW_SHIFT(1),.PAN_X(3),.PAN_Y(1)) crop();
endmodule
