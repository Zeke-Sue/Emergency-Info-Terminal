`timescale 1ns/1ps

module tb_museum_integration;
    tb_media_player #(.TEST_MUSEUM(1),.FIXED_RATE_AXIS(1)) museum_test();
endmodule
