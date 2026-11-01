// A板顶层：连接TF读取、SDRAM帧缓存、HDMI输出与板间通信。
`timescale 1ns/1ps
module hdmi_player_top(
    input wire clk, key_zoom, key1, key2, key3,
    input wire effect_sw1, effect_sw2, overlay_sw3, grayscale_sw4,
    output wire [5:0] seg_sel,
    output wire [7:0] seg_data,
    output wire HDMI_CLK_P, HDMI_D2_P, HDMI_D1_P, HDMI_D0_P,
    output wire HDMI_DDC_SCL,
    inout wire HDMI_DDC_SDA,
    output wire sd_ncs, sd_dclk, sd_mosi,
    input wire sd_miso,
    input wire console_uart_rx,
    output wire console_uart_tx,
    output wire extension_pcm_tx
);
    wire sys_clk,pixel_clk,serial_clk,mem_shift_clk,sys_rst,pixel_rst;
    wire video_pll_locked,system_pll_locked;

    clock_reset clocks(.clk(clk),.rst_n(1'b1),.pixel_clk(pixel_clk),.serial_clk(serial_clk),
        .sys_clk(sys_clk),.mem_shift_clk(mem_shift_clk),
        .video_locked(video_pll_locked),.system_locked(system_pll_locked),
        .sys_rst(sys_rst),.pixel_rst(pixel_rst));
    wire sec_req,sec_valid,sec_end,sd_ready;
    wire [31:0] sec_lba;
    wire [7:0] sec_data;
    sd_card_top #(.SPI_LOW_SPEED_DIV(123),.SPI_HIGH_SPEED_DIV(0)) card(
        .clk(sys_clk),.rst(sys_rst),.SD_nCS(sd_ncs),.SD_DCLK(sd_dclk),.SD_MOSI(sd_mosi),.SD_MISO(sd_miso),
        .sd_init_done(sd_ready),.sd_sec_read(sec_req),.sd_sec_read_addr(sec_lba),
        .sd_sec_read_data(sec_data),.sd_sec_read_data_valid(sec_valid),.sd_sec_read_end(sec_end),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
        .sd_sec_write_data_req(),.sd_sec_write_end());
    wire mem_init,mem_busy,wr_en,rd_en,rd_valid;
    wire [20:0] wr_addr,rd_addr;
    wire [31:0] wr_data,rd_data,raw_rd_data;
    memory_phy memory(.clk(sys_clk),.shifted_clk(mem_shift_clk),.rst(sys_rst),.initialized(mem_init),.busy(mem_busy),
        .wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),.rd_en(rd_en),.rd_addr(rd_addr),.rd_valid(rd_valid),.rd_data(raw_rd_data));

    sdram_read_alignment read_alignment(.clk(sys_clk),.raw_data(raw_rd_data),.aligned_data(rd_data));
    wire axis_valid,axis_user,axis_last,axis_ready,audio_valid,acr_valid;
    wire [23:0] axis_data;
    wire [15:0] audio_left,audio_right;
    wire [127:0] extension_context;wire extension_overrun;
    pcm_context_tx extension_link(.clk(pixel_clk),.rst(pixel_rst),.sample_valid(audio_valid),
     .sample(audio_left),.context(extension_context),.tx(extension_pcm_tx),.overrun(extension_overrun));
    wire [19:0] acr_n,acr_cts;
    wire ready,autoplay,underflow,overflow;
    wire video_frame_tick;
    wire [15:0] panel_debug;
    reg [15:0] panel_debug_meta,panel_debug_sync;
    always @(posedge clk)begin panel_debug_meta<=panel_debug;panel_debug_sync<=panel_debug_meta;end
    wire [4:0] image_count;
    wire [2:0] brightness_level,contrast_level,saturation_level;
    wire osd_visible,zoom_mode,grayscale_enable;
    wire [3:0] image_index;
    wire [5:0] period_seconds;
    wire [3:0] loader_error,memory_error;
    wire media_playlist_fault;
    wire alarm_active,alarm_buzzer,alarm_latency_valid;
    wire [2:0] alarm_level;
    wire [3:0] alarm_active_count;
    wire [7:0] alarm_blocked_set;
    wire [23:0] alarm_pixel_latency_us,alarm_audio_latency_us;
    wire narration_external_allowed,narration_audio_underflow,narration_playing;
    wire [7:0] narration_subtitle;
    wire [3:0] narration_reject_reason,event_finish_reason;
    wire event_finish_valid;
    wire [23:0] e5_peak_frequency_q8;
    wire [7:0] e5_waterfall_sample;
    wire emergency_cmd_valid,emergency_cmd_ready,emergency_result_valid;
    wire link_cmd_ready;
    wire [2:0] emergency_cmd_opcode,emergency_cmd_kind,emergency_cmd_level;
    wire [1:0] emergency_cmd_source;
    wire [15:0] emergency_cmd_event_id,emergency_cmd_remaining_seconds;
    wire [7:0] emergency_cmd_sequence;
    wire emergency_cmd_drill,emergency_cmd_pending,emergency_cmd_time_trusted;
    wire [2:0] emergency_cmd_region;
    wire [3:0] emergency_result_code;
    wire [32:0] emergency_cmd_snapshot;
    wire emergency_cmd_epoch_changed;
    wire service_valid,service_last;
    wire [7:0] service_type;wire [15:0] service_batch;
    wire [95:0] service_payload;
    wire [31:0] sync_parameters;wire [63:0] sync_event;
    wire [7:0] sync_blocked;wire [95:0] sync_certificate;
    wire [15:0] sync_certificate_valid_bitmap;
    wire sync_state_valid,sync_apply,sync_batch_error;wire [15:0] sync_active_batch;
    reg [95:0] console_status_pending,console_status_active;
    reg console_status_dirty,console_status_valid;
    reg [7:0] console_status_age;
    reg [4:0] uart_us_div;
    reg [24:0] uart_heartbeat_div;
    reg [21:0] uart_telemetry_div;
    reg uart_us_tick,uart_heartbeat_tick,uart_telemetry_tick;
    always @(posedge pixel_clk or posedge pixel_rst) begin
        if(pixel_rst) begin
            uart_us_div<=0;uart_heartbeat_div<=0;uart_telemetry_div<=0;
            uart_us_tick<=0;uart_heartbeat_tick<=0;uart_telemetry_tick<=0;
        end else begin
            uart_us_tick<=0;uart_heartbeat_tick<=0;uart_telemetry_tick<=0;
            if(uart_us_div==24) begin uart_us_div<=0;uart_us_tick<=1;end
            else uart_us_div<=uart_us_div+1'b1;
            if(uart_heartbeat_div==24999999) begin
                uart_heartbeat_div<=0;uart_heartbeat_tick<=1;
            end else uart_heartbeat_div<=uart_heartbeat_div+1'b1;
            if(uart_telemetry_div==2499999) begin
                uart_telemetry_div<=0;uart_telemetry_tick<=1;
            end else uart_telemetry_div<=uart_telemetry_div+1'b1;
        end
    end
    wire link_frame_error,link_crc_error;
    reg mem_busy_meta,mem_busy_pixel,line_start_pending;
    wire telemetry_line_start=axis_valid&&(axis_user||line_start_pending);
    wire telemetry_line_end=axis_valid&&axis_last;
    always @(posedge pixel_clk or posedge pixel_rst)begin
        if(pixel_rst)begin mem_busy_meta<=0;mem_busy_pixel<=0;line_start_pending<=1;end
        else begin
            mem_busy_meta<=mem_busy;mem_busy_pixel<=mem_busy_meta;
            if(telemetry_line_start)line_start_pending<=0;
            if(telemetry_line_end)line_start_pending<=1;
        end
    end
    wire [15:0] telemetry_last_line,telemetry_max_line;
    wire [31:0] telemetry_video_count,telemetry_audio_count;
    wire [31:0] telemetry_crc_count,telemetry_frame_count;
    wire [31:0] telemetry_cache_count,telemetry_tf_count;
    v41_telemetry_monitor telemetry(.clk(pixel_clk),.rst(pixel_rst),.clear_stats(1'b0),
        .line_start(telemetry_line_start),.line_end(telemetry_line_end),
        .sdram_busy(mem_busy_pixel),.video_underflow(underflow),
        .audio_underflow(narration_audio_underflow),
        .uart_crc_error(link_crc_error),.uart_frame_error(link_frame_error),
        .cache_error(memory_error!=0),.tf_error(loader_error!=0),
        .last_line_cycles(telemetry_last_line),.max_line_cycles(telemetry_max_line),
        .video_underflow_count(telemetry_video_count),
        .audio_underflow_count(telemetry_audio_count),
        .uart_crc_error_count(telemetry_crc_count),
        .uart_frame_error_count(telemetry_frame_count),
        .cache_error_count(telemetry_cache_count),.tf_error_count(telemetry_tf_count));
    p3_uart_endpoint #(.CLK_HZ(25000000),.BAUD(115200),.CERTIFICATE_COUNT(15),.SINGLE_CARD_CONTROL(1),
        .ENABLE_EVENT_SNAPSHOT(1)) console_link(
        .clk(pixel_clk),.rst(pixel_rst),.rx(console_uart_rx),.tx(console_uart_tx),
        .us_tick(uart_us_tick),.command_valid(emergency_cmd_valid),
        .command_ready(link_cmd_ready),.command_opcode(emergency_cmd_opcode),
        .command_source(emergency_cmd_source),.command_kind(emergency_cmd_kind),
        .command_event_id(emergency_cmd_event_id),.command_sequence(emergency_cmd_sequence),
        .command_level(emergency_cmd_level),.command_drill(emergency_cmd_drill),
        .command_pending_flag(emergency_cmd_pending),.command_region(emergency_cmd_region),
        .command_time_trusted(emergency_cmd_time_trusted),
        .command_remaining_seconds(emergency_cmd_remaining_seconds),
        .command_snapshot(emergency_cmd_snapshot),.command_epoch_changed(emergency_cmd_epoch_changed),
        .command_result_valid(emergency_result_valid),.command_result_code(emergency_result_code),

        .latency_valid(1'b0),.pixel_latency_us(24'd0),
        .audio_latency_us(24'd0),
        .finish_valid(event_finish_valid),.finish_reason(event_finish_reason),
        .heartbeat_tick(uart_heartbeat_tick),.alarm_active(alarm_active),
        .alarm_level(alarm_level),.active_count(alarm_active_count),
        .blocked_set(alarm_blocked_set),.boot_count(32'h0004_1001),
        .telemetry_tick(uart_telemetry_tick),.telemetry_last_line(telemetry_last_line),
        .telemetry_max_line(telemetry_max_line),
        .telemetry_video_underflows(telemetry_video_count[15:0]),
        .telemetry_uart_errors(telemetry_crc_count[15:0]+telemetry_frame_count[15:0]),
        .service_valid(service_valid),.service_type(service_type),
        .service_batch(service_batch),.service_payload(service_payload),
        .service_last(service_last),.frame_error(link_frame_error),.crc_error(link_crc_error));
    wire [3:0] certificate_lookup_index;
    wire console_status_message=service_valid&&service_type==8'h20;
    wire sync_certificate_ready;
    v41_resync_receiver #(.CERTIFICATE_COUNT(15),.ENABLE_CERTIFICATES(0)) resync(.clk(pixel_clk),.rst(pixel_rst),
        .frame_tick(video_frame_tick),.msg_valid(service_valid&&service_type<8'h20),
        .msg_type(service_type),.msg_batch(service_batch),
        .msg_payload(service_payload),.msg_last(service_last),
        .certificate_lookup_index(certificate_lookup_index),
        .active_parameters(sync_parameters),.active_event(sync_event),
        .active_blocked(sync_blocked),.active_certificate(sync_certificate),
        .certificate_ready(sync_certificate_ready),
        .active_certificate_valid_bitmap(sync_certificate_valid_bitmap),
        .state_valid(sync_state_valid),.apply_pulse(sync_apply),
        .batch_error(sync_batch_error),.active_batch(sync_active_batch));
    always @(posedge pixel_clk or posedge pixel_rst)begin
        if(pixel_rst)begin
            console_status_pending<=0;console_status_active<=0;
            console_status_dirty<=0;console_status_valid<=0;console_status_age<=0;
        end else begin
            if(console_status_message)begin
                console_status_pending<=service_payload;console_status_dirty<=1;
            end
            if(video_frame_tick)begin
                if(console_status_dirty)begin
                    console_status_active<=console_status_pending;
                    console_status_dirty<=0;console_status_valid<=1;console_status_age<=0;
                end else if(console_status_valid)begin
                    if(console_status_age==8'd179)begin
                        console_status_valid<=0;console_status_age<=0;
                    end else console_status_age<=console_status_age+1'b1;
                end
            end
        end
    end

    assign link_cmd_ready=emergency_cmd_ready;

    wire active_narration_certificate_valid=
        sync_certificate_ready&&sync_certificate_valid_bitmap[certificate_lookup_index];
    wire audio_play_permitted;
    audio_play_permission permission(.clk(pixel_clk),.rst(pixel_rst),
        .frame_tick(video_frame_tick),.snapshot_apply(sync_apply),
        .parameters(sync_parameters),.allowed(audio_play_permitted));
    media_core #(.FILMING_PROFILE(1),.FIXED_RATE_AXIS(1),.MUSEUM_UI(0),.ENABLE_LOCAL_STFT(0),.ENABLE_TF_IMA(0),
        .ENABLE_L0_VOICE(0),.COMPACT_SCENES(1),.COMPACT_DIAGNOSTICS(1),.STRICT_CHAIN(0),.CANONICAL_PCM(1),.HUMAN_RECORDINGS(1),
        .ENABLE_TF_NARRATION(1),.SINGLE_CARD_AUDIO(1),.DUAL_TRANSITIONS(1),.REMOTE_SPECTRUM(1),.DUAL_EXTENSIONS(1),
        .ROUTE_GUIDANCE(1),.BOARD_ROUTE_AUTHORITY(1),.BOARD_EVENT_AUTHORITY(1),.V5_CONTROLS(1),.SIMPLE_DEMO(1)) core(.extension_context(extension_context),.sys_clk(sys_clk),.pixel_clk(pixel_clk),.sys_rst(sys_rst),.pixel_rst(pixel_rst),
        .key_zoom_n(key_zoom),.key_next_n(key1),.key_auto_n(key2),.key_period_n(key3),
        .effect_switch({effect_sw2,effect_sw1}),
        .overlay_switch(overlay_sw3),
        .grayscale_switch(grayscale_sw4),
        .mem_init(mem_init),.mem_busy(mem_busy),.sd_ready(sd_ready),
        .emergency_cmd_valid(emergency_cmd_valid),
        .emergency_cmd_opcode(emergency_cmd_opcode),
        .emergency_cmd_source(emergency_cmd_source),
        .emergency_cmd_kind(emergency_cmd_kind),
        .emergency_cmd_event_id(emergency_cmd_event_id),
        .emergency_cmd_sequence(emergency_cmd_sequence),
        .emergency_cmd_level(emergency_cmd_level),
        .emergency_cmd_drill(emergency_cmd_drill),
        .emergency_cmd_pending(emergency_cmd_pending),
        .emergency_cmd_region(emergency_cmd_region),
        .emergency_cmd_time_trusted(emergency_cmd_time_trusted),
        .emergency_cmd_remaining_seconds(emergency_cmd_remaining_seconds),
        .emergency_cmd_snapshot(emergency_cmd_snapshot),.emergency_cmd_epoch_changed(emergency_cmd_epoch_changed),
        .sync_blocked_valid(sync_apply),.sync_blocked_set(sync_blocked),
        .console_proxy_valid(console_status_valid),
        .console_proxy_status(console_status_active),
        .spectrum_message_valid(service_valid),.spectrum_message_type(service_type),
        .spectrum_message_payload(service_payload),
        .narration_enable(1'b1),.narration_cfg_we(1'b0),
        .narration_cfg_index(8'd0),.narration_cfg_sample(32'd0),
        .narration_cfg_subtitle(8'd0),.narration_cfg_last(1'b0),
        .narration_sample_valid(1'b0),.narration_sample(16'sd0),
        .narration_asset_begin(1'b0),.narration_asset_complete(1'b0),
        .narration_asset_purpose(8'h21+certificate_lookup_index),
        .narration_asset_length(32'd0),.narration_asset_crc32(32'd0),
        .narration_certificate_valid(active_narration_certificate_valid),
        .audio_play_permitted(audio_play_permitted),
        .narration_certificate(sync_certificate),
        .audio_certificate_index(certificate_lookup_index),
        .sector_req(sec_req),.sector_lba(sec_lba),.sector_data(sec_data),.sector_valid(sec_valid),.sector_end(sec_end),
        .wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),.rd_en(rd_en),.rd_addr(rd_addr),.rd_valid(rd_valid),.rd_data(rd_data),
        .axis_valid(axis_valid),.axis_user(axis_user),.axis_last(axis_last),.axis_data(axis_data),.axis_ready(axis_ready),
        .audio_valid(audio_valid),.audio_left(audio_left),.audio_right(audio_right),.acr_valid(acr_valid),.acr_n(acr_n),.acr_cts(acr_cts),
        .cache_ready(ready),.image_count(image_count),.image_index(image_index),.autoplay(autoplay),.period_seconds(period_seconds),
        .brightness_level(brightness_level),.contrast_level(contrast_level),
        .saturation_level(saturation_level),.osd_visible(osd_visible),.zoom_mode(zoom_mode),
        .grayscale_enable(grayscale_enable),
        .loader_error(loader_error),.memory_error(memory_error),.video_underflow(underflow),.video_overflow(overflow),
        .media_playlist_fault(media_playlist_fault),
        .alarm_active(alarm_active),.alarm_buzzer(alarm_buzzer),.alarm_blocked_set(alarm_blocked_set),
        .alarm_latency_valid(alarm_latency_valid),.alarm_pixel_latency_us(alarm_pixel_latency_us),
        .alarm_audio_latency_us(alarm_audio_latency_us),.emergency_cmd_ready(emergency_cmd_ready),
        .emergency_result_valid(emergency_result_valid),.emergency_result_code(emergency_result_code),
        .alarm_level(alarm_level),.alarm_active_count(alarm_active_count),
        .narration_playing(narration_playing),.narration_subtitle(narration_subtitle),
        .narration_external_allowed(narration_external_allowed),
        .narration_reject_reason(narration_reject_reason),
        .audio_underflow(narration_audio_underflow),
        .event_finish_valid(event_finish_valid),.event_finish_reason(event_finish_reason),
        .e5_peak_frequency_q8(e5_peak_frequency_q8),
        .e5_waterfall_sample(e5_waterfall_sample),.video_frame_tick(video_frame_tick),.panel_debug_status(panel_debug));
    reg [19:0] edid_count;
    wire edid_trigger=edid_count==20'd999999;
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst) edid_count<=0; else if(edid_count<20'd1000000) edid_count<=edid_count+1'b1;
    wire [9:0] tmds0,tmds1,tmds2,tmdsclk;
    hdmi_1_4b_transmitter_core_wrapper #(
        .DEVICE("EG"),.HTOTAL(800),.HSA(96),.HFP(16),.HBP(48),.HACTIVE(640),
        .VTOTAL(525),.VSA(2),.VFP(10),.VBP(33),.VACTIVE(480),
        .VIDEO_VIC(1),.VIDEO_TPG("Disable"),.VIDEO_FORMAT("RGB"),.AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(250)
    ) hdmi(.I_pixel_clk(pixel_clk),.I_rst(pixel_rst),.I_edid_read_trig(edid_trigger),.O_edid_read_valid(),.O_edid_read_data(),
        .I_axis_s_user(axis_user),.I_axis_s_valid(axis_valid),.I_axis_s_last(axis_last),.I_axis_s_data(axis_data),.O_axis_s_ready(axis_ready),
        .I_audio_valid(audio_valid),.I_audio_left_data({audio_left,8'd0}),.I_audio_right_data({audio_right,8'd0}),
        .I_acr_valid(acr_valid),.I_acr_cts(acr_cts),.I_acr_n(acr_n),.O_video_locked(),
        .O_ddc_scl(HDMI_DDC_SCL),.IO_ddc_sda(HDMI_DDC_SDA),
        .O_ch0_tmds_data(tmds0),.O_ch1_tmds_data(tmds1),.O_ch2_tmds_data(tmds2),.O_clk_tmds_data(tmdsclk));
    hdmi_phy_wrapper #(.DEVICE("EG")) phy(.I_pixel_clk(pixel_clk),.I_serial_clk(serial_clk),.I_rst(pixel_rst),
        .I_tmds_channel_0(tmds0),.I_tmds_channel_1(tmds1),.I_tmds_channel_2(tmds2),.I_tmds_channel_clk(tmdsclk),
        .O_tmds_ch0_p(HDMI_D0_P),.O_tmds_ch1_p(HDMI_D1_P),.O_tmds_ch2_p(HDMI_D2_P),.O_tmds_clk_p(HDMI_CLK_P));

    reg [26:0] status_s1,status_s2;
    reg [1:0] video_lock_sync,system_lock_sync,analyzer_fault_sync;

    wire analyzer_fault_async=media_playlist_fault;
    always @(posedge clk) begin
        if(!video_pll_locked || !system_pll_locked) begin
            status_s1<=27'd0;
            status_s2<=27'd0;
            video_lock_sync<=2'b00;
            system_lock_sync<=2'b00;
            analyzer_fault_sync<=2'b00;
        end else begin
            status_s1<={ready,image_count,image_index,autoplay,period_seconds,
                loader_error,memory_error,underflow,overflow};
            status_s2<=status_s1;
            video_lock_sync<={video_lock_sync[0],video_pll_locked};
            system_lock_sync<={system_lock_sync[0],system_pll_locked};
            analyzer_fault_sync<={analyzer_fault_sync[0],analyzer_fault_async};
        end
    end
    wire [3:0] diagnostic_error=!video_lock_sync[1] ? 4'd9 :
        !system_lock_sync[1] ? 4'd10 :
        status_s2[9:6]!=0 ? status_s2[9:6] :
        status_s2[5:2]!=0 ? status_s2[5:2] :
        status_s2[1] ? 4'd7 : status_s2[0] ? 4'd8 : analyzer_fault_sync[1] ? 4'd11 : 4'd0;
    status_display #(.TEST_STATUS(1)) display(
        .test_status(panel_debug_sync),.clk(clk),.rst(!video_pll_locked || !system_pll_locked),.image_index(status_s2[20:17]),
        .image_count(status_s2[25:21]),.autoplay(status_s2[16]),.ready(status_s2[26]),
        .period_seconds(status_s2[15:10]),.error_code(diagnostic_error),
        .seg_sel(seg_sel),.seg_data(seg_data));
endmodule
