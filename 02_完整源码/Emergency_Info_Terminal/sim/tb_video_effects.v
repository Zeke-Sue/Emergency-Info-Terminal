`timescale 1ns/1ps
module tb_video_effects;
    localparam integer WIDTH=64, HEIGHT=32, TOTAL_SCROLL=WIDTH+12*16;
    reg clk=0,rst=1,frame_tick=0;
    reg [10:0] x=0,y=0;
    reg [3:0] image_index=0;
    reg [4:0] fade_gain=16;
    reg [2:0] brightness_level=2,contrast_level=2,saturation_level=2;
    reg osd_visible=0,audio_sample_valid=0;
    reg [15:0] audio_sample=0;
    reg [23:0] rgb_in=24'h804020;
    wire [23:0] rgb_out;
    wire [12:0] scroll_position;
    wire banner_pixel,text_pixel,osd_pixel,waveform_pixel;
    always #5 clk=~clk;
    video_effects #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ENABLE(1),.SCROLL_STEP(1)) dut(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.x(x),.y(y),.image_index(image_index),
        .fade_gain(fade_gain),.transition_mode(3'b000),.zoom_mode(1'b0),.grayscale_enable(1'b0),
        .overlay_enable(1'b1),
        .brightness_level(brightness_level),.contrast_level(contrast_level),
        .saturation_level(saturation_level),
        .osd_visible(osd_visible),.color_lut_active(1'b0),
        .audio_sample_valid(audio_sample_valid),.audio_sample(audio_sample),
        .rgb_in(rgb_in),.rgb_out(rgb_out),.scroll_position(scroll_position),
        .banner_pixel(banner_pixel),.text_pixel(text_pixel),.osd_pixel(osd_pixel),
        .waveform_pixel(waveform_pixel));

    task fail;
        input [8*160-1:0] reason;
        begin
            $display("TEST_FAIL tb_video_effects: %0s",reason);
            $finish;
        end
    endtask

    task automatic pulse_frame;
        begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end
    endtask
    task automatic expect_rgb(input [23:0] expected,input [127:0] label_text);
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
        $dumpfile("tb_video_effects.vcd");$dumpvars(0,tb_video_effects);
        repeat(3)@(negedge clk);rst=0;@(negedge clk);
        x=0;y=0;fade_gain=16;expect_rgb(24'h804020,"full-gain base layer");
        fade_gain=8;expect_rgb(24'h402010,"half-gain fade layer");
        fade_gain=16;y=8;expect_rgb(24'h402010,"50-percent banner blend");
        if(!banner_pixel||text_pixel)fail("banner/text masks before ticker entry");
        for(i=0;i<68;i=i+1)pulse_frame();
        if(scroll_position!=68)fail("scroll must advance one pixel per frame");
        x=0;y=10;expect_rgb(24'hcfb04c,"75-percent scrolling glyph blend");
        if(!banner_pixel||!text_pixel)fail("glyph mask not asserted");
        pulse_frame();
        if(scroll_position!=69)fail("smooth scroll position did not advance");
        x=0;y=0;fade_gain=0;expect_rgb(24'h000000,"black transition midpoint");
        for(i=0;i<TOTAL_SCROLL-69;i=i+1)pulse_frame();
        if(scroll_position!=0)begin
            $display("ticker wrap failed %0d",scroll_position);
            fail("ticker wrap failed");
        end
        $display("TEST_PASS tb_video_effects fade gain, translucent banner, scrolling ANLOGIC FPGA glyphs and wrap");
        $finish;
    end
    initial begin #100000;fail("video effects timeout");end
endmodule
