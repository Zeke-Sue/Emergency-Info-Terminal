// B板顶层：连接操作面板、事件控制、路线求解与PCM频谱分析。
`timescale 1ns/1ps
module duty_console_top #(
    parameter integer CLK_HZ=50000000,
    parameter integer BAUD=115200,
    parameter integer RESET_CYCLES=1048575,
    parameter integer DEBOUNCE_CYCLES=500000,
    parameter integer LONG_CYCLES=2*CLK_HZ,
    parameter integer DISPLAY_SCAN_DIV=25000,
    parameter integer LINK_TIMEOUT_MS=3000,
    parameter integer ACK_TIMEOUT_MS=500,
    parameter integer CONFIRM_HOLD_MS=2000,
    parameter integer SINGLE_CARD_AUDIO=1,
    parameter integer SIMPLE_DEMO=1,
    parameter integer DUAL_EXTENSIONS=1,

    parameter integer ENABLE_MAINTENANCE_HDMI=0
)(
    input wire clk,input wire key1,input wire key2,input wire key3,input wire key4,
    input wire sw1,input wire sw2,input wire sw3,input wire sw4,
    input wire console_uart_rx,output wire console_uart_tx,
    input wire extension_pcm_rx,
    output wire sd_ncs,output wire sd_dclk,output wire sd_mosi,
    input wire sd_miso,
    output wire flash_cs_n,output wire flash_sclk,output wire flash_mosi,
    input wire flash_miso,output wire flash_wp_n,output wire flash_hold_n,
    output wire [5:0] seg_sel,output wire [7:0] seg_data,
    output wire HDMI_CLK_P,output wire HDMI_D2_P,
    output wire HDMI_D1_P,output wire HDMI_D0_P,
    output wire HDMI_DDC_SCL,inout wire HDMI_DDC_SDA
);
    localparam integer RESET_BITS=RESET_CYCLES<2 ? 1 : $clog2(RESET_CYCLES+1);
    localparam integer US_DIV=CLK_HZ/1000000;
    localparam integer MS_DIV=CLK_HZ/1000;
    localparam integer US_BITS=US_DIV<2 ? 1 : $clog2(US_DIV);
    localparam integer MS_BITS=MS_DIV<2 ? 1 : $clog2(MS_DIV);
    reg [RESET_BITS-1:0] reset_count=0;
    wire rst=reset_count!=RESET_CYCLES;
    always @(posedge clk)if(rst)reset_count<=reset_count+1'b1;
    reg [US_BITS-1:0] us_count;
    reg [MS_BITS-1:0] ms_count;
    reg us_tick,ms_tick;
    always @(posedge clk or posedge rst)begin
        if(rst)begin us_count<=0;ms_count<=0;us_tick<=0;ms_tick<=0;end
        else begin
            us_tick<=0;ms_tick<=0;
            if(us_count==US_DIV-1)begin us_count<=0;us_tick<=1;end
            else us_count<=us_count+1'b1;
            if(ms_count==MS_DIV-1)begin ms_count<=0;ms_tick<=1;end
            else ms_count<=ms_count+1'b1;
        end
    end
    wire [3:0] key_press,key_short,key_long,key_held;
    reg [3:0] switch_meta,switch_sync;
    always @(posedge clk or posedge rst)
        if(rst)begin switch_meta<=0;switch_sync<=0;end
        else begin switch_meta<={sw4,sw3,sw2,sw1};switch_sync<=switch_meta;end
    key_events_shared #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.LONG_CYCLES(LONG_CYCLES)) keys(
        .clk(clk),.rst(rst),.key_n({key4,key3,key2,key1}),.press(key_press),
        .short_release(key_short),.long_press(key_long),.held(key_held));

    wire sd_ready,sd_sector_req,sd_sector_valid,sd_sector_end;
    wire [31:0] sd_sector_lba;wire [7:0] sd_sector_data;
    wire admission_valid,admission_pass,admission_mounted,admission_busy;
    wire [3:0] admission_reason,admission_error,admission_result_index;
    wire [4:0] admission_wav_count,admission_completed_count;
    wire [15:0] admission_certificate_bitmap,admission_pass_bitmap;
    wire [31:0] admission_length,admission_crc32;
    wire [7:0] admission_purpose;wire [15:0] admission_version;
    wire [95:0] admission_certificate;wire admission_certificate_valid;
    wire live_pcm_valid,live_context_valid,live_pcm_alive,live_pcm_gap;
    wire [15:0] live_pcm;wire [127:0] live_context;
    pcm_context_rx #(.CLK_HZ(CLK_HZ)) pcm_link(.clk(clk),.rst(rst),.rx(extension_pcm_rx),
      .sample_valid(live_pcm_valid),.sample(live_pcm),.context(live_context),
      .context_valid(live_context_valid),.link_alive(live_pcm_alive),.discontinuity(live_pcm_gap));
    wire file_spectrum_valid,file_transform_done,file_analysis_start,file_sample_valid;
    wire [5:0] file_spectrum_bin;wire [15:0] file_spectrum_magnitude;
    wire [23:0] file_peak;wire [3:0] file_analysis_index;
    generate if(!SINGLE_CARD_AUDIO)begin: dual_card_analysis
    sd_card_top #(.SPI_LOW_SPEED_DIV(123),.SPI_HIGH_SPEED_DIV(0)) card(
        .clk(clk),.rst(rst),.SD_nCS(sd_ncs),.SD_DCLK(sd_dclk),
        .SD_MOSI(sd_mosi),.SD_MISO(sd_miso),.sd_init_done(sd_ready),
        .sd_sec_read(sd_sector_req),.sd_sec_read_addr(sd_sector_lba),
        .sd_sec_read_data(sd_sector_data),
        .sd_sec_read_data_valid(sd_sector_valid),.sd_sec_read_end(sd_sector_end),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),
        .sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
    console_wav_admission_pipeline #(.CLK_HZ(CLK_HZ),.MAX_AUDIO_FILES(15),
        .DEPLOYMENT_PROFILES(1),.STRICT_CHAIN(1),.FIXED_PLAYLIST(1),.ENABLE_IMA(0)) admission(.clk(clk),.rst(rst),
        .start_ready(!rst),.sd_ready(sd_ready),.reload(1'b0),
        .trajectory_error(1'b0),.purpose(8'h21),
        .sector_req(sd_sector_req),.sector_lba(sd_sector_lba),
        .sector_data(sd_sector_data),.sector_valid(sd_sector_valid),
        .sector_end(sd_sector_end),.result_valid(admission_valid),
        .admitted(admission_pass),.reason(admission_reason),
        .admitted_length(admission_length),.admitted_crc32(admission_crc32),
        .admitted_purpose(admission_purpose),.admitted_version(admission_version),
        .certificate(admission_certificate),
        .certificate_valid(admission_certificate_valid),
        .result_index(admission_result_index),
        .completed_count(admission_completed_count),
        .certificate_valid_bitmap(admission_certificate_bitmap),
        .admitted_bitmap(admission_pass_bitmap),.mounted(admission_mounted),
        .wav_count(admission_wav_count),.busy(admission_busy),
        .error_code(admission_error),.spectrum_valid(file_spectrum_valid),
        .spectrum_bin(file_spectrum_bin),.spectrum_magnitude(file_spectrum_magnitude),
        .transform_done(file_transform_done),.peak_frequency_q8(file_peak),
        .analysis_start(file_analysis_start),.analysis_sample_valid(file_sample_valid),
        .analysis_file_index(file_analysis_index));
    end else begin: single_card_control
        assign sd_ncs=1'b1;assign sd_dclk=1'b0;assign sd_mosi=1'b1;
        assign sd_ready=0;assign sd_sector_valid=0;assign sd_sector_end=0;
        assign sd_sector_data=0;assign sd_sector_req=0;assign sd_sector_lba=0;

        assign admission_valid=0;assign admission_pass=0;assign admission_mounted=0;
        assign admission_busy=0;assign admission_reason=0;assign admission_error=0;
        assign admission_result_index=0;assign admission_wav_count=0;
        assign admission_completed_count=0;assign admission_certificate_bitmap=0;
        assign admission_pass_bitmap=0;assign admission_length=0;assign admission_crc32=0;
        assign admission_purpose=0;assign admission_version=0;assign admission_certificate=0;
        assign admission_certificate_valid=0;
        if(DUAL_EXTENSIONS)begin: live_analysis
          stft_512_fft analyzer(.clk(clk),.rst(rst||!live_pcm_alive||live_pcm_gap),
            .sample_tick(live_pcm_valid),.sample_in(live_pcm),
            .spectrum_valid(file_spectrum_valid),.spectrum_bin(file_spectrum_bin),
            .spectrum_magnitude(file_spectrum_magnitude),.transform_done(file_transform_done),
            .peak_frequency_q8(file_peak),.busy(),.full_bin_valid(),.full_bin_index(),.full_bin_magnitude(),.overrun());
          assign file_analysis_start=live_pcm_gap;assign file_sample_valid=live_pcm_valid;
          assign file_analysis_index=0;
        end else begin
          assign file_spectrum_valid=0;assign file_transform_done=0;
          assign file_analysis_start=0;assign file_sample_valid=0;
          assign file_spectrum_bin=0;assign file_spectrum_magnitude=0;
          assign file_peak=0;assign file_analysis_index=0;
        end
    end endgenerate

    wire command_request,command_ready,command_byte_valid,command_byte_ready;
    wire status_request_ready,status_byte_valid,status_byte_ready;
    wire [7:0] status_byte;
    wire [7:0] command_byte;
    wire tx_byte_valid,tx_byte_ready;wire [7:0] tx_byte;
    wire [1:0] request_action,request_source;
    wire [31:0] request_session,request_sequence;
    wire [15:0] request_event_id,request_remaining;
    wire [7:0] request_event_sequence;
    wire [2:0] request_level,request_region,request_kind;
    wire request_drill,request_pending,request_trusted;
    wire snapshot_valid,snapshot_ready;
    wire [95:0] snapshot_payload;
    wire [31:0] snapshot_session,snapshot_sequence;
    console_status_framer #(.DYNAMIC_TYPE(1),.EXTERNAL_IDENTITY(1),
        .STABLE_EXTERNAL_SESSION(1)) framer(
        .clk(clk),.rst(rst),.request_valid(snapshot_valid),.request_ready(snapshot_ready),
        .request_type(8'h26),.request_payload(snapshot_payload),
        .request_session(snapshot_session),.request_sequence(snapshot_sequence),
        .byte_valid(command_byte_valid),.byte_ready(command_byte_ready),
        .byte_data(command_byte));
    uart_tx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) transmitter(.clk(clk),.rst(rst),
        .data(tx_byte),.valid(tx_byte_valid),.ready(tx_byte_ready),
        .tx(console_uart_tx));

    wire [7:0] reply_byte;wire reply_byte_valid,reply_framing_error;
    uart_rx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) receiver(.clk(clk),.rst(rst),
        .rx(console_uart_rx),.data(reply_byte),.valid(reply_byte_valid),
        .framing_error(reply_framing_error));
    wire ack_valid,heartbeat_valid,heartbeat_alarm,latency_valid,finish_valid;
    wire [3:0] ack_result,heartbeat_active_count,finish_reason;
    wire [31:0] ack_session,ack_sequence;
    wire [2:0] heartbeat_level;
    wire [7:0] heartbeat_blocked_set;
    wire [31:0] heartbeat_boot_count,heartbeat_session;
    wire [23:0] pixel_latency_us,audio_latency_us;
    wire telemetry_valid;
    wire [15:0] telemetry_last_line,telemetry_max_line;
    wire [15:0] telemetry_video_underflows,telemetry_uart_errors;
    wire reply_frame_error,reply_crc_error;
    console_reply_parser replies(.clk(clk),.rst(rst),.byte_valid(reply_byte_valid),
        .byte_data(reply_byte),.us_tick(us_tick),.ack_valid(ack_valid),
        .ack_result(ack_result),.ack_session(ack_session),.ack_sequence(ack_sequence),
        .heartbeat_valid(heartbeat_valid),.remote_alarm(heartbeat_alarm),
        .remote_level(heartbeat_level),.remote_active_count(heartbeat_active_count),
        .remote_blocked_set(heartbeat_blocked_set),.remote_boot_count(heartbeat_boot_count),
        .remote_session(heartbeat_session),
        .telemetry_valid(telemetry_valid),.telemetry_last_line(telemetry_last_line),
        .telemetry_max_line(telemetry_max_line),
        .telemetry_video_underflows(telemetry_video_underflows),
        .telemetry_uart_errors(telemetry_uart_errors),
        .latency_valid(latency_valid),
        .pixel_latency_us(pixel_latency_us),.audio_latency_us(audio_latency_us),
        .finish_valid(finish_valid),.finish_reason(finish_reason),
        .frame_error(reply_frame_error),.crc_error(reply_crc_error));

    wire [2:0] selected_level,selected_region,remote_level;
    wire [1:0] selected_action,selected_role;
    wire selected_evacuation;
    wire confirmation_armed,confirmation_expired;
    wire [4:0] confirmation_progress;
    wire [1:0] request_role;
    wire link_alive,ack_pending,permission_denied,error_latched,remote_alarm;
    wire [3:0] last_ack_result,remote_active_count;
    wire [7:0] remote_blocked_set;
    wire user_ack_valid,event_recovery_required;
    wire [3:0] user_ack_result;
    wire [31:0] user_ack_session,user_ack_sequence;
    wire [63:0] authoritative_event;
    wire [7:0] authoritative_blocked;
    console_event_authority #(.FRAME_CYCLES((CLK_HZ/62500)*1050),.CHECK_ROLE(1)) authority(
        .clk(clk),.rst(rst),.ms_tick(ms_tick),
        .request_valid(command_request),.request_ready(command_ready),
        .request_action(request_action),.request_source(request_source),
        .request_session(request_session),.request_sequence(request_sequence),
        .request_event_id(request_event_id),.request_remaining(request_remaining),
        .request_event_sequence(request_event_sequence),.request_level(request_level),
        .request_region(request_region),.request_kind(request_kind),
        .request_drill(request_drill),.request_pending(request_pending),.request_trusted(request_trusted),
        .request_role(request_role),
        .ack_valid(ack_valid),.ack_result(ack_result),.ack_session(ack_session),.ack_sequence(ack_sequence),
        .heartbeat_valid(heartbeat_valid),.remote_boot(heartbeat_boot_count),
        .remote_session(heartbeat_session),
        .user_ack_valid(user_ack_valid),.user_ack_result(user_ack_result),
        .user_ack_session(user_ack_session),.user_ack_sequence(user_ack_sequence),
        .snapshot_valid(snapshot_valid),.snapshot_ready(snapshot_ready),.snapshot_payload(snapshot_payload),
        .snapshot_session(snapshot_session),.snapshot_sequence(snapshot_sequence),
        .authoritative_event(authoritative_event),.blocked_set(authoritative_blocked),
        .recovery_required(event_recovery_required));
    duty_console_core #(.LINK_TIMEOUT_MS(LINK_TIMEOUT_MS),
        .ACK_TIMEOUT_MS(ACK_TIMEOUT_MS),.CONFIRM_HOLD_MS(CONFIRM_HOLD_MS),.V5_CONTROLS(1),.SIMPLE_ACTIONS(SIMPLE_DEMO)) control(.clk(clk),.rst(rst),.ms_tick(ms_tick),
        .key_press(key_short),.key_long_press(key_long),.key_held(key_held),
        .switches(switch_sync),
        .request_valid(command_request),.request_ready(command_ready),
        .request_action(request_action),.request_source(request_source),
        .request_session(request_session),.request_sequence(request_sequence),
        .request_event_id(request_event_id),.request_event_sequence(request_event_sequence),
        .request_level(request_level),.request_drill(request_drill),
        .request_pending(request_pending),.request_region(request_region),
        .request_time_trusted(request_trusted),.request_remaining_seconds(request_remaining),
        .request_kind(request_kind),.ack_valid(user_ack_valid),.ack_result(user_ack_result),
        .request_role(request_role),.confirmation_armed(confirmation_armed),
        .confirmation_progress(confirmation_progress),.confirmation_expired(confirmation_expired),
        .ack_session(user_ack_session),.ack_sequence(user_ack_sequence),
        .heartbeat_valid(heartbeat_valid),.heartbeat_alarm(heartbeat_alarm),
        .heartbeat_level(heartbeat_level),.heartbeat_active_count(heartbeat_active_count),
        .heartbeat_blocked_set(heartbeat_blocked_set),
        .rx_frame_error(reply_frame_error|reply_framing_error),.rx_crc_error(reply_crc_error),
        .selected_level(selected_level),.selected_region(selected_region),
        .selected_action(selected_action),.selected_role(selected_role),
        .selected_evacuation(selected_evacuation),
        .link_alive(link_alive),.ack_pending(ack_pending),
        .last_ack_result(last_ack_result),.permission_denied(permission_denied),
        .error_latched(error_latched),.remote_alarm(remote_alarm),
        .remote_level(remote_level),.remote_active_count(remote_active_count),
        .remote_blocked_set(remote_blocked_set));
    reg link_alive_q;
    always @(posedge clk or posedge rst)
        if(rst)link_alive_q<=0;else link_alive_q<=link_alive;
    wire [31:0] authoritative_parameters={SINGLE_CARD_AUDIO ? 12'ha61 : 12'd0,
        2'd0,selected_role,selected_action,selected_level,selected_region,switch_sync,
        3'd0,SINGLE_CARD_AUDIO&&link_alive};
    wire sync_msg_valid,sync_msg_ready,sync_msg_last,sync_active,sync_done;
    wire [7:0] sync_msg_type;wire [15:0] sync_msg_batch;
    wire [95:0] sync_msg_payload;
    v41_resync_sender #(.CERTIFICATE_COUNT(15),.ENABLE_CERTIFICATES(!SINGLE_CARD_AUDIO)) resync_sender(.clk(clk),.rst(rst),
        .heartbeat_valid(heartbeat_valid),.remote_boot_count(heartbeat_boot_count),
        .force_resync((SINGLE_CARD_AUDIO&&(heartbeat_valid||link_alive!=link_alive_q))||admission_certificate_valid||
            (heartbeat_valid&&!link_alive)),
        .parameters(authoritative_parameters),.event_state(authoritative_event),
        .blocked_set(authoritative_blocked),
        .certificate_update_valid(admission_certificate_valid),
        .certificate_update_index(admission_result_index),
        .certificate_update(admission_certificate),
        .msg_valid(sync_msg_valid),.msg_ready(sync_msg_ready),
        .msg_type(sync_msg_type),.msg_batch(sync_msg_batch),
        .msg_payload(sync_msg_payload),.msg_last(sync_msg_last),
        .resync_active(sync_active),.resync_done(sync_done));
    wire sync_byte_valid,sync_byte_ready;wire [7:0] sync_byte;
    v41_record_framer resync_framer(.clk(clk),.rst(rst),
        .msg_valid(sync_msg_valid),.msg_ready(sync_msg_ready),
        .msg_type(sync_msg_type),.msg_batch(sync_msg_batch),
        .msg_payload(sync_msg_payload),.msg_last(sync_msg_last),
        .byte_valid(sync_byte_valid),.byte_ready(sync_byte_ready),
        .byte_data(sync_byte));
    reg [1:0] tx_grant;
    always @(posedge clk or posedge rst)begin
        if(rst)tx_grant<=0;
        else case(tx_grant)
            0:if(command_byte_valid)tx_grant<=1;
              else if(sync_byte_valid)tx_grant<=2;
              else if(status_byte_valid)tx_grant<=3;
            1:if(!command_byte_valid)tx_grant<=0;
            2:if(!sync_byte_valid)tx_grant<=0;
            3:if(!status_byte_valid)tx_grant<=0;
            default:tx_grant<=0;
        endcase
    end
    assign tx_byte_valid=tx_grant==1 ? command_byte_valid :
                         (tx_grant==2 ? sync_byte_valid :
                         (tx_grant==3 ? status_byte_valid : 1'b0));
    assign tx_byte=tx_grant==1 ? command_byte :
                   (tx_grant==2 ? sync_byte : status_byte);
    assign command_byte_ready=tx_grant==1&&tx_byte_ready;
    assign sync_byte_ready=tx_grant==2&&tx_byte_ready;
    assign status_byte_ready=tx_grant==3&&tx_byte_ready;
    duty_console_display #(.SCAN_DIV(DISPLAY_SCAN_DIV)) display(.clk(clk),.rst(rst),
        .link_alive(link_alive),.ack_pending(ack_pending),.error_latched(error_latched),
        .permission_denied(permission_denied),.remote_alarm(remote_alarm),
        .role(selected_role),.action(selected_action),.level(selected_level),
        .region(selected_region),.ack_result(last_ack_result),
        .seg_sel(seg_sel),.seg_data(seg_data));

    wire log_append_valid,log_append_ready;
    wire [1:0] log_category;wire [5:0] log_flags;
    wire [15:0] log_b_boot,log_dropped_count;
    wire [31:0] log_b_ms,log_a_boot,log_a_us,log_uptime_ms;
    wire [7:0] log_event_type;wire [55:0] log_payload;
    console_event_log_manager log_events(.clk(clk),.rst(rst),.ms_tick(ms_tick),
        .b_boot(16'd1),.a_boot(heartbeat_boot_count),
        .ack_valid(ack_valid),.ack_result(ack_result),.ack_session(ack_session),
        .ack_sequence(ack_sequence),.heartbeat_valid(heartbeat_valid),
        .heartbeat_alarm(heartbeat_alarm),.heartbeat_level(heartbeat_level),
        .heartbeat_active_count(heartbeat_active_count),
        .heartbeat_blocked_set(heartbeat_blocked_set),
        .telemetry_valid(telemetry_valid),.telemetry_last_line(telemetry_last_line),
        .telemetry_max_line(telemetry_max_line),
        .telemetry_video_underflows(telemetry_video_underflows),
        .telemetry_uart_errors(telemetry_uart_errors),.latency_valid(latency_valid),
        .pixel_latency_us(pixel_latency_us),.audio_latency_us(audio_latency_us),
        .finish_valid(finish_valid),.finish_reason(finish_reason),
        .admission_valid(admission_valid),.admission_pass(admission_pass),
        .admission_reason(admission_reason),.admission_purpose(admission_purpose),
        .admission_length(admission_length),.admission_version(admission_version),
        .append_ready(log_append_ready),
        .append_valid(log_append_valid),.category(log_category),.flags(log_flags),
        .log_b_boot(log_b_boot),.log_b_ms(log_b_ms),.log_a_boot(log_a_boot),
        .log_a_us(log_a_us),.event_type(log_event_type),.payload(log_payload),
        .dropped_count(log_dropped_count),.uptime_ms(log_uptime_ms));
    wire log_program_valid,log_program_ready,log_program_done,log_program_error;
    wire log_committed,log_failed;
    wire [23:0] log_program_address;wire [7:0] log_program_data;
    wire [15:0] log_next_sequence;wire [7:0] log_write_slot;
    wire log_restore_valid,log_transport_initialized;
    wire [15:0] log_restore_next_sequence;wire [7:0] log_restore_write_slot;
    console_log_journal #(.BASE_ADDRESS(24'h7fc000)) journal(.clk(clk),.rst(rst),
        .append_valid(log_append_valid),.append_ready(log_append_ready),
        .category(log_category),.flags(log_flags),.b_boot(log_b_boot),
        .b_ms(log_b_ms),.a_boot(log_a_boot),.a_us(log_a_us),
        .event_type(log_event_type),.payload(log_payload),
        .program_valid(log_program_valid),.program_ready(log_program_ready),
        .program_address(log_program_address),.program_data(log_program_data),
        .program_done(log_program_done),.program_error(log_program_error),
        .restore_valid(log_restore_valid),
        .restore_next_sequence(log_restore_next_sequence),
        .restore_write_slot(log_restore_write_slot),
        .committed_pulse(log_committed),.next_sequence(log_next_sequence),
        .write_slot(log_write_slot),.failed_pulse(log_failed));
    spi_nor_log_transport #(.CLK_DIV(2),.BASE_ADDRESS(24'h7fc000)) log_flash(
        .clk(clk),.rst(rst),.program_valid(log_program_valid),
        .program_ready(log_program_ready),.program_address(log_program_address),
        .program_data(log_program_data),.program_done(log_program_done),
        .program_error(log_program_error),.restore_valid(log_restore_valid),
        .restore_next_sequence(log_restore_next_sequence),
        .restore_write_slot(log_restore_write_slot),
        .initialized(log_transport_initialized),.flash_cs_n(flash_cs_n),
        .flash_sclk(flash_sclk),.flash_mosi(flash_mosi),.flash_miso(flash_miso),
        .flash_wp_n(flash_wp_n),.flash_hold_n(flash_hold_n));
    reg [7:0] log_transport_digest;
    always @(posedge clk or posedge rst)begin
        if(rst)log_transport_digest<=0;
        else if(log_program_valid&&log_program_ready)
            log_transport_digest<={log_transport_digest[6:0],log_transport_digest[7]}^
                log_program_data^log_program_address[7:0];
    end

    wire [95:0] status_payload={
        link_alive,ack_pending,(error_latched||event_recovery_required),permission_denied,remote_alarm,
            admission_busy,(admission_error!=0),log_transport_initialized,
        selected_role,selected_action,selected_level,selected_evacuation,
        last_ack_result,confirmation_armed,selected_region,
        admission_pass,(SINGLE_CARD_AUDIO ? 4'hf : admission_reason),admission_result_index[2:0],
        confirmation_progress[4:2],admission_completed_count,
        confirmation_progress[1:0],confirmation_expired,admission_wav_count,
        admission_pass_bitmap,log_next_sequence,log_dropped_count};
    reg status_request;
    reg [7:0] status_interval_ms;
    always @(posedge clk or posedge rst)begin
        if(rst)begin status_request<=0;status_interval_ms<=0;end
        else begin
            if((|key_press)||(|key_long)||admission_valid||log_committed)
                status_request<=1;
            else if(ms_tick)begin
                if(status_interval_ms==8'd199)begin
                    status_interval_ms<=0;status_request<=1;
                end else status_interval_ms<=status_interval_ms+1'b1;
            end else if(status_request&&status_request_ready)
                status_request<=0;
        end
    end
    wire ui_request;wire [95:0] ui_payload;
    wire spectrum_request,low_request_ready;
    wire health_request;wire [95:0] health_payload;
    generate if(DUAL_EXTENSIONS)begin: audio_diagnostics
      audio_health_packetizer #(.CLK_HZ(CLK_HZ)) health(.clk(clk),.rst(rst),
       .link_alive(live_pcm_alive),.sample_valid(live_pcm_valid),.sample(live_pcm),
       .test_active(live_context[77]),.page(live_context[76:72]),
       .transform_done(file_transform_done),.peak_frequency_q8(file_peak),
       .request_valid(health_request),.request_ready(low_request_ready&&!status_request&&!ui_request),
       .request_payload(health_payload));
    end else begin assign health_request=0;assign health_payload=0;end endgenerate
    generate if(DUAL_EXTENSIONS)begin: remote_ui
      status_rows_packetizer #(.CLK_HZ(CLK_HZ)) status_layout(.clk(clk),.rst(rst),
       .link_alive(live_pcm_alive),.context(live_context[63:0]),.request_valid(ui_request),
       .request_ready(low_request_ready&&!status_request),.request_payload(ui_payload));
    end else begin assign ui_request=0;assign ui_payload=0;end endgenerate
    wire route_request,route_busy,route_error;
    wire [7:0] route_type;wire [95:0] route_payload;
    reg route_boot_seen,route_turn;
    reg [31:0] route_boot;
    reg [12:0] route_refresh_ms;
    wire route_refresh=heartbeat_valid&&(!route_boot_seen||route_boot!=heartbeat_boot_count||!link_alive)||
        (ms_tick&&route_refresh_ms==4999);
    wire choose_route=route_request&&(!spectrum_request||route_turn);
    always @(posedge clk or posedge rst)begin
        if(rst)begin route_boot_seen<=0;route_boot<=0;route_refresh_ms<=0;route_turn<=1;end
        else begin
            if(heartbeat_valid)begin route_boot_seen<=1;route_boot<=heartbeat_boot_count;end
            if(ms_tick)route_refresh_ms<=route_refresh_ms==4999 ? 13'd0 : route_refresh_ms+1'b1;
            if(low_request_ready&&!status_request&&!ui_request&&!health_request&&(route_request||spectrum_request))route_turn<=!choose_route;
        end
    end
    generate if(DUAL_EXTENSIONS)begin: live_routes
      live_route_packetizer #(.CLK_HZ(CLK_HZ)) route_solver(.clk(clk),.rst(rst),
       .link_alive(live_pcm_alive),.blocked(live_context[71:64]),.request_valid(route_request),
       .request_ready(low_request_ready&&!status_request&&!ui_request&&!health_request&&choose_route),.request_payload(route_payload));
      assign route_type=8'h29;assign route_busy=0;assign route_error=0;
    end else if(!SIMPLE_DEMO)begin: routes_enabled
    n10_route_packetizer route_link(.clk(clk),.rst(rst),.refresh(route_refresh),
        .request_valid(route_request),.request_ready(low_request_ready&&!status_request&&!ui_request&&!health_request&&choose_route),
        .request_type(route_type),.request_payload(route_payload),.busy(route_busy),.error(route_error));
    end else begin: routes_removed
        assign route_request=0;assign route_type=0;assign route_payload=0;
        assign route_busy=0;assign route_error=0;
    end endgenerate
    wire [7:0] spectrum_type;wire [95:0] spectrum_payload;
    spectrum_packetizer spectrum_link(.clk(clk),.rst(rst),
        .file_start(file_analysis_start),.sample_valid(file_sample_valid),
        .file_index(file_analysis_index),.spectrum_valid(file_spectrum_valid),
        .spectrum_bin(file_spectrum_bin),.spectrum_magnitude(file_spectrum_magnitude),
        .transform_done(file_transform_done),.peak_frequency_q8(file_peak),
        .request_valid(spectrum_request),.request_ready(low_request_ready&&!status_request&&!ui_request&&!health_request&&!choose_route),
        .request_type(spectrum_type),.request_payload(spectrum_payload));
    assign status_request_ready=low_request_ready;
    console_status_framer #(.DYNAMIC_TYPE(1)) status_framer(.clk(clk),.rst(rst),
        .request_valid(status_request||ui_request||health_request||route_request||spectrum_request),.request_ready(low_request_ready),
        .request_type(status_request ? 8'h20 : ui_request ? 8'h27 : health_request ? 8'h2a : choose_route ? route_type : spectrum_type),
        .request_payload(status_request ? status_payload : ui_request ? ui_payload : health_request ? health_payload : choose_route ? route_payload : spectrum_payload),.byte_valid(status_byte_valid),
        .byte_ready(status_byte_ready),.byte_data(status_byte));

    generate if(ENABLE_MAINTENANCE_HDMI) begin: maintenance_hdmi
    wire pixel_clk,serial_clk,video_locked,pixel_rst;
    console_video_clock video_clock(.clk(clk),.pixel_clk(pixel_clk),
        .serial_clk(serial_clk),.locked(video_locked),.pixel_rst(pixel_rst));
    reg [101:0] video_status_s1,video_status_s2;
    reg [39:0] video_log_s1,video_log_s2;
    reg [39:0] video_admission_s1,video_admission_s2;
    always @(posedge pixel_clk or posedge pixel_rst)begin
        if(pixel_rst)begin video_status_s1<=0;video_status_s2<=0;
            video_log_s1<=0;video_log_s2<=0;
            video_admission_s1<=0;video_admission_s2<=0;end
        else begin
            video_status_s1<={link_alive,ack_pending,error_latched,
                permission_denied,remote_alarm,selected_role,selected_action,
                selected_level,selected_region,remote_level,remote_active_count,
                remote_blocked_set,pixel_latency_us,telemetry_max_line,
                telemetry_video_underflows,telemetry_uart_errors};
            video_status_s2<=video_status_s1;
            video_log_s1<={log_next_sequence,log_dropped_count,log_transport_digest};
            video_log_s2<=video_log_s1;
            video_admission_s1<={admission_busy,admission_completed_count,
                admission_wav_count,admission_pass_bitmap,admission_error,
                admission_reason,admission_result_index,admission_pass};
            video_admission_s2<=video_admission_s1;
        end
    end
    wire console_axis_valid,console_axis_user,console_axis_last,console_frame_tick;
    wire [23:0] console_axis_data;
    console_video_source video_source(.clk(pixel_clk),.rst(pixel_rst),
        .link_alive(video_status_s2[101]),.ack_pending(video_status_s2[100]),
        .error_latched(video_status_s2[99]),
        .permission_denied(video_status_s2[98]),.remote_alarm(video_status_s2[97]),
        .role(video_status_s2[96:95]),.action(video_status_s2[94:93]),
        .selected_level(video_status_s2[92:90]),
        .selected_region(video_status_s2[89:87]),
        .remote_level(video_status_s2[86:84]),
        .remote_active_count(video_status_s2[83:80]),
        .remote_blocked_set(video_status_s2[79:72]),
        .pixel_latency_us(video_status_s2[71:48]),
        .telemetry_max_line(video_status_s2[47:32]),
        .telemetry_video_underflows(video_status_s2[31:16]),
        .telemetry_uart_errors(video_status_s2[15:0]),
        .log_records(video_log_s2[39:24]),.log_dropped(video_log_s2[23:8]),
        .log_digest(video_log_s2[7:0]),
        .admission_busy(video_admission_s2[39]),
        .admission_completed(video_admission_s2[38:34]),
        .admission_total(video_admission_s2[33:29]),
        .admission_pass_bitmap(video_admission_s2[28:13]),
        .admission_error(video_admission_s2[12:9]),
        .admission_reason(video_admission_s2[8:5]),
        .axis_valid(console_axis_valid),.axis_user(console_axis_user),
        .axis_last(console_axis_last),.axis_data(console_axis_data),
        .frame_tick(console_frame_tick));
    reg [19:0] edid_count;
    wire edid_trigger=edid_count==20'd999999;
    always @(posedge pixel_clk or posedge pixel_rst)
        if(pixel_rst)edid_count<=0;
        else if(edid_count<20'd1000000)edid_count<=edid_count+1'b1;
    wire [9:0] tmds0,tmds1,tmds2,tmdsclk;
    hdmi_1_4b_transmitter_core_wrapper #(
        .DEVICE("EG"),.HTOTAL(800),.HSA(96),.HFP(16),.HBP(48),.HACTIVE(640),
        .VTOTAL(525),.VSA(2),.VFP(10),.VBP(33),.VACTIVE(480),
        .VIDEO_VIC(1),.VIDEO_TPG("Disable"),.VIDEO_FORMAT("RGB"),
        .AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(250)) hdmi(
        .I_pixel_clk(pixel_clk),.I_rst(pixel_rst),
        .I_edid_read_trig(edid_trigger),.O_edid_read_valid(),.O_edid_read_data(),
        .I_axis_s_user(console_axis_user),.I_axis_s_valid(console_axis_valid),
        .I_axis_s_last(console_axis_last),.I_axis_s_data(console_axis_data),
        .O_axis_s_ready(),.I_audio_valid(1'b0),.I_audio_left_data(24'd0),
        .I_audio_right_data(24'd0),.I_acr_valid(1'b0),.I_acr_cts(20'd0),
        .I_acr_n(20'd0),.O_video_locked(),.O_ddc_scl(HDMI_DDC_SCL),
        .IO_ddc_sda(HDMI_DDC_SDA),.O_ch0_tmds_data(tmds0),
        .O_ch1_tmds_data(tmds1),.O_ch2_tmds_data(tmds2),
        .O_clk_tmds_data(tmdsclk));
    hdmi_phy_wrapper #(.DEVICE("EG")) phy(.I_pixel_clk(pixel_clk),
        .I_serial_clk(serial_clk),.I_rst(pixel_rst),.I_tmds_channel_0(tmds0),
        .I_tmds_channel_1(tmds1),.I_tmds_channel_2(tmds2),
        .I_tmds_channel_clk(tmdsclk),.O_tmds_ch0_p(HDMI_D0_P),
        .O_tmds_ch1_p(HDMI_D1_P),.O_tmds_ch2_p(HDMI_D2_P),
        .O_tmds_clk_p(HDMI_CLK_P));
    end else begin: single_screen
        assign HDMI_CLK_P=1'b0;
        assign HDMI_D2_P=1'b0;
        assign HDMI_D1_P=1'b0;
        assign HDMI_D0_P=1'b0;
        assign HDMI_DDC_SCL=1'b1;
        assign HDMI_DDC_SDA=1'bz;
    end endgenerate
endmodule
