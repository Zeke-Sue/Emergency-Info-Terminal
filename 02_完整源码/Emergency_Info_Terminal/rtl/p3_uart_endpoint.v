`timescale 1ns/1ps

module p3_uart_endpoint #(
    parameter integer CLK_HZ=25000000,
    parameter integer CERTIFICATE_COUNT=10,
    parameter integer SINGLE_CARD_CONTROL=0,
    parameter integer BAUD=115200,
    parameter integer ENABLE_EVENT_SNAPSHOT=0
)(
    input wire clk,input wire rst,input wire rx,output wire tx,input wire us_tick,
    output wire command_valid,input wire command_ready,
    output reg [2:0] command_opcode,output reg [1:0] command_source,
    output reg [2:0] command_kind,output reg [15:0] command_event_id,
    output reg [7:0] command_sequence,output reg [2:0] command_level,
    output reg command_drill,output reg command_pending_flag,
    output reg [2:0] command_region,output reg command_time_trusted,
    output reg [15:0] command_remaining_seconds,
    output reg [32:0] command_snapshot,
    output reg command_epoch_changed,
    input wire command_result_valid,input wire [3:0] command_result_code,
    input wire latency_valid,input wire [23:0] pixel_latency_us,
    input wire [23:0] audio_latency_us,input wire finish_valid,
    input wire [3:0] finish_reason,input wire heartbeat_tick,
    input wire alarm_active,input wire [2:0] alarm_level,
    input wire [3:0] active_count,input wire [7:0] blocked_set,
    input wire [31:0] boot_count,
    input wire telemetry_tick,input wire [15:0] telemetry_last_line,
    input wire [15:0] telemetry_max_line,input wire [15:0] telemetry_video_underflows,
    input wire [15:0] telemetry_uart_errors,
    output wire service_valid,output wire [7:0] service_type,
    output wire [15:0] service_batch,output wire [95:0] service_payload,
    output wire service_last,
    output wire frame_error,output wire crc_error
);
    wire [7:0] rx_data;wire rx_valid,rx_framing_error;
    uart_rx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) receiver(
        .clk(clk),.rst(rst),.rx(rx),.data(rx_data),.valid(rx_valid),
        .framing_error(rx_framing_error));
    wire parsed_valid;wire [2:0] parsed_opcode,parsed_kind,parsed_level,parsed_region;
    wire [1:0] parsed_source_raw,parsed_source;
    wire [15:0] parsed_event_id,parsed_remaining;
    wire [15:0] parsed_event_id_raw;wire [2:0] parsed_level_raw;

    physical_hold_buffer #(.WIDTH(16)) event_id_hold(.d(parsed_event_id_raw),.q(parsed_event_id));
    physical_hold_buffer #(.WIDTH(3)) level_hold(.d(parsed_level_raw),.q(parsed_level));
    wire [7:0] parsed_sequence;wire parsed_drill,parsed_pending,parsed_trusted;
    wire [31:0] parsed_session,parsed_message_sequence;
    wire parser_frame_error,parser_crc_error;
    wire [32:0] parsed_snapshot;
    uart_protocol_parser #(.CLK_HZ(CLK_HZ),.CERTIFICATE_COUNT(CERTIFICATE_COUNT),
        .SINGLE_CARD_CONTROL(SINGLE_CARD_CONTROL),
        .ENABLE_EVENT_SNAPSHOT(ENABLE_EVENT_SNAPSHOT)) parser(
        .clk(clk),.rst(rst),.byte_valid(rx_valid),.byte_data(rx_data),.us_tick(us_tick),
        .command_valid(parsed_valid),.command_opcode(parsed_opcode),
        .command_source(parsed_source_raw),.command_kind(parsed_kind),
        .command_event_id(parsed_event_id_raw),.command_sequence(parsed_sequence),
        .command_level(parsed_level_raw),.command_drill(parsed_drill),
        .command_pending(parsed_pending),.command_region(parsed_region),
        .command_time_trusted(parsed_trusted),.command_remaining_seconds(parsed_remaining),
        .command_session(parsed_session),.command_message_sequence(parsed_message_sequence),
        .command_snapshot(parsed_snapshot),
        .service_valid(service_valid),.service_type(service_type),
        .service_batch(service_batch),.service_payload(service_payload),
        .service_last(service_last),
        .frame_error(parser_frame_error),.crc_error(parser_crc_error));

    AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) source_hold_lut0(
        .o(parsed_source[0]),.a(parsed_source_raw[0]));
    AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) source_hold_lut1(
        .o(parsed_source[1]),.a(parsed_source_raw[1]));
    assign frame_error=parser_frame_error|rx_framing_error;
    assign crc_error=parser_crc_error;

    reg cmd_pending,await_result;
    assign command_valid=cmd_pending;
    wire filter_enable=parsed_valid&&!cmd_pending&&!await_result;
    wire filter_accept,filter_duplicate,filter_session_changed;
    uart_single_session_filter sessions(.clk(clk),.rst(rst),.command_valid(filter_enable),
        .command_source(parsed_source),.command_session(parsed_session),
        .command_sequence(parsed_message_sequence),.accept_valid(filter_accept),
        .duplicate_valid(filter_duplicate),.session_changed(filter_session_changed));

    reg [1:0] reply_source,context_source,ack_source;
    reg [31:0] reply_session,reply_sequence;
    reg [31:0] context_session,context_sequence,ack_session,ack_sequence;
    reg [7:0] reply_type;
    reg [63:0] reply_payload;
    reg framer_request,ack_pending,latency_pending,finish_pending;
    reg telemetry_pending,heartbeat_pending;
    reg [3:0] pending_ack_result;
    reg [3:0] pending_finish_reason;
    reg [23:0] pending_pixel_latency,pending_audio_latency;
    reg [15:0] pending_last_line,pending_max_line;
    reg [15:0] pending_video_underflows,pending_uart_errors;
    reg pending_alarm_active;
    reg [2:0] pending_alarm_level;
    reg [3:0] pending_active_count;
    reg [7:0] pending_blocked_set;
    reg [31:0] pending_boot_count;
    wire [15:0] telemetry_last_line_handoff,telemetry_max_line_handoff;
    wire [15:0] telemetry_video_underflows_handoff,telemetry_uart_errors_handoff;
    genvar telemetry_bit;
    generate
        for(telemetry_bit=0;telemetry_bit<16;telemetry_bit=telemetry_bit+1) begin : telemetry_queue_boundary

            AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) last_line_lut(
                .o(telemetry_last_line_handoff[telemetry_bit]),
                .a(pending_last_line[telemetry_bit]));
            AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) max_line_lut(
                .o(telemetry_max_line_handoff[telemetry_bit]),
                .a(pending_max_line[telemetry_bit]));
            AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) video_underflows_lut(
                .o(telemetry_video_underflows_handoff[telemetry_bit]),
                .a(pending_video_underflows[telemetry_bit]));
            AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) uart_errors_lut(
                .o(telemetry_uart_errors_handoff[telemetry_bit]),
                .a(pending_uart_errors[telemetry_bit]));
        end
    endgenerate
    wire framer_ready,framer_byte_valid,tx_ready;
    wire [7:0] framer_byte;
    uart_reply_framer #(.CAPTURE_REQUEST(0),.PACKED_PAYLOAD(1)) replies(.clk(clk),.rst(rst),.request_valid(framer_request),
        .request_ready(framer_ready),.request_type(reply_type),
        .request_source(reply_source),.request_session(reply_session),
        .request_sequence(reply_sequence),.request_payload(reply_payload),
        .result_code(4'd0),.finish_reason(4'd0),.pixel_latency_us(24'd0),
        .audio_latency_us(24'd0),.alarm_active(1'b0),.alarm_level(3'd0),
        .active_count(4'd0),.blocked_set(8'd0),.boot_count(32'd0),
        .telemetry_last_line(16'd0),.telemetry_max_line(16'd0),
        .telemetry_video_underflows(16'd0),.telemetry_uart_errors(16'd0),
        .byte_valid(framer_byte_valid),.byte_ready(tx_ready),.byte_data(framer_byte));
    uart_tx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) transmitter(
        .clk(clk),.rst(rst),.data(framer_byte),.valid(framer_byte_valid),
        .ready(tx_ready),.tx(tx));

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            cmd_pending<=0;await_result<=0;command_opcode<=0;command_source<=0;
            command_kind<=0;command_event_id<=0;command_sequence<=0;command_level<=4;
            command_drill<=0;command_pending_flag<=0;command_region<=0;
            command_time_trusted<=0;command_remaining_seconds<=0;
            command_snapshot<=0;command_epoch_changed<=0;
            reply_source<=0;reply_session<=0;reply_sequence<=0;
            context_source<=0;context_session<=0;context_sequence<=0;
            ack_source<=0;ack_session<=0;ack_sequence<=0;ack_pending<=0;
            reply_type<=0;reply_payload<=0;framer_request<=0;
            latency_pending<=0;finish_pending<=0;telemetry_pending<=0;
            heartbeat_pending<=0;pending_ack_result<=0;pending_finish_reason<=0;
            pending_pixel_latency<=0;pending_audio_latency<=0;
            pending_last_line<=0;pending_max_line<=0;
            pending_video_underflows<=0;pending_uart_errors<=0;
            pending_alarm_active<=0;pending_alarm_level<=0;pending_active_count<=0;
            pending_blocked_set<=0;pending_boot_count<=0;
        end else begin
            framer_request<=0;
            if(framer_ready&&!framer_request) begin
                if(ack_pending) begin
                    framer_request<=1;ack_pending<=0;reply_type<=8'h81;
                    reply_source<=ack_source;reply_session<=ack_session;
                    reply_sequence<=ack_sequence;
                    reply_payload<={4'd0,pending_ack_result,56'd0};
                end else if(latency_pending) begin
                    framer_request<=1;latency_pending<=0;reply_type<=8'h82;
                    reply_source<=context_source;reply_session<=context_session;
                    reply_sequence<=context_sequence;
                    reply_payload<={pending_pixel_latency,pending_audio_latency,16'd0};
                end else if(finish_pending) begin
                    framer_request<=1;finish_pending<=0;reply_type<=8'h83;
                    reply_source<=context_source;reply_session<=context_session;
                    reply_sequence<=context_sequence;
                    reply_payload<={4'd0,pending_finish_reason,56'd0};
                end else if(telemetry_pending) begin
                    framer_request<=1;telemetry_pending<=0;reply_type<=8'h91;
                    reply_source<=context_source;reply_session<=context_session;
                    reply_sequence<=context_sequence;
                    reply_payload<={telemetry_last_line_handoff,telemetry_max_line_handoff,
                        telemetry_video_underflows_handoff,telemetry_uart_errors_handoff};
                end else if(heartbeat_pending) begin
                    framer_request<=1;heartbeat_pending<=0;reply_type<=8'h90;
                    reply_source<=context_source;reply_session<=context_session;
                    reply_sequence<=context_sequence;
                    reply_payload<={pending_alarm_active,4'd0,pending_alarm_level,
                        4'd0,pending_active_count,pending_blocked_set,8'd0,pending_boot_count};
                end
            end
            if(filter_accept) begin
                command_snapshot<=parsed_snapshot;command_epoch_changed<=filter_session_changed;
                command_opcode<=parsed_opcode;command_source<=parsed_source;
                command_kind<=parsed_kind;command_event_id<=parsed_event_id;
                command_sequence<=parsed_sequence;command_level<=parsed_level;
                command_drill<=parsed_drill;command_pending_flag<=parsed_pending;
                command_region<=parsed_region;command_time_trusted<=parsed_trusted;
                command_remaining_seconds<=parsed_remaining;cmd_pending<=1;
                context_source<=parsed_source;context_session<=parsed_session;
                context_sequence<=parsed_message_sequence;
            end
            if(cmd_pending&&command_ready) begin cmd_pending<=0;await_result<=1;end
            if(command_result_valid&&await_result) begin
                await_result<=0;ack_pending<=1;pending_ack_result<=command_result_code;
                ack_source<=context_source;ack_session<=context_session;
                ack_sequence<=context_sequence;
            end else if(filter_duplicate) begin
                ack_source<=parsed_source;ack_session<=parsed_session;
                ack_sequence<=parsed_message_sequence;ack_pending<=1;
                pending_ack_result<=1;
            end else if(parsed_valid&&(cmd_pending||await_result)) begin
                ack_source<=parsed_source;ack_session<=parsed_session;
                ack_sequence<=parsed_message_sequence;ack_pending<=1;
                pending_ack_result<=6;
            end
            if(latency_valid) begin
                latency_pending<=1;pending_pixel_latency<=pixel_latency_us;
                pending_audio_latency<=audio_latency_us;
            end
            if(finish_valid) begin
                finish_pending<=1;pending_finish_reason<=finish_reason;
            end
            if(telemetry_tick) begin
                telemetry_pending<=1;pending_last_line<=telemetry_last_line;
                pending_max_line<=telemetry_max_line;
                pending_video_underflows<=telemetry_video_underflows;
                pending_uart_errors<=telemetry_uart_errors;
            end
            if(heartbeat_tick) begin
                heartbeat_pending<=1;pending_alarm_active<=alarm_active;
                pending_alarm_level<=alarm_level;pending_active_count<=active_count;
                pending_blocked_set<=blocked_set;pending_boot_count<=boot_count;
            end
        end
    end
endmodule
