`timescale 1ns/1ps
module tb_waveform_ui;
    reg clk=0,rst=1,frame=0,audio=0;
    always #5 clk=~clk;
    reg [10:0] x=0,y=0;
    reg signed [15:0] sample=0;
    reg [15:0] local_status=0;
    reg [95:0] status=0;
    wire [23:0] wave_rgb,card_rgb,rgb;
    wire waveform;
    integer n,px,py,fd,green=0;
    video_effects #(.AUXILIARY_OVERLAY(0),.WAVEFORM_OVERLAY(1),.FRAME_CAPTURE(1),.LUT_ONLY(1),.V5_CONTROLS(1)) effects(
        .clk(clk),.rst(rst),.frame_tick(frame),.x(x),.y(y),.image_index(4'd0),
        .fade_gain(5'd16),.transition_mode(3'd2),.zoom_mode(1'b0),.zoom_scale(2'd0),
        .grayscale_enable(1'b0),.overlay_enable(1'b1),.brightness_level(3'd2),
        .contrast_level(3'd2),.saturation_level(3'd2),.gamma_mode(2'd1),
        .temperature_mode(2'd1),.quality_selection(4'd0),.volume_level(3'd7),
        .flash_rate(2'd1),.flash_duty(2'd1),.audio_peak_absolute(16'd4096),
        .audio_limited_count(32'd0),.audio_clipped_count(32'd0),.transition_settings(6'd0),
        .osd_visible(1'b0),.color_lut_active(1'b0),.audio_sample_valid(audio),
        .audio_sample(sample),.rgb_in(24'he9eef4),.rgb_out(wave_rgb),.waveform_pixel(waveform));
    console_proxy_overlay #(.MODERN_UI(1)) card(.x(x),.y(y),.status_valid(1'b1),
        .status(status),.rgb_in(wave_rgb),.rgb_out(card_rgb));
    local_status_overlay #(.MODERN_UI(1)) labels(.clk(clk),.x(x),.y(y),.enable(1'b1),
        .fire_visible(1'b0),.media_fault(1'b0),.waveform_status(2'b11),
        .remote_evacuation_selected(1'b0),.remote_confirmation(8'd0),
        .status(local_status),.quality_status(16'd0),.rgb_in(card_rgb),.rgb_out(rgb));
    task render;input [255:0] path;begin
        fd=$fopen(path,"w");$fwrite(fd,"P3\n640 480\n255\n");
        for(py=0;py<480;py=py+1)begin
            for(px=0;px<640;px=px+1)begin
                x=px;y=py;@(negedge clk);@(negedge clk);
                if(waveform)green=green+1;
                $fwrite(fd,"%0d %0d %0d ",rgb[23:16],rgb[15:8],rgb[7:0]);
            end
            $fwrite(fd,"\n");
        end
        $fclose(fd);
    end endtask
    initial begin
        status[95]=1;status[87:86]=2;status[83:81]=1;status[70:67]=15;
        repeat(3)@(negedge clk);rst=0;
        for(n=0;n<300;n=n+1)begin
            sample=$rtoi(4096.0*$sin(6.283185307179586*n/40.0));audio=1;
            @(negedge clk);audio=0;@(negedge clk);
        end
        frame=1;@(negedge clk);frame=0;@(negedge clk);
        render("hardware_ui_test.ppm");
        if(green<1000)$fatal(1,"waveform missing from compact production effects");
        local_status[4]=1;local_status[7:6]=2;local_status[9:8]=1;local_status[15]=1;
        status[75]=1;
        render("hardware_ui_local.ppm");
        $display("TEST_PASS production waveform and semantic UI rendered to PPM, curve pixels=%0d",green);$finish;
    end
    initial begin #20000000;$fatal(1,"UI render timeout");end
endmodule
