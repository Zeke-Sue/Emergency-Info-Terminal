`timescale 1ns/1ps

module tb_transitions;
    tb_media_player #(.FADE_STEPS(4),.TEST_TRANSITIONS(1)) transition_test();
endmodule
