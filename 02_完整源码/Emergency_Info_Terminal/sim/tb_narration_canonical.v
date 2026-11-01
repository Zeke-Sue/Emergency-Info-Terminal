`timescale 1ns/1ps
module tb_narration_canonical;
    tb_narration_wav_streamer #(.CANONICAL_PCM(1)) test();
endmodule

module tb_narration_shared_metadata;
    tb_narration_wav_streamer #(.CANONICAL_PCM(1),.CHANGE_METADATA(1)) test();
endmodule
