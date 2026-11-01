`timescale 1ns/1ps
module tb_extension_subtitle_scanout;
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
    video_scanout #(.WIDTH(64),.HEIGHT(48),.HTOTAL(80),.VTOTAL(60),
        .HSTART(16),.VSTART(12),.ENABLE_EFFECTS(0),.FIXED_RATE_AXIS(1),.COMPACT_SCENES(1),.FINAL_SUBTITLES(1),.DAILY_SCROLL_SUBTITLES(1),.DUAL_EXTENSIONS(1)) dut(
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
        .console_proxy_valid(1'b0),.console_proxy_status(96'd0),
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

    reg [3:0] bitmap[0:8191];
    integer white_pixels=0;
    task check_caption_frame;
        input [23:0] base;
        integer n,x,y,address;
        reg glyph;
        begin
            n=0;white_pixels=0;

            repeat(2)@(posedge dut.frame_tick);
            @(negedge clk);while(!(valid&&first))@(negedge clk);
            while(n<64*48)begin
                if(valid)begin
                    x=n%64;y=n/64;expected=base;
                    if((scroll||caption>=9)&&x>=16&&x<48&&y<32)begin
                        expected={1'b0,base[23:17],1'b0,base[15:9],1'b0,base[7:1]};
                        if(y>=8&&y<24)begin
                            if(scroll)begin
                                offset=positions[track*256+samples/2048];sx=x-48+offset;
                                address=track*2048+(y-8)*128+sx/8;
                                glyph=sx>=0&&sx<1024 ? strips[address][7-(sx%8)] : 0;
                            end else begin
                                address=(caption-1)*512+(y-8)*32+((x-16)/4);
                                glyph=bitmap[address][3-((x-16)%4)];
                            end
                            if(glyph)begin expected=24'hffffff;white_pixels=white_pixels+1;end
                        end
                    end
                    if(rgb!==expected||first!==(n==0)||last!==((n%64)==63))
                        $fatal(1,"final caption pixel %0d id=%0d got=%h expected=%h",n,caption,rgb,expected);
                    n=n+1;
                end
                if(n<64*48)@(negedge clk);
            end
            if(((scroll&&samples!=0)||caption>=9)&&white_pixels==0)$fatal(1,"caption glyph was hidden");
        end
    endtask
    initial begin
        $readmemh("../../rtl/subtitle_bitmap.mem",bitmap);
        $readmemh("../../rtl/daily_subtitle_strip.mem",strips);
        $readmemh("../../rtl/daily_subtitle_position.mem",positions);
        repeat(5)@(negedge clk);rst=0;
        check_caption_frame(24'h102030);
        caption=1;check_caption_frame(24'h102030);
        scroll=1;check_caption_frame(24'h102030);
        for(c=0;c<8;c=c+1)begin
            track=c;samples=81920;check_caption_frame(24'h102030);
        end
        scroll=0;
        alarm=1;caption=9;check_caption_frame(24'hdc2828);
        caption=10;check_caption_frame(24'hdc2828);
        cancel=1;caption=13;check_caption_frame(24'h50606c);
        $display("TEST_PASS scrolling subtitle pixels, eight audio mappings, emergency/release priority and unchanged AXI alignment");$finish;
    end
    initial begin #4000000;$fatal(1,"final subtitle timeout");end
endmodule

