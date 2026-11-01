`timescale 1ns/1ps
module tb_narration_timeline;
    reg clk=0,rst=1,sample_tick=0,start=0,stop=0,pause=0,cfg_we=0;
    always #5 clk=~clk;
    reg [3:0] image_id=0;reg [7:0] cfg_index=0;reg [31:0] cfg_sample=0;
    reg [7:0] cfg_subtitle=0;reg cfg_last=0;
    wire playing,done;wire [47:0] elapsed;wire [7:0] subtitle;wire [3:0] active_image;
    narration_timeline dut(.clk(clk),.rst(rst),.sample_tick(sample_tick),
        .start(start),.stop(stop),.pause(pause),.image_id(image_id),.cfg_we(cfg_we),
        .start_sample(32'd0),.asset_samples(32'd0),
        .cfg_index(cfg_index),.cfg_sample(cfg_sample),.cfg_subtitle(cfg_subtitle),
        .cfg_last(cfg_last),.playing(playing),.elapsed_samples(elapsed),
        .subtitle_id(subtitle),.active_image(active_image),.narration_done(done));
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_narration_timeline: %0s",reason);$finish;end endtask
    task configure;input [7:0] index;input [31:0] at_sample;input [7:0] sid;input last;
        begin @(negedge clk);cfg_index=index;cfg_sample=at_sample;cfg_subtitle=sid;
            cfg_last=last;cfg_we=1;@(negedge clk);cfg_we=0;end endtask
    task tick;begin repeat(4)@(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        configure({4'd15,4'd0},2,1,0);configure({4'd15,4'd1},5,4,1);
        image_id=15;@(negedge clk);start=1;@(negedge clk);start=0;repeat(4)@(negedge clk);
        if(!playing||active_image!=15||subtitle!=0)fail("image 15 did not start");
        pause=1;tick();tick();if(elapsed!=0||subtitle!=0)
            fail("paused narration advanced");
        pause=0;
        tick();if(subtitle!=0)fail("subtitle changed before cue");
        tick();if(subtitle!=1||!playing)fail("first cue");
        repeat(4)@(negedge clk);tick();tick();tick();
        if(subtitle!=4||playing||!done)fail("last cue or done pulse");
        image_id=2;@(negedge clk);start=1;@(negedge clk);start=0;repeat(4)@(negedge clk);
        tick();if(playing||!done)fail("unconfigured image did not terminate safely");
        $display("TEST_PASS tb_narration_timeline pause-safe 16-image sample cues");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
