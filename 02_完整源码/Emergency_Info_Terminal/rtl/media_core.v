// 媒体处理顶层：协调文件读取、图像缓存、音频、字幕及应急画面。
`timescale 1ns/1ps

module media_core #(
    parameter integer WIDTH=640, HEIGHT=480, BURST=128,
    parameter integer HTOTAL=800, VTOTAL=525, HSTART=160, VSTART=45,
    parameter integer CONTROL_HZ=25000000, DEBOUNCE_CYCLES=500000,
    parameter integer KEY_LONG_CYCLES=CONTROL_HZ, OSD_FRAMES=120,
    parameter integer DRAIN_CYCLES=32,
    parameter integer FADE_STEPS=16, ENABLE_EFFECTS=1,
    parameter integer FIXED_RATE_AXIS=0,
    parameter integer MUSEUM_UI=0, IDLE_SECONDS=60,
    parameter integer FOUR_SLOT_CACHE=1,
    parameter integer LOGICAL_IMAGES=16,
    parameter integer ENABLE_LOCAL_STFT=1,
    parameter integer ENABLE_TF_NARRATION=0,
    parameter integer ENABLE_TF_IMA=1,
    parameter integer ENABLE_L0_VOICE=1,
    parameter integer COMPACT_SCENES=0,
    parameter integer COMPACT_DIAGNOSTICS=0,
    parameter integer CANONICAL_PCM=0,
    parameter integer HUMAN_RECORDINGS=0,
    parameter integer SINGLE_CARD_AUDIO=0,
    parameter integer DUAL_TRANSITIONS=0,
    parameter integer REMOTE_SPECTRUM=0,
    parameter integer DUAL_EXTENSIONS=0,
    parameter integer ROUTE_GUIDANCE=0,
    parameter integer BOARD_ROUTE_AUTHORITY=0,
    parameter integer BOARD_EVENT_AUTHORITY=0,
    parameter integer V5_CONTROLS=0,
    parameter integer SIMPLE_DEMO=0,
    parameter integer FILMING_PROFILE=SIMPLE_DEMO&&DUAL_EXTENSIONS,
    parameter integer STRICT_CHAIN=V5_CONTROLS,
    parameter integer ORIGINAL_DETAIL=V5_CONTROLS && FOUR_SLOT_CACHE,
    parameter [31:0] SCAN_FIRST=2048, SCAN_LIMIT=131072
)(
    input wire sys_clk, pixel_clk, sys_rst, pixel_rst,
    output wire [127:0] extension_context,
    input wire key_zoom_n, key_next_n, key_auto_n, key_period_n,
    input wire [1:0] effect_switch,
    input wire overlay_switch,
    input wire grayscale_switch,
    input wire mem_init, mem_busy, sd_ready,

    input wire emergency_cmd_valid,
    input wire [2:0] emergency_cmd_opcode,
    input wire [1:0] emergency_cmd_source,
    input wire [2:0] emergency_cmd_kind,
    input wire [15:0] emergency_cmd_event_id,
    input wire [7:0] emergency_cmd_sequence,
    input wire [2:0] emergency_cmd_level,
    input wire emergency_cmd_drill,
    input wire emergency_cmd_pending,
    input wire [2:0] emergency_cmd_region,
    input wire emergency_cmd_time_trusted,
    input wire [15:0] emergency_cmd_remaining_seconds,
    input wire [32:0] emergency_cmd_snapshot,
    input wire emergency_cmd_epoch_changed,
    input wire sync_blocked_valid,
    input wire [7:0] sync_blocked_set,
    input wire console_proxy_valid,
    input wire [95:0] console_proxy_status,
    input wire spectrum_message_valid,
    input wire [7:0] spectrum_message_type,
    input wire [95:0] spectrum_message_payload,
    input wire narration_enable,
    input wire narration_cfg_we,
    input wire [7:0] narration_cfg_index,
    input wire [31:0] narration_cfg_sample,
    input wire [7:0] narration_cfg_subtitle,
    input wire narration_cfg_last,
    input wire narration_sample_valid,
    input wire signed [15:0] narration_sample,
    input wire narration_asset_begin,
    input wire narration_asset_complete,
    input wire [7:0] narration_asset_purpose,
    input wire [31:0] narration_asset_length,
    input wire [31:0] narration_asset_crc32,
    input wire narration_certificate_valid,
    input wire audio_play_permitted,
    input wire [95:0] narration_certificate,
    output wire sector_req,
    output wire [31:0] sector_lba,
    input wire [7:0] sector_data,
    input wire sector_valid, sector_end,
    output wire wr_en,
    output wire [20:0] wr_addr,
    output wire [31:0] wr_data,
    output wire rd_en,
    output wire [20:0] rd_addr,
    input wire rd_valid,
    input wire [31:0] rd_data,
    output wire axis_valid, axis_user, axis_last,
    output wire [23:0] axis_data,
    input wire axis_ready,
    output wire audio_valid,
    output wire [15:0] audio_left, audio_right,
    output wire acr_valid,
    output wire [19:0] acr_n, acr_cts,
    output wire cache_ready,
    output wire [4:0] image_count,
    output wire [3:0] image_index,
    output wire autoplay,
    output wire [5:0] period_seconds,
    output wire [2:0] brightness_level, contrast_level, saturation_level,
    output wire osd_visible,
    output wire zoom_mode,
    output wire grayscale_enable,
    output wire [3:0] loader_error, memory_error,
    output wire media_playlist_fault,
    output wire video_underflow, video_overflow,
    output wire alarm_active,
    output wire alarm_buzzer,
    output wire [7:0] alarm_blocked_set,
    output wire alarm_latency_valid,
    output wire [23:0] alarm_pixel_latency_us, alarm_audio_latency_us,
    output wire emergency_cmd_ready,
    output wire emergency_result_valid,
    output wire [3:0] emergency_result_code,
    output wire [2:0] alarm_level,
    output wire [3:0] alarm_active_count,
    output wire narration_playing,
    output wire [7:0] narration_subtitle,
    output wire narration_external_allowed,
    output wire [3:0] audio_certificate_index,
    output wire [3:0] narration_reject_reason,
    output wire audio_underflow,
    output wire [15:0] audio_peak_absolute,
    output wire [31:0] audio_limited_count,audio_clipped_count,
    output wire event_finish_valid,
    output wire [3:0] event_finish_reason,
    output wire [23:0] e5_peak_frequency_q8,
    output wire [7:0] e5_waterfall_sample
    ,output wire [15:0] panel_debug_status
    ,output wire video_frame_tick
);
    wire load_done, load_valid, load_ready;
    wire [21:0] load_addr;
    wire [23:0] load_rgb;
    wire line_req, line_ack, line_bank;
    wire [3:0] line_image,line_second_image;
    wire [9:0] line_row,line_split;
    wire line_horizontal_slide;wire [1:0] line_zoom;
    wire [10:0] ram_addr;
    wire [23:0] ram_q;
    wire [23:0] second_ram_q;
    wire [10:0] second_ram_addr;
    wire line_dual;
    wire [6:0] transition_phase;
    wire manual_next_event,auto_event,period_event,reload_event,frame_tick;
    assign video_frame_tick=frame_tick;
    wire zoom_key_press, zoom_key_short, zoom_key_long, zoom_key_held;
    wire key1_press, key1_short, key1_long, key1_held;
    wire key2_press, key2_short, key2_long, key2_held;
    wire key3_press, key3_short, key3_long, key3_held;
    wire [1:0] period_select;
    wire [4:0] video_gain;
    wire transition_active,slide_active;
    wire [2:0] transition_mode;
    wire [3:0] transition_target;
    wire [4:0] slide_progress;
    wire [12:0] scroll_position;
    reg [3:0] narration_image_q;
    reg narration_start,narration_next_event;
    reg [31:0] narration_hold_count;
    reg narration_seed_active;
    reg [5:0] narration_seed_index;
    reg narration_request_toggle;
    reg narration_request_loop;
    reg [3:0] narration_request_image;
    wire alarm_evacuation;
    wire [15:0] alarm_countdown_seconds;
    wire raw_alarm_active,raw_alarm_drill,raw_alarm_cancel_notice,raw_alarm_pending;
    wire raw_alarm_flash_on,raw_alarm_countdown_trusted,raw_alarm_evacuation;
    wire [2:0] raw_alarm_kind,raw_alarm_level;
    wire [15:0] raw_alarm_countdown_seconds;
    wire [3:0] raw_alarm_active_count;
    wire panel_mode,panel_running,panel_active,panel_cancel,panel_pending,panel_evac,panel_trusted;
    wire panel_tone,panel_synth,panel_restart,panel_flash;
    wire [4:0] panel_selection;
    wire panel_voice;
    wire panel_audio_hold=panel_mode&&(!panel_running||!panel_voice||panel_restart);
    wire [2:0] panel_level,panel_kind;
    wire [15:0] panel_seconds;
    wire media_audio_request,media_alarm_asset;
    wire media_voice_asset;
    wire tf_stream_failed;
    wire [7:0] media_voice_subtitle,timeline_subtitle;
    wire alarm_drill,alarm_cancel_notice,alarm_flash_on,alarm_countdown_trusted,alarm_pending;

    wire audible_alarm=alarm_active&&!(HUMAN_RECORDINGS&&alarm_cancel_notice)&&!panel_audio_hold;
    wire tf_asset_begin,tf_asset_complete,tf_stream_sample_valid;
    wire [7:0] tf_asset_purpose;
    wire [31:0] tf_asset_length,tf_asset_crc32,tf_asset_samples;
    wire daily_audio_valid,daily_acr_valid;
    wire diagnostic_test_active;
    wire selected_asset_begin;
    wire [95:0] live_route_result;wire live_route_fresh;
    wire [31:0] route_voice_start;wire route_speech_current;
    generate if(DUAL_EXTENSIONS)begin: route_snapshot
      live_route_state snapshot(.clk(pixel_clk),.rst(pixel_rst),.frame_tick(frame_tick),
        .message_valid(spectrum_message_valid),.message_type(spectrum_message_type),.payload(spectrum_message_payload),
        .blocked(alarm_blocked_set),.active(live_route_result),.fresh(live_route_fresh));
    end else begin assign live_route_result=0;assign live_route_fresh=0;end endgenerate
    wire human_sample_consumed=!panel_audio_hold&&!panel_synth&&daily_audio_valid&&media_voice_asset&&
        route_speech_current&&
        narration_external_allowed&&tf_stream_sample_valid&&
        tf_asset_purpose==8'h21+audio_certificate_index;
    reg human_voice_started;
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst)human_voice_started<=0;
        else if(!media_voice_asset||media_audio_request||selected_asset_begin)human_voice_started<=0;
        else if(human_sample_consumed)human_voice_started<=1;
    assign narration_subtitle=media_voice_asset ? media_voice_subtitle : timeline_subtitle;
    wire [2:0] alarm_kind;
    wire [3:0] playlist_asset;
    wire [31:0] playlist_cue_sample;
    wire [7:0] playlist_cue_subtitle;
    wire playlist_cue_last;
    wire daily_transport_hold,daily_stop_needed,broadcast_mode;
    reg narration_request_stop;
    wire playlist_valid_sys;
    reg [1:0] playlist_valid_sync;
    assign media_playlist_fault=V5_CONTROLS&&ENABLE_TF_NARRATION&&cache_ready&&!playlist_valid_sync[1];
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst)playlist_valid_sync<=0;
        else if(reload_event)playlist_valid_sync<=0;
        else playlist_valid_sync<={playlist_valid_sync[0],playlist_valid_sys};
    generate if(HUMAN_RECORDINGS)begin: human_assets
    human_playlist_rom playlist(.image_id(image_index),.cue_address(narration_seed_index),
        .asset_index(playlist_asset),.cue_sample(playlist_cue_sample),
        .cue_subtitle(playlist_cue_subtitle),.cue_last(playlist_cue_last));
    human_stage_audio_requests #(.EXPLICIT_RELEASE(SIMPLE_DEMO),.RESTART_DAILY(SIMPLE_DEMO),.ROUTE_GUIDANCE(ROUTE_GUIDANCE)) audio_requests(
        .route_enabled(alarm_active&&(alarm_evacuation||alarm_kind==3)&&!alarm_pending),
        .route_fresh(live_route_fresh),.route_exit(live_route_result[66:64]),.route_status(live_route_result[68:67]),
        .route_start_sample(route_voice_start),.route_speech_current(route_speech_current),
        .daily_blocked(daily_transport_hold),
        .release_request(panel_cancel),.clk(pixel_clk),.rst(pixel_rst|reload_event|panel_restart),
        .frame_tick(frame_tick),.ready(cache_ready&&!narration_seed_active&&!alarm_cancel_notice),
        .narration_enable(narration_enable&&(!SIMPLE_DEMO||broadcast_mode)),.image_index(image_index),
        .alarm_active(audible_alarm),.alarm_kind(alarm_kind),.alarm_drill(alarm_drill),
        .alarm_pending(alarm_pending),.configured_narration_index(playlist_asset),
        .configuration_valid((!ENABLE_TF_NARRATION||playlist_valid_sync[1])&&
            (!SINGLE_CARD_AUDIO||audio_play_permitted)&&!panel_synth&&!panel_audio_hold),
        .asset_complete(tf_asset_complete),.asset_purpose(tf_asset_purpose),
        .asset_samples(tf_asset_samples),.consume(human_sample_consumed),
        .asset_failed(narration_reject_reason>=3),
        .io_failed(tf_asset_begin&&tf_stream_failed&&tf_asset_purpose==8'h21+audio_certificate_index),
        .request(media_audio_request),.asset_index(audio_certificate_index),
        .alarm_asset(media_alarm_asset),.voice_asset(media_voice_asset),
        .voice_subtitle(media_voice_subtitle));
    end else begin: legacy_assets
    assign route_voice_start=0;assign route_speech_current=1;
    assign media_voice_asset=0;assign media_voice_subtitle=0;
    demo_playlist_rom playlist(.image_id(image_index),.cue_address(narration_seed_index),
        .asset_index(playlist_asset),.cue_sample(playlist_cue_sample),
        .cue_subtitle(playlist_cue_subtitle),.cue_last(playlist_cue_last));
    media_audio_requests #(.CONFIGURED_PLAYLIST(V5_CONTROLS)) audio_requests(.clk(pixel_clk),.rst(pixel_rst|reload_event),
        .frame_tick(frame_tick),.ready(cache_ready&&!narration_seed_active),
        .narration_enable(narration_enable),.image_index(image_index),
        .alarm_active(alarm_active),.alarm_kind(alarm_kind),
        .configured_narration_index(playlist_asset),
        .configuration_valid(!ENABLE_TF_NARRATION || playlist_valid_sync[1]),
        .request(media_audio_request),.asset_index(audio_certificate_index),
        .alarm_asset(media_alarm_asset));
    end endgenerate
    reg narration_waiting_for_audio,narration_verified;
    reg [1:0] ready_sync,effect_meta,effect_synced;
    reg overlay_meta,overlay_synced,grayscale_meta,grayscale_synced;
    wire panel_switch=SIMPLE_DEMO&&effect_synced[0];
    assign panel_voice=grayscale_synced;
    panel_test_control panel_test(.clk(pixel_clk),.rst(pixel_rst),.frame_tick(frame_tick),
        .enable(panel_switch),.blocked(raw_alarm_active),.voice_enable(panel_voice),
        .previous(zoom_key_short),.next(key1_short),.toggle(key3_short),.level_next(key2_short),
        .mode(panel_mode),.running(panel_running),.selection(panel_selection),.level(panel_level),
        .active(panel_active),.cancel(panel_cancel),.pending(panel_pending),.evacuation(panel_evac),
        .trusted(panel_trusted),.tone40k(panel_tone),.synth_only(panel_synth),.kind(panel_kind),
        .seconds(panel_seconds),.restart_audio(panel_restart),.flash(panel_flash));
    wire [3:0] panel_scene=panel_selection<16 ? 0 : panel_selection==16 ? 1 : panel_selection-14;
    wire [15:0] panel_status={panel_mode,panel_running,panel_scene,panel_level,panel_voice,1'b0,panel_selection};
    assign panel_debug_status=panel_status;
    assign alarm_active=raw_alarm_active||panel_active||panel_cancel;
    assign alarm_cancel_notice=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_cancel_notice : panel_cancel;
    assign alarm_kind=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_kind : panel_kind;
    assign alarm_level=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_level : panel_level;
    assign alarm_drill=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_drill : panel_active;
    assign alarm_pending=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_pending : panel_pending;
    assign alarm_evacuation=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_evacuation : panel_evac;
    assign alarm_countdown_trusted=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_countdown_trusted : panel_active&&panel_trusted;
    assign alarm_countdown_seconds=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_countdown_seconds : panel_seconds;
    assign alarm_flash_on=raw_alarm_active||!SIMPLE_DEMO ? raw_alarm_flash_on : panel_flash;
    assign alarm_active_count=(!SIMPLE_DEMO||raw_alarm_active) ? raw_alarm_active_count : {3'd0,panel_active};

    assign diagnostic_test_active=SIMPLE_DEMO ? panel_tone&&!raw_alarm_active :
        V5_CONTROLS&&effect_synced[1]&&overlay_synced&&!alarm_active&&!alarm_cancel_notice;
    wire [1:0] daily_zoom_scale;
    wire [2:0] daily_pan_x,daily_pan_y;
    wire daily_auto_contrast;
    wire [1:0] realtime_zoom_scale=panel_mode ? 2'd0 : V5_CONTROLS ? daily_zoom_scale :
        zoom_mode ? (grayscale_synced ? 2'd2 : 2'd1) : 2'd0;
    wire [10:0] realtime_pan_x=V5_CONTROLS ? (daily_zoom_scale==0 ? WIDTH/2 : daily_zoom_scale==2 ? WIDTH/8+daily_pan_x*(3*WIDTH/16) :
        WIDTH/4+daily_pan_x*(WIDTH/8)) : zoom_mode&&grayscale_synced ?
        (effect_synced[0] ? WIDTH/2+WIDTH/8 : WIDTH/2-WIDTH/8) : WIDTH/2;
    wire [10:0] realtime_pan_y=V5_CONTROLS ? (daily_zoom_scale==0 ? HEIGHT/2 : daily_zoom_scale==2 ? HEIGHT/8+daily_pan_y*(3*HEIGHT/16) :
        HEIGHT/4+daily_pan_y*(HEIGHT/8)) : zoom_mode&&grayscale_synced ?
        (effect_synced[1] ? HEIGHT/2+HEIGHT/8 : HEIGHT/2-HEIGHT/8) : HEIGHT/2;
    always @(posedge pixel_clk or posedge pixel_rst)
        if (pixel_rst) begin
            ready_sync<=0;effect_meta<=0;effect_synced<=0;
            overlay_meta<=0;overlay_synced<=0;
            grayscale_meta<=0;grayscale_synced<=0;
        end else begin
            ready_sync<={ready_sync[0],cache_ready};
            effect_meta<=effect_switch;
            effect_synced<=effect_meta;
            overlay_meta<=overlay_switch;
            overlay_synced<=overlay_meta;
            grayscale_meta<=grayscale_switch;
            grayscale_synced<=grayscale_meta;
        end
    key_events_shared #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.LONG_CYCLES(KEY_LONG_CYCLES)) key_filters(
        .clk(pixel_clk),.rst(pixel_rst),.key_n({key_period_n,key_auto_n,key_next_n,key_zoom_n}),
        .press({key3_press,key2_press,key1_press,zoom_key_press}),
        .short_release({key3_short,key2_short,key1_short,zoom_key_short}),
        .long_press({key3_long,key2_long,key1_long,zoom_key_long}),
        .held({key3_held,key2_held,key1_held,zoom_key_held}));
    wire previous_event,museum_playing,museum_activity;
    wire local_contact_closed,local_fire_active,local_fire_confirmed,local_evacuation;
    wire local_menu,local_armed,local_action_valid,local_fire_visible;
    wire [1:0] local_role,local_selection,local_action;
    wire [3:0] local_result;
    wire [15:0] local_event_version;
    wire daily_follow_narration;
    wire [15:0] local_control_status={daily_follow_narration,(SIMPLE_DEMO ? grayscale_synced : effect_synced[0]),
        local_result,local_selection,local_role,local_armed,local_menu,
        local_evacuation,local_fire_confirmed,local_fire_active,local_contact_closed};
    generate if(V5_CONTROLS&&!SIMPLE_DEMO)begin: local_safety
        local_fire_control #(.CLK_HZ(CONTROL_HZ),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) control(
            .clk(pixel_clk),.rst(pixel_rst),.contact_raw(grayscale_switch),
            .previous(zoom_key_short),.next(key1_short),.confirm(key2_short),
            .back(key3_short&&!osd_visible),.confirm_held(key2_held),
            .contact_closed(local_contact_closed),.fire_active(local_fire_active),
            .fire_confirmed(local_fire_confirmed),.evacuation(local_evacuation),
            .menu_visible(local_menu),.armed(local_armed),.role(local_role),
            .selection(local_selection),.result(local_result),
            .action_valid(local_action_valid),.action(local_action),.event_version(local_event_version));
    end else begin: no_local_safety
        assign local_contact_closed=0;assign local_fire_active=0;assign local_fire_confirmed=0;
        assign local_evacuation=0;assign local_menu=0;assign local_armed=0;assign local_role=0;
        assign local_selection=0;assign local_result=0;assign local_action_valid=0;
        assign local_action=0;assign local_event_version=0;
    end endgenerate
    wire [1:0] quality_gamma,quality_temperature;
    wire [3:0] quality_selection;
    wire [2:0] audio_volume;
    wire [1:0] flash_rate,flash_duty;
    wire [2:0] daily_effect;
    wire [1:0] daily_duration;
    wire daily_easing;
    wire [3:0] museum_page,museum_error;
    wire [2:0] museum_selection;
    wire [1:0] museum_period;
    generate if(MUSEUM_UI) begin: museum
        wire previous,next,confirm,back,home,activity,timeout_event,idle_enable;
        reg [3:0] error_snapshot,error_pending,error_frame;
        reg error_request,error_ack;
        reg [1:0] error_request_sync,error_ack_sync;
        reg error_ack_seen;

        always @(posedge sys_clk or posedge sys_rst)
            if(sys_rst) begin error_request_sync<=0;error_ack<=0;error_snapshot<=0;end
            else begin
                error_request_sync<={error_request_sync[0],error_request};
                if(error_request_sync[1]!=error_ack) begin
                    error_snapshot<=loader_error!=0 ? loader_error : memory_error;
                    error_ack<=error_request_sync[1];
                end
            end
        always @(posedge pixel_clk or posedge pixel_rst)
            if(pixel_rst) begin
                error_request<=0;error_ack_sync<=0;error_ack_seen<=0;error_pending<=0;error_frame<=0;
            end
            else begin
                error_ack_sync<={error_ack_sync[0],error_ack};
                if(error_ack_sync[1]!=error_ack_seen) begin
                    error_ack_seen<=error_ack_sync[1];error_pending<=error_snapshot;
                end
                if(frame_tick) begin
                    error_frame<=error_pending!=0 ? error_pending : video_underflow ? 4'd7 : video_overflow ? 4'd8 : 4'd0;
                    if(error_request==error_ack_seen) error_request<=!error_request;
                end
            end
        assign museum_error=error_frame;
        assign museum_activity=activity || zoom_key_held || key1_held || key2_held || key3_held;
        museum_ui_control keys(.clk(pixel_clk),.rst(pixel_rst),
            .short_event({key2_short,key3_short,key1_short,zoom_key_short}),
            .long_event({key2_long,key3_long,key1_long,zoom_key_long}),
            .previous(previous),.next(next),.confirm(confirm),.back(back),.home(home),.activity(activity));
        idle_return_control #(.CLK_HZ(CONTROL_HZ),.TIMEOUT_SECONDS(IDLE_SECONDS)) idle(
            .clk(pixel_clk),.rst(pixel_rst),.enable(idle_enable),.activity(activity),
            .key_held(zoom_key_held || key1_held || key2_held || key3_held),.timeout_event(timeout_event));
        museum_menu_fsm menus(.clk(pixel_clk),.rst(pixel_rst),.frame_tick(frame_tick),
            .resource_ready(ready_sync[1]),.error_code(museum_error),
            .previous(previous),.next(next),.confirm(confirm),.back(back),.home(home),
            .activity(museum_activity),.timeout_event(timeout_event),.video_busy(transition_active),
            .page(museum_page),.selection(museum_selection),.playing(museum_playing),
            .brightness(brightness_level),.contrast(contrast_level),.saturation(saturation_level),
            .zoom(zoom_mode),.mono(grayscale_enable),.period_select(museum_period),
            .previous_event(previous_event),.next_event(manual_next_event),.reload_event(reload_event),.idle_enable(idle_enable));
        assign auto_event=1'b0;
        assign period_event=1'b0;
        assign osd_visible=1'b0;
        assign quality_gamma=1;assign quality_temperature=1;assign quality_selection=0;
        assign daily_effect=0;assign daily_duration=0;assign daily_easing=0;
        assign audio_volume=7;assign flash_rate=1;assign flash_duty=1;
        assign daily_follow_narration=0;
        assign daily_zoom_scale=0;assign daily_pan_x=2;assign daily_pan_y=2;assign daily_auto_contrast=0;
    end else begin: legacy
        daily_control #(.FILMING_EFFECTS(FILMING_PROFILE),.MAX_EFFECT_MODE(FILMING_PROFILE ? 5 : 6),.EXTENDED_MENU(DUAL_TRANSITIONS),.AUDIO_MENU(ENABLE_TF_NARRATION),
            .ALERT_MENU(DUAL_TRANSITIONS),.V5_CONTROLS(V5_CONTROLS),
            .DIRECT_MENU(SIMPLE_DEMO),.DEFAULT_FOLLOW_NARRATION(SIMPLE_DEMO ? 0 : HUMAN_RECORDINGS),.ENABLE_AUTO_CONTRAST(!COMPACT_SCENES),
            .FOLLOW_SWITCH_CONTROL(SIMPLE_DEMO),
            .MAINTENANCE_FRAMES(V5_CONTROLS ? 900 : 179)) daily_keys(
            .clk(pixel_clk),.rst(pixel_rst),.frame_tick(frame_tick),
            .maintenance_enable(overlay_synced&&!panel_switch),.grayscale_switch(grayscale_synced),
            .key1_short(zoom_key_short&&!local_menu&&!panel_switch),
            .key1_long((SIMPLE_DEMO ? key2_long : zoom_key_long)&&!local_menu&&!panel_switch),
            .key2_short(key1_short&&!local_menu&&!panel_switch),
            .key3_short((SIMPLE_DEMO ? key3_short : V5_CONTROLS ? key2_short : key3_short)&&!local_menu&&!panel_switch),
            .key3_long((SIMPLE_DEMO ? key3_long : V5_CONTROLS ? key2_long : key3_long)&&!local_menu&&!panel_switch),
            .key4_long(!SIMPLE_DEMO&&(V5_CONTROLS ? key3_long : key2_long)&&!local_menu),
            .key4_short((SIMPLE_DEMO ? key2_short : key3_short)&&!panel_switch),
            .night_switch(SIMPLE_DEMO ? 1'b0 : effect_synced[0]),
            .follow_switch(grayscale_synced),
            .period_select(period_select),.follow_narration(daily_follow_narration),
            .zoom_scale(daily_zoom_scale),.pan_x_level(daily_pan_x),.pan_y_level(daily_pan_y),
            .auto_contrast_enable(daily_auto_contrast),
            .previous_event(previous_event),.next_event(manual_next_event),
            .auto_event(auto_event),.period_event(period_event),.reload_event(reload_event),
            .zoom_mode(zoom_mode),.grayscale_enable(grayscale_enable),
            .osd_visible(osd_visible),.brightness_level(brightness_level),
            .contrast_level(contrast_level),.saturation_level(saturation_level),
            .gamma_mode(quality_gamma),.temperature_mode(quality_temperature),
            .effect_mode(daily_effect),.effect_duration(daily_duration),.effect_easing(daily_easing),
            .maintenance_selection(quality_selection),.volume_level(audio_volume),
            .flash_rate(flash_rate),.flash_duty(flash_duty));
        assign museum_playing=1'b0;
        assign museum_activity=1'b0;
        assign museum_page=0;assign museum_error=0;assign museum_selection=0;assign museum_period=2;
    end endgenerate

    reg reload_toggle;
    reg [2:0] reload_sync;
    always @(posedge pixel_clk or posedge pixel_rst)
        if (pixel_rst) reload_toggle<=0;
        else if (reload_event) reload_toggle<=!reload_toggle;
    always @(posedge sys_clk or posedge sys_rst)
        if (sys_rst) reload_sync<=0;
        else reload_sync<={reload_sync[1:0],reload_toggle};
    wire reload_sys_pulse=reload_sync[2]^reload_sync[1];
    wire media_data_rst=sys_rst|reload_sys_pulse;
    wire [15:0] resident;
    wire [15:0] failed_images;
    wire [3:0] desired_image,command_image;
    wire [1:0] display_slot,lookup_slot;
    wire [1:0] second_lookup_slot;
    wire [1:0] command_slot;
    wire [7:0] command_view;
    wire viewport_pending;
    wire [7:0] requested_view=ORIGINAL_DETAIL && !panel_mode && daily_zoom_scale!=0 ?
        {daily_zoom_scale,daily_pan_x,daily_pan_y} : 8'd0;
    wire command_toggle,slot_ready,loader_busy,store_idle,store_ready;
    reg [1:0] command_sync,failed_sync,memory_failed_sync;
    reg complete_toggle;
    reg load_result_failed;
    reg [1:0] load_state;
    wire load_request=FOUR_SLOT_CACHE && load_state==1;
    always @(posedge sys_clk or posedge media_data_rst)begin
        if(media_data_rst)begin command_sync<=0;complete_toggle<=0;load_state<=0;load_result_failed<=0;end
        else begin
            command_sync<={command_sync[0],command_toggle};
            case(load_state)
                0:if(command_sync[1]!=complete_toggle)load_state<=1;
                1:if(loader_busy)load_state<=2;
                2:if(store_idle && !loader_busy && (load_done || loader_error!=0))begin
                    load_result_failed<=loader_error!=0 || memory_error!=0;
                    complete_toggle<=command_sync[1];load_state<=0;
                end
            endcase
        end
    end
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst)begin failed_sync<=0;memory_failed_sync<=0;end
        else begin
            failed_sync<={failed_sync[0],load_result_failed};
            memory_failed_sync<={memory_failed_sync[0],memory_error!=0};
        end
    image_cache_control #(.FORWARD_PREFETCH(FILMING_PROFILE),.IMAGE_COUNT(LOGICAL_IMAGES),.TRANSITION_PIN(DUAL_TRANSITIONS),.FAULT_CONTROL(1),
        .VIEWPORT_CACHE(ORIGINAL_DETAIL),.FAST_PREVIEW(ORIGINAL_DETAIL)) slots(
        .clk(pixel_clk),.rst(pixel_rst|reload_event),.frame_tick(frame_tick),
        .sequential_mode(autoplay&&!panel_mode),.current_image(image_index),.requested_image(desired_image),
        .lookup_image(line_image),.lookup_slot(lookup_slot),
        .second_lookup_image(line_second_image),.second_lookup_slot(second_lookup_slot),
        .pin_valid(slide_active),.pin_image(transition_target),
        .complete_toggle(complete_toggle),.load_failed(failed_sync[1]),
        .storage_fault(memory_failed_sync[1]),.failed_images(failed_images),
        .command_toggle(command_toggle),.command_image(command_image),.command_slot(command_slot),
        .requested_view(requested_view),.command_view(command_view),
        .ready(slot_ready),.resident(resident),.display_slot(display_slot),.view_pending(viewport_pending));
    assign cache_ready=FOUR_SLOT_CACHE ? slot_ready : store_ready;
    wire [4:0] loaded_count;
    assign image_count=FOUR_SLOT_CACHE ? (slot_ready ? LOGICAL_IMAGES : 0) : loaded_count;
    wire file_route_write,file_route_commit,file_route_crc_ok;
    wire file_route_checked,file_route_assets_match,file_route_config_valid;
    wire file_route_ready;
    wire [7:0] file_route_key;
    wire [31:0] file_route_segments,file_route_directions,file_route_crc32;
    wire [2:0] file_route_exit;wire [1:0] file_route_status;
    wire [15:0] file_route_version;wire [3:0] file_route_config_error;
    wire tf_audio_open_req,tf_audio_file_busy,tf_audio_open_done;
    wire tf_audio_abort;
    wire tf_audio_not_found,tf_audio_file_valid,tf_audio_file_ready;
    wire tf_audio_file_end;wire [3:0] tf_audio_file_index;
    wire [4:0] tf_audio_wav_count;wire [31:0] tf_audio_file_size;
    wire [7:0] tf_audio_file_data;
    wire [3:0] tf_audio_read_error;
    wire tf_audio_read_progress;
    wire audio_mem_valid,audio_mem_write,audio_mem_ready,audio_mem_done;
    wire [20:0] audio_mem_addr;
    wire [31:0] audio_mem_wdata,audio_mem_rdata;
    wire audio_ring_fault;
    reg [1:0] audio_ring_fault_sync;
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst)audio_ring_fault_sync<=0;
        else audio_ring_fault_sync<={audio_ring_fault_sync[0],audio_ring_fault};

    reg [2:0] broadcast_effect;
    always @* case(image_index)
        0,7,14:broadcast_effect=0;
        1,8,15:broadcast_effect=1;
        2,9:broadcast_effect=2;
        3,10:broadcast_effect=3;
        4,11:broadcast_effect=4;
        5,12:broadcast_effect=5;
        default:broadcast_effect=6;
    endcase
    wire [2:0] filming_broadcast_effect=image_index[1:0]==3 ? 3'd5 : {1'b0,image_index[1:0]};
    wire [2:0] selected_transition_effect=broadcast_mode ? (FILMING_PROFILE ? filming_broadcast_effect : broadcast_effect) : DUAL_TRANSITIONS ? daily_effect : effect_synced==2'b11 ?
        3'd3+{1'b0,image_index[1:0]} : {1'b0,effect_synced};
    wire narration_follow_mode=narration_enable&&(V5_CONTROLS ? daily_follow_narration :
        overlay_synced&&grayscale_synced&&effect_synced==2'b01);
    assign broadcast_mode=SIMPLE_DEMO&&HUMAN_RECORDINGS&&narration_follow_mode;
    reg broadcast_mode_q;
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst)broadcast_mode_q<=0;
        else broadcast_mode_q<=broadcast_mode;
    wire [3:0] broadcast_next_image=image_index==LOGICAL_IMAGES-1 ? 4'd0 : image_index+1'b1;
    wire broadcast_prefetched=!FOUR_SLOT_CACHE||resident[broadcast_next_image]||failed_images[broadcast_next_image];

    assign daily_transport_hold=SIMPLE_DEMO&&(!broadcast_mode||panel_audio_hold||alarm_cancel_notice||
        (panel_mode&&panel_selection!=image_index)||
        transition_active||(!panel_mode&&daily_zoom_scale!=0)||broadcast_mode!=broadcast_mode_q||
        (broadcast_mode&&!panel_mode&&(!autoplay||!broadcast_prefetched)));
    assign daily_stop_needed=(daily_transport_hold&&!alarm_active&&!media_voice_asset)||panel_audio_hold;
    wire human_daily_next;

    player_control #(.PERIOD_COUNT(FILMING_PROFILE ? 3 : 4),.MANUAL_TARGET(SIMPLE_DEMO),.CLK_HZ(CONTROL_HZ),.FADE_STEPS(FADE_STEPS),.EXTERNAL_CONTROL(MUSEUM_UI),
        .USE_CACHE(FOUR_SLOT_CACHE),.SKIP_FAILED(FOUR_SLOT_CACHE),.IMAGE_COUNT(LOGICAL_IMAGES),.DUAL_SOURCE(DUAL_TRANSITIONS),
        .EASING_CONTROL(DUAL_TRANSITIONS),.PIPELINED_PHASE(DUAL_TRANSITIONS),
        .NAVIGATION_HOLD(ORIGINAL_DETAIL),
        .START_AUTOPLAY(1),.DEFAULT_PERIOD(0),
        .PERIOD_0(FILMING_PROFILE ? 2 : 1),.PERIOD_1(FILMING_PROFILE ? 5 : 2),
        .PERIOD_2(FILMING_PROFILE ? 10 : 5),.PERIOD_3(10)) controls(
        .clk(pixel_clk),.rst(pixel_rst),.ready(ready_sync[1]),.frame_tick(frame_tick),
        .target_enable(panel_mode&&panel_selection<16),.target_index(panel_selection[3:0]),
        .next_event(manual_next_event||narration_next_event||human_daily_next),.auto_event(auto_event),.period_event(period_event),
        .effect_select(selected_transition_effect),
        .external_play(museum_playing),.previous_event(previous_event),
        .external_activity(museum_activity),.external_period(museum_period),
        .follow_narration(narration_follow_mode||panel_switch),
        .transition_duration(broadcast_mode ? 2'd1 : DUAL_TRANSITIONS ? daily_duration : period_select),
        .transition_easing(broadcast_mode ? 1'b1 : daily_easing),.transition_phase(transition_phase),
        .resident(resident),.failed_images(failed_images),.emergency_abort(alarm_active),.desired_image(desired_image),
        .navigation_hold(!panel_mode&&daily_zoom_scale!=0),
        .image_index(image_index),.autoplay(autoplay),.period_select(period_select),.period_seconds(period_seconds),
        .video_gain(video_gain),.transition_mode(transition_mode),.transition_target(transition_target),
        .slide_progress(slide_progress),.slide_active(slide_active),.transition_active(transition_active));
    bmp_preloader #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.SCAN_FIRST(SCAN_FIRST),.SCAN_LIMIT(SCAN_LIMIT),
        .ON_DEMAND(FOUR_SLOT_CACHE),.IMAGE_COUNT(LOGICAL_IMAGES),
        .ENABLE_AUDIO_STREAM(ENABLE_TF_NARRATION),.ENABLE_AUDIO_ABORT(SIMPLE_DEMO),.STRICT_CHAIN(STRICT_CHAIN),
        .ENABLE_ROUTE_CONFIG(!BOARD_ROUTE_AUTHORITY),
        .ENABLE_VIEWPORT(ORIGINAL_DETAIL),.FIXED_PLAYLIST(V5_CONTROLS && ENABLE_TF_NARRATION),
        .FIXED_WAV_FILES(HUMAN_RECORDINGS ? (ROUTE_GUIDANCE ? 16 : 15) : 12)) loader(
        .clk(sys_clk),.rst(media_data_rst),.start_ready(mem_init),.sd_ready(sd_ready),
        .load_request(load_request),.load_image(command_image),.load_slot(command_slot),.busy(loader_busy),
        .load_view(command_view),
        .sector_req(sector_req),.sector_lba(sector_lba),.sector_data(sector_data),
        .sector_valid(sector_valid),.sector_end(sector_end),
        .pixel_valid(load_valid),.pixel_ready(load_ready),.pixel_addr(load_addr),.pixel_rgb(load_rgb),
        .done(load_done),.image_count(loaded_count),.error_code(loader_error),
        .route_cfg_ready(file_route_ready),
        .route_cfg_write(file_route_write),.route_cfg_key(file_route_key),
        .route_cfg_segments(file_route_segments),
        .route_cfg_directions(file_route_directions),
        .route_cfg_exit(file_route_exit),.route_cfg_status(file_route_status),
        .route_cfg_commit(file_route_commit),.route_cfg_crc_ok(file_route_crc_ok),
        .route_cfg_checked(file_route_checked),
        .route_cfg_assets_match(file_route_assets_match),
        .route_cfg_version(file_route_version),.route_cfg_crc32(file_route_crc32),
        .route_config_valid(file_route_config_valid),
        .route_config_error(file_route_config_error),
        .audio_open_req(tf_audio_open_req),.audio_file_index(tf_audio_file_index),.audio_abort(tf_audio_abort),
        .audio_busy(tf_audio_file_busy),.audio_open_done(tf_audio_open_done),
        .audio_not_found(tf_audio_not_found),.audio_file_size(tf_audio_file_size),
        .audio_file_data(tf_audio_file_data),.audio_file_valid(tf_audio_file_valid),
        .audio_file_ready(tf_audio_file_ready),.audio_file_end(tf_audio_file_end),
        .audio_wav_count(tf_audio_wav_count),.audio_read_error(tf_audio_read_error),
        .audio_read_progress(tf_audio_read_progress),.playlist_valid(playlist_valid_sys));
    frame_store #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BURST(BURST),.DRAIN_CYCLES(DRAIN_CYCLES),
        .STREAMING(FOUR_SLOT_CACHE),.DUAL_SOURCE(DUAL_TRANSITIONS),
        .ENABLE_AUX(ENABLE_TF_NARRATION)) cache(
        .clk(sys_clk),.rst(media_data_rst),.pixel_clk(pixel_clk),.mem_init(mem_init),.mem_busy(mem_busy),
        .load_done(load_done),.pixel_valid(load_valid),.pixel_ready(load_ready),.pixel_addr(load_addr),.pixel_rgb(load_rgb),
        .reads_enabled(cache_ready),
        .cache_ready(store_ready),.write_idle(store_idle),.error_code(memory_error),
        .line_req_toggle(line_req),.line_image(FOUR_SLOT_CACHE ? {2'd0,lookup_slot} : line_image),
        .line_row(line_row),.line_bank(line_bank),.line_ack_toggle(line_ack),
        .line_second_image(FOUR_SLOT_CACHE ? {2'd0,second_lookup_slot} : line_second_image),.line_split(line_split),
        .line_dual(line_dual),.second_ram_addr(second_ram_addr),.second_ram_q(second_ram_q),
        .line_horizontal_slide(line_horizontal_slide),.line_zoom(line_zoom),
        .line_ram_addr(ram_addr),.line_ram_q(ram_q),
        .wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),.rd_en(rd_en),.rd_addr(rd_addr),.rd_valid(rd_valid),.rd_data(rd_data),
        .aux_valid(audio_mem_valid),.aux_write(audio_mem_write),.aux_addr(audio_mem_addr),
        .aux_wdata(audio_mem_wdata),.aux_ready(audio_mem_ready),
        .aux_done(audio_mem_done),.aux_rdata(audio_mem_rdata));
    wire [15:0] daily_audio_left,daily_audio_right;
    wire [19:0] daily_acr_n,daily_acr_cts;
    pcm_audio audio(.clk(pixel_clk),.rst(pixel_rst),.enable(ready_sync[1] && (!MUSEUM_UI || museum_playing)),
        .test_mode(V5_CONTROLS ? osd_visible : overlay_synced),.image_index(image_index),
        .sample_valid(daily_audio_valid),.sample_left(daily_audio_left),.sample_right(daily_audio_right),
        .acr_valid(daily_acr_valid),.acr_n(daily_acr_n),.acr_cts(daily_acr_cts));
    wire test_native_valid,test_underflow,test_overflow;
    wire signed [15:0] test_native_sample,test_hdmi_sample;
    generate if(SIMPLE_DEMO)begin: native_test_audio
    if(DUAL_EXTENSIONS)begin: page_tones
    page_test_tone_48k diagnostic_tone(.clk(pixel_clk),.rst(pixel_rst),.enable(diagnostic_test_active),
        .page(panel_selection),.output_tick(daily_audio_valid),.native_valid(test_native_valid),
        .native_sample(test_native_sample),.output_sample(test_hdmi_sample));
    end else begin: single_tone
    test_tone_48k diagnostic_tone(
        .clk(pixel_clk),.rst(pixel_rst),.enable(diagnostic_test_active),
        .output_tick(daily_audio_valid),.native_valid(test_native_valid),
        .native_sample(test_native_sample),.output_sample(test_hdmi_sample));
    end
    assign test_underflow=0;assign test_overflow=0;
    end else begin: legacy_test_audio
    test_tone_40k #(.CLK_HZ(CONTROL_HZ)) diagnostic_tone(
        .clk(pixel_clk),.rst(pixel_rst),.enable(diagnostic_test_active),
        .output_tick(daily_audio_valid),.native_valid(test_native_valid),
        .native_sample(test_native_sample),.output_sample(test_hdmi_sample),
        .underflow(test_underflow),.overflow(test_overflow));
    end endgenerate
    wire [31:0] narration_sentence_start;
    reg [31:0] narration_resume_sample,saved_sentence_sample;
    reg [3:0] saved_narration_image;
    reg saved_sentence_valid,resume_alarm_q;
    wire signed [15:0] tf_stream_sample;
    generate if(ENABLE_TF_NARRATION) begin: tf_narration_stream
        reg [2:0] request_sync,begin_sync,complete_sync;
        reg [1:0] allowed_sync;
        reg [1:0] loop_sync;
        wire request_pulse=request_sync[2]^request_sync[1];
        wire begin_pulse=begin_sync[2]^begin_sync[1];
        wire complete_pulse=complete_sync[2]^complete_sync[1];
        wire stream_sample_valid;wire signed [15:0] stream_sample;
        wire fifo_write_ready,fifo_flush,fifo_overflow;
        wire ring_ready,ring_valid,stream_end;
        wire [15:0] ring_sample;
        wire [16:0] ring_buffered_samples;
        wire fifo_read_valid;wire signed [15:0] fifo_read_sample;
        wire begin_toggle,complete_toggle;
        wire [3:0] stream_error;
        reg [1:0] error_sync;
        always @(posedge pixel_clk or posedge pixel_rst)
            if(pixel_rst)error_sync<=0;
            else error_sync<={error_sync[0],stream_error!=0};
        assign tf_stream_failed=error_sync[1];
        always @(posedge sys_clk or posedge media_data_rst)
            if(media_data_rst)begin request_sync<=0;allowed_sync<=0;loop_sync<=0;end
            else begin
                request_sync<={request_sync[1:0],narration_request_toggle};
                allowed_sync<={allowed_sync[0],SINGLE_CARD_AUDIO ? audio_play_permitted : narration_external_allowed};
                loop_sync<={loop_sync[0],SINGLE_CARD_AUDIO ? narration_request_loop :
                    (alarm_active&&media_alarm_asset&&!media_voice_asset)};
            end
        always @(posedge pixel_clk or posedge pixel_rst)
            if(pixel_rst)begin begin_sync<=0;complete_sync<=0;end
            else begin
                begin_sync<={begin_sync[1:0],begin_toggle};
                complete_sync<={complete_sync[1:0],complete_toggle};
            end
        narration_wav_streamer #(.ENABLE_FILE_ERROR(1),.ENABLE_RESUME(!SIMPLE_DEMO||ROUTE_GUIDANCE),.ENABLE_WINDOW(ROUTE_GUIDANCE),.ENABLE_STOP(SIMPLE_DEMO),.ENABLE_IO_PROGRESS(1),.ENABLE_IMA(ENABLE_TF_IMA),.CANONICAL_PCM(CANONICAL_PCM),.DIRECT_PLAY(SINGLE_CARD_AUDIO)) streamer(.clk(sys_clk),.rst(media_data_rst),
            .requested_sample_limit(ROUTE_GUIDANCE&&narration_request_image==15 ? 32'd240000 : 32'd0),
            .play_request(request_pulse&&!narration_request_stop),
            .stop_request(request_pulse&&narration_request_stop),.file_abort(tf_audio_abort),
            .requested_index(narration_request_image),
            .requested_start_sample(narration_resume_sample),
            .loop_enable(loop_sync[1]),
            .file_error(tf_audio_read_error),
            .file_io_progress(tf_audio_read_progress),
            .external_allowed(allowed_sync[1]),.file_open_req(tf_audio_open_req),
            .file_index(tf_audio_file_index),.file_busy(tf_audio_file_busy),
            .file_open_done(tf_audio_open_done),.file_not_found(tf_audio_not_found),
            .file_size(tf_audio_file_size),.file_data(tf_audio_file_data),
            .file_valid(tf_audio_file_valid),.file_ready(tf_audio_file_ready),
            .file_end(tf_audio_file_end),.asset_begin_toggle(begin_toggle),
            .asset_complete_toggle(complete_toggle),.asset_purpose(tf_asset_purpose),
            .asset_length(tf_asset_length),.asset_crc32(tf_asset_crc32),
            .asset_samples(tf_asset_samples),
            .sample_valid(stream_sample_valid),.sample(stream_sample),
            .sample_ready(loop_sync[1] ? fifo_write_ready : ring_ready),.fifo_flush(fifo_flush),
            .error_code(stream_error),.stream_end(stream_end),.debug_state());
        sdram_audio_ring ring(.clk(sys_clk),.rst(media_data_rst),.flush(fifo_flush),
            .sample_valid(stream_sample_valid&&!loop_sync[1]),.sample(stream_sample),
            .sample_ready(ring_ready),.stream_end(stream_end&&!loop_sync[1]),
            .output_valid(ring_valid),.output_sample(ring_sample),
            .output_ready(fifo_write_ready&&!loop_sync[1]),
            .mem_valid(audio_mem_valid),.mem_write(audio_mem_write),
            .mem_addr(audio_mem_addr),.mem_wdata(audio_mem_wdata),
            .mem_ready(audio_mem_ready),.mem_done(audio_mem_done),.mem_rdata(audio_mem_rdata),
            .mem_error(memory_error!=0),.buffered_samples(ring_buffered_samples),.fault(audio_ring_fault));
        audio_sample_fifo sample_fifo(.wr_clk(sys_clk),.wr_rst(media_data_rst),
            .wr_flush(fifo_flush),.wr_valid(loop_sync[1] ? stream_sample_valid : ring_valid&&fifo_write_ready),
            .wr_data(loop_sync[1] ? stream_sample : ring_sample),.wr_ready(fifo_write_ready),
            .wr_overflow(fifo_overflow),.rd_clk(pixel_clk),.rd_rst(pixel_rst|reload_event),
            .rd_ready(!panel_audio_hold&&!diagnostic_test_active&&daily_audio_valid&&narration_external_allowed&&
                ((alarm_active||media_voice_asset) ? (tf_asset_purpose==8'h21+audio_certificate_index) :
                 (narration_playing&&!daily_transport_hold&&!(narration_follow_mode&&!autoplay&&!panel_mode)))),
            .rd_valid(fifo_read_valid),.rd_data(fifo_read_sample));
        assign tf_asset_begin=begin_pulse;
        assign tf_asset_complete=complete_pulse;
        assign tf_stream_sample_valid=fifo_read_valid;
        assign tf_stream_sample=fifo_read_sample;
    end else begin: no_tf_narration_stream
        assign tf_stream_failed=0;
        assign tf_audio_abort=0;
        assign tf_audio_open_req=1'b0;assign tf_audio_file_index=4'd0;
        assign tf_audio_file_ready=1'b0;
        assign tf_asset_begin=1'b0;assign tf_asset_complete=1'b0;
        assign tf_asset_purpose=8'd0;assign tf_asset_length=32'd0;
        assign tf_asset_samples=32'd0;
        assign tf_asset_crc32=32'd0;assign tf_stream_sample_valid=1'b0;
        assign tf_stream_sample=16'sd0;
        assign audio_mem_valid=0;assign audio_mem_write=0;assign audio_mem_addr=0;
        assign audio_mem_wdata=0;assign audio_ring_fault=0;
    end endgenerate
    wire narration_done;
    reg narration_consumed,alarm_sample_tag;
    generate if(HUMAN_RECORDINGS)begin: daily_follow
        human_daily_follow #(.CLK_HZ(CONTROL_HZ),.DWELL_SECONDS(SIMPLE_DEMO ? 1 : 3)) follow(
            .clk(pixel_clk),.rst(pixel_rst),.enabled(narration_follow_mode&&!panel_switch),
            .ready(ready_sync[1]),.autoplay(autoplay),
            .blocked(alarm_active||alarm_cancel_notice||transition_active||daily_zoom_scale!=0||diagnostic_test_active||daily_transport_hold),
            .restart(media_audio_request||manual_next_event||previous_event||reload_event),
            .consumed(audio_valid&&narration_consumed),.done(narration_done),
            .next_event(human_daily_next));
    end else begin: timed_daily
        assign human_daily_next=0;
    end endgenerate
    wire narration_prompt_valid;
    wire [47:0] narration_elapsed_samples;
    wire [3:0] narration_active_image;
    wire daily_subtitle_active=HUMAN_RECORDINGS&&SIMPLE_DEMO&&broadcast_mode&&
        narration_playing&&!daily_transport_hold&&!alarm_active&&!alarm_cancel_notice&&
        !media_voice_asset&&!media_alarm_asset&&!diagnostic_test_active&&
        narration_external_allowed&&audio_certificate_index<8&&
        narration_active_image==image_index&&!selected_asset_begin&&!media_audio_request;
    wire [1:0] narration_seed_cue=narration_seed_index[1:0];
    wire [7:0] narration_seed_address={narration_seed_index[5:2],2'b00,
        narration_seed_index[1:0]};
    reg [31:0] narration_seed_sample;
    always @* begin
        case(narration_seed_cue)
            0:narration_seed_sample=32'd240000;
            1:narration_seed_sample=32'd480000;
            2:narration_seed_sample=32'd720000;
            default:narration_seed_sample=32'd960000;
        endcase
    end
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst)begin narration_consumed<=0;alarm_sample_tag<=0;end
        else if(daily_audio_valid)begin
            narration_consumed<=narration_prompt_valid;
            alarm_sample_tag<=alarm_active;
        end
    narration_timeline #(.USE_ASSET_LENGTH(ENABLE_TF_NARRATION),.ENABLE_RESUME(!SIMPLE_DEMO)) narration(.clk(pixel_clk),.rst(pixel_rst),
        .sample_tick(ENABLE_TF_NARRATION ? audio_valid&&narration_consumed : daily_audio_valid),
        .start(narration_start),.stop(alarm_active||selected_asset_begin||daily_stop_needed),
        .pause(!ENABLE_TF_NARRATION&&narration_follow_mode&&!autoplay),
        .asset_samples(tf_asset_samples),
        .start_sample(narration_resume_sample),.sentence_start_sample(narration_sentence_start),
        .image_id(image_index),.cfg_we(narration_seed_active||narration_cfg_we),
        .cfg_index(narration_seed_active ? narration_seed_address : narration_cfg_index),
        .cfg_sample(narration_seed_active ? (V5_CONTROLS ? playlist_cue_sample : narration_seed_sample) : narration_cfg_sample),
        .cfg_subtitle(narration_seed_active ? (V5_CONTROLS ? playlist_cue_subtitle : {6'd0,narration_seed_cue}+1'b1) :
            narration_cfg_subtitle),
        .cfg_last(narration_seed_active ? (V5_CONTROLS ? playlist_cue_last : narration_seed_cue==3) : narration_cfg_last),
        .playing(narration_playing),
        .elapsed_samples(narration_elapsed_samples),.subtitle_id(timeline_subtitle),
        .active_image(narration_active_image),.narration_done(narration_done));
    always @(posedge pixel_clk or posedge pixel_rst) begin
        if(pixel_rst) begin
            narration_image_q<=LOGICAL_IMAGES-1;narration_start<=0;narration_next_event<=0;
            narration_hold_count<=0;narration_seed_active<=1;narration_seed_index<=0;
            narration_request_toggle<=0;narration_request_image<=0;narration_request_loop<=0;narration_request_stop<=0;
            narration_waiting_for_audio<=0;narration_verified<=0;
            narration_resume_sample<=0;saved_sentence_sample<=0;saved_narration_image<=0;
            saved_sentence_valid<=0;resume_alarm_q<=0;
        end else begin
            narration_start<=0;narration_next_event<=0;
            resume_alarm_q<=alarm_active;
            if(!SIMPLE_DEMO&&alarm_active&&!resume_alarm_q&&narration_playing)begin
                saved_sentence_sample<=narration_sentence_start;
                saved_narration_image<=narration_active_image;saved_sentence_valid<=1;
            end
            if(reload_event)saved_sentence_valid<=0;
            if(narration_seed_active) begin
                if(narration_seed_index==63) narration_seed_active<=0;
                else narration_seed_index<=narration_seed_index+1'b1;
            end
            if(daily_stop_needed)begin
                narration_waiting_for_audio<=0;narration_verified<=0;
                if(!narration_request_stop)begin
                    narration_request_stop<=1;narration_request_loop<=0;
                    narration_request_toggle<=!narration_request_toggle;
                end
            end else if(media_audio_request) begin
                narration_request_stop<=0;
                narration_image_q<=image_index;narration_hold_count<=0;
                narration_resume_sample<=ROUTE_GUIDANCE&&audio_certificate_index==15 ? route_voice_start :
                    !SIMPLE_DEMO&&!media_alarm_asset&&!media_voice_asset&&saved_sentence_valid&&
                    saved_narration_image==image_index ? saved_sentence_sample : 32'd0;
                if(!media_alarm_asset&&!media_voice_asset)saved_sentence_valid<=0;
                if(ENABLE_TF_NARRATION)begin
                    narration_request_loop<=alarm_active&&media_alarm_asset&&!media_voice_asset;
                    narration_request_image<=audio_certificate_index;
                    narration_request_toggle<=!narration_request_toggle;
                    narration_waiting_for_audio<=!media_alarm_asset&&!media_voice_asset;narration_verified<=0;
                end else if(!media_alarm_asset&&!media_voice_asset)narration_start<=1;
            end
            if(!daily_stop_needed&&ENABLE_TF_NARRATION&&narration_waiting_for_audio&&tf_asset_complete)
                narration_verified<=1;
            if(!daily_stop_needed&&ENABLE_TF_NARRATION&&narration_waiting_for_audio&&
                    narration_verified&&tf_stream_sample_valid)begin
                narration_start<=1;narration_waiting_for_audio<=0;
            end
            if(alarm_active)begin
                narration_waiting_for_audio<=0;narration_verified<=0;
            end
            if(!HUMAN_RECORDINGS && narration_done && narration_follow_mode && autoplay)
                narration_hold_count<=CONTROL_HZ*3;
            else if(!narration_follow_mode || !autoplay || alarm_active)
                narration_hold_count<=0;
            else if(narration_hold_count!=0) begin
                narration_hold_count<=narration_hold_count-1'b1;
                if(narration_hold_count==1) narration_next_event<=1;
            end
        end
    end
    wire alarm_display_active;

    wire [25:0] alarm_identity;
    wire [47:0] emergency_sample_count;

    wire local_demo_alarm=!V5_CONTROLS&&(effect_synced==2'b11)&&overlay_synced;
    emergency_control_core #(.CLK_HZ(CONTROL_HZ),.CONFIGURABLE_FLASH(1),
        .REMOTE_EVENTS(BOARD_EVENT_AUTHORITY),.LOCAL_FIRE(V5_CONTROLS)) emergency(
        .clk(pixel_clk),.rst(pixel_rst),.frame_tick(frame_tick),
        .first_active_pixel(axis_valid&&axis_user&&alarm_display_active),
        .audio_sample_tick(audio_valid&&alarm_sample_tag&&audio_left!=0),
        .demo_alarm(local_demo_alarm),.flash_rate(flash_rate),.flash_duty(flash_duty),
        .local_fire_active(local_fire_active),.local_fire_confirmed(local_fire_confirmed),
        .local_fire_evacuation(local_evacuation),.local_fire_visible(local_fire_visible),
        .alarm_evacuation(raw_alarm_evacuation),
        .alarm_identity(alarm_identity),
        .command_valid(emergency_cmd_valid),
        .command_opcode(emergency_cmd_opcode),.command_source(emergency_cmd_source),
        .command_kind(emergency_cmd_kind),.command_event_id(emergency_cmd_event_id),
        .command_sequence(emergency_cmd_sequence),.command_level(emergency_cmd_level),
        .command_drill(emergency_cmd_drill),.command_pending(emergency_cmd_pending),
        .command_region(emergency_cmd_region),.command_time_trusted(emergency_cmd_time_trusted),
        .command_remaining_seconds(emergency_cmd_remaining_seconds),
        .command_snapshot(emergency_cmd_snapshot),.command_epoch_changed(emergency_cmd_epoch_changed),
        .sync_blocked_valid(sync_blocked_valid),.sync_blocked_set(sync_blocked_set),
        .command_result_valid(emergency_result_valid),.command_result_code(emergency_result_code),
        .command_ready(emergency_cmd_ready),
        .alarm_active(raw_alarm_active),.alarm_level(raw_alarm_level),.alarm_kind(raw_alarm_kind),.alarm_drill(raw_alarm_drill),
        .alarm_pending(raw_alarm_pending),
        .countdown_trusted(raw_alarm_countdown_trusted),.countdown_seconds(raw_alarm_countdown_seconds),
        .cancel_notice(raw_alarm_cancel_notice),.flash_on(raw_alarm_flash_on),.buzzer_on(alarm_buzzer),
        .blocked_set(alarm_blocked_set),.active_count(raw_alarm_active_count),
        .latency_valid(alarm_latency_valid),
        .pixel_latency_us(alarm_pixel_latency_us),.audio_latency_us(alarm_audio_latency_us),
        .finish_valid(event_finish_valid),.finish_reason(event_finish_reason),
        .sample_count(emergency_sample_count));
    wire l0_cfg_we,l0_enqueue,l0_enqueue_urgent,l0_enqueue_ready;
    wire [5:0] l0_cfg_segment,l0_enqueue_segment,l0_active_segment;
    wire [15:0] l0_cfg_start,l0_cfg_length,l0_rom_address;
    wire [3:0] l0_rom_nibble;
    wire l0_voice_valid,l0_voice_playing,l0_queue_overflow,l0_active_audio,l0_cancel_queue,l0_decode_underflow;
    wire signed [15:0] l0_voice_sample;
    generate if(ENABLE_L0_VOICE)begin: local_voice
    l0_voice_scheduler #(.ENABLE_CONTEXT(V5_CONTROLS)) l0_scheduler(.clk(pixel_clk),.rst(pixel_rst),
        .alarm_active(alarm_active),.alarm_drill(alarm_drill),
        .cancel_notice(alarm_cancel_notice),.alarm_level(alarm_level),
        .countdown_trusted(alarm_countdown_trusted),
        .countdown_seconds(alarm_countdown_seconds),.enqueue_ready(l0_enqueue_ready),
        .alarm_kind(alarm_kind),.alarm_pending(alarm_pending),.alarm_evacuation(alarm_evacuation),
        .event_identity(local_fire_visible ? {10'h3ff,local_event_version} : alarm_identity),
        .cancel_queue(l0_cancel_queue),
        .cfg_we(l0_cfg_we),.cfg_segment(l0_cfg_segment),.cfg_start(l0_cfg_start),
        .cfg_length(l0_cfg_length),.enqueue_valid(l0_enqueue),
        .enqueue_segment(l0_enqueue_segment),.enqueue_urgent(l0_enqueue_urgent));
    l0_voice_rom l0_rom(.clk(pixel_clk),.address(l0_rom_address),
        .nibble(l0_rom_nibble));
    voice_segment_player #(.ENABLE_CANCEL(1),.FADE_SAMPLES(V5_CONTROLS ? 256 : 0)) l0_player(.clk(pixel_clk),.rst(pixel_rst),
        .sample_tick(daily_audio_valid),.enqueue_valid(l0_enqueue),
        .enqueue_segment(l0_enqueue_segment),.enqueue_urgent(l0_enqueue_urgent),
        .enqueue_ready(l0_enqueue_ready),.cfg_we(l0_cfg_we),
        .cancel_queue(l0_cancel_queue),.active_audio(l0_active_audio),.decode_underflow(l0_decode_underflow),
        .cfg_segment(l0_cfg_segment),.cfg_start(l0_cfg_start),
        .cfg_length(l0_cfg_length),.rom_address(l0_rom_address),
        .rom_nibble(l0_rom_nibble),.voice_valid(l0_voice_valid),
        .voice_sample(l0_voice_sample),.playing(l0_voice_playing),
        .active_segment(l0_active_segment),.queue_overflow(l0_queue_overflow));
    end else begin: tone_only_fallback
        assign l0_active_audio=0;
        assign l0_voice_sample=0;
        assign l0_decode_underflow=0;
    end endgenerate
    wire signed [15:0] emergency_mixed_audio;
    wire signed [17:0] unlimited_audio;
    wire mixed_valid,output_overrun;
    wire certificate_pass=narration_certificate[72];
    wire [3:0] certificate_reason=narration_certificate[76:73];
    wire narration_underflow,alarm_audio_overrun;
    wire external_alarm_selected=ENABLE_TF_NARRATION && alarm_active && !panel_synth && !panel_audio_hold &&
        media_alarm_asset && !media_voice_asset && narration_external_allowed &&
        tf_asset_purpose==8'h21+audio_certificate_index;
    assign audio_underflow=narration_underflow|alarm_audio_overrun|output_overrun|audio_ring_fault_sync[1]|l0_decode_underflow|
        (daily_audio_valid&&human_voice_started&&media_voice_asset&&narration_external_allowed&&
         tf_asset_purpose==8'h21+audio_certificate_index&&!tf_stream_sample_valid)|
        (daily_audio_valid&&external_alarm_selected&&!tf_stream_sample_valid);
    assign selected_asset_begin=ENABLE_TF_NARRATION ?
        (tf_asset_begin|reload_event|audio_ring_fault_sync[1]) : narration_asset_begin;
    wire selected_asset_complete=ENABLE_TF_NARRATION ?
        tf_asset_complete : narration_asset_complete;
    wire [7:0] selected_asset_purpose=ENABLE_TF_NARRATION ?
        tf_asset_purpose : narration_asset_purpose;
    wire [31:0] selected_asset_length=ENABLE_TF_NARRATION ?
        tf_asset_length : narration_asset_length;
    wire [31:0] selected_asset_crc32=ENABLE_TF_NARRATION ?
        tf_asset_crc32 : narration_asset_crc32;
    wire selected_narration_valid=ENABLE_TF_NARRATION ?
        tf_stream_sample_valid : narration_sample_valid;
    wire signed [15:0] selected_narration_sample=ENABLE_TF_NARRATION ?
        tf_stream_sample : narration_sample;
    generate if(SINGLE_CARD_AUDIO)begin: permission_audio_guard
        reg header_ready;
        always @(posedge pixel_clk or posedge pixel_rst)
            if(pixel_rst)header_ready<=0;
            else if(!audio_play_permitted||selected_asset_begin||media_audio_request)header_ready<=0;
            else if(selected_asset_complete)header_ready<=1;
        assign narration_external_allowed=audio_play_permitted&&header_ready&&
            !audio_ring_fault_sync[1]&&!tf_stream_failed;
        assign narration_reject_reason=tf_stream_failed||audio_ring_fault_sync[1] ? 4'd4 :
            !audio_play_permitted ? 4'd1 : !header_ready ? 4'd2 : 4'd0;
        assign narration_prompt_valid=!daily_transport_hold&&!diagnostic_test_active&&selected_narration_valid&&narration_playing&&
            !(narration_follow_mode&&!autoplay&&!panel_mode)&&!alarm_active&&narration_external_allowed;
        assign narration_underflow=!daily_transport_hold&&!diagnostic_test_active&&daily_audio_valid&&narration_playing&&
            !(narration_follow_mode&&!autoplay&&!panel_mode)&&!alarm_active&&
            narration_external_allowed&&!selected_narration_valid;
    end else begin: certificate_audio_guard
    narration_audio_guard #(.LIVE_CERTIFICATE(1)) narration_guard(.clk(pixel_clk),.rst(pixel_rst),
        .asset_begin(selected_asset_begin),
        .asset_complete(selected_asset_complete),
        .asset_purpose(selected_asset_purpose),
        .asset_length(selected_asset_length),.asset_crc32(selected_asset_crc32),
        .certificate_valid(narration_certificate_valid),
        .certificate_purpose(narration_certificate[7:0]),
        .certificate_length(narration_certificate[39:8]),
        .certificate_crc32(narration_certificate[71:40]),
        .certificate_pass(certificate_pass&&certificate_reason==0),
        .certificate_version(narration_certificate[92:77]),
        .sample_tick(daily_audio_valid),
        .narration_playing(narration_playing&&!(narration_follow_mode&&!autoplay&&!panel_mode)),
        .sample_valid(selected_narration_valid),.alarm_active(alarm_active),
        .external_allowed(narration_external_allowed),
        .reject_reason(narration_reject_reason),.prompt_valid(narration_prompt_valid),
        .audio_underflow(narration_underflow));
    end endgenerate
    emergency_audio_mixer #(.ENABLE_EXTERNAL_ALARM(ENABLE_TF_NARRATION),.SOURCE_FADES(V5_CONTROLS),
        .FADE_SAMPLES(256),.PIPELINED_MIX(HUMAN_RECORDINGS)) alarm_mix(.clk(pixel_clk),.rst(pixel_rst),
        .sample_valid(daily_audio_valid),
        .normal_sample(diagnostic_test_active ? test_hdmi_sample : HUMAN_RECORDINGS ? 16'd0 : daily_audio_left),.alarm_active(audible_alarm),
        .alarm_kind(alarm_kind),

        .voice_valid(media_voice_asset ? human_sample_consumed : l0_active_audio),
        .voice_sample(media_voice_asset ? selected_narration_sample : l0_voice_sample),
        .external_alarm_valid(external_alarm_selected&&tf_stream_sample_valid),
        .external_alarm_sample(tf_stream_sample),
        .prompt_valid(narration_prompt_valid||(human_sample_consumed&&!audible_alarm)),
        .prompt_sample(selected_narration_sample),
        .unlimited_sample(unlimited_audio),.output_valid(mixed_valid),
        .alarm_overrun(alarm_audio_overrun));
    audio_output_stage #(.SATURATING_FLAGS(COMPACT_DIAGNOSTICS)) output_conditioner(.clk(pixel_clk),.rst(pixel_rst),
        .sample_valid(mixed_valid),.sample_in(unlimited_audio),.volume_level(audio_volume),
        .mute(1'b0),.output_valid(audio_valid),.sample_out(emergency_mixed_audio),
        .peak_absolute(audio_peak_absolute),.limited_count(audio_limited_count),
        .clipped_count(audio_clipped_count),.overrun(output_overrun));
    assign audio_left=emergency_mixed_audio;
    assign audio_right=emergency_mixed_audio;
    assign acr_valid=daily_acr_valid;
    assign acr_n=daily_acr_n;
    assign acr_cts=daily_acr_cts;
    wire [6:0] e5_waterfall_query_age;
    wire [5:0] e5_waterfall_query_bin;
    generate if(ENABLE_LOCAL_STFT) begin: local_e5_analysis
        wire spectrum_valid,transform_done,analyzer_busy;
        wire [5:0] spectrum_bin;
        wire [15:0] spectrum_magnitude;
        wire [6:0] newest_column;
        stft_512_serial analyzer(.clk(pixel_clk),.rst(pixel_rst),
            .sample_tick(audio_valid),.sample_in(emergency_mixed_audio),
            .spectrum_valid(spectrum_valid),.spectrum_bin(spectrum_bin),
            .spectrum_magnitude(spectrum_magnitude),
            .transform_done(transform_done),
            .peak_frequency_q8(e5_peak_frequency_q8),.busy(analyzer_busy));
        waterfall_buffer waterfall(.clk(pixel_clk),.rst(pixel_rst),
            .frame_tick(frame_tick),.spectrum_valid(spectrum_valid),
            .spectrum_bin(spectrum_bin),.spectrum_magnitude(spectrum_magnitude),
            .query_age(e5_waterfall_query_age),
            .query_bin(e5_waterfall_query_bin),
            .query_value(e5_waterfall_sample),.newest_column(newest_column));
    end else if(REMOTE_SPECTRUM) begin: remote_e5_analysis
        remote_spectrum_receiver receiver(.clk(pixel_clk),.rst(pixel_rst),
            .frame_tick(frame_tick),.message_valid(spectrum_message_valid),
            .message_type(spectrum_message_type),.payload(spectrum_message_payload),
            .query_age(e5_waterfall_query_age),.query_bin(e5_waterfall_query_bin),
            .query_value(e5_waterfall_sample),.peak_frequency_q8(e5_peak_frequency_q8),
            .file_index(),.sample_position(),.valid(),.dropped_columns());
    end else begin: no_e5_spectrum
        assign e5_peak_frequency_q8=0;
        assign e5_waterfall_sample=0;
    end endgenerate
    wire prototype_route_write,prototype_route_commit;
    wire prototype_route_crc_ok,prototype_route_checked,prototype_route_assets_match;
    wire [7:0] prototype_route_key;
    wire [31:0] prototype_route_segments,prototype_route_directions;
    wire [31:0] prototype_route_crc32;
    wire [2:0] prototype_route_exit;wire [1:0] prototype_route_status;
    wire [15:0] prototype_route_version;
    n10_prototype_route_loader route_loader(.clk(pixel_clk),.rst(pixel_rst),
        .cfg_write(prototype_route_write),.cfg_blocked_key(prototype_route_key),
        .cfg_segment_mask(prototype_route_segments),
        .cfg_direction_mask(prototype_route_directions),
        .cfg_exit(prototype_route_exit),.cfg_status(prototype_route_status),
        .cfg_commit(prototype_route_commit),.cfg_crc_ok(prototype_route_crc_ok),
        .cfg_checked(prototype_route_checked),
        .cfg_assets_match(prototype_route_assets_match),
        .cfg_version(prototype_route_version),.cfg_crc32(prototype_route_crc32));
    wire dynamic_route_write,dynamic_route_commit,dynamic_route_crc_ok;
    wire dynamic_route_checked,dynamic_route_assets_match,route_cdc_overflow;
    wire [7:0] dynamic_route_key;
    wire [31:0] dynamic_route_segments,dynamic_route_directions,dynamic_route_crc32;
    wire [2:0] dynamic_route_exit;wire [1:0] dynamic_route_status;
    wire [15:0] dynamic_route_version;
    route_config_cdc route_cdc(.src_clk(sys_clk),.src_rst(sys_rst),
        .src_write(file_route_write),.src_key(file_route_key),
        .src_segments(file_route_segments),.src_directions(file_route_directions),
        .src_exit(file_route_exit),.src_status(file_route_status),
        .src_commit(file_route_commit),.src_crc_ok(file_route_crc_ok),
        .src_checked(file_route_checked),.src_assets_match(file_route_assets_match),
        .src_version(file_route_version),.src_crc32(file_route_crc32),
        .src_ready(file_route_ready),.src_overflow(route_cdc_overflow),
        .dst_clk(pixel_clk),.dst_rst(pixel_rst),
        .dst_write(dynamic_route_write),.dst_key(dynamic_route_key),
        .dst_segments(dynamic_route_segments),
        .dst_directions(dynamic_route_directions),.dst_exit(dynamic_route_exit),
        .dst_status(dynamic_route_status),.dst_commit(dynamic_route_commit),
        .dst_crc_ok(dynamic_route_crc_ok),.dst_checked(dynamic_route_checked),
        .dst_assets_match(dynamic_route_assets_match),
        .dst_version(dynamic_route_version),.dst_crc32(dynamic_route_crc32));
    wire board_route_write,board_route_commit,route_stage_ready,board_route_error;
    wire [7:0] board_route_key;
    wire [31:0] board_route_segments,board_route_directions,board_route_crc;
    wire [2:0] board_route_exit;wire [1:0] board_route_status;
    wire [15:0] board_route_version;
    generate if(!SIMPLE_DEMO)begin: route_reception
    n10_route_receiver board_routes(.clk(pixel_clk),.rst(pixel_rst),.frame_tick(frame_tick),
        .message_valid(BOARD_ROUTE_AUTHORITY&&spectrum_message_valid),
        .message_type(spectrum_message_type),.payload(spectrum_message_payload),
        .cfg_ready(route_stage_ready),.cfg_write(board_route_write),.cfg_key(board_route_key),
        .cfg_segments(board_route_segments),.cfg_directions(board_route_directions),
        .cfg_exit(board_route_exit),.cfg_status(board_route_status),.cfg_commit(board_route_commit),
        .batch_error(board_route_error),.cfg_version(board_route_version),.cfg_crc32(board_route_crc));
    end else begin: no_route_reception
        assign board_route_write=0;assign board_route_commit=0;assign board_route_key=0;
        assign board_route_segments=0;assign board_route_directions=0;assign board_route_crc=0;
        assign board_route_exit=0;assign board_route_status=0;assign board_route_version=0;assign board_route_error=0;
    end endgenerate
    wire route_cfg_write=BOARD_ROUTE_AUTHORITY ? board_route_write : dynamic_route_write||prototype_route_write;
    wire route_cfg_commit=BOARD_ROUTE_AUTHORITY ? board_route_commit : dynamic_route_commit||prototype_route_commit;
    wire use_dynamic_route=dynamic_route_write||dynamic_route_commit;
    wire [7:0] route_cfg_key=BOARD_ROUTE_AUTHORITY ? board_route_key : use_dynamic_route ? dynamic_route_key : prototype_route_key;

    wire board_route_bit20;
    physical_hold_buffer route_bit20_hold(.d(board_route_segments[20]),.q(board_route_bit20));
    wire [31:0] board_route_segments_ram={board_route_segments[31:21],board_route_bit20,board_route_segments[19:0]};
    wire [31:0] route_cfg_segments=BOARD_ROUTE_AUTHORITY ? board_route_segments_ram : use_dynamic_route ?
        dynamic_route_segments : prototype_route_segments;
    wire [31:0] route_cfg_directions=BOARD_ROUTE_AUTHORITY ? board_route_directions : use_dynamic_route ?
        dynamic_route_directions : prototype_route_directions;
    wire [2:0] route_cfg_exit=BOARD_ROUTE_AUTHORITY ? board_route_exit : use_dynamic_route ? dynamic_route_exit : prototype_route_exit;
    wire [1:0] route_cfg_status=BOARD_ROUTE_AUTHORITY ? board_route_status : use_dynamic_route ? dynamic_route_status : prototype_route_status;
    wire route_cfg_crc_ok=BOARD_ROUTE_AUTHORITY ? board_route_commit : use_dynamic_route ? dynamic_route_crc_ok : prototype_route_crc_ok;
    wire route_cfg_checked=BOARD_ROUTE_AUTHORITY ? board_route_commit : use_dynamic_route ? dynamic_route_checked : prototype_route_checked;
    wire route_cfg_assets_match=BOARD_ROUTE_AUTHORITY ? board_route_commit : use_dynamic_route ?
        dynamic_route_assets_match : prototype_route_assets_match;
    wire [15:0] route_cfg_version=BOARD_ROUTE_AUTHORITY ? board_route_version : use_dynamic_route ?
        dynamic_route_version : prototype_route_version;
    wire [31:0] route_cfg_crc32=BOARD_ROUTE_AUTHORITY ? board_route_crc : use_dynamic_route ?
        dynamic_route_crc32 : prototype_route_crc32;
    wire [63:0] remote_ui_context;
    assign extension_context={48'd0,2'd0,diagnostic_test_active,panel_selection,alarm_blocked_set,remote_ui_context};
    video_scanout #(.BASIC_TRANSITIONS(FILMING_PROFILE),.DUAL_EXTENSIONS(DUAL_EXTENSIONS),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.HTOTAL(HTOTAL),.VTOTAL(VTOTAL),.HSTART(HSTART),.VSTART(VSTART),
        .BOARD_ROUTE_AUTHORITY(BOARD_ROUTE_AUTHORITY),.V5_CONTROLS(V5_CONTROLS),.FINAL_SUBTITLES(HUMAN_RECORDINGS),
        .DAILY_SCROLL_SUBTITLES(HUMAN_RECORDINGS&&SIMPLE_DEMO),
        .SIMPLE_DEMO(SIMPLE_DEMO),.ENABLE_ROUTES(!SIMPLE_DEMO),.ENABLE_SPRITES(!SIMPLE_DEMO),
        .ENABLE_EFFECTS(ENABLE_EFFECTS),.FIXED_RATE_AXIS(FIXED_RATE_AXIS),.MUSEUM_UI(MUSEUM_UI),
        .DUAL_SOURCE(DUAL_TRANSITIONS),.PRELOADED_VIEW(ORIGINAL_DETAIL),.DYNAMIC_VIEWPORT(ORIGINAL_DETAIL),.COMPACT_SCENES(COMPACT_SCENES)) video(
        .service_valid(spectrum_message_valid),.service_type(spectrum_message_type),.service_payload(spectrum_message_payload),
        .remote_ui_context(remote_ui_context),.diagnostic_active(diagnostic_test_active),.diagnostic_page(panel_selection),
        .live_route_result(live_route_result),.live_route_fresh(live_route_fresh),
        .clk(pixel_clk),.rst(pixel_rst),.cache_ready(cache_ready),
        .image_index(image_index),.fade_gain(video_gain),
        .zoom_mode(zoom_mode),.zoom_scale(realtime_zoom_scale),.viewport_ready(!viewport_pending),
        .media_playlist_error(media_playlist_fault),
        .zoom_pan_x(realtime_pan_x),.zoom_pan_y(realtime_pan_y),
        .grayscale_enable(grayscale_enable),
        .overlay_enable((V5_CONTROLS ? effect_synced[1] : overlay_synced)||diagnostic_test_active),
        .panel_status(panel_status),
        .audio_test_mode(diagnostic_test_active),
        .museum_page(museum_page),.museum_error(museum_error),.museum_selection(museum_selection),
        .museum_period(museum_period),.museum_playing(museum_playing),
        .museum_narration_ready(1'b0),.museum_progress(8'd0),.museum_subtitle(8'd0),
        .transition_mode(transition_mode),.transition_target(transition_target),
        .slide_progress(slide_progress),.slide_active(slide_active),
        .transition_phase(transition_phase),.line_dual(line_dual),
        .transition_settings({daily_easing,daily_duration,daily_effect}),
        .second_ram_addr(second_ram_addr),.second_ram_q(second_ram_q),
        .brightness_level(brightness_level),.contrast_level(contrast_level),
        .saturation_level(saturation_level),.osd_visible(osd_visible),
        .gamma_mode(quality_gamma),.temperature_mode(quality_temperature),
        .quality_selection(quality_selection),
        .volume_level(audio_volume),.flash_rate(flash_rate),.flash_duty(flash_duty),
        .audio_peak_absolute(audio_peak_absolute),.audio_limited_count(audio_limited_count),
        .audio_clipped_count(audio_clipped_count),
        .quality_enable(DUAL_TRANSITIONS||osd_visible||brightness_level!=3'd2||
            contrast_level!=3'd2||saturation_level!=3'd2||quality_gamma!=1||quality_temperature!=1||
            (overlay_synced&&grayscale_synced&&effect_synced==2'b10)),
        .quality_auto_enable(V5_CONTROLS ? daily_auto_contrast :
            overlay_synced&&grayscale_synced&&effect_synced==2'b10),
        .analysis_view(V5_CONTROLS ? ((ENABLE_LOCAL_STFT||REMOTE_SPECTRUM)&&effect_synced[1] ? 2'd2 : 2'd0) :
            (overlay_synced ? effect_synced : 2'd0)),
        .narration_subtitle(narration_subtitle),
        .daily_subtitle_active(daily_subtitle_active),
        .daily_subtitle_track(audio_certificate_index[2:0]),
        .daily_subtitle_samples(narration_elapsed_samples[31:0]),
        .e5_peak_frequency_q8(e5_peak_frequency_q8),
        .e5_waterfall_value(e5_waterfall_sample),
        .audio_sample_valid(diagnostic_test_active ? test_native_valid : audio_valid),
        .audio_sample(diagnostic_test_active ? test_native_sample : audio_left),
        .console_proxy_valid(console_proxy_valid),
        .console_proxy_status(console_proxy_status),
        .alarm_active(alarm_active),.alarm_kind(alarm_kind),.alarm_level(alarm_level),.alarm_drill(alarm_drill),
        .alarm_pending(alarm_pending),
        .alarm_evacuation(alarm_evacuation),.local_fire_visible(local_fire_visible),
        .local_control_status(local_control_status),
        .extended_control_status({osd_visible,quality_selection,grayscale_enable,daily_zoom_scale,
            daily_pan_x,daily_pan_y,daily_auto_contrast,viewport_pending}),
        .alarm_display_active(alarm_display_active),
        .alarm_cancel_notice(alarm_cancel_notice),.alarm_flash_on(alarm_flash_on),
        .alarm_countdown_trusted(alarm_countdown_trusted),.alarm_countdown_seconds(alarm_countdown_seconds),
        .alarm_latency_valid(alarm_latency_valid),.alarm_pixel_latency_us(alarm_pixel_latency_us),
        .alarm_audio_latency_us(alarm_audio_latency_us),.frame_tick(frame_tick),
        .alarm_blocked_set(alarm_blocked_set),.route_cfg_write(route_cfg_write),
        .route_cfg_key(route_cfg_key),.route_cfg_segments(route_cfg_segments),
        .route_cfg_directions(route_cfg_directions),.route_cfg_exit(route_cfg_exit),
        .route_cfg_status(route_cfg_status),.route_cfg_commit(route_cfg_commit),
        .route_cfg_crc_ok(route_cfg_crc_ok),.route_cfg_checked(route_cfg_checked),
        .route_cfg_assets_match(route_cfg_assets_match),.route_cfg_version(route_cfg_version),
        .route_cfg_crc32(route_cfg_crc32),
        .route_cfg_ready(route_stage_ready),
        .line_req_toggle(line_req),.line_image(line_image),.line_row(line_row),.line_bank(line_bank),.line_ack_toggle(line_ack),
        .line_second_image(line_second_image),.line_split(line_split),
        .line_horizontal_slide(line_horizontal_slide),.line_zoom(line_zoom),
        .line_ram_addr(ram_addr),.line_ram_q(ram_q),.axis_valid(axis_valid),.axis_user(axis_user),.axis_last(axis_last),
        .axis_data(axis_data),.axis_ready(axis_ready),.underflow(video_underflow),.overflow(video_overflow),
        .scroll_position(scroll_position),
        .e5_waterfall_query_age(e5_waterfall_query_age),
        .e5_waterfall_query_bin(e5_waterfall_query_bin));
endmodule
