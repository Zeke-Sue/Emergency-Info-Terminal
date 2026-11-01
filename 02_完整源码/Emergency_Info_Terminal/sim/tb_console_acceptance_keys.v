`timescale 1ns/1ps

module tb_console_acceptance_keys;
    reg clk=0,rst=1,connected=1,send_heartbeat=0;
    always #5 clk=~clk;
    wire a_tx,b_tx,sd_cs,sd_clk,sd_mosi;
    reg [3:0] keys=15;reg fire=0;
    reg [15:0] heartbeat_count=0;
    wire heartbeat_tick=send_heartbeat&&heartbeat_count==9999;
    always @(posedge clk)
        if(rst)heartbeat_count<=0;
        else heartbeat_count<=heartbeat_count==9999 ? 0 : heartbeat_count+1'b1;
    duty_console_top #(.SIMPLE_DEMO(0),.CLK_HZ(1000000),.BAUD(100000),.RESET_CYCLES(8),
        .DEBOUNCE_CYCLES(4),.LONG_CYCLES(2000),.CONFIRM_HOLD_MS(20),.LINK_TIMEOUT_MS(30),.ACK_TIMEOUT_MS(50)) b(
        .clk(clk),.key1(keys[0]),.key2(keys[1]),.key3(keys[2]),.key4(keys[3]),
        .sw1(1'b0),.sw2(1'b1),.sw3(1'b0),.sw4(fire),
        .console_uart_rx(connected ? a_tx : 1'b1),.console_uart_tx(b_tx),
        .sd_ncs(sd_cs),.sd_dclk(sd_clk),.sd_mosi(sd_mosi),.sd_miso(1'b1),
        .flash_miso(1'b1));
    wire svc,svc_last;wire [7:0] svc_type;
    wire [15:0] svc_batch;wire [95:0] svc_payload;
    wire command_valid,command_ready,command_result,drill,pending_flag,trusted,epoch;
    wire [2:0] opcode,kind,level,region,primary_kind,primary_level;
    wire [15:0] event_id,remaining;wire [7:0] sequence,blocked;
    wire [32:0] event_snapshot;wire [3:0] result_code,active_count;
    wire primary,cancel;wire frame_tick;
    event_snapshot_sink #(.CHECK_ROLE(1)) event_sink(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .command_valid(command_valid),.command_ready(command_ready),.result_valid(command_result),.result_code(result_code),
        .command_opcode(opcode),.command_kind(kind),.command_level(level),.command_region(region),
        .command_event_id(event_id),.command_remaining(remaining),.command_sequence(sequence),
        .command_drill(drill),.command_pending(pending_flag),.command_trusted(trusted),.epoch_changed(epoch),
        .snapshot(event_snapshot),.primary_valid(primary),.primary_kind(primary_kind),.primary_level(primary_level),
        .active_count(active_count),.blocked_set(blocked),.cancel_notice(cancel));
    p3_uart_endpoint #(.CLK_HZ(1000000),.BAUD(100000),
        .CERTIFICATE_COUNT(15),.SINGLE_CARD_CONTROL(1),.ENABLE_EVENT_SNAPSHOT(1)) a(
        .clk(clk),.rst(rst),.rx(connected ? b_tx : 1'b1),.tx(a_tx),.us_tick(1'b1),
        .command_ready(command_ready),.command_result_valid(command_result),.command_result_code(result_code),
        .command_valid(command_valid),.command_opcode(opcode),.command_kind(kind),.command_level(level),
        .command_region(region),.command_event_id(event_id),.command_remaining_seconds(remaining),
        .command_sequence(sequence),.command_drill(drill),.command_pending_flag(pending_flag),
        .command_time_trusted(trusted),.command_epoch_changed(epoch),.command_snapshot(event_snapshot),
        .latency_valid(1'b0),.pixel_latency_us(24'd0),.audio_latency_us(24'd0),
        .finish_valid(1'b0),.finish_reason(4'd0),.heartbeat_tick(heartbeat_tick),
        .alarm_active(primary),.alarm_level(primary_level),.active_count(active_count),.blocked_set(blocked),
        .boot_count(32'd1),.telemetry_tick(1'b0),.telemetry_last_line(16'd0),
        .telemetry_max_line(16'd0),.telemetry_video_underflows(16'd0),.telemetry_uart_errors(16'd0),
        .service_valid(svc),.service_type(svc_type),.service_batch(svc_batch),
        .service_payload(svc_payload),.service_last(svc_last));
    reg [9:0] frame_count=0;
    assign frame_tick=frame_count==999;
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
    task short_key;input integer index;begin
        @(negedge clk);keys[index]=0;repeat(30)@(negedge clk);
        keys[index]=1;repeat(30)@(negedge clk);
    end endtask
    task long_key;input integer index;begin
        @(negedge clk);keys[index]=0;repeat(2200)@(negedge clk);
        keys[index]=1;repeat(30)@(negedge clk);
    end endtask
    task submit;reg [31:0] old_sequence;begin
        old_sequence=b.request_sequence;
        short_key(3);
        if(!b.confirmation_armed)$fatal(1,"dialog not armed, denied=%b kind=%0d",b.permission_denied,b.control.selected_kind);
        keys[3]=0;repeat(22000)@(negedge clk);keys[3]=1;
        wait(b.request_sequence!=old_sequence);
        wait(!b.ack_pending&&!b.command_request&&b.last_ack_result!=14);
        if(b.last_ack_result>1)$fatal(1,"submit rejected %0d",b.last_ack_result);

        repeat(12000)@(negedge clk);
    end endtask
    initial begin
        repeat(20)@(negedge clk);rst=0;send_heartbeat=1;wait(allowed);
        submit();if(!primary||primary_kind!=0)$fatal(1,"step33 earthquake drill missing");
        repeat(3)short_key(2);submit();
        if(primary||!cancel)$fatal(1,"step35 cancel missing");
        short_key(2);fire=1;repeat(30)@(negedge clk);submit();
        if(!primary||primary_kind!=1||cancel)$fatal(1,"step37 fire drill hidden by previous release");
        long_key(0);if(!b.selected_evacuation)$fatal(1,"step38 long KEY1 ignored");
        submit();if(!primary||primary_kind!=3)$fatal(1,"step38 evacuation missing");
        repeat(3)short_key(2);submit();
        if(primary||active_count!=0)$fatal(1,"step39 cancel ignored after evacuation");
        fire=0;short_key(2);submit();
        if(!primary||primary_kind!=0)$fatal(1,"step40 subsequent commands blocked");
        $display("TEST_PASS physical KEY1/3/4 debounce+hold, actual B top, UART, A snapshot: steps33-40 and republish");$finish;
    end
    initial begin #10000000;$fatal(1,"physical key acceptance timeout");end
endmodule
