`timescale 1ns/1ps
module tb_l0_voice;
    reg clk=0,rst=1,sample_tick=0,alarm=0,drill=0,cancel=0,trusted=1;
    always #5 clk=~clk;
    reg [2:0] level=1;reg [15:0] countdown=12;
    wire cfg_we,enqueue,urgent,ready,voice_valid,playing,overflow;
    wire [5:0] cfg_segment,segment,active;
    wire [15:0] cfg_start,cfg_length,address;
    wire [3:0] nibble;wire signed [15:0] voice;
    l0_voice_scheduler scheduler(.clk(clk),.rst(rst),.alarm_active(alarm),
        .alarm_drill(drill),.cancel_notice(cancel),.alarm_level(level),
        .countdown_trusted(trusted),.countdown_seconds(countdown),
        .enqueue_ready(ready),.cfg_we(cfg_we),.cfg_segment(cfg_segment),
        .cfg_start(cfg_start),.cfg_length(cfg_length),.enqueue_valid(enqueue),
        .enqueue_segment(segment),.enqueue_urgent(urgent));
    l0_voice_rom rom(.clk(clk),.address(address),.nibble(nibble));
    voice_segment_player #(.GAP_SAMPLES(3)) player(.clk(clk),.rst(rst),
        .sample_tick(sample_tick),.enqueue_valid(enqueue),.enqueue_segment(segment),
        .enqueue_urgent(urgent),.enqueue_ready(ready),.cfg_we(cfg_we),
        .cfg_segment(cfg_segment),.cfg_start(cfg_start),.cfg_length(cfg_length),
        .rom_address(address),.rom_nibble(nibble),.voice_valid(voice_valid),
        .voice_sample(voice),.playing(playing),.active_segment(active),
        .queue_overflow(overflow));
    task tick;begin repeat(4)@(negedge clk);sample_tick=1;
        @(negedge clk);sample_tick=0;end endtask
    task fail;input [8*100-1:0] reason;
        begin $display("TEST_FAIL tb_l0_voice: %0s",reason);$finish;end endtask
    integer i,nonzero,saw_warning,saw_ten,saw_cancel;
    initial begin
        repeat(3)@(negedge clk);rst=0;repeat(30)@(negedge clk);
        alarm=1;drill=1;nonzero=0;saw_warning=0;
        for(i=0;i<17000;i=i+1) begin
            tick();if(voice_valid&&voice!=0)nonzero=1;
            if(active==12)saw_warning=1;
        end
        if(!nonzero||!saw_warning||overflow)fail("initial L0 phrase");
        countdown=11;repeat(10)tick();countdown=10;saw_ten=0;
        for(i=0;i<6000;i=i+1)begin tick();if(active==10)saw_ten=1;end
        if(!saw_ten)begin
            $display("active=%0d pending=%0d queue=%0d playing=%b countdown_q=%0d",
                active,scheduler.sequence_count,player.queue_count,playing,
                scheduler.countdown_q);
            fail("countdown prompt");
        end
        cancel=1;saw_cancel=0;repeat(2)@(negedge clk);cancel=0;
        for(i=0;i<6000;i=i+1)begin tick();if(active==19)saw_cancel=1;end
        if(!saw_cancel)fail("urgent cancellation prompt");
        $display("TEST_PASS tb_l0_voice BRAM catalog, ADPCM output, countdown and urgent cancel");
        $finish;
    end
    initial begin #3000000;fail("timeout");end
endmodule
