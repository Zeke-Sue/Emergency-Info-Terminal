`timescale 1ns/1ps
module tb_demo_playlist_guard;
    reg clk=0,rst=1,mounted=0,entry=0,wav=0,long_name=0;
    always #5 clk=~clk;
    reg [4:0] ordinal=0,bmps=0,wavs=0;
    reg [31:0] hash=0;
    reg [7:0] length=11;
    wire [31:0] short_hash,long_hash;
    wire [7:0] expected_length;
    wire known,valid;
    demo_playlist_names names(.wav(wav),.ordinal(ordinal),.short_hash(short_hash),
        .long_hash(long_hash),.name_length(expected_length),.known(known));
    demo_playlist_guard guard(.clk(clk),.rst(rst),.mounted(mounted),.entry_valid(entry),
        .entry_wav(wav),.entry_long(long_name),.entry_ordinal(ordinal),.entry_hash(hash),
        .entry_length(length),.bmp_count(bmps),.wav_count(wavs),
        .malformed_count(8'd0),.overflow(1'b0),.valid(valid));
    integer i;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(i=0;i<28;i=i+1)begin
            wav=i>=16;ordinal=i>=16 ? i-16 : i;long_name=i%2;
            #1;hash=long_name ? long_hash : short_hash;length=long_name ? expected_length : 11;
            entry=1;@(negedge clk);entry=0;
        end
        mounted=1;bmps=16;wavs=11;#1;if(valid)$fatal(1,"missing WAV accepted");
        wavs=12;#1;if(!valid)$fatal(1,"complete playlist refused");
        hash=hash^32'd1;entry=1;@(negedge clk);entry=0;
        if(valid)$fatal(1,"renamed asset accepted");
        $display("TEST_PASS tb_demo_playlist_guard filenames, missing file and mismatch rejection");$finish;
    end
    initial begin #20000;$fatal(1,"playlist guard timeout");end
endmodule
