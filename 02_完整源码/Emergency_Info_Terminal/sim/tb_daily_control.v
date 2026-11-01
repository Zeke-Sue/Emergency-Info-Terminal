`timescale 1ns/1ps
module tb_daily_control;
    reg clk=0,rst=1,ready=0,frame_tick=0;
    reg k1=0,k1_long=0,k2=0,k3=0,k3_long=0,k4_long=0;
    reg maintenance_enable=0,grayscale_switch=0;
    always #5 clk=~clk;
    wire previous_event,next_event,auto_event,period_event,reload_event;
    wire zoom_mode,grayscale_enable,osd_visible;
    wire [2:0] brightness_level,contrast_level,saturation_level;
    wire [1:0] gamma,temp;wire [3:0] selection;wire [2:0] volume;
    wire [2:0] effect_mode;wire [1:0] effect_duration;wire effect_easing;
    wire [1:0] flash_rate,flash_duty;
    wire [3:0] image_index,transition_target;
    wire autoplay,slide_active,transition_active;
    wire [1:0] period_select;wire [2:0] transition_mode;
    wire [5:0] period_seconds;
    wire [4:0] video_gain,slide_progress;
    daily_control #(.EXTENDED_MENU(1),.AUDIO_MENU(1),.ALERT_MENU(1)) keys(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),
        .follow_switch(1'b0),
        .maintenance_enable(maintenance_enable),.grayscale_switch(grayscale_switch),
        .key1_short(k1),.key1_long(k1_long),.key2_short(k2),.key3_short(k3),
        .key3_long(k3_long),.key4_long(k4_long),
        .previous_event(previous_event),.next_event(next_event),
        .auto_event(auto_event),.period_event(period_event),.reload_event(reload_event),
        .zoom_mode(zoom_mode),.grayscale_enable(grayscale_enable),.osd_visible(osd_visible),
        .brightness_level(brightness_level),.contrast_level(contrast_level),
        .saturation_level(saturation_level),.gamma_mode(gamma),.temperature_mode(temp),
        .effect_mode(effect_mode),.effect_duration(effect_duration),.effect_easing(effect_easing),
        .maintenance_selection(selection),.volume_level(volume),
        .flash_rate(flash_rate),.flash_duty(flash_duty));
    player_control #(.CLK_HZ(100),.FADE_STEPS(1),.START_AUTOPLAY(1),.IMAGE_COUNT(8),
        .DEFAULT_PERIOD(0),.PERIOD_0(1),.PERIOD_1(2),
        .PERIOD_2(5),.PERIOD_3(10)) player(
        .clk(clk),.rst(rst),.ready(ready),.frame_tick(frame_tick),
        .next_event(next_event),.auto_event(auto_event),.period_event(period_event),
        .effect_select(3'd0),.external_play(1'b0),.previous_event(previous_event),
        .external_activity(1'b0),.external_period(2'd0),
        .follow_narration(1'b0),
        .resident(16'h00ff),.emergency_abort(1'b0),.desired_image(),
        .image_index(image_index),.autoplay(autoplay),.period_select(period_select),
        .period_seconds(period_seconds),.video_gain(video_gain),
        .transition_mode(transition_mode),.transition_target(transition_target),
        .slide_progress(slide_progress),.slide_active(slide_active),
        .transition_active(transition_active));
    task fail;
        input [8*120-1:0] reason;
        begin $display("TEST_FAIL tb_daily_control: %0s",reason);$finish;end
    endtask
    task pulse;
        input integer key_id;
        begin
            @(negedge clk);
            case(key_id)
                1:k1=1;2:k2=1;3:k3=1;4:k3_long=1;5:k4_long=1;
                6:k1_long=1;
            endcase
            @(negedge clk);k1=0;k1_long=0;k2=0;k3=0;k3_long=0;k4_long=0;
        end
    endtask
    task frame;
        begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end
    endtask
    task settle;
        integer n;
        begin
            n=0;
            while(transition_active)begin frame();n=n+1;if(n>4)fail("transition stuck");end
        end
    endtask
    integer p;
    initial begin
        repeat(3)@(negedge clk);rst=0;ready=1;
        repeat(3)@(negedge clk);
        if(!autoplay||period_seconds!=1)fail("startup autoplay/period");
        pulse(1);settle();if(image_index!=7)fail("previous did not wrap 0 to 7");
        pulse(2);settle();if(image_index!=0)fail("next did not wrap 7 to 0");
        pulse(6);frame();if(!zoom_mode)fail("KEY1 long did not enable playback zoom");
        pulse(6);frame();if(zoom_mode)fail("KEY1 long did not disable playback zoom");
        grayscale_switch=1;@(negedge clk);
        if(!grayscale_enable)fail("SW4 grayscale input not connected");
        grayscale_switch=0;@(negedge clk);
        pulse(3);if(autoplay)fail("KEY3 short did not pause");
        for(p=0;p<4;p=p+1)begin
            pulse(4);
            case(p)
                0:if(period_seconds!=2)fail("2 second period");
                1:if(period_seconds!=5)fail("5 second period");
                2:if(period_seconds!=10)fail("10 second period");
                3:if(period_seconds!=1)fail("1 second wrap");
            endcase
        end
        k1=1;k2=1;#1;
        if(!previous_event||next_event)fail("simultaneous key priority");
        k4_long=1;#1;
        if(!reload_event||previous_event||next_event)fail("reload priority");
        k1=0;k2=0;k4_long=0;
        pulse(3);if(!autoplay)fail("KEY3 short did not resume");
        repeat(100)@(negedge clk);
        if(!transition_active)fail("automatic advance did not start at one second");
        settle();if(image_index!=1)fail("autoplay did not advance");
        maintenance_enable=1;pulse(5);
        if(!osd_visible||reload_event)fail("protected maintenance entry");
        pulse(2);if(brightness_level!=3||next_event)
            fail("maintenance brightness adjustment or navigation leak");
        pulse(3);pulse(1);if(contrast_level!=1)
            fail("maintenance contrast adjustment");
        pulse(3);pulse(2);if(saturation_level!=3)
            fail("maintenance colour-temperature adjustment");
        pulse(3);pulse(2);if(gamma!=2||temp!=1||selection!=3)
            fail("independent gamma control");
        pulse(3);pulse(1);if(temp!=0||gamma!=2||selection!=4)
            fail("independent temperature control");
        pulse(3);repeat(7)pulse(2);if(effect_mode!=6||selection!=5)
            fail("seven-effect control or upper clamp");
        repeat(7)pulse(1);if(effect_mode!=0)fail("effect lower clamp");
        pulse(3);repeat(3)pulse(2);if(effect_duration!=2||selection!=6)
            fail("transition duration upper clamp");
        repeat(3)pulse(1);if(effect_duration!=0)fail("transition duration lower clamp");
        pulse(3);pulse(2);if(!effect_easing||selection!=7)fail("easing enable");
        pulse(1);if(effect_easing)fail("easing disable");
        pulse(3);if(selection!=8||volume!=7)fail("audio menu entry");
        repeat(8)pulse(1);if(volume!=0)fail("volume lower clamp");
        repeat(8)pulse(2);if(volume!=7)fail("volume upper clamp");
        pulse(3);if(selection!=9||flash_rate!=1)fail("flash rate menu");
        repeat(3)pulse(1);if(flash_rate!=0)fail("flash rate lower clamp");
        repeat(3)pulse(2);if(flash_rate!=2)fail("flash rate upper clamp");
        pulse(3);if(selection!=10||flash_duty!=1)fail("flash duty menu");
        repeat(3)pulse(1);if(flash_duty!=0)fail("flash duty lower clamp");
        repeat(3)pulse(2);if(flash_duty!=2)fail("flash duty upper clamp");
        pulse(3);if(selection!=0)fail("extended menu wrap");
        repeat(179)frame();if(osd_visible)fail("three-second quick-adjust timeout");
        maintenance_enable=0;@(negedge clk);
        if(osd_visible||brightness_level!=3||contrast_level!=1||
                saturation_level!=3)fail("maintenance exit or value retention");
        @(negedge clk);k4_long=1;#1;if(!reload_event)
            fail("reload outside maintenance");
        @(negedge clk);k4_long=0;
        $display("TEST_PASS tb_daily_control playback periods and protected persistent E4 controls");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
