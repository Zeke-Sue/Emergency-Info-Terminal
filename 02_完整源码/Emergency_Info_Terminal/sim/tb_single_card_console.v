`timescale 1ns/1ps

module tb_single_card_console;
    reg clk=0,rst=1,connected=1,send_heartbeat=0;
    always #5 clk=~clk;
    wire a_tx,b_tx,sd_cs,sd_clk,sd_mosi;
    reg [15:0] heartbeat_count=0;
    wire heartbeat_tick=send_heartbeat&&heartbeat_count==9999;
    always @(posedge clk)
        if(rst)heartbeat_count<=0;
        else heartbeat_count<=heartbeat_count==9999 ? 0 : heartbeat_count+1'b1;
    duty_console_top #(.CLK_HZ(1000000),.BAUD(100000),.RESET_CYCLES(8),
        .DEBOUNCE_CYCLES(4),.LINK_TIMEOUT_MS(30),.ACK_TIMEOUT_MS(5)) b(
        .clk(clk),.key1(1'b1),.key2(1'b1),.key3(1'b1),.key4(1'b1),
        .sw1(1'b0),.sw2(1'b0),.sw3(1'b0),.sw4(1'b0),
        .console_uart_rx(connected ? a_tx : 1'b1),.console_uart_tx(b_tx),
        .sd_ncs(sd_cs),.sd_dclk(sd_clk),.sd_mosi(sd_mosi),.sd_miso(1'b1),
        .flash_miso(1'b1));
    wire svc,svc_last;wire [7:0] svc_type;
    wire [15:0] svc_batch;wire [95:0] svc_payload;
    p3_uart_endpoint #(.CLK_HZ(1000000),.BAUD(100000),
        .CERTIFICATE_COUNT(15),.SINGLE_CARD_CONTROL(1),.ENABLE_EVENT_SNAPSHOT(1)) a(
        .clk(clk),.rst(rst),.rx(connected ? b_tx : 1'b1),.tx(a_tx),.us_tick(1'b1),
        .command_ready(1'b1),.command_result_valid(1'b0),.command_result_code(4'd0),
        .latency_valid(1'b0),.pixel_latency_us(24'd0),.audio_latency_us(24'd0),
        .finish_valid(1'b0),.finish_reason(4'd0),.heartbeat_tick(heartbeat_tick),
        .alarm_active(1'b0),.alarm_level(3'd0),.active_count(4'd0),.blocked_set(8'd0),
        .boot_count(32'd1),.telemetry_tick(1'b0),.telemetry_last_line(16'd0),
        .telemetry_max_line(16'd0),.telemetry_video_underflows(16'd0),.telemetry_uart_errors(16'd0),
        .service_valid(svc),.service_type(svc_type),.service_batch(svc_batch),
        .service_payload(svc_payload),.service_last(svc_last));
    reg [9:0] frame_count=0;
    wire frame_tick=frame_count==999;
    always @(posedge clk)frame_count<=frame_tick ? 0 : frame_count+1'b1;
    wire apply;wire [31:0] parameters;wire allowed;
    v41_resync_receiver #(.CERTIFICATE_COUNT(15),.ENABLE_CERTIFICATES(0)) snapshot(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.msg_valid(svc&&svc_type<8'h20),
        .msg_type(svc_type),.msg_batch(svc_batch),.msg_payload(svc_payload),.msg_last(svc_last),
        .certificate_lookup_index(4'd0),.active_parameters(parameters),.apply_pulse(apply));
    audio_play_permission #(.TIMEOUT_FRAMES(50)) permit(.clk(clk),.rst(rst),
        .frame_tick(frame_tick),.snapshot_apply(apply),.parameters(parameters),.allowed(allowed));
    integer certificates=0;
    always @(posedge clk)if(!rst)begin
        if(sd_cs!==1'b1||sd_clk!==1'b0||sd_mosi!==1'b1||b.admission_certificate_valid)
            $fatal(1,"B tried to access absent TF card or certify audio");
        if(svc&&svc_type==8'h0e)certificates=certificates+1;
    end
    initial begin
        repeat(20)@(negedge clk);rst=0;
        repeat(10000)@(negedge clk);if(allowed)$fatal(1,"B allowed before link");
        send_heartbeat=1;wait(allowed);$display("CONSOLE granted");
        repeat(120000)@(negedge clk);if(!allowed)$fatal(1,"lease not refreshed");
        send_heartbeat=0;wait(!b.link_alive);wait(!allowed);$display("CONSOLE revoked");
        send_heartbeat=1;wait(allowed);$display("CONSOLE regranted");
        connected=0;repeat(55000)@(negedge clk);
        if(allowed)$fatal(1,"disconnected permission retained");
        connected=1;wait(allowed);
        if(certificates!=0)$fatal(1,"single-card B sent certificate records");
        $display("TEST_PASS actual B top without TF: link permission, periodic renewal, one-way heartbeat loss, disconnect and reconnect");
        $finish;
    end
    initial begin #10000000;
        $display("link=%b hb=%b sync=%b txgrant=%d svc=%h params=%h status=%b rst=%b",b.link_alive,b.heartbeat_valid,b.sync_active,b.tx_grant,svc_type,parameters,allowed,b.rst);
        $fatal(1,"single-card console timeout");end
endmodule
