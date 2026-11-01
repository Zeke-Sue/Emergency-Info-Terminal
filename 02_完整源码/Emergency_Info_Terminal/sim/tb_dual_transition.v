`timescale 1ns/1ps
module tb_dual_transition;
    reg clk=0,rst=1,frame=0,next=0,abort=0;
    always #5 clk=~clk;
    reg [2:0] mode=0;reg [1:0] duration=0;reg easing=0;
    wire [6:0] phase;wire active;wire [3:0] image,target;
    player_control #(.DUAL_SOURCE(1),.USE_CACHE(1),.EASING_CONTROL(1)) control(
        .clk(clk),.rst(rst),.ready(1'b1),.frame_tick(frame),.next_event(next),
        .auto_event(1'b0),.period_event(1'b0),.effect_select(mode),.external_play(1'b0),
        .previous_event(1'b0),.external_activity(1'b0),.follow_narration(1'b0),
        .external_period(2'd0),.resident(16'hffff),.emergency_abort(abort),
        .transition_duration(duration),.image_index(image),.transition_target(target),
        .transition_easing(easing),
        .slide_active(active),.transition_phase(phase));
    reg [23:0] old_rgb=0,new_rgb=0;reg [6:0] p=0;
    wire [23:0] rgb;
    dual_source_blend blend(.old_rgb(old_rgb),.new_rgb(new_rgb),.progress(p),
        .crossfade(1'b1),.select_new(1'b0),.enable(1'b1),.rgb(rgb));
    task fail;input [255:0] why;begin $display("TEST_FAIL dual transition: %0s",why);$finish;end endtask
    task tick;begin @(negedge clk);frame=1;@(negedge clk);frame=0;end endtask
    integer a,b,k,n,d,expected,e,linear,distance,previous_phase,start_image;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(d=0;d<3;d=d+1)begin
            duration=d;next=1;@(negedge clk);next=0;tick();
            if(!active||phase!=0)fail("start");
            n=0;
            while(active)begin tick();n=n+1;if(n>64)fail("stuck");end
            if(n!=(16<<d)||image!=d+1)fail("duration or commit");
        end
        next=1;@(negedge clk);next=0;tick();repeat(20)tick();
        abort=1;tick();abort=0;
        if(active||image!=3)fail("emergency abort changed source");
        for(e=0;e<2;e=e+1)for(d=0;d<3;d=d+1)begin
            easing=e;duration=d;start_image=image;
            next=1;@(negedge clk);next=0;tick();previous_phase=0;

            easing=!e;duration=(d+1)%3;
            for(n=1;n<=(16<<d);n=n+1)begin
                tick();linear=n*(4>>d);distance=linear<=32 ? linear : 64-linear;
                expected=e ? (distance*distance+16)/32 : linear;
                if(e && linear>32)expected=64-expected;
                if(phase!==expected || phase<previous_phase)fail("curve or latched controls");
                previous_phase=phase;
                if(n<(16<<d) && !active)fail("early eased commit");
            end
            if(active || image!=start_image+1)fail("eased endpoint commit");
        end
        easing=1;duration=2;
        for(k=1;k<64;k=k+1)begin
            start_image=image;next=1;@(negedge clk);next=0;tick();repeat(k)tick();
            abort=1;tick();abort=0;
            if(active || image!=start_image || phase!=0)fail("eased abort phase");
        end
        for(a=0;a<256;a=a+17)for(b=0;b<256;b=b+17)for(k=0;k<=64;k=k+1)begin
            old_rgb={3{a[7:0]}};new_rgb={3{b[7:0]}};p=k;#1;
            expected=(a*(64-k)+b*k+32)/64;
            if(rgb!=={3{expected[7:0]}})fail("rounding or signed blend");
        end
        $display("TEST_PASS tb_dual_transition 16/32/64 linear/eased frames, locked settings, 63 abort phases, 16640 blend vectors");$finish;
    end
    initial begin #1000000;fail("timeout");end
endmodule
