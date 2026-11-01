`timescale 1ns/1ps
module tb_alarm_waveform_scanout;
    reg [7:0] caption=0;
    reg clk=0,rst=1,alarm=0,cancel=0;
    reg [2:0] kind=2;
    reg evacuation=0;
    reg audio_valid=0;
    reg signed [15:0] sample=0;
    integer audio_clock=0,sample_number=0;
    always @(negedge clk)begin
        audio_clock=audio_clock+1;audio_valid=audio_clock%20==0;
        if(audio_valid)begin
            sample=$rtoi(8192.0*$sin(6.283185307179586*sample_number/48.0));
            sample_number=sample_number+1;
        end
    end
    always #5 clk=~clk;
    wire valid,first,last,visible;
    wire [23:0] rgb;
    integer checked=0,f,p,c;
    reg [23:0] expected;
    video_scanout #(.WIDTH(640),.HEIGHT(480),.HTOTAL(800),.VTOTAL(525),
        .HSTART(160),.VSTART(45),.ENABLE_EFFECTS(1),.V5_CONTROLS(1),.BOARD_ROUTE_AUTHORITY(1),.FIXED_RATE_AXIS(1),.COMPACT_SCENES(1),.FINAL_SUBTITLES(1)) dut(
        .clk(clk),.rst(rst),.cache_ready(1'b0),.image_index(4'd0),.fade_gain(5'd16),
        .audio_test_mode(1'b0),.media_playlist_error(1'b0),.viewport_ready(1'b0),.zoom_mode(1'b0),.zoom_scale(2'd0),.zoom_pan_x(11'd0),.zoom_pan_y(11'd0),
        .grayscale_enable(1'b0),.overlay_enable(1'b0),.transition_mode(3'd0),
        .transition_target(4'd0),.slide_progress(5'd0),.slide_active(1'b0),
        .transition_phase(7'd0),.transition_settings(6'd0),
        .brightness_level(3'd2),.contrast_level(3'd2),.saturation_level(3'd2),
        .gamma_mode(2'd1),.temperature_mode(2'd1),.quality_selection(4'd0),
        .volume_level(3'd4),.flash_rate(2'd0),.flash_duty(2'd0),
        .audio_peak_absolute(16'd0),.audio_limited_count(32'd0),.audio_clipped_count(32'd0),
        .osd_visible(1'b0),.quality_enable(1'b0),.quality_auto_enable(1'b0),
        .analysis_view(2'd0),.narration_subtitle(caption),.e5_peak_frequency_q8(24'd0),
        .e5_waterfall_value(8'd0),.audio_sample_valid(audio_valid),.audio_sample(sample),
        .console_proxy_valid(1'b0),.console_proxy_status(96'd0),
        .alarm_evacuation(evacuation),.alarm_pending(1'b0),.local_fire_visible(1'b0),.local_control_status(16'd0),.extended_control_status(16'd0),.alarm_active(alarm),.alarm_kind(kind),.alarm_level(3'd1),.alarm_drill(1'b1),
        .alarm_cancel_notice(cancel),.alarm_flash_on(1'b0),.alarm_countdown_trusted(1'b0),
        .alarm_countdown_seconds(16'd0),.alarm_latency_valid(1'b0),
        .alarm_pixel_latency_us(24'd0),.alarm_audio_latency_us(24'd0),.alarm_blocked_set(8'd0),
        .route_cfg_write(1'b0),.route_cfg_key(8'd0),.route_cfg_segments(32'd0),
        .route_cfg_directions(32'd0),.route_cfg_exit(3'd0),.route_cfg_status(2'd0),
        .route_cfg_commit(1'b0),.route_cfg_crc_ok(1'b0),.route_cfg_checked(1'b0),
        .route_cfg_assets_match(1'b0),.route_cfg_version(16'd0),.route_cfg_crc32(32'd0),
        .line_ack_toggle(1'b0),.line_ram_q(24'd0),.second_ram_q(24'd0),
        .axis_valid(valid),.axis_user(first),.axis_last(last),.axis_data(rgb),
        .axis_ready(1'b1),.alarm_display_active(visible));

    integer green,red,title_pixels,release_pixels,ticker_pixels,n,px,py,fd;
    task check_frame;
        input integer expect_wave;
        input integer save_image;
        begin
            repeat(2)begin @(negedge clk);while(!dut.frame_tick)@(negedge clk);end
            @(negedge clk);while(!(valid&&first))@(negedge clk);
            n=0;green=0;red=0;title_pixels=0;release_pixels=0;ticker_pixels=0;
            if(save_image)begin
                fd=$fopen(save_image==5 ? "hardware_ui_scroll.ppm" : save_image==4 ? "hardware_ui_fire.ppm" : save_image==3 ? "hardware_ui_release.ppm" : save_image==2 ? "hardware_ui_evac.ppm" : "hardware_ui_alarm.ppm","w");
                $fwrite(fd,"P3\n640 480\n255\n");
            end
            while(n<640*480)begin
                if(valid)begin
                    px=n%640;py=n/640;
                    if(first!==(n==0)||last!==(px==639))$fatal(1,"alarm waveform raster tags");
                    if(rgb===24'h40ff70)begin
                        if(py<360||py>=432)$fatal(1,"waveform mask is displaced y=%0d",py);
                        green=green+1;
                    end
                    if(py<320&&rgb===24'hdc2828)red=red+1;
                    if(py<24&&rgb===24'hfff4cc)ticker_pixels=ticker_pixels+1;
                    if(alarm&&!evacuation&&px==100&&py==240&&rgb!==24'hdc2828)
                        $fatal(1,"alarm background is not red");
                    if(px>=224&&px<416&&py>=244&&py<308&&rgb===24'hf4f7fb)title_pixels=title_pixels+1;
                    if(px>=256&&px<384&&py>=244&&py<308&&rgb===24'h66dfb0)release_pixels=release_pixels+1;
                    if(alarm&&!evacuation&&px==320&&py==150&&rgb!==24'hffd166)
                        $fatal(1,"central exclamation missing");
                    if(evacuation)begin
                        if(px==550&&py==370&&rgb!==24'hd8e8e0)$fatal(1,"waveform covered exit 3");
                        if(((px==100&&py==380)||(px==320&&py==420)||(px==320&&py==340))&&
                            rgb!==24'h526464)$fatal(1,"waveform/legend covered route segment x=%0d y=%0d",px,py);
                        if(px==320&&py==436&&rgb!==24'h206c7f)$fatal(1,"waveform covered YOU ARE HERE marker");
                    end
                    if(save_image)$fwrite(fd,"%0d %0d %0d ",rgb[23:16],rgb[15:8],rgb[7:0]);
                    n=n+1;
                end
                if(n<640*480)@(negedge clk);
            end
            if(save_image)$fclose(fd);
            if(expect_wave&&green<1000)$fatal(1,"alarm or release hid waveform: kind=%0d evacuation=%0d cancel=%0d green=%0d",kind,evacuation,cancel,green);
            if(cancel&&release_pixels<1000)$fatal(1,"release title missing");
            if(!expect_wave&&green!=0)$fatal(1,"automatic waveform did not stop");
            if(alarm&&ticker_pixels<750)$fatal(1,"disaster ticker hidden by scene");
            if(!alarm&&ticker_pixels!=0)$fatal(1,"stale disaster ticker on idle/release");
            if(alarm&&!evacuation&&(red<1000||title_pixels<1000))$fatal(1,"warning title or severity header missing");
            $display("CHECK alarm=%0d kind=%0d evac=%0d release=%0d green=%0d",alarm,kind,evacuation,cancel,green);
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        check_frame(0,0);
        alarm=1;kind=0;caption=9;check_frame(1,1);
        check_frame(1,5);
        kind=1;caption=11;check_frame(1,4);
        kind=3;evacuation=1;caption=12;check_frame(1,2);
        alarm=0;cancel=1;evacuation=0;caption=13;check_frame(1,3);
        cancel=0;caption=0;check_frame(0,0);
        $display("TEST_PASS actual AXI output: automatic waveform with switch off across earthquake/fire/evacuation/release, captions and raster intact");$finish;
    end
    initial begin #150000000;$fatal(1,"alarm waveform timeout");end
endmodule
