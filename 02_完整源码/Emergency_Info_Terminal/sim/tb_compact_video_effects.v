`timescale 1ns/1ps
module tb_compact_video_effects;
    reg clk=0,rst=1,frame=0,osd=0,audio=0;
    reg [10:0] x=0,y=0;
    wire [23:0] rgb;
    wire banner,text,osd_pixel,waveform;
    wire [12:0] scroll;
    integer n;
    always #5 clk=~clk;
    video_effects #(.AUXILIARY_OVERLAY(0),.LUT_ONLY(1),.V5_CONTROLS(1)) dut(
        .clk(clk),.rst(rst),.frame_tick(frame),.x(x),.y(y),.image_index(4'd0),
        .fade_gain(5'd16),.transition_mode(3'd2),.zoom_mode(1'b0),.zoom_scale(2'd0),
        .grayscale_enable(1'b0),.overlay_enable(1'b1),.brightness_level(3'd2),
        .contrast_level(3'd2),.saturation_level(3'd2),.gamma_mode(2'd1),
        .temperature_mode(2'd1),.quality_selection(4'd0),.volume_level(3'd7),
        .flash_rate(2'd1),.flash_duty(2'd1),.audio_peak_absolute(16'd0),
        .audio_limited_count(32'd0),.audio_clipped_count(32'd0),.transition_settings(6'd0),
        .osd_visible(osd),.color_lut_active(1'b0),.audio_sample_valid(audio),
        .audio_sample(16'd0),.rgb_in(24'h804020),.rgb_out(rgb),.scroll_position(scroll),
        .banner_pixel(banner),.text_pixel(text),.osd_pixel(osd_pixel),.waveform_pixel(waveform));
    task check;
        input [23:0] expected;
        begin @(posedge clk);#1;
            if(rgb!==expected||banner||text||waveform||scroll!=0)
                $fatal(1,"compact overlay changed image/masks %h expected %h",rgb,expected);
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;frame=1;audio=1;
        repeat(200)@(negedge clk);frame=0;audio=0;
        x=320;y=432;check(24'h804020);
        @(negedge clk);y=462;check(24'h804020);
        @(negedge clk);osd=1;x=64;y=16;check(24'hffb030);
        if(!osd_pixel)$fatal(1,"parameter OSD removed");
        $display("TEST_PASS compact auxiliary overlay removes brand ticker/scope while preserving picture and adjustment OSD");$finish;
    end
endmodule
