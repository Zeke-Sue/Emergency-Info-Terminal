`timescale 1ns/1ps
module tb_terminal_uart_integration;
    localparam CLK_HZ=1000000,BAUD=100000;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg request=0;wire request_ready,byte_valid,byte_ready,command_serial;
    reg [1:0] action=0;reg [31:0] message_sequence=1;
    wire [7:0] command_byte;
    console_command_framer command_frame(.clk(clk),.rst(rst),
        .request_valid(request),.request_ready(request_ready),.request_action(action),
        .request_source(2'd2),.request_session(32'h12345678),
        .request_sequence(message_sequence),.request_event_id(16'h1234),
        .request_event_sequence(message_sequence[7:0]),.request_level(3'd2),
        .request_drill(1'b1),.request_pending(1'b0),.request_region(3'd2),
        .request_time_trusted(1'b1),.request_remaining_seconds(16'd30),
        .request_kind(3'd0),.byte_valid(byte_valid),.byte_ready(byte_ready),
        .byte_data(command_byte));
    uart_tx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) command_tx(.clk(clk),.rst(rst),
        .data(command_byte),.valid(byte_valid),.ready(byte_ready),.tx(command_serial));

    wire a_tx,cmd_valid,cmd_ready,result_valid,latency_valid;
    wire terminal_finish_valid;wire [3:0] terminal_finish_reason;
    wire [2:0] cmd_opcode,cmd_kind,cmd_level,cmd_region,alarm_level;
    wire [1:0] cmd_source;wire [15:0] cmd_event_id,cmd_remaining;
    wire [7:0] cmd_event_sequence,blocked_set;
    wire cmd_drill,cmd_pending,cmd_trusted,alarm_active,alarm_drill;
    wire [3:0] result_code,active_count;
    wire [23:0] pixel_latency,audio_latency;
    p3_uart_endpoint #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) endpoint(.clk(clk),.rst(rst),
        .rx(command_serial),.tx(a_tx),.us_tick(1'b1),.command_valid(cmd_valid),
        .command_ready(cmd_ready),.command_opcode(cmd_opcode),.command_source(cmd_source),
        .command_kind(cmd_kind),.command_event_id(cmd_event_id),
        .command_sequence(cmd_event_sequence),.command_level(cmd_level),
        .command_drill(cmd_drill),.command_pending_flag(cmd_pending),
        .command_region(cmd_region),.command_time_trusted(cmd_trusted),
        .command_remaining_seconds(cmd_remaining),.command_result_valid(result_valid),
        .command_result_code(result_code),.latency_valid(latency_valid),
        .pixel_latency_us(pixel_latency),.audio_latency_us(audio_latency),
        .finish_valid(terminal_finish_valid),
        .finish_reason(terminal_finish_reason),.heartbeat_tick(1'b0),
        .alarm_active(alarm_active),.alarm_level(alarm_level),
        .active_count(active_count),.blocked_set(blocked_set),
        .boot_count(32'd1),.telemetry_tick(1'b0),
        .telemetry_last_line(16'd0),.telemetry_max_line(16'd0),
        .telemetry_video_underflows(16'd0),.telemetry_uart_errors(16'd0),
        .frame_error(),.crc_error());
    reg [5:0] frame_div=0;wire frame_tick=frame_div==49;
    always @(posedge clk)if(rst)frame_div<=0;else frame_div<=frame_tick?0:frame_div+1'b1;
    wire countdown_trusted,cancel_notice,flash_on,buzzer_on;
    wire [15:0] countdown;wire [47:0] samples;
    emergency_control_core #(.CLK_HZ(CLK_HZ)) emergency(.clk(clk),.rst(rst),
        .frame_tick(frame_tick),.first_active_pixel(frame_tick),
        .audio_sample_tick(frame_tick),.demo_alarm(1'b0),.command_valid(cmd_valid),
        .command_opcode(cmd_opcode),.command_source(cmd_source),.command_kind(cmd_kind),
        .command_event_id(cmd_event_id),.command_sequence(cmd_event_sequence),
        .command_level(cmd_level),.command_drill(cmd_drill),.command_pending(cmd_pending),
        .command_region(cmd_region),.command_time_trusted(cmd_trusted),
        .command_remaining_seconds(cmd_remaining),.command_result_valid(result_valid),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .command_result_code(result_code),.command_ready(cmd_ready),
        .alarm_active(alarm_active),.alarm_level(alarm_level),.alarm_drill(alarm_drill),
        .countdown_trusted(countdown_trusted),.countdown_seconds(countdown),
        .cancel_notice(cancel_notice),.flash_on(flash_on),.buzzer_on(buzzer_on),
        .blocked_set(blocked_set),.active_count(active_count),
        .latency_valid(latency_valid),.pixel_latency_us(pixel_latency),
        .audio_latency_us(audio_latency),.finish_valid(terminal_finish_valid),
        .finish_reason(terminal_finish_reason),.sample_count(samples));

    wire [7:0] reply_byte;wire reply_valid,reply_uart_error;
    uart_rx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) reply_rx(.clk(clk),.rst(rst),
        .rx(a_tx),.data(reply_byte),.valid(reply_valid),.framing_error(reply_uart_error));
    wire ack_valid,heartbeat_valid,reply_latency_valid,finish_valid;
    wire [3:0] ack_result,remote_count,finish_reason;
    wire [31:0] ack_session,ack_sequence;wire remote_alarm;
    wire [2:0] remote_level;wire [7:0] remote_blocked;
    wire [23:0] reply_pixel_latency,reply_audio_latency;
    wire reply_frame_error,reply_crc_error;
    reg saw_latency_reply=0;
    console_reply_parser reply_parser(.clk(clk),.rst(rst),.byte_valid(reply_valid),
        .byte_data(reply_byte),.us_tick(1'b1),.ack_valid(ack_valid),
        .ack_result(ack_result),.ack_session(ack_session),.ack_sequence(ack_sequence),
        .heartbeat_valid(heartbeat_valid),.remote_alarm(remote_alarm),
        .remote_level(remote_level),.remote_active_count(remote_count),
        .remote_blocked_set(remote_blocked),.latency_valid(reply_latency_valid),
        .pixel_latency_us(reply_pixel_latency),.audio_latency_us(reply_audio_latency),
        .finish_valid(finish_valid),.finish_reason(finish_reason),
        .frame_error(reply_frame_error),.crc_error(reply_crc_error));
    always @(posedge clk)if(reply_latency_valid)saw_latency_reply<=1;

    task fail;input [8*120-1:0] reason;begin
        $display("TEST_FAIL tb_terminal_uart_integration: %0s",reason);$finish;
    end endtask
    integer stage=0;
    task send_command;input [1:0] new_action;begin
        wait(request_ready);@(negedge clk);action=new_action;request=1;
        @(negedge clk);request=0;
    end endtask
    initial begin
        repeat(8)@(negedge clk);rst=0;
        stage=1;wait(cmd_ready);send_command(0);
        stage=2;
        wait(ack_valid);#1;
        if(ack_result!=0||ack_session!=32'h12345678||ack_sequence!=1)
            fail("publish ACK contents");
        stage=3;wait(alarm_active&&active_count==1);
        if(alarm_level!=2||!alarm_drill)fail("event did not become primary alarm");
        wait(saw_latency_reply);
        stage=4;message_sequence=2;send_command(1);wait(ack_valid);#1;
        if(ack_result!=0)fail("blocked-region ACK");
        stage=5;wait(blocked_set[2]);
        stage=6;message_sequence=3;send_command(3);wait(ack_valid);#1;
        if(ack_result!=0)fail("cancel ACK");
        stage=7;wait(finish_valid);#1;
        if(finish_reason!=1)fail("cancel finish reason");
        if(reply_uart_error||reply_frame_error||reply_crc_error)
            fail("reply serial/protocol error");
        $display("TEST_PASS tb_terminal_uart_integration ACK, blocked state and finish reply");
        $finish;
    end
    initial begin #3000000;$display("timeout stage=%0d",stage);fail("timeout");end
endmodule
