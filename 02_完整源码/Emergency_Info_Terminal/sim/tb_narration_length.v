`timescale 1ns/1ps
module tb_narration_length;
    reg clk=0,rst=1,tick=0,start=0,stop=0,pause=0,we=0;
    reg [31:0] length=12,cue_sample=4;
    reg [7:0] cfg_index=0,cfg_subtitle=1;reg cfg_last=1;
    wire playing,done;wire [47:0] elapsed;wire [7:0] subtitle;
    integer i;
    always #5 clk=~clk;
    narration_timeline #(.USE_ASSET_LENGTH(1)) dut(.clk(clk),.rst(rst),
        .sample_tick(tick),.start(start),.stop(stop),.pause(pause),.image_id(4'd0),
        .start_sample(32'd0),
        .asset_samples(length),.cfg_we(we),.cfg_index(cfg_index),.cfg_sample(cue_sample),
        .cfg_subtitle(cfg_subtitle),.cfg_last(cfg_last),.playing(playing),
        .elapsed_samples(elapsed),.subtitle_id(subtitle),.narration_done(done));
    task fail;input [8*90-1:0] message;begin
        $display("TEST_FAIL tb_narration_length %0s elapsed=%0d",message,elapsed);$finish;
    end endtask
    task begin_track;begin
        @(negedge clk);start=1;@(negedge clk);start=0;
        repeat(4)@(negedge clk);
    end endtask
    task sample_tick;begin
        @(negedge clk);tick=1;@(negedge clk);tick=0;
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;we=1;
        @(negedge clk);we=0;begin_track();
        for(i=1;i<=12;i=i+1)begin
            sample_tick();if(elapsed!=i)fail("output sample count");
            if(i<12&&(!playing||done))fail("last subtitle stopped longer file");
        end
        if(playing||!done)fail("real file length did not end track");
        length=3;begin_track();repeat(2)sample_tick();pause=1;
        repeat(20)sample_tick();if(elapsed!=2||!playing)fail("pause advanced samples");
        pause=0;sample_tick();if(playing||!done)fail("shorter file did not end");
        cue_sample=1200000;we=1;@(negedge clk);we=0;
        length=1300000;begin_track();
        if(dut.current_sample!=1200000)fail("25-second cue truncated to 20 bits");
        stop=1;@(negedge clk);stop=0;
        if(playing||done)fail("preemption incorrectly completed narration");
        $display("TEST_PASS tb_narration_length actual EOF, early/late last cue, pause, 25s timestamp and preemption");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
