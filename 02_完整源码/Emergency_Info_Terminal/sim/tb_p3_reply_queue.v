`timescale 1ns/1ps
module tb_p3_reply_queue;
    localparam integer CLK_HZ=1000000,BAUD=100000;
    reg clk=0,rst=1;
    always #5 clk=~clk;

    reg request=0;
    wire request_ready,command_byte_valid,command_byte_ready,command_serial;
    wire [7:0] command_byte;
    console_command_framer command_frame(.clk(clk),.rst(rst),
        .request_valid(request),.request_ready(request_ready),.request_action(2'd0),
        .request_source(2'd2),.request_session(32'h12345678),
        .request_sequence(32'h01020304),.request_event_id(16'h4321),
        .request_event_sequence(8'h12),.request_level(3'd2),
        .request_drill(1'b0),.request_pending(1'b0),.request_region(3'd3),
        .request_time_trusted(1'b1),.request_remaining_seconds(16'd30),
        .request_kind(3'd1),.byte_valid(command_byte_valid),
        .byte_ready(command_byte_ready),.byte_data(command_byte));
    uart_tx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) command_tx(
        .clk(clk),.rst(rst),.data(command_byte),.valid(command_byte_valid),
        .ready(command_byte_ready),.tx(command_serial));

    wire reply_serial,command_valid;
    reg command_result_valid=0,latency_valid=0,finish_valid=0;
    reg telemetry_tick=0,heartbeat_tick=0;
    p3_uart_endpoint #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) endpoint(
        .clk(clk),.rst(rst),.rx(command_serial),.tx(reply_serial),.us_tick(1'b1),
        .command_valid(command_valid),.command_ready(1'b1),.command_opcode(),
        .command_source(),.command_kind(),.command_event_id(),.command_sequence(),
        .command_level(),.command_drill(),.command_pending_flag(),.command_region(),
        .command_time_trusted(),.command_remaining_seconds(),
        .command_result_valid(command_result_valid),.command_result_code(4'd0),
        .latency_valid(latency_valid),.pixel_latency_us(24'h010203),
        .audio_latency_us(24'h040506),.finish_valid(finish_valid),
        .finish_reason(4'd2),.heartbeat_tick(heartbeat_tick),
        .alarm_active(1'b1),.alarm_level(3'd2),.active_count(4'd3),
        .blocked_set(8'ha5),.boot_count(32'h11223344),
        .telemetry_tick(telemetry_tick),.telemetry_last_line(16'h0102),
        .telemetry_max_line(16'h0304),.telemetry_video_underflows(16'h0506),
        .telemetry_uart_errors(16'h0708),.service_valid(),.service_type(),
        .service_batch(),.service_payload(),.service_last(),.frame_error(),.crc_error());

    wire [7:0] reply_byte;
    wire reply_byte_valid,reply_uart_error;
    uart_rx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) reply_rx(
        .clk(clk),.rst(rst),.rx(reply_serial),.data(reply_byte),
        .valid(reply_byte_valid),.framing_error(reply_uart_error));
    wire ack_valid,heartbeat_valid,telemetry_valid,reply_latency_valid,reply_finish_valid;
    wire [3:0] ack_result,remote_active_count,finish_reason;
    wire [31:0] ack_session,ack_sequence,remote_boot_count;
    wire remote_alarm;
    wire [2:0] remote_level;
    wire [7:0] remote_blocked_set;
    wire [15:0] last_line,max_line,video_underflows,uart_errors;
    wire [23:0] pixel_latency,audio_latency;
    wire parser_frame_error,parser_crc_error;
    console_reply_parser parser(.clk(clk),.rst(rst),.byte_valid(reply_byte_valid),
        .byte_data(reply_byte),.us_tick(1'b1),.ack_valid(ack_valid),
        .ack_result(ack_result),.ack_session(ack_session),.ack_sequence(ack_sequence),
        .heartbeat_valid(heartbeat_valid),.remote_alarm(remote_alarm),
        .remote_level(remote_level),.remote_active_count(remote_active_count),
        .remote_blocked_set(remote_blocked_set),.remote_boot_count(remote_boot_count),
        .telemetry_valid(telemetry_valid),.telemetry_last_line(last_line),
        .telemetry_max_line(max_line),.telemetry_video_underflows(video_underflows),
        .telemetry_uart_errors(uart_errors),.latency_valid(reply_latency_valid),
        .pixel_latency_us(pixel_latency),.audio_latency_us(audio_latency),
        .finish_valid(reply_finish_valid),.finish_reason(finish_reason),
        .frame_error(parser_frame_error),.crc_error(parser_crc_error));

    task fail;
        input [8*120-1:0] reason;
        begin $display("TEST_FAIL tb_p3_reply_queue: %0s",reason);$finish;end
    endtask
    integer received=0;
    always @(posedge clk) begin
        if(ack_valid) begin
            if(received!=0||ack_result!=0||ack_session!=32'h12345678||
                    ack_sequence!=32'h01020304)fail("ACK order or snapshot");
            received<=1;
        end
        if(reply_latency_valid) begin
            if(received!=1||pixel_latency!=24'h010203||audio_latency!=24'h040506)
                fail("latency order or snapshot");
            received<=2;
        end
        if(reply_finish_valid) begin
            if(received!=2||finish_reason!=2)fail("finish order or snapshot");
            received<=3;
        end
        if(telemetry_valid) begin
            if(received!=3||last_line!=16'h0102||max_line!=16'h0304||
                    video_underflows!=16'h0506||uart_errors!=16'h0708)
                fail("telemetry order or snapshot");
            received<=4;
        end
        if(heartbeat_valid) begin
            if(received!=4||!remote_alarm||remote_level!=2||remote_active_count!=3||
                    remote_blocked_set!=8'ha5||remote_boot_count!=32'h11223344)
                fail("heartbeat order or snapshot");
            received<=5;
        end
    end

    initial begin
        repeat(8)@(negedge clk);rst=0;
        wait(request_ready);@(negedge clk);request=1;@(negedge clk);request=0;
        wait(command_valid);wait(!command_valid);
        @(negedge clk);
        command_result_valid=1;latency_valid=1;finish_valid=1;
        telemetry_tick=1;heartbeat_tick=1;
        @(negedge clk);
        command_result_valid=0;latency_valid=0;finish_valid=0;
        telemetry_tick=0;heartbeat_tick=0;
        wait(received==5);repeat(4)@(negedge clk);
        if(reply_uart_error||parser_frame_error||parser_crc_error)
            fail("UART or parser error");
        $display("TEST_PASS tb_p3_reply_queue simultaneous ACK, latency, finish, telemetry and heartbeat are ordered and lossless");
        $finish;
    end
    initial begin #3000000;fail("timeout");end
endmodule
