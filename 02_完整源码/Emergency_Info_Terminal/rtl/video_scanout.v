// 按视频时序读取缓存，合成画质处理、字幕、状态及应急图层。
`timescale 1ns/1ps

module video_scanout #(
    parameter integer WIDTH=640, HEIGHT=480,
    parameter integer HTOTAL=800, VTOTAL=525,
    parameter integer HSTART=160, VSTART=45,
    parameter integer ENABLE_EFFECTS=1,

    parameter integer FIXED_RATE_AXIS=0,
    parameter integer MUSEUM_UI=0, DUAL_SOURCE=0, BOARD_ROUTE_AUTHORITY=0,
    parameter integer V5_CONTROLS=0, PRELOADED_VIEW=0, COMPACT_SCENES=0,
    parameter integer DYNAMIC_VIEWPORT=0,
    parameter integer ENABLE_ROUTES=1,ENABLE_SPRITES=1,SIMPLE_DEMO=0,
    parameter integer DUAL_EXTENSIONS=0,
    parameter integer BASIC_TRANSITIONS=SIMPLE_DEMO&&DUAL_EXTENSIONS,
    parameter integer FINAL_SUBTITLES=0, DAILY_SCROLL_SUBTITLES=0
)(
    input wire clk, rst, cache_ready,
    input wire diagnostic_active,input wire [4:0] diagnostic_page,
    input wire [95:0] live_route_result,input wire live_route_fresh,
    input wire service_valid,input wire [7:0] service_type,input wire [95:0] service_payload,
    output wire [63:0] remote_ui_context,
    input wire [3:0] image_index,
    input wire [4:0] fade_gain,
    input wire zoom_mode,
    input wire [1:0] zoom_scale,
    input wire viewport_ready,
    input wire media_playlist_error,
    input wire [10:0] zoom_pan_x,zoom_pan_y,
    input wire grayscale_enable,
    input wire overlay_enable,
    input wire audio_test_mode,
    input wire [15:0] panel_status,
    input wire [2:0] transition_mode,
    input wire [3:0] transition_target,
    input wire [4:0] slide_progress,
    input wire slide_active,
    input wire [6:0] transition_phase,
    input wire [5:0] transition_settings,
    input wire [2:0] brightness_level, contrast_level, saturation_level,
    input wire [1:0] gamma_mode,temperature_mode,
    input wire [3:0] quality_selection,
    input wire [2:0] volume_level,
    input wire [1:0] flash_rate,flash_duty,
    input wire [15:0] audio_peak_absolute,
    input wire [31:0] audio_limited_count,audio_clipped_count,
    input wire osd_visible,
    input wire quality_enable,
    input wire quality_auto_enable,
    input wire [1:0] analysis_view,
    input wire [7:0] narration_subtitle,
    input wire daily_subtitle_active,
    input wire [2:0] daily_subtitle_track,
    input wire [31:0] daily_subtitle_samples,
    input wire [23:0] e5_peak_frequency_q8,
    input wire [7:0] e5_waterfall_value,
    input wire [3:0] museum_page,museum_error,
    input wire [2:0] museum_selection,
    input wire [1:0] museum_period,
    input wire museum_playing,museum_narration_ready,
    input wire [7:0] museum_progress,museum_subtitle,
    input wire audio_sample_valid,
    input wire [15:0] audio_sample,
    input wire console_proxy_valid,
    input wire [95:0] console_proxy_status,
    input wire alarm_active,
    input wire [2:0] alarm_kind,
    input wire [2:0] alarm_level,
    input wire alarm_drill,
    input wire alarm_pending,
    input wire alarm_evacuation,local_fire_visible,
    input wire [15:0] local_control_status,
    input wire [15:0] extended_control_status,
    input wire alarm_cancel_notice,
    input wire alarm_flash_on,
    input wire alarm_countdown_trusted,
    input wire [15:0] alarm_countdown_seconds,
    input wire alarm_latency_valid,
    input wire [23:0] alarm_pixel_latency_us,
    input wire [23:0] alarm_audio_latency_us,
    input wire [7:0] alarm_blocked_set,
    input wire route_cfg_write,input wire [7:0] route_cfg_key,
    input wire [31:0] route_cfg_segments,input wire [31:0] route_cfg_directions,
    input wire [2:0] route_cfg_exit,input wire [1:0] route_cfg_status,
    input wire route_cfg_commit,input wire route_cfg_crc_ok,
    input wire route_cfg_checked,input wire route_cfg_assets_match,
    input wire [15:0] route_cfg_version,input wire [31:0] route_cfg_crc32,
    output wire route_cfg_ready,
    output wire frame_tick,
    output reg line_req_toggle,
    output reg [3:0] line_image,
    output reg [9:0] line_row,
    output reg line_bank,
    output reg [3:0] line_second_image,
    output reg [9:0] line_split,
    output reg line_horizontal_slide,
    output reg [1:0] line_zoom,
    input wire line_ack_toggle,
    output wire [10:0] line_ram_addr,
    input wire [23:0] line_ram_q,
    output wire [10:0] second_ram_addr,
    input wire [23:0] second_ram_q,
    output reg line_dual,
    output wire axis_valid, axis_user, axis_last,
    output wire [23:0] axis_data,
    input wire axis_ready,
    output reg underflow,
    output wire overflow,
    output wire [12:0] scroll_position,
    output wire [6:0] e5_waterfall_query_age,
    output wire [5:0] e5_waterfall_query_bin,
    output wire alarm_display_active
);
    reg [10:0] h, v;
    reg [1:0] ready_sync, ack_sync;
    reg ack_seen, display_enabled;
    reg [1:0] bank_valid;
    reg [3:0] tag_image0, tag_image1;
    reg [3:0] tag_second_image0, tag_second_image1;
    reg [9:0] tag_row0, tag_row1;
    reg [9:0] tag_split0, tag_split1;
    reg [1:0] tag_horizontal_slide;
    reg [1:0] tag_zoom0,tag_zoom1;
    reg line_good;
    reg active_d, user_d, last_d, good_d;
    reg [10:0] x_d, y_d;
    reg [23:0] background_d;
    wire [10:0] y = v-VSTART;
    wire [10:0] x = h-HSTART;
    wire [10:0] request_output_y=v==0 ? 11'd0 : y+1'b1;
    wire [14:0] horizontal_slide_product=slide_progress*WIDTH;
    wire [14:0] vertical_slide_product=slide_progress*HEIGHT;
    wire [10:0] horizontal_slide_pixels=horizontal_slide_product>>4;
    wire [10:0] vertical_slide_pixels=vertical_slide_product>>4;
    wire [10:0] vertical_old_height=HEIGHT-vertical_slide_pixels;
    wire vertical_slide=!DUAL_SOURCE && slide_active && transition_mode==2;
    wire horizontal_slide=1'b0;
    wire current_uses_new=vertical_slide && y>=vertical_old_height;
    wire request_uses_new=vertical_slide && request_output_y>=vertical_old_height;
    wire [10:0] current_virtual_y=vertical_slide ?
        (current_uses_new ? y-vertical_old_height : y+vertical_slide_pixels) : y;
    wire [10:0] request_virtual_y=vertical_slide ?
        (request_uses_new ? request_output_y-vertical_old_height :
        request_output_y+vertical_slide_pixels) : request_output_y;
    wire [10:0] source_x,current_source_y,request_source_x,request_source_y;
    wire use_preloaded_view=PRELOADED_VIEW&&(!DYNAMIC_VIEWPORT||viewport_ready);
    wire [1:0] sample_scale=use_preloaded_view ? 2'd0 : zoom_scale;

    wire [10:0] sample_pan_x=use_preloaded_view||sample_scale==0 ? WIDTH/2 : zoom_pan_x;
    wire [10:0] sample_pan_y=use_preloaded_view||sample_scale==0 ? HEIGHT/2 : zoom_pan_y;
    wire [10:0] dual_old_x,dual_new_x,unused_old_y,unused_new_y;
    wire dual_select,unused_dual;
    wire [10:0] virtual_x=DUAL_SOURCE && slide_active && transition_mode==2 ?
        (dual_select ? dual_new_x : dual_old_x) : x;
    localparam [10:0] SOURCE_WIDTH=WIDTH;
    localparam [10:0] SOURCE_HEIGHT=HEIGHT;
    wire source_valid,request_source_valid;
    wire [10:0] route_x_unused,route_y_unused,request_route_x_unused,request_route_y_unused;
    shared_coordinate_mapper #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) current_mapper(
        .x(virtual_x),.y(current_virtual_y),.scale(sample_scale),.pan_x(sample_pan_x),.pan_y(sample_pan_y),
        .source_width(SOURCE_WIDTH),.source_height(SOURCE_HEIGHT),.source_x(source_x),.source_y(current_source_y),
        .source_valid(source_valid),.route_x(route_x_unused),.route_y(route_y_unused));
    shared_coordinate_mapper #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) request_mapper(
        .x(11'd0),.y(request_virtual_y),.scale(sample_scale),.pan_x(sample_pan_x),.pan_y(sample_pan_y),
        .source_width(SOURCE_WIDTH),.source_height(SOURCE_HEIGHT),.source_x(request_source_x),.source_y(request_source_y),
        .source_valid(request_source_valid),.route_x(request_route_x_unused),.route_y(request_route_y_unused));
    wire [9:0] current_line_row=current_source_y[9:0];
    wire [9:0] request_line_row=request_source_y[9:0];
    wire [3:0] current_line_image=current_uses_new ? transition_target : image_index;
    wire [3:0] request_line_image=request_uses_new ? transition_target : image_index;
    wire [9:0] horizontal_split=WIDTH-horizontal_slide_pixels;
    wire active = h>=HSTART && h<HSTART+WIDTH && v>=VSTART && v<VSTART+HEIGHT;
    wire tag_matches0=bank_valid[0] && tag_image0==current_line_image &&
        tag_row0==current_line_row && tag_horizontal_slide[0]==horizontal_slide && tag_zoom0==sample_scale &&
        (!horizontal_slide || (tag_second_image0==transition_target &&
        tag_split0==horizontal_split));
    wire tag_matches1=bank_valid[1] && tag_image1==current_line_image &&
        tag_row1==current_line_row && tag_horizontal_slide[1]==horizontal_slide && tag_zoom1==sample_scale &&
        (!horizontal_slide || (tag_second_image1==transition_target &&
        tag_split1==horizontal_split));
    wire tag_matches=y[0] ? tag_matches1 : tag_matches0;
    assign frame_tick = h==0 && v==0;
    wire [7:0] unused_alpha;
    wire [10:0] shape_old_x,shape_old_y,shape_new_x,shape_new_y;
    wire shape_select;
    wire [7:0] shape_alpha;
    wire shape_dual;
    transition_coordinate_generator #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) read_coordinates(

        .mode(3'd2),.progress(transition_phase),.x(x),.y(y),
        .select_new(dual_select),.new_alpha(unused_alpha),
        .old_x(dual_old_x),.old_y(unused_old_y),.new_x(dual_new_x),
        .new_y(unused_new_y),.dual_source(unused_dual));
    transition_coordinate_generator #(.BASIC_ONLY(BASIC_TRANSITIONS),.WIDTH(WIDTH),.HEIGHT(HEIGHT)) pixel_shape(
        .mode(transition_mode),.progress(transition_phase),.x(x_d),.y(y_d),
        .select_new(shape_select),.new_alpha(shape_alpha),
        .old_x(shape_old_x),.old_y(shape_old_y),.new_x(shape_new_x),
        .new_y(shape_new_y),.dual_source(shape_dual));
    wire [10:0] old_read_x=source_x;
    wire [10:0] new_read_x=source_x;
    assign line_ram_addr = {y[0],horizontal_slide ? x[9:0] : old_read_x[9:0]};
    assign second_ram_addr={y[0],new_read_x[9:0]};
    wire [23:0] blended_rgb;
    dual_source_blend blend(.old_rgb(line_ram_q),.new_rgb(second_ram_q),
        .progress(transition_phase),.crossfade(transition_mode==0),
        .select_new(shape_select),.enable(DUAL_SOURCE && slide_active),.rgb(blended_rgb));
    wire [23:0] raw_rgb = good_d ? blended_rgb : background_d;
    wire [23:0] effected_rgb;
    wire [23:0] sprite_rgb;
    wire [23:0] daily_composed_rgb;
    wire [23:0] analysis_rgb,subtitle_rgb,proxy_rgb,composed_rgb;
    reg [10:0] museum_x,museum_y;
    reg active_q, user_q, last_q;
    reg active_qq,user_qq,last_qq;
    reg active_qqq,user_qqq,last_qqq;
    reg [10:0] museum_x_q,museum_y_q;
    reg [10:0] museum_x_qq,museum_y_qq;
    always @(posedge clk or posedge rst)
        if(rst) begin museum_x<=0;museum_y<=0;end
        else begin museum_x<=x_d;museum_y<=y_d;end
    generate if(MUSEUM_UI) begin: museum_overlay
        museum_osd osd(.x(museum_x_q),.y(museum_y_q),.rgb_in(effected_rgb),
            .page(museum_page),.error_code(museum_error),.selection(museum_selection),
            .brightness(brightness_level),.contrast(contrast_level),.saturation(saturation_level),
            .exhibit_index(image_index[2:0]),.period_select(museum_period),
            .playing(museum_playing),.zoom(zoom_mode),.mono(grayscale_enable),
            .narration_ready(museum_narration_ready),.progress(museum_progress),.subtitle_id(museum_subtitle),
            .rgb_out(daily_composed_rgb));
    end else begin: legacy_overlay
        assign daily_composed_rgb=sprite_rgb;
    end endgenerate
    generate if(V5_CONTROLS&&ENABLE_SPRITES)begin: display_sprites
        demo_sprite_overlay #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.HALF_ALPHA(COMPACT_SCENES)) sprites(
            .clk(clk),.rst(rst),.frame_tick(frame_tick),
            .enable(cache_ready&&!alarm_active&&!osd_visible&&!zoom_mode&&analysis_view==0),
            .x(museum_x),.y(museum_y),.rgb_in(effected_rgb),.rgb_out(sprite_rgb));
    end else begin: no_display_sprites
        assign sprite_rgb=effected_rgb;
    end endgenerate
    wire [5:0] quality_histogram_column;
    wire [19:0] quality_histogram_value,quality_histogram_column_value;
    generate if(!SIMPLE_DEMO||DUAL_EXTENSIONS)begin: legacy_analysis
    p2_analysis_overlay #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) analysis_overlay(
        .x(museum_x_q),.y(museum_y_q),.view(COMPACT_SCENES ? {analysis_view[1],1'b0} : analysis_view),
        .histogram_value(quality_histogram_column_value),.waterfall_value(e5_waterfall_value),
        .peak_frequency_q8(e5_peak_frequency_q8),.rgb_in(daily_composed_rgb),
        .histogram_column(quality_histogram_column),
        .waterfall_age(e5_waterfall_query_age),.waterfall_bin(e5_waterfall_query_bin),
        .rgb_out(analysis_rgb));
    end else begin: no_analysis
        assign analysis_rgb=daily_composed_rgb;assign quality_histogram_column=0;
        assign e5_waterfall_query_age=0;assign e5_waterfall_query_bin=0;
    end endgenerate
    generate if(FINAL_SUBTITLES)begin: deferred_subtitles
        reg [23:0] rgb_q;
        always @(posedge clk)rgb_q<=analysis_rgb;
        assign subtitle_rgb=rgb_q;
    end else begin: early_subtitles
    subtitle_overlay_renderer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) subtitles(
        .clk(clk),.x(museum_x_q),.y(museum_y_q),.subtitle_id(narration_subtitle),
        .rgb_in(analysis_rgb),.rgb_out(subtitle_rgb));
    end endgenerate
    wire scene_visible,scene_drill,scene_cancel,scene_flash,scene_trusted;
    wire [6:0] scene_opacity;
    wire [2:0] scene_level;
    wire [15:0] scene_seconds;

    wire scene_tick=h==0 && v==VSTART;
    alarm_scene_control #(.DIRECT_RELEASE(SIMPLE_DEMO)) scene(.clk(clk),.rst(rst),.scene_tick(scene_tick),
        .alarm_active(alarm_active),.alarm_kind(alarm_kind),.alarm_level(alarm_level),
        .alarm_drill(alarm_drill),.cancel_notice(alarm_cancel_notice),
        .flash_on(alarm_flash_on),.countdown_trusted(alarm_countdown_trusted),
        .countdown_seconds(alarm_countdown_seconds),.opacity(scene_opacity),
        .level(scene_level),.drill(scene_drill),.cancel(scene_cancel),
        .flash(scene_flash),.trusted(scene_trusted),.seconds(scene_seconds),.visible(scene_visible));
    assign alarm_display_active=scene_visible;
    reg [7:0] control_card_frames;
    reg [19:0] control_card_context;
    always @(posedge clk or posedge rst)
      if(rst)begin control_card_frames<=0;control_card_context<=0;end
      else if(frame_tick)begin
        control_card_context<=console_proxy_status[87:68];
        if(console_proxy_valid&&control_card_context!=console_proxy_status[87:68])control_card_frames<=180;
        else if(control_card_frames!=0)control_card_frames<=control_card_frames-1'b1;
      end
    wire control_card_visible=!DUAL_EXTENSIONS||control_card_frames!=0||
        console_proxy_status[75]||console_proxy_status[94]||console_proxy_status[92];
    console_proxy_overlay #(.MODERN_UI(1)) console_proxy(.x(museum_x_qq),.y(museum_y_qq),
        .status_valid(console_proxy_valid&&!scene_visible&&control_card_visible),
        .status(console_proxy_status),.rgb_in(subtitle_rgb),.rgb_out(proxy_rgb));
    alarm_page_renderer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MODERN_UI(V5_CONTROLS&&COMPACT_SCENES)) emergency_page(
        .clk(clk),.rst(rst),.x(museum_x_qq),.y(museum_y_qq),.rgb_in(proxy_rgb),.alarm_active(scene_visible),
        .alarm_level(scene_level),.alarm_drill(scene_drill),.cancel_notice(scene_cancel),
        .flash_on(scene_flash),.countdown_trusted(scene_trusted),
        .countdown_seconds(scene_seconds),.latency_valid(alarm_latency_valid),
        .pixel_latency_us(alarm_pixel_latency_us),.audio_latency_us(alarm_audio_latency_us),
        .rgb_out(composed_rgb));
    wire [5:0] route_segment_id;wire [7:0] route_segment_phase;
    wire [1:0] route_segment_distance;
    wire route_blocked_exit_pixel,route_overlay_valid;
    wire [23:0] route_overlay_rgb;wire route_table_valid,route_reachable;
    wire route_all_blocked,route_unreachable,route_fallback,route_changed;
    wire [2:0] route_exit;wire [1:0] route_status;
    wire [31:0] route_segments,route_directions;wire [15:0] route_version;
    wire [31:0] route_crc;
    reg [7:0] scene_blocked;
    reg [2:0] scene_kind;
    reg scene_pending,scene_evacuation,scene_local_fire;
    reg [15:0] scene_local_status;
    reg [15:0] scene_extended_status;
    reg [15:0] scene_panel_status;
    reg scene_media_error;
    always @(posedge clk or posedge rst)
        if(rst)begin
            scene_blocked<=0;scene_kind<=0;scene_pending<=1;
            scene_evacuation<=0;scene_local_fire<=0;scene_local_status<=0;
            scene_extended_status<=0;scene_media_error<=0;scene_panel_status<=0;
        end
        else if(scene_tick)begin
            scene_blocked<=alarm_blocked_set;scene_kind<=alarm_kind;scene_pending<=alarm_pending;
            scene_evacuation<=alarm_evacuation;scene_local_fire<=local_fire_visible;
            scene_local_status<=local_control_status;
            scene_extended_status<=extended_control_status;
            scene_panel_status<=panel_status;
            scene_media_error<=media_playlist_error;
        end
    wire route_stage=ENABLE_ROUTES&&(V5_CONTROLS ? scene_evacuation : scene_kind==1&&!scene_pending);
    generate if(ENABLE_ROUTES)begin: enabled_routes
    if(BOARD_ROUTE_AUTHORITY)begin: board_map
        n10_demo_segment_map segment_map(.x(museum_x_qq),.y(museum_y_qq),
            .blocked_set(scene_blocked),.segment_id(route_segment_id),
            .segment_phase(route_segment_phase),.segment_distance(route_segment_distance),
            .blocked_exit_pixel(route_blocked_exit_pixel));
    end else begin: legacy_map
        assign route_segment_distance=0;
        n10_prototype_segment_map segment_map(.x(museum_x_qq),.y(museum_y_qq),
            .blocked_set(scene_blocked),.segment_id(route_segment_id),
            .segment_phase(route_segment_phase),.blocked_exit_pixel(route_blocked_exit_pixel));
    end
    n10_route_engine #(.SHAPED_ARROWS(BOARD_ROUTE_AUTHORITY)) routes(
        .clk(clk),.rst(rst),.frame_tick(scene_tick),.cfg_ready(route_cfg_ready),
        .cfg_write(route_cfg_write),.cfg_blocked_key(route_cfg_key),
        .cfg_segment_mask(route_cfg_segments),.cfg_direction_mask(route_cfg_directions),
        .cfg_exit(route_cfg_exit),.cfg_status(route_cfg_status),
        .cfg_commit(route_cfg_commit),.cfg_crc_ok(route_cfg_crc_ok),
        .cfg_checked(route_cfg_checked),.cfg_assets_match(route_cfg_assets_match),
        .cfg_version(route_cfg_version),.cfg_crc32(route_cfg_crc32),
        .blocked_set(alarm_blocked_set),.pixel_valid(active_qqq&&scene_visible&&!scene_cancel&&
            (!BOARD_ROUTE_AUTHORITY||route_stage)),
        .segment_id(route_segment_id),.segment_phase(route_segment_phase),
        .segment_distance(route_segment_distance),
        .blocked_exit_pixel(route_blocked_exit_pixel),.flash_on(alarm_flash_on),
        .route_valid(route_table_valid),.route_reachable(route_reachable),
        .all_exits_blocked(route_all_blocked),.route_unreachable(route_unreachable),
        .selected_exit(route_exit),.selected_status(route_status),
        .selected_segment_mask(route_segments),.selected_direction_mask(route_directions),
        .overlay_valid(route_overlay_valid),.overlay_rgb(route_overlay_rgb),
        .safe_fallback(route_fallback),.route_changed(route_changed),
        .active_version(route_version),.active_crc32(route_crc));
    end else begin: no_routes
        assign route_cfg_ready=1;assign route_overlay_valid=0;assign route_overlay_rgb=0;
        assign route_segment_id=0;assign route_segment_phase=0;assign route_segment_distance=0;
        assign route_blocked_exit_pixel=0;assign route_table_valid=0;assign route_status=0;assign route_exit=0;
    end endgenerate
    wire [23:0] map_rgb;wire map_foreground;
    generate if(BOARD_ROUTE_AUTHORITY&&ENABLE_ROUTES)begin: board_map_background
        n10_demo_map_renderer background(.x(museum_x_qq),.y(museum_y_qq),
            .enable(scene_visible&&!scene_cancel&&route_stage),
            .segment_id(route_segment_id),.route_valid(route_table_valid),
            .status(route_status),.selected_exit(route_exit),
            .rgb_in(composed_rgb),.rgb_out(map_rgb),.foreground(map_foreground));
    end else begin: legacy_map_background
        assign map_rgb=composed_rgb;
        assign map_foreground=1'b0;
    end endgenerate
    wire [23:0] routed_rgb=route_overlay_valid&&(!map_foreground||route_blocked_exit_pixel) ?
        route_overlay_rgb : map_rgb;
    wire fire_map_active=SIMPLE_DEMO&&!DUAL_EXTENSIONS&&WIDTH>=640&&HEIGHT>=480&&scene_visible&&!scene_cancel&&
        (scene_kind==1||scene_kind==3);
    wire [23:0] fire_map_rgb;
    generate if(SIMPLE_DEMO&&!DUAL_EXTENSIONS&&WIDTH>=640&&HEIGHT>=480)begin: fixed_fire_map
        fire_escape_map map(.x(museum_x_qq),.y(museum_y_qq),.enable(fire_map_active),
            .flash_on(scene_flash),.drill(scene_drill),.rgb_in(routed_rgb),.rgb_out(fire_map_rgb));
    end else begin: no_fixed_fire_map
        assign fire_map_rgb=routed_rgb;
    end endgenerate
    wire live_map_active=DUAL_EXTENSIONS&&scene_visible&&!scene_cancel&&(scene_kind==1||scene_kind==3||scene_evacuation);
    wire [23:0] live_map_rgb;
    generate if(DUAL_EXTENSIONS)begin: live_routes
      live_route_overlay #(.FLOORPLAN(1),.EXTERNAL_RESULT(1)) route_display(.clk(clk),.rst(rst),.frame_tick(frame_tick),
       .pre_x(museum_x_q),.pre_y(museum_y_q),.route_result(live_route_result),.route_fresh(live_route_fresh),
       .message_valid(service_valid),.message_type(service_type),.payload(service_payload),
       .blocked(scene_blocked),.enable(live_map_active),
       .flash_on(scene_flash),.x(museum_x_qq),.y(museum_y_qq),.rgb_in(fire_map_rgb),.rgb_out(live_map_rgb));
    end else begin assign live_map_rgb=fire_map_rgb;end endgenerate
    wire [23:0] fire_control_rgb,ticker_rgb;
    generate if(DUAL_EXTENSIONS)begin: fire_control_strip
      console_status_card #(.COMPACT(1)) card(.x(museum_x_qq),.y(museum_y_qq),
        .status_valid(console_proxy_valid&&live_map_active),.status(console_proxy_status),
        .rgb_in(ticker_rgb),.rgb_out(fire_control_rgb));
    end else begin assign fire_control_rgb=ticker_rgb;end endgenerate
    generate if(V5_CONTROLS&&COMPACT_SCENES&&WIDTH>=640&&HEIGHT>=480)begin: disaster_ticker
        alarm_disaster_ticker #(.SHOW_LOCATION(0)) ticker(.clk(clk),.rst(rst),.frame_tick(scene_tick),
            .enable(alarm_active&&!alarm_cancel_notice),.kind(alarm_kind),
            .evacuation(alarm_evacuation),.drill(alarm_drill),
            .x(museum_x_qq),.y(museum_y_qq),.rgb_in(live_map_rgb),.rgb_out(ticker_rgb));
    end else begin: no_disaster_ticker
        assign ticker_rgb=live_map_rgb;
    end endgenerate
    wire [23:0] local_status_rgb,local_daily_rgb;

    wire banner_pixel, text_pixel, osd_pixel, waveform_pixel, waveform_panel;
    wire automatic_waveform=V5_CONTROLS&&(alarm_active||alarm_cancel_notice);
    reg waveform_pixel_q,waveform_panel_q;
    always @(posedge clk or posedge rst)
        if(rst)begin waveform_pixel_q<=0;waveform_panel_q<=0;end
        else begin waveform_pixel_q<=waveform_pixel;waveform_panel_q<=waveform_panel;end
    wire route_waveform_exclusion=BOARD_ROUTE_AUTHORITY&&scene_visible&&!scene_cancel&&route_stage&&
        (map_foreground||route_segment_id!=0||route_blocked_exit_pixel||route_overlay_valid);
    wire [23:0] emergency_wave_rgb=waveform_panel_q&&!route_waveform_exclusion&&!fire_map_active&&!live_map_active ?
        (waveform_pixel_q ? 24'h40ff70 : 24'h142b3c) : fire_control_rgb;
    reg [7:0] console_confirmation_frame;
    reg console_evacuation_frame;
    always @(posedge clk or posedge rst)
        if(rst)begin console_confirmation_frame<=0;console_evacuation_frame<=0;end
        else if(frame_tick)begin
            console_confirmation_frame<=console_proxy_valid ?
                {console_proxy_status[75],console_proxy_status[53],
                 console_proxy_status[63:61],console_proxy_status[55:54],console_proxy_status[94]} : 8'd0;
            console_evacuation_frame<=console_proxy_valid&&console_proxy_status[80];
        end
    wire [47:0] audio_health;wire audio_health_fresh;

    assign audio_health=48'd0;
    assign audio_health_fresh=1'b0;
    wire [103:0] remote_rows;
    wire remote_rows_valid;
    generate if(DUAL_EXTENSIONS)begin: status_from_b
      remote_status_rows row_receiver(.clk(clk),.rst(rst),.frame_tick(frame_tick),
       .message_valid(service_valid),.message_type(service_type),.payload(service_payload),
       .rows(remote_rows),.valid(remote_rows_valid));
    end else begin assign remote_rows=0;assign remote_rows_valid=0;end endgenerate
    wire map_status_hidden=fire_map_active||live_map_active;
    assign remote_ui_context={2'd0,audio_test_mode,(overlay_enable||automatic_waveform)&&
        !(scene_opacity!=0&&!scene_cancel&&route_stage)&&!map_status_hidden,
        (scene_opacity==0)&&console_evacuation_frame,(scene_opacity==0)&&scene_media_error,
        (scene_opacity!=0)&&scene_local_fire&&!map_status_hidden,V5_CONTROLS!=0,
        console_confirmation_frame,map_status_hidden ? 16'd0 : scene_panel_status,
        scene_opacity!=0 ? 16'd0 : scene_extended_status,map_status_hidden ? 16'd0 : scene_local_status};
    generate if(COMPACT_SCENES)begin: shared_scene_status
        wire [23:0] shared_rgb;
        wire page_visible=scene_opacity!=0;
        if(DUAL_EXTENSIONS)begin: remote_render
          remote_status_overlay #(.EXTENSIONS(1),.CLEAN_PRESENTATION(1)) status(.rst(rst),.link_ready(remote_rows_valid),
           .health_enable(diagnostic_active&&!map_status_hidden),.health_fresh(audio_health_fresh),.health(audio_health),.clk(clk),.x(museum_x_q),.y(museum_y_q),
           .enable(V5_CONTROLS!=0),.remote_confirmation(console_confirmation_frame),.remote_rows(remote_rows),
           .rgb_in(page_visible ? emergency_wave_rgb : proxy_rgb),.rgb_out(shared_rgb));
        end else begin: local_render
        local_status_overlay #(.REGISTERED(1),.MODERN_UI(1),.SIMPLE_DEMO(SIMPLE_DEMO)) status(.clk(clk),.x(museum_x_qq),.y(museum_y_qq),
            .enable(V5_CONTROLS!=0),.panel_status(fire_map_active ? 16'd0 : scene_panel_status),
            .fire_visible(page_visible&&scene_local_fire&&!fire_map_active),
            .remote_evacuation_selected(!page_visible&&console_evacuation_frame),
            .remote_confirmation(console_confirmation_frame),
            .quality_status(page_visible ? 16'd0 : scene_extended_status),
            .media_fault(!page_visible&&scene_media_error),.status(fire_map_active ? 16'd0 : scene_local_status),
            .waveform_status({audio_test_mode,(overlay_enable||automatic_waveform)&&
                !(page_visible&&!scene_cancel&&route_stage)&&!fire_map_active}),
            .rgb_in(page_visible ? emergency_wave_rgb : proxy_rgb),.rgb_out(shared_rgb));
        end
        assign local_status_rgb=shared_rgb;
        assign local_daily_rgb=shared_rgb;
    end else begin: blended_scene_status
    local_status_overlay local_emergency_status(.x(museum_x_qq),.y(museum_y_qq),
        .enable(V5_CONTROLS!=0),.fire_visible(scene_local_fire),
        .remote_evacuation_selected(1'b0),
        .remote_confirmation(console_confirmation_frame),
        .quality_status(16'd0),
        .media_fault(1'b0),
        .waveform_status(2'd0),
        .status(scene_local_status),.rgb_in(routed_rgb),.rgb_out(local_status_rgb));
    local_status_overlay local_daily_status(.x(museum_x_qq),.y(museum_y_qq),
        .enable(V5_CONTROLS!=0),.fire_visible(1'b0),
        .remote_evacuation_selected(console_evacuation_frame),
        .remote_confirmation(console_confirmation_frame),
        .quality_status(scene_extended_status),
        .media_fault(scene_media_error),
        .waveform_status({audio_test_mode,overlay_enable&&!scene_visible}),
        .status(scene_local_status),.rgb_in(proxy_rgb),.rgb_out(local_daily_rgb));
    end endgenerate
    reg [23:0] scene_base_q,scene_page_q;
    wire [23:0] scene_rgb_q;
    reg [6:0] scene_opacity_q;
    reg scene_valid_q,scene_user_q,scene_last_q;
    reg scene_valid_qq,scene_user_qq,scene_last_qq;
    wire [23:0] scene_blended_rgb;
    generate if(COMPACT_SCENES)begin: immediate_scene

        assign scene_blended_rgb=local_daily_rgb;
    end else begin: faded_scene
    dual_source_blend scene_blend(.old_rgb(scene_base_q),.new_rgb(scene_page_q),
        .progress(scene_opacity_q),.crossfade(1'b1),.select_new(1'b1),
        .enable(1'b1),.rgb(scene_blended_rgb));
    end endgenerate

    always @(posedge clk)begin
        scene_base_q<=local_daily_rgb;scene_page_q<=local_status_rgb;
        scene_opacity_q<=scene_opacity;
    end

    generate if(FINAL_SUBTITLES)begin: final_subtitles
        reg [10:0] x_q,y_q;
        always @(posedge clk)begin x_q<=museum_x_qq;y_q<=museum_y_qq;end
        if(DAILY_SCROLL_SUBTITLES)begin: scrolling
        daily_subtitle_overlay #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) subtitles(
            .clk(clk),.rst(rst),.frame_tick(frame_tick),.active(daily_subtitle_active),
            .track(daily_subtitle_track),.elapsed_samples(daily_subtitle_samples),
            .x(x_q),.y(y_q),.subtitle_id(narration_subtitle),
            .rgb_in(scene_blended_rgb),.rgb_out(scene_rgb_q));
        end else begin: static_caption
        subtitle_overlay_renderer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) subtitles(
            .clk(clk),.x(x_q),.y(y_q),.subtitle_id(narration_subtitle),
            .rgb_in(scene_blended_rgb),.rgb_out(scene_rgb_q));
        end
    end else begin: final_pixel_register
        reg [23:0] rgb_q;
        always @(posedge clk)rgb_q<=scene_blended_rgb;
        assign scene_rgb_q=rgb_q;
    end endgenerate
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            scene_valid_q<=0;scene_user_q<=0;scene_last_q<=0;
            scene_valid_qq<=0;scene_user_qq<=0;scene_last_qq<=0;
        end else begin
            scene_valid_q<=active_qqq;scene_user_q<=user_qqq;scene_last_q<=last_qqq;
            scene_valid_qq<=scene_valid_q;scene_user_qq<=scene_user_q;scene_last_qq<=scene_last_q;
        end
    end
    wire [23:0] quality_rgb;
    wire [7:0] quality_low_cut,quality_high_cut;
    wire quality_lut_ready;
    wire signed [8:0] quality_brightness=brightness_level==0 ? -9'sd32 :
        (brightness_level==1 ? -9'sd16 :
        (brightness_level==3 ? 9'sd16 :
        (brightness_level>=4 ? 9'sd32 : 9'sd0)));
    wire [7:0] quality_contrast=contrast_level==0 ? 8'd96 :
        (contrast_level==1 ? 8'd112 :
        (contrast_level==3 ? 8'd144 :
        (contrast_level>=4 ? 8'd160 : 8'd128)));
    image_quality_engine #(.FRAME_PIXELS(WIDTH*HEIGHT),.SEPARATE_STATS(1),.SMOOTH_PARAMETERS(!COMPACT_SCENES),
        .ENABLE_STATISTICS(!COMPACT_SCENES)) quality(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.pixel_valid(active_d),
        .enable(quality_enable),.alarm_bypass(1'b0),.rgb_in(raw_rgb),
        .histogram_rgb(raw_rgb),.histogram_valid(active_d&&good_d&&!alarm_active),
        .target_brightness(quality_brightness),
        .target_contrast_q7(quality_contrast),.gamma_mode(gamma_mode),
        .temperature_mode(temperature_mode),
        .auto_contrast_enable(quality_auto_enable),
        .histogram_query(8'd128),.histogram_column(quality_histogram_column),
        .histogram_value(quality_histogram_value),
        .histogram_column_value(quality_histogram_column_value),
        .low_cut(quality_low_cut),.high_cut(quality_high_cut),.lut_ready(quality_lut_ready),
        .rgb_out(quality_rgb));

    video_effects #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ENABLE(ENABLE_EFFECTS),.LUT_ONLY(DUAL_SOURCE),
        .V5_CONTROLS(V5_CONTROLS),.AUXILIARY_OVERLAY(!COMPACT_SCENES),
        .WAVEFORM_OVERLAY(1),.FRAME_CAPTURE(COMPACT_SCENES)) effects(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.x(museum_x),.y(museum_y),
        .image_index(image_index),.fade_gain(DUAL_SOURCE ? 5'd16 : fade_gain),
        .transition_mode(DUAL_SOURCE ? 3'd2 : transition_mode),
        .zoom_mode(zoom_mode),
        .zoom_scale(zoom_scale),
        .grayscale_enable(grayscale_enable),
        .overlay_enable(overlay_enable||automatic_waveform),
        .brightness_level(brightness_level),.contrast_level(contrast_level),
        .saturation_level(saturation_level),.osd_visible(osd_visible),
        .gamma_mode(gamma_mode),.temperature_mode(temperature_mode),.quality_selection(quality_selection),
        .volume_level(volume_level),.flash_rate(flash_rate),.flash_duty(flash_duty),
        .audio_peak_absolute(audio_peak_absolute),
        .audio_limited_count(audio_limited_count),.audio_clipped_count(audio_clipped_count),
        .transition_settings(transition_settings),
        .color_lut_active(DUAL_SOURCE ? 1'b0 : quality_enable),
        .audio_sample_valid(audio_sample_valid),.audio_sample(audio_sample),
        .rgb_in(quality_rgb),.rgb_out(effected_rgb),.scroll_position(scroll_position),
        .banner_pixel(banner_pixel),.text_pixel(text_pixel),.osd_pixel(osd_pixel),
        .waveform_pixel(waveform_pixel),.waveform_panel(waveform_panel));
    generate
        if (FIXED_RATE_AXIS) begin: vendor_fixed_rate_axis

            assign axis_valid=scene_valid_qq;
            assign axis_user=scene_user_qq;
            assign axis_last=scene_last_qq;
            assign axis_data=scene_rgb_q;
            assign overflow=1'b0;
        end else begin: elastic_axis
            wire [25:0] fifo_in = {scene_user_qq,scene_last_qq,scene_rgb_q};
            wire [25:0] fifo_out;
            assign {axis_user,axis_last,axis_data} = fifo_out;
            axis_fifo video_elastic(.clk(clk),.rst(rst),.push(scene_valid_qq),.push_data(fifo_in),
                .overflow(overflow),.valid(axis_valid),.ready(axis_ready),.data(fifo_out));
        end
    endgenerate
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h<=0; v<=0; ready_sync<=0; ack_sync<=0; ack_seen<=0;
            display_enabled<=0; line_req_toggle<=0; line_image<=0; line_row<=0; line_bank<=0;
            line_second_image<=0;line_split<=0;line_horizontal_slide<=0;line_zoom<=0;
            line_dual<=0;
            bank_valid<=0; tag_image0<=0; tag_image1<=0; tag_row0<=0; tag_row1<=0;
            tag_second_image0<=0;tag_second_image1<=0;tag_split0<=0;tag_split1<=0;
            tag_horizontal_slide<=0;tag_zoom0<=0;tag_zoom1<=0;
            line_good<=0; active_d<=0; user_d<=0; last_d<=0; good_d<=0;
            x_d<=0;y_d<=0;background_d<=0;underflow<=0;
            active_q<=0;user_q<=0;last_q<=0;active_qq<=0;user_qq<=0;last_qq<=0;
            active_qqq<=0;user_qqq<=0;last_qqq<=0;
            museum_x_q<=0;museum_y_q<=0;
            museum_x_qq<=0;museum_y_qq<=0;
        end else begin
            ready_sync <= {ready_sync[0],cache_ready};
            ack_sync <= {ack_sync[0],line_ack_toggle};
            if (h==HTOTAL-1) begin
                h<=0;
                if (v==VTOTAL-1) v<=0; else v<=v+1'b1;
            end else h<=h+1'b1;
            if (!ready_sync[1]) begin
                display_enabled<=0;
                bank_valid<=0;
            end else if (frame_tick) display_enabled<=1;
            if (ack_sync[1]!=ack_seen) begin
                ack_seen<=ack_sync[1];
                bank_valid[line_bank]<=1;
                if (line_bank) begin
                    tag_image1<=line_image;tag_row1<=line_row;
                    tag_second_image1<=line_second_image;tag_split1<=line_split;
                    tag_horizontal_slide[1]<=line_horizontal_slide;tag_zoom1<=line_zoom;
                end else begin
                    tag_image0<=line_image;tag_row0<=line_row;
                    tag_second_image0<=line_second_image;tag_split0<=line_split;
                    tag_horizontal_slide[0]<=line_horizontal_slide;tag_zoom0<=line_zoom;
                end
            end
            if (ready_sync[1] && display_enabled && h==2 &&
                    (v==0 || (v>=VSTART && v<VSTART+HEIGHT-1))) begin
                if (line_req_toggle==ack_sync[1]) begin
                    line_image<=request_line_image;
                    line_row<=request_line_row;
                    line_second_image<=transition_target;
                    line_dual<=DUAL_SOURCE && slide_active;
                    line_split<=horizontal_split;
                    line_horizontal_slide<=horizontal_slide;
                    line_zoom<=sample_scale;
                    line_bank<=v==0 ? 1'b0 : !y[0];
                    line_req_toggle<=!line_req_toggle;
                end else underflow<=1;
            end
            if (h==HSTART-2) begin
                line_good<=display_enabled && tag_matches;
                if (ready_sync[1] && display_enabled &&
                        v>=VSTART && v<VSTART+HEIGHT && !tag_matches) underflow<=1;
            end
            active_d<=active;
            user_d<=active && x==0 && y==0;
            last_d<=active && x==WIDTH-1;
            active_q<=active_d;
            user_q<=user_d;
            last_q<=last_d;
            active_qq<=active_q;
            user_qq<=user_q;
            last_qq<=last_q;
            active_qqq<=active_qq;
            user_qqq<=user_qq;
            last_qqq<=last_qq;
            museum_x_q<=museum_x;
            museum_y_q<=museum_y;
            museum_x_qq<=museum_x_q;museum_y_qq<=museum_y_q;
            good_d<=line_good;
            x_d<=x;y_d<=y;

            background_d<=display_enabled ? 24'h800080 : (x[6]^y[6] ? 24'h203050 : 24'h102030);
        end
    end
endmodule
