`timescale 1ns/1ps
module tb_voice_segments;
    reg clk=0,rst=1,sample_tick=0,enqueue=0,urgent=0,cfg_we=0;
    always #5 clk=~clk;
    reg [5:0] segment=0,cfg_segment=0;reg [15:0] cfg_start=0,cfg_length=0;
    wire [15:0] address;reg [3:0] nibble;wire voice_valid,playing,ready,overflow;wire signed [15:0] voice;wire [5:0] active;
    reg [3:0] rom [0:31];
    always @* nibble=rom[address[4:0]];
    voice_segment_player #(.GAP_SAMPLES(3)) dut(.clk(clk),.rst(rst),.sample_tick(sample_tick),
        .enqueue_valid(enqueue),.enqueue_segment(segment),.enqueue_urgent(urgent),.enqueue_ready(ready),
        .cfg_we(cfg_we),.cfg_segment(cfg_segment),.cfg_start(cfg_start),.cfg_length(cfg_length),
        .rom_address(address),.rom_nibble(nibble),.voice_valid(voice_valid),.voice_sample(voice),
        .playing(playing),.active_segment(active),.queue_overflow(overflow));
    task tick;begin @(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;end endtask
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_voice_segments: %0s",reason);$finish;end endtask
    integer i,valid_samples,nonzero;
    initial begin
        for(i=0;i<32;i=i+1)rom[i]=i[0]?4'h1:4'h7;
        repeat(3)@(negedge clk);rst=0;
        @(negedge clk);cfg_we=1;cfg_segment=3;cfg_start=0;cfg_length=4;@(negedge clk);cfg_we=0;
        segment=3;enqueue=1;@(negedge clk);enqueue=0;
        valid_samples=0;nonzero=0;
        for(i=0;i<40;i=i+1)begin tick();if(voice_valid)begin valid_samples=valid_samples+1;if(voice!=0)nonzero=1;end end
        if(valid_samples<18||!nonzero||playing)fail("segment decode/interpolation/gap");
        segment=3;urgent=1;enqueue=1;@(negedge clk);enqueue=0;urgent=0;

        tick();repeat(12)@(negedge clk);tick();
        if(!playing||active!=3)fail("urgent queue start");
        $display("TEST_PASS tb_voice_segments IMA-ADPCM segment queue, 8k-to-48k interpolation and gap");$finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
