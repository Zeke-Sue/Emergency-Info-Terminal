`timescale 1ns/1ps
module tb_audio_output_flags;
    tb_audio_output_stage #(.SATURATING_FLAGS(1)) test();
endmodule
