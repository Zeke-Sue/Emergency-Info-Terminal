`timescale 1ns/1ps
module tb_n10_scanout #(parameter integer V5=0);
    reg clk=0,rst=1,alarm=0,pending=1;
    reg evacuation=0;
    reg [7:0] blocked=0,key=0;
    reg cfg_write=0,cfg_commit=0;reg [31:0] segments=0;reg [2:0] ex=0;reg [1:0] status=0;
    wire valid,first,last;wire [23:0] rgb;
    integer frames=0,n,f;reg [10:0] rx=0,ry=0;
    reg reference_map=0;reg [7:0] reference_blocked=0;
    reg [1:0] reference_status=0;reg [23:0] expected;
    wire [5:0] ref_segment;wire [7:0] ref_phase;
    wire ref_cross,ref_foreground;wire [23:0] ref_rgb;
    always #5 clk=~clk;

    n10_demo_segment_map ref_geometry(.x(rx),.y(ry),.blocked_set(reference_blocked),
        .segment_id(ref_segment),.segment_phase(ref_phase),.blocked_exit_pixel(ref_cross));
    n10_demo_map_renderer ref_page(.x(rx),.y(ry),.enable(reference_map),
        .segment_id(ref_segment),.route_valid(1'b1),.status(reference_status),
        .selected_exit(reference_status==0 ? 3'd3 : 3'd0),
        .rgb_in(24'hdc2828),.rgb_out(ref_rgb),.foreground(ref_foreground));
    video_scanout #(.ENABLE_EFFECTS(0),.FIXED_RATE_AXIS(1),.BOARD_ROUTE_AUTHORITY(1),.V5_CONTROLS(V5)) dut(
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
        .analysis_view(2'd0),.narration_subtitle(8'd0),.e5_peak_frequency_q8(24'd0),
        .e5_waterfall_value(8'd0),.audio_sample_valid(1'b0),.audio_sample(16'd0),
        .console_proxy_valid(1'b0),.console_proxy_status(96'd0),
        .alarm_active(alarm),.alarm_kind(3'd1),.alarm_level(3'd1),.alarm_drill(1'b0),
        .alarm_pending(pending),.alarm_cancel_notice(1'b0),.alarm_flash_on(1'b0),
        .alarm_evacuation(evacuation),.local_fire_visible(1'b0),.local_control_status(16'd0),
        .extended_control_status(16'd0),
        .alarm_countdown_trusted(1'b0),.alarm_countdown_seconds(16'd0),.alarm_latency_valid(1'b0),
        .alarm_pixel_latency_us(24'd0),.alarm_audio_latency_us(24'd0),.alarm_blocked_set(blocked),
        .route_cfg_write(cfg_write),.route_cfg_key(key),.route_cfg_segments(segments),
        .route_cfg_directions(32'd0),.route_cfg_exit(ex),.route_cfg_status(status),
        .route_cfg_commit(cfg_commit),.route_cfg_crc_ok(cfg_commit),.route_cfg_checked(cfg_commit),
        .route_cfg_assets_match(cfg_commit),.route_cfg_version(16'h5001),.route_cfg_crc32(32'h12345678),
        .line_ack_toggle(1'b0),.line_ram_q(24'd0),.second_ram_q(24'd0),
        .axis_valid(valid),.axis_user(first),.axis_last(last),.axis_data(rgb),.axis_ready(1'b1));
    task fail;input [8*90-1:0] msg;begin
        $display("TEST_FAIL route scanout: %0s frame=%d at %d,%d got=%h expected=%h",msg,frames,rx,ry,rgb,expected);$finish;end endtask
    task check_frame;
        input integer mode,injection;
        begin
            reference_map=mode>=2;reference_blocked=mode==3 ? 7 : 0;reference_status=mode==3 ? 1 : 0;
            @(negedge clk);while(!(valid&&first))@(negedge clk);
            n=0;
            while(n<640*480)begin
                if(valid)begin
                    rx=n%640;ry=n/640;#1;
                    expected=mode==0 ? ((rx[6]^ry[6]) ? 24'h203050 : 24'h102030) : ref_rgb;
                    if(reference_map&&ref_cross)expected=24'hff2020;
                    else if(mode==2&&(ref_segment==15||ref_segment==16||ref_segment==32)&&!ref_foreground)
                        expected=24'hb0ffb0;
                    if(rgb!==expected||first!==(n==0)||last!==((n%640)==639))fail("pixel or AXI tag mismatch");
                    if(n==100000)begin
                        if(injection==1)alarm=1;
                        if(injection==2)pending=0;
                        if(injection==3)blocked=7;
                        if(injection==4)begin pending=1;evacuation=0;end
                        if(injection==5)evacuation=1;
                    end
                    n=n+1;
                end
                if(n<640*480)@(negedge clk);
            end
            frames=frames+1;
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        key=0;segments=32'h8000c000;ex=3;status=0;cfg_write=1;
        @(negedge clk);key=7;segments=0;ex=0;status=1;
        @(negedge clk);cfg_write=0;cfg_commit=1;
        @(negedge clk);cfg_commit=0;
        check_frame(0,1);
        check_frame(1,2);
        if(V5)check_frame(1,5);
        check_frame(2,3);
        check_frame(3,4);
        check_frame(1,0);
        $display("TEST_PASS route scanout: %0d full 640x480 frames, 1536000 pixels, pending suppression, map/markers, atomic blocked/pending changes",frames);$finish;
    end
    initial begin #40000000;fail("bounded timeout");end
endmodule

module tb_v5_route_stage;
    tb_n10_scanout #(.V5(1)) test();
endmodule
