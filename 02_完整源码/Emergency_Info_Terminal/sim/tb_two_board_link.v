`timescale 1ns/1ps
module tb_two_board_link;
    localparam CLK_HZ=1000000,BAUD=100000;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg connected=1;reg [3:0] press=0,long_press=0;
    reg [3:0] switches=4'b0010;
    reg [9:0] ms_div=0;wire ms_tick=ms_div==999;
    always @(posedge clk)if(rst)ms_div<=0;else ms_div<=ms_tick?0:ms_div+1'b1;

    wire b_request,b_request_ready;wire [1:0] b_action,b_source;
    wire [31:0] b_session,b_sequence;wire [15:0] b_event_id,b_remaining;
    wire [7:0] b_event_sequence;wire [2:0] b_level,b_region,b_kind;
    wire b_drill,b_pending,b_trusted;
    wire ack_valid,heartbeat_valid,heartbeat_alarm;
    wire [3:0] ack_result,heartbeat_count;wire [31:0] ack_session,ack_sequence;
    wire [2:0] heartbeat_level;wire [7:0] heartbeat_blocked;
    wire [2:0] selected_level,selected_region,console_remote_level;
    wire [1:0] selected_action,selected_role;
    wire console_link,console_pending,permission_denied,console_error,console_alarm;
    wire [3:0] last_ack,console_remote_count;wire [7:0] console_remote_blocked;
    wire reply_frame_error,reply_crc_error;
    duty_console_core #(.LINK_TIMEOUT_MS(6),.ACK_TIMEOUT_MS(20),.MAX_RETRIES(1)) console(
        .clk(clk),.rst(rst),.ms_tick(ms_tick),.key_press(press),
        .key_long_press(long_press),.switches(switches),.request_valid(b_request),
        .request_ready(b_request_ready),.request_action(b_action),.request_source(b_source),
        .request_session(b_session),.request_sequence(b_sequence),.request_event_id(b_event_id),
        .request_event_sequence(b_event_sequence),.request_level(b_level),
        .request_drill(b_drill),.request_pending(b_pending),.request_region(b_region),
        .request_time_trusted(b_trusted),.request_remaining_seconds(b_remaining),
        .request_kind(b_kind),.ack_valid(ack_valid),.ack_result(ack_result),
        .ack_session(ack_session),.ack_sequence(ack_sequence),
        .heartbeat_valid(heartbeat_valid),.heartbeat_alarm(heartbeat_alarm),
        .heartbeat_level(heartbeat_level),.heartbeat_active_count(heartbeat_count),
        .heartbeat_blocked_set(heartbeat_blocked),.rx_frame_error(reply_frame_error),
        .rx_crc_error(reply_crc_error),.selected_level(selected_level),
        .selected_region(selected_region),.selected_action(selected_action),
        .selected_role(selected_role),.link_alive(console_link),.ack_pending(console_pending),
        .last_ack_result(last_ack),.permission_denied(permission_denied),
        .error_latched(console_error),.remote_alarm(console_alarm),
        .remote_level(console_remote_level),.remote_active_count(console_remote_count),
        .remote_blocked_set(console_remote_blocked));
    wire command_byte_valid,command_byte_ready;wire [7:0] command_byte;wire b_tx;
    console_command_framer command_frame(.clk(clk),.rst(rst),.request_valid(b_request),
        .request_ready(b_request_ready),.request_action(b_action),.request_source(b_source),
        .request_session(b_session),.request_sequence(b_sequence),.request_event_id(b_event_id),
        .request_event_sequence(b_event_sequence),.request_level(b_level),
        .request_drill(b_drill),.request_pending(b_pending),.request_region(b_region),
        .request_time_trusted(b_trusted),.request_remaining_seconds(b_remaining),
        .request_kind(b_kind),.byte_valid(command_byte_valid),.byte_ready(command_byte_ready),
        .byte_data(command_byte));
    uart_tx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) b_transmitter(.clk(clk),.rst(rst),
        .data(command_byte),.valid(command_byte_valid),.ready(command_byte_ready),.tx(b_tx));

    wire a_rx=connected ? b_tx : 1'b1;
    wire a_tx,cmd_valid,cmd_ready,result_valid,latency_valid;
    wire [2:0] cmd_opcode,cmd_kind,cmd_level,cmd_region,alarm_level;
    wire [1:0] cmd_source;wire [15:0] cmd_event_id,cmd_remaining;
    wire [7:0] cmd_event_sequence,blocked_set;wire [3:0] result_code,active_count;
    wire cmd_drill,cmd_pending,cmd_trusted,alarm_active,alarm_drill;
    wire [23:0] pixel_latency,audio_latency;
    reg [10:0] heartbeat_div=0;wire heartbeat_tick=heartbeat_div==1999;
    always @(posedge clk)if(rst)heartbeat_div<=0;else heartbeat_div<=heartbeat_tick?0:heartbeat_div+1'b1;
    wire terminal_finish_valid;wire [3:0] terminal_finish_reason;
    p3_uart_endpoint #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) terminal_link(.clk(clk),.rst(rst),
        .rx(a_rx),.tx(a_tx),.us_tick(1'b1),.command_valid(cmd_valid),
        .command_ready(cmd_ready),.command_opcode(cmd_opcode),.command_source(cmd_source),
        .command_kind(cmd_kind),.command_event_id(cmd_event_id),
        .command_sequence(cmd_event_sequence),.command_level(cmd_level),
        .command_drill(cmd_drill),.command_pending_flag(cmd_pending),
        .command_region(cmd_region),.command_time_trusted(cmd_trusted),
        .command_remaining_seconds(cmd_remaining),.command_result_valid(result_valid),
        .command_result_code(result_code),.latency_valid(latency_valid),
        .pixel_latency_us(pixel_latency),.audio_latency_us(audio_latency),
        .finish_valid(terminal_finish_valid),
        .finish_reason(terminal_finish_reason),.heartbeat_tick(heartbeat_tick),
        .alarm_active(alarm_active),.alarm_level(alarm_level),.active_count(active_count),
        .blocked_set(blocked_set),.boot_count(32'd1),.telemetry_tick(1'b0),
        .telemetry_last_line(16'd0),.telemetry_max_line(16'd0),
        .telemetry_video_underflows(16'd0),.telemetry_uart_errors(16'd0),
        .frame_error(),.crc_error());
    reg [5:0] frame_div=0;wire frame_tick=frame_div==49;
    always @(posedge clk)if(rst)frame_div<=0;else frame_div<=frame_tick?0:frame_div+1'b1;
    wire countdown_trusted,cancel_notice,flash_on,buzzer_on;wire [15:0] countdown;
    wire [47:0] samples;
    emergency_control_core #(.CLK_HZ(CLK_HZ)) terminal_core(.clk(clk),.rst(rst),
        .frame_tick(frame_tick),.first_active_pixel(frame_tick),.audio_sample_tick(frame_tick),
        .demo_alarm(1'b0),.command_valid(cmd_valid),.command_opcode(cmd_opcode),
        .command_source(cmd_source),.command_kind(cmd_kind),.command_event_id(cmd_event_id),
        .command_sequence(cmd_event_sequence),.command_level(cmd_level),
        .command_drill(cmd_drill),.command_pending(cmd_pending),.command_region(cmd_region),
        .command_time_trusted(cmd_trusted),.command_remaining_seconds(cmd_remaining),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .command_result_valid(result_valid),.command_result_code(result_code),
        .command_ready(cmd_ready),.alarm_active(alarm_active),.alarm_level(alarm_level),
        .alarm_drill(alarm_drill),.countdown_trusted(countdown_trusted),
        .countdown_seconds(countdown),.cancel_notice(cancel_notice),.flash_on(flash_on),
        .buzzer_on(buzzer_on),.blocked_set(blocked_set),.active_count(active_count),
        .latency_valid(latency_valid),.pixel_latency_us(pixel_latency),
        .audio_latency_us(audio_latency),.finish_valid(terminal_finish_valid),
        .finish_reason(terminal_finish_reason),.sample_count(samples));

    wire b_rx=connected ? a_tx : 1'b1;wire [7:0] reply_byte;
    wire reply_byte_valid,reply_uart_error;
    uart_rx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) b_receiver(.clk(clk),.rst(rst),
        .rx(b_rx),.data(reply_byte),.valid(reply_byte_valid),.framing_error(reply_uart_error));
    wire latency_reply,finish_valid;wire [23:0] rpix,raud;wire [3:0] finish_reason;
    console_reply_parser reply_parser(.clk(clk),.rst(rst),.byte_valid(reply_byte_valid),
        .byte_data(reply_byte),.us_tick(1'b1),.ack_valid(ack_valid),
        .ack_result(ack_result),.ack_session(ack_session),.ack_sequence(ack_sequence),
        .heartbeat_valid(heartbeat_valid),.remote_alarm(heartbeat_alarm),
        .remote_level(heartbeat_level),.remote_active_count(heartbeat_count),
        .remote_blocked_set(heartbeat_blocked),.latency_valid(latency_reply),
        .pixel_latency_us(rpix),.audio_latency_us(raud),.finish_valid(finish_valid),
        .finish_reason(finish_reason),.frame_error(reply_frame_error),
        .crc_error(reply_crc_error));

    task fail;input [8*120-1:0] reason;begin
        $display("TEST_FAIL tb_two_board_link: %0s",reason);$finish;
    end endtask
    task pulse_long;begin @(negedge clk);long_press[3]=1;@(negedge clk);long_press=0;end endtask
    task pulse_action;begin @(negedge clk);press[2]=1;@(negedge clk);press=0;end endtask
    initial begin
        repeat(8)@(negedge clk);rst=0;wait(cmd_ready);
        pulse_long;wait(alarm_active&&active_count==1);wait(console_link&&!console_pending);
        if(!alarm_drill||last_ack>1)fail("Board-B drill publish/ACK");
        pulse_action;if(selected_action!=1)fail("block action selection");
        pulse_long;wait(blocked_set[0]);wait(!console_pending);
        connected=0;wait(!console_link);
        if(!alarm_active||active_count!=1)fail("Board A did not retain alarm after link loss");
        if(!console_error)fail("Board B did not report link loss");
        $display("TEST_PASS tb_two_board_link publish, ACK, blocked exit and disconnected-console degradation");
        $finish;
    end
    initial begin #5000000;fail("timeout");end
endmodule
