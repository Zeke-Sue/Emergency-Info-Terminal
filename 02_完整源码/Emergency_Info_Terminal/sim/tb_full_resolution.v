`timescale 1ns/1ps

module tb_full_resolution;
    tb_media_player #(.WIDTH(640),.HEIGHT(480),.BURST(128),
        .HTOTAL(800),.VTOTAL(525),.HSTART(160),.VSTART(45),
        .FIXED_RATE_AXIS(1)) full_test();
endmodule
