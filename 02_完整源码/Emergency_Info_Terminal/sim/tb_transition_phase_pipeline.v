`timescale 1ns/1ps
module tb_transition_phase_pipeline;
    reg clk=0,rst=1,frame=0,next=0,abort=0;
    reg [1:0] duration=0;
    reg ease=0;
    wire [6:0] direct,piped;
    wire active0,active1;
    wire [3:0] image0,image1;
    reg [6:0] previous=0;
    integer d,e,n;
    always #5 clk=~clk;
    player_control #(.DUAL_SOURCE(1),.EASING_CONTROL(1),.PIPELINED_PHASE(0)) reference(
        .clk(clk),.rst(rst),.ready(1'b1),.frame_tick(frame),.next_event(next),
        .auto_event(1'b0),.period_event(1'b0),.effect_select(3'd6),
        .external_play(1'b0),.previous_event(1'b0),.external_activity(1'b0),
        .follow_narration(1'b0),.external_period(2'd0),.resident(16'hffff),
        .emergency_abort(abort),.transition_duration(duration),.transition_easing(ease),
        .transition_phase(direct),.transition_active(active0),.image_index(image0));
    player_control #(.DUAL_SOURCE(1),.EASING_CONTROL(1),.PIPELINED_PHASE(1)) dut(
        .clk(clk),.rst(rst),.ready(1'b1),.frame_tick(frame),.next_event(next),
        .auto_event(1'b0),.period_event(1'b0),.effect_select(3'd6),
        .external_play(1'b0),.previous_event(1'b0),.external_activity(1'b0),
        .follow_narration(1'b0),.external_period(2'd0),.resident(16'hffff),
        .emergency_abort(abort),.transition_duration(duration),.transition_easing(ease),
        .transition_phase(piped),.transition_active(active1),.image_index(image1));
    always @(posedge clk)begin
        previous=direct;#1;
        if(!rst&&(piped!==previous||image0!==image1||active0!==active1))
            $fatal(1,"TEST_FAIL phase pipeline changed arithmetic or frame transaction");
    end
    task video_frame;
        begin frame=1;@(negedge clk);frame=0;repeat(3)@(negedge clk);
            if(piped!==direct)$fatal(1,"TEST_FAIL phase not settled before active video");
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(d=0;d<3;d=d+1)for(e=0;e<2;e=e+1)begin
            duration=d;ease=e;next=1;@(negedge clk);next=0;
            for(n=0;n<70;n=n+1)video_frame();
            if(active1||piped!=64)$fatal(1,"TEST_FAIL transition completion");
        end
        next=1;@(negedge clk);next=0;repeat(8)video_frame();abort=1;video_frame();
        if(active1||piped!=0)$fatal(1,"TEST_FAIL emergency abort");
        $display("TEST_PASS registered transition phase, 16/32/64 frames, easing, emergency abort");$finish;
    end
endmodule
