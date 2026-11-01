`timescale 1ns/1ps

module tb_mid_resolution;
    tb_media_player #(.WIDTH(256),.HEIGHT(120),.BURST(128),
        .HTOTAL(320),.VTOTAL(140),.HSTART(64),.VSTART(16),
        .FIXED_RATE_AXIS(1)) mid_test();
endmodule
