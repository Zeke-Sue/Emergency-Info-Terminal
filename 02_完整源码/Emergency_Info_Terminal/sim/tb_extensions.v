`timescale 1ns/1ps
module tb_extensions;
    reg clk=0,rst=1,frame_tick=0;
    always #5 clk=~clk;

    reg zoom_key_press=0,zoom_key_short=0,zoom_key_long=0,zoom_key_held=0;
    reg key1_press=0,key1_short=0,key1_long=0,key1_held=0;
    reg key2_press=0,key2_short=0,key2_long=0,key2_held=0;
    reg key3_press=0,key3_short=0,key3_long=0,key3_held=0;
    reg grayscale_switch=0;
    wire next_event,auto_event,period_event,reload_event,zoom_mode,control_grayscale;
    wire [2:0] brightness_level,contrast_level,saturation_level;
    wire control_osd_visible;
    display_control #(.OSD_FRAMES(3)) controls(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),
        .zoom_key_press(zoom_key_press),.zoom_key_short(zoom_key_short),
        .zoom_key_long(zoom_key_long),.zoom_key_held(zoom_key_held),
        .key1_press(key1_press),.key1_short(key1_short),.key1_long(key1_long),.key1_held(key1_held),
        .key2_press(key2_press),.key2_short(key2_short),.key2_long(key2_long),.key2_held(key2_held),
        .key3_press(key3_press),.key3_short(key3_short),.key3_long(key3_long),.key3_held(key3_held),
        .grayscale_switch(grayscale_switch),
        .next_event(next_event),.auto_event(auto_event),.period_event(period_event),.reload_event(reload_event),
        .zoom_mode(zoom_mode),.grayscale_enable(control_grayscale),
        .brightness_level(brightness_level),.contrast_level(contrast_level),
        .saturation_level(saturation_level),.osd_visible(control_osd_visible));

    reg [10:0] x=0,y=0;
    reg [3:0] image_index=0;
    reg [4:0] fade_gain=16;
    reg [2:0] fx_brightness=2,fx_contrast=2,fx_saturation=2;
    reg fx_osd_visible=0,fx_grayscale=0,fx_zoom=0,fx_overlay_enable=1;
    reg audio_sample_valid=0;
    reg [2:0] fx_transition_mode=0;
    reg [15:0] audio_sample=0;
    reg [23:0] rgb_in=24'h804020;
    wire [23:0] rgb_out;
    wire [12:0] scroll_position;
    wire banner_pixel,text_pixel,osd_pixel,waveform_pixel;
    video_effects #(.WIDTH(200),.HEIGHT(160),.ENABLE(1),.AUDIO_SAMPLES(128)) effects(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.x(x),.y(y),.image_index(image_index),
        .fade_gain(fade_gain),.transition_mode(fx_transition_mode),.zoom_mode(fx_zoom),
        .grayscale_enable(fx_grayscale),
        .overlay_enable(fx_overlay_enable),
        .brightness_level(fx_brightness),.contrast_level(fx_contrast),
        .saturation_level(fx_saturation),
        .osd_visible(fx_osd_visible),.color_lut_active(1'b0),
        .audio_sample_valid(audio_sample_valid),.audio_sample(audio_sample),
        .rgb_in(rgb_in),.rgb_out(rgb_out),.scroll_position(scroll_position),
        .banner_pixel(banner_pixel),.text_pixel(text_pixel),.osd_pixel(osd_pixel),.waveform_pixel(waveform_pixel));

    task fail;
        input [8*160-1:0] reason;
        begin
            $display("TEST_FAIL tb_extensions: %0s",reason);
            $finish;
        end
    endtask
    task automatic pulse_input(inout reg signal_value);
        begin
            @(negedge clk);signal_value=1;@(negedge clk);signal_value=0;@(negedge clk);
        end
    endtask
    task automatic pulse_frame;
        begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end
    endtask
    task automatic expect_rgb(input [23:0] expected,input [255:0] label_text);
        begin

            @(posedge clk);#1;
            if(rgb_out!==expected)begin
                $display("%0s got=%h expected=%h",label_text,rgb_out,expected);
                fail("pixel mismatch");
            end
        end
    endtask
    integer i;
    initial begin
        $dumpfile("tb_extensions.vcd");$dumpvars(0,tb_extensions);
        repeat(3)@(negedge clk);rst=0;@(negedge clk);
        if(brightness_level!=2||contrast_level!=2||saturation_level!=2||
                control_grayscale||control_osd_visible)
            fail("display controls reset state");

        @(negedge clk);zoom_key_short=1;@(negedge clk);zoom_key_short=0;
        if(!control_osd_visible)fail("zoom change did not show OSD");
        if(zoom_mode)fail("KEY1 zoom changed before frame boundary");
        pulse_frame();@(negedge clk);
        if(!zoom_mode)fail("KEY1 short did not enable 2x zoom at frame boundary");
        @(negedge clk);zoom_key_short=1;@(negedge clk);zoom_key_short=0;
        pulse_frame();@(negedge clk);
        if(zoom_mode)fail("KEY1 second short did not return to 1x");
        @(negedge clk);zoom_key_long=1;@(negedge clk);
        if(!reload_event)fail("KEY1 long reload mapping");
        zoom_key_long=0;@(negedge clk);
        if(reload_event)fail("reload event must be one cycle");

        @(negedge clk);key1_short=1;@(negedge clk);
        if(!next_event||auto_event||period_event)fail("KEY1 short mapping");
        key1_short=0;@(negedge clk);
        @(negedge clk);key2_short=1;@(negedge clk);
        if(!auto_event||next_event)fail("KEY2 short mapping");
        key2_short=0;@(negedge clk);
        @(negedge clk);key2_long=1;@(negedge clk);
        if(period_event||contrast_level!=2||saturation_level!=3||
                control_grayscale||!control_osd_visible)
            fail("KEY4 long saturation/OSD mapping");
        key2_long=0;@(negedge clk);
        grayscale_switch=1;#1;
        if(!control_grayscale)fail("SW4 grayscale enable mapping");
        @(negedge clk);
        if(!control_osd_visible)fail("grayscale change did not show OSD");
        grayscale_switch=0;#1;
        if(control_grayscale)fail("SW4 colour restore mapping");
        @(negedge clk);key3_short=1;@(negedge clk);
        if(!period_event||next_event||auto_event)fail("KEY3 short period mapping");
        key3_short=0;@(negedge clk);
        @(negedge clk);key1_long=1;@(negedge clk);
        if(brightness_level!=3||!control_osd_visible)fail("KEY1 long brightness/OSD mapping");
        key1_long=0;@(negedge clk);

        @(negedge clk);key3_long=1;@(negedge clk);
        if(contrast_level!=3||!control_osd_visible)fail("KEY3 long contrast/OSD mapping");
        if(next_event||auto_event||period_event)fail("KEY3 long leaked player action");
        key3_long=0;@(negedge clk);
        repeat(3)pulse_frame();@(negedge clk);
        if(control_osd_visible)fail("OSD frame timeout");

        x=0;y=0;fx_osd_visible=0;fx_brightness=3;fx_contrast=2;fx_saturation=2;
        expect_rgb(24'ha06040,"brightness +32");
        rgb_in=24'hc04080;fx_brightness=2;fx_contrast=4;
        expect_rgb(24'he02080,"contrast 1.5x around midpoint");
        rgb_in=24'h804020;fx_contrast=2;fx_saturation=4;
        expect_rgb(24'h9a3a0a,"saturation 1.5x around luma");
        fx_saturation=0;
        expect_rgb(24'h664636,"saturation 0.5x around luma");
        fx_saturation=2;fx_grayscale=1;
        expect_rgb(24'h4c4c4c,"shift-add grayscale filter");
        fx_grayscale=0;fade_gain=8;fx_transition_mode=1;x=150;y=0;
        expect_rgb(24'h000000,"horizontal curtain hidden region");
        x=50;expect_rgb(24'h804020,"horizontal curtain visible region");
        fade_gain=16;fx_transition_mode=0;
        rgb_in=24'h804020;fx_brightness=3;fx_contrast=4;fx_saturation=1;
        fx_osd_visible=1;
        x=8;y=8;expect_rgb(24'h231108,"OSD translucent panel after BRI/CON/SAT");
        if(!osd_pixel)fail("OSD mask missing");
        x=48;y=16;expect_rgb(24'hffb030,"brightness bar");
        x=48;y=34;expect_rgb(24'h40e0ff,"contrast bar");
        x=48;y=52;expect_rgb(24'hff50c8,"saturation bar");
        x=12;y=16;expect_rgb(24'hffffff,"BRI label glyph");
        x=14;y=52;expect_rgb(24'hffffff,"SAT label glyph");
        x=137;y=19;expect_rgb(24'hffffff,"brightness numeric sign");
        x=139;y=34;expect_rgb(24'hffffff,"contrast numeric value");
        x=138;y=52;expect_rgb(24'hffffff,"saturation numeric value");
        fx_zoom=1;x=138;y=70;expect_rgb(24'hffffff,"zoom numeric value");
        fx_grayscale=1;x=138;y=88;expect_rgb(24'hffffff,"mono state value");
        fx_zoom=0;fx_grayscale=0;
        fx_osd_visible=0;fx_brightness=2;fx_contrast=2;fx_saturation=2;

        x=0;y=150;fx_overlay_enable=0;
        expect_rgb(24'h804020,"SW3 hidden subtitle restores base image");
        if(banner_pixel||text_pixel)fail("subtitle masks remained active with SW3 off");
        fx_overlay_enable=1;

        for(i=0;i<128;i=i+1)begin
            @(negedge clk);audio_sample=i==0 ? 16'sd0 : 16'sd1024;audio_sample_valid=1;
            @(negedge clk);audio_sample_valid=0;
        end
        @(negedge clk);x=0;y=84;@(posedge clk);#1;
        if(!waveform_pixel)fail("audio waveform sample was not rendered");
        expect_rgb(24'h40ff70,"audio waveform color");
        y=50;@(posedge clk);#1;if(waveform_pixel)fail("waveform line mask too wide");
        expect_rgb(24'h402010,"audio panel translucent background");
        fx_overlay_enable=0;
        expect_rgb(24'h804020,"SW3 hidden waveform restores base image");
        if(waveform_pixel)fail("waveform mask remained active with SW3 off");

        $display("TEST_PASS tb_extensions SW3 overlay, SW4 grayscale, KEY4 saturation, numeric OSD and curtain");
        $finish;
    end
    initial begin #100000;fail("extension test timeout");end
endmodule
