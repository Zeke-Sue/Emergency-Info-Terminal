`timescale 1ns/1ps
module tb_controls;
    reg clk=0,rst=1,ready=1,frame_tick=0,next_event=0,auto_event=0,period_event=0,key_n=1;
    reg [2:0] effect_select=0;
    always #5 clk=~clk;
    wire [3:0] image_index,transition_target;
    wire [1:0] period_select;
    wire autoplay,press,short_release,long_press,held,transition_active;
    wire slide_active;
    wire [5:0] period_seconds;
    wire [4:0] video_gain;
    wire [2:0] transition_mode;
    wire [4:0] slide_progress;
    player_control #(.CLK_HZ(20),.FADE_STEPS(4)) dut(
        .clk(clk),.rst(rst),.ready(ready),.frame_tick(frame_tick),
        .next_event(next_event),.auto_event(auto_event),.period_event(period_event),
        .effect_select(effect_select),
        .external_play(1'b0),.previous_event(1'b0),.external_activity(1'b0),
        .external_period(2'd2),.follow_narration(1'b0),
        .resident(16'hffff),.emergency_abort(1'b0),
        .image_index(image_index),.autoplay(autoplay),.period_select(period_select),
        .period_seconds(period_seconds),.video_gain(video_gain),.transition_mode(transition_mode),
        .transition_target(transition_target),.slide_progress(slide_progress),
        .slide_active(slide_active),.transition_active(transition_active));
    key_events #(.CLK_HZ(20),.DEBOUNCE_CYCLES(3),.LONG_CYCLES(12)) key_dut(
        .clk(clk),.rst(rst),.key_n(key_n),.press(press),.short_release(short_release),
        .long_press(long_press),.held(held));
    integer press_count=0,short_count=0,long_count=0;
    task fail;
        input [8*160-1:0] reason;
        begin
            $display("TEST_FAIL tb_controls: %0s",reason);
            $finish;
        end
    endtask
    always @(posedge clk)if(!rst)begin
        if(press)press_count=press_count+1;
        if(short_release)short_count=short_count+1;
        if(long_press)long_count=long_count+1;
    end
    task automatic step(input integer n);repeat(n)@(negedge clk);endtask
    task automatic restart;
        begin rst=1;step(3);rst=0;step(2);end
    endtask
    task automatic frame;
        begin frame_tick=1;step(1);frame_tick=0;step(1);end
    endtask
    task automatic period_change;
        begin period_event=1;step(1);period_event=0;step(1);end
    endtask
    task automatic finish_transition(input [3:0] expected_image);
        integer guard;
        begin
            guard=0;
            while(image_index!=expected_image || transition_active)begin
                frame();guard=guard+1;
                if(guard>12)begin
                    $display("transition timeout image=%0d gain=%0d",image_index,video_gain);
                    fail("transition timeout");
                end
            end
            if(video_gain!=16)fail("transition did not restore full gain");
        end
    endtask
    integer p,seconds,dwell_elapsed;
    initial begin
        $dumpfile("tb_controls.vcd");$dumpvars(0,tb_controls);
        restart();
        key_n=0;step(1);key_n=1;step(8);
        if(press_count!=0)fail("bounce was accepted");
        key_n=0;step(8);key_n=1;step(8);
        if(press_count!=1||short_count!=1||long_count!=0)fail("short key classification");
        key_n=0;step(35);key_n=1;step(8);
        if(press_count!=2||short_count!=1||long_count!=1)fail("long press repeated or also generated short press");
        next_event=1;step(1);next_event=0;step(3);
        if(image_index!=0)fail("manual switch before frame boundary");
        frame();if(image_index!=0||video_gain!=12||!transition_active)fail("fade-out step 1");
        frame();if(image_index!=0||video_gain!=8)fail("fade-out step 2");
        frame();if(image_index!=0||video_gain!=4)fail("fade-out step 3");
        frame();if(image_index!=1||video_gain!=0)fail("black-frame image commit");
        repeat(3)frame();if(video_gain!=12)fail("fade-in progression");
        frame();if(video_gain!=16||transition_active)fail("fade-in completion");
        for(p=0;p<15;p=p+1)begin
            next_event=1;step(1);next_event=0;finish_transition(image_index+1'b1);
        end
        if(image_index!=0)fail("manual wrap failed");
        for(p=0;p<4;p=p+1)begin
            restart();repeat(p)period_change();seconds=period_seconds;
            auto_event=1;step(1);auto_event=0;
            step(seconds*20-1);
            if(dut.requested_index!=0)begin
                $display("autoplay early at %0ds",seconds);
                fail("autoplay early");
            end
            step(1);
            if(dut.requested_index!=1 || image_index!=0)begin
                $display("autoplay period or deferred commit failed at %0ds",seconds);
                fail("autoplay period or deferred commit failed");
            end
            finish_transition(1);if(image_index!=1)fail("autoplay did not complete transition");
            dwell_elapsed=dut.elapsed_seconds*20+dut.second_div;
            if(dut.elapsed_seconds!=0||dwell_elapsed>1)
                fail("autoplay dwell timer counted during transition");
            step(seconds*20-dwell_elapsed-1);
            if(dut.requested_index!=1)
                fail("next autoplay request did not wait a full post-transition dwell");
            step(1);
            if(dut.requested_index!=2)
                fail("post-transition autoplay dwell expired late");
            finish_transition(2);
            auto_event=1;step(1);auto_event=0;step(seconds*20+2);frame();
            if(autoplay||image_index!=2)fail("autoplay pause failed");
        end
        restart();effect_select=2;next_event=1;step(1);next_event=0;effect_select=3;step(2);
        frame();
        if(!slide_active||transition_mode!=2||transition_target!=1||slide_progress!=4)
            fail("transition mode was not latched with the request");
        finish_transition(1);
        ready=0;step(3);if(image_index!=0||autoplay)fail("not-ready state unsafe");
        $display("TEST_PASS tb_controls keys, fade, latched slide mode, manual wrap, autoplay periods and pause");$finish;
    end
    initial begin #100000;fail("controls timeout");end
endmodule
