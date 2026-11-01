`timescale 1ns/1ps
module tb_fire_control_composition;
    reg scroll=0;
    reg [2:0] track=0;
    reg [31:0] samples=0;
    reg [7:0] strips[0:16383];
    reg [15:0] positions[0:2047];
    integer offset,sx;
    reg [7:0] caption=0;
    reg clk=0,rst=1,alarm=0,cancel=0;
    reg [2:0] kind=2;
    always #5 clk=~clk;
    wire valid,first,last,visible;
    wire [23:0] rgb;
    integer checked=0,f,p,c;
    reg [23:0] expected;
    video_scanout #(.WIDTH(640),.HEIGHT(480),.HTOTAL(800),.VTOTAL(525),
        .HSTART(160),.VSTART(45),.V5_CONTROLS(1),.SIMPLE_DEMO(1),.ENABLE_EFFECTS(0),.FIXED_RATE_AXIS(1),.COMPACT_SCENES(1),.FINAL_SUBTITLES(1),.DAILY_SCROLL_SUBTITLES(1),.DUAL_EXTENSIONS(1)) dut(
        .service_valid(1'b0),.service_type(8'd0),.service_payload(96'd0),
        .diagnostic_active(1'b0),.diagnostic_page(5'd0),.live_route_result(96'd0),.live_route_fresh(1'b0),
        .alarm_evacuation(1'b0),.local_fire_visible(1'b0),.audio_test_mode(1'b0),
        .clk(clk),.rst(rst),.cache_ready(1'b0),.image_index(4'd0),.fade_gain(5'd16),
        .zoom_mode(1'b0),.zoom_scale(2'd0),.zoom_pan_x(11'd0),.zoom_pan_y(11'd0),
        .grayscale_enable(1'b0),.overlay_enable(1'b0),.transition_mode(3'd0),
        .transition_target(4'd0),.slide_progress(5'd0),.slide_active(1'b0),
        .transition_phase(7'd0),.transition_settings(6'd0),
        .brightness_level(3'd2),.contrast_level(3'd2),.saturation_level(3'd2),
        .gamma_mode(2'd1),.temperature_mode(2'd1),.quality_selection(4'd0),
        .volume_level(3'd4),.flash_rate(2'd0),.flash_duty(2'd0),
        .audio_peak_absolute(16'd0),.audio_limited_count(32'd0),.audio_clipped_count(32'd0),
        .osd_visible(1'b0),.quality_enable(1'b0),.quality_auto_enable(1'b0),
        .daily_subtitle_active(scroll),.daily_subtitle_track(track),.daily_subtitle_samples(samples),
        .analysis_view(2'd0),.narration_subtitle(caption),.e5_peak_frequency_q8(24'd0),
        .e5_waterfall_value(8'd0),.audio_sample_valid(1'b0),.audio_sample(16'd0),
        .console_proxy_valid(1'b1),.console_proxy_status({8'h80,2'd2,2'd0,3'd1,1'b1,4'd0,1'b0,3'd5,72'd0}),
        .alarm_active(alarm),.alarm_kind(kind),.alarm_level(3'd1),.alarm_drill(1'b0),
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

    initial begin
      repeat(4)@(negedge clk);rst=0;alarm=1;kind=1;
      repeat(3)@(posedge dut.frame_tick);
      @(negedge clk);
      wait(dut.museum_x_qq==440&&dut.museum_y_qq==12);#1;
      if(!dut.live_map_active||!dut.fire_control_strip.card.panel)$fatal(1,"operator card inactive during fire");
      if(dut.emergency_wave_rgb!==dut.fire_control_rgb)$fatal(1,"ticker covered operator card");
      if(dut.fire_control_strip.card.text_line!="ZONE 5  APPLY  ")$fatal(1,"selected zone text mismatch");
      if(dut.fire_control_rgb==dut.ticker_rgb)$fatal(1,"operator card invisible above red ticker");
      $display("TEST_PASS full-size fire scanout: selected zone card visible above alarm ticker");$finish;
    end
    initial begin #20000000;$fatal(1,"fire card timeout");end
endmodule
