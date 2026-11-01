`timescale 1ns/1ps
module tb_event_authority_link #(parameter integer CHECK_ROLES=0);
    reg ac=0,bc=0,ar=1,br=1;
    always #10 ac=~ac;
    always #5 bc=~bc;
    reg forward_link=1,return_link=1,demo=0,corrupt_wire=0;
    reg [31:0] a_boot=1;
    reg [15:0] af=0;
    reg [12:0] ah=0;
    reg [11:0] bm=0;
    reg au=0;reg [1:0] bu=0;
    wire frame_tick=af==33599,heartbeat_tick=ah==4999,ms_tick=bm==3999;
    always @(posedge ac)if(ar)begin af<=0;ah<=0;au<=0;end
        else begin af<=frame_tick ? 0 : af+1'b1;ah<=heartbeat_tick ? 0 : ah+1'b1;au<=!au;end
    always @(posedge bc)if(br)begin bm<=0;bu<=0;end
        else begin bm<=ms_tick ? 0 : bm+1'b1;bu<=bu+1'b1;end
    reg request=0;wire request_ready;
    reg [1:0] action=0;
    reg [1:0] role=2;
    reg [31:0] request_sequence=1;
    reg [15:0] event_id=16'h1001,remaining=120;
    reg [7:0] event_sequence=1;
    reg [2:0] level=1,region=0;
    wire snap_valid,snap_ready,user_ack,recovery;
    wire [3:0] user_result;
    wire [95:0] payload;
    wire [31:0] wire_session,wire_sequence;
    wire reply_ack,reply_heartbeat;
    wire [3:0] reply_result;
    wire [31:0] reply_session,reply_sequence,remote_boot,remote_session;
    console_event_authority #(.FRAME_CYCLES(67200),.RETRY_MS(30),.REFRESH_MS(5),.SECOND_MS(4),.CHECK_ROLE(CHECK_ROLES)) authority(
        .clk(bc),.rst(br),.ms_tick(ms_tick),.request_valid(request),.request_ready(request_ready),
        .request_action(action),.request_source(2'd2),.request_session(32'h12345678),
        .request_sequence(request_sequence),.request_event_id(event_id),.request_remaining(remaining),
        .request_event_sequence(event_sequence),.request_level(level),.request_region(region),
        .request_kind(3'd0),.request_drill(1'b0),.request_pending(1'b0),.request_trusted(1'b1),
        .request_role(role),
        .ack_valid(reply_ack),.ack_result(reply_result),.ack_session(reply_session),.ack_sequence(reply_sequence),
        .heartbeat_valid(reply_heartbeat),.remote_boot(remote_boot),.remote_session(remote_session),
        .user_ack_valid(user_ack),.user_ack_result(user_result),.user_ack_session(),.user_ack_sequence(),
        .snapshot_valid(snap_valid),.snapshot_ready(snap_ready),.snapshot_payload(payload),
        .snapshot_session(wire_session),.snapshot_sequence(wire_sequence),
        .authoritative_event(),.blocked_set(),.recovery_required(recovery));
    wire bv,bready,btx;wire [7:0] byte_b;
    console_status_framer #(.DYNAMIC_TYPE(1),.EXTERNAL_IDENTITY(1),
        .STABLE_EXTERNAL_SESSION(1)) framer(
        .clk(bc),.rst(br),.request_valid(snap_valid),.request_ready(snap_ready),
        .request_payload(payload),.request_type(8'h26),.request_session(wire_session),
        .request_sequence(wire_sequence),.byte_valid(bv),.byte_ready(bready),.byte_data(byte_b));
    uart_tx_8n1 #(.CLK_HZ(4000000),.BAUD(100000)) txb(
        .clk(bc),.rst(br),.data(byte_b),.valid(bv),.ready(bready),.tx(btx));
    wire atx,cv,cr,rv,drill,pending,trusted,epoch;
    wire [2:0] op,kind,cl,regn;wire [1:0] source;
    wire [15:0] id,rem;wire [7:0] seq;wire [32:0] metadata;
    wire [3:0] result,count;wire alarm,online,alarm_pending;
    wire [2:0] alarm_level;wire [7:0] blocked;
    wire latency,finish;wire [3:0] finish_reason;wire [23:0] pixel_latency,audio_latency;
    p3_uart_endpoint #(.CLK_HZ(2000000),.BAUD(100000),.ENABLE_EVENT_SNAPSHOT(1)) endpoint(
        .clk(ac),.rst(ar),.rx(forward_link ? btx^corrupt_wire : 1'b1),.tx(atx),.us_tick(au),
        .command_valid(cv),.command_ready(cr),.command_opcode(op),.command_source(source),
        .command_kind(kind),.command_event_id(id),.command_sequence(seq),.command_level(cl),
        .command_drill(drill),.command_pending_flag(pending),.command_region(regn),
        .command_time_trusted(trusted),.command_remaining_seconds(rem),
        .command_snapshot(metadata),.command_epoch_changed(epoch),
        .command_result_valid(rv),.command_result_code(result),.latency_valid(latency),
        .pixel_latency_us(pixel_latency),.audio_latency_us(audio_latency),
        .finish_valid(finish),.finish_reason(finish_reason),.heartbeat_tick(heartbeat_tick),
        .alarm_active(alarm),.alarm_level(alarm_level),.active_count(count),.blocked_set(blocked),
        .boot_count(a_boot),.telemetry_tick(1'b0),.telemetry_last_line(16'd0),
        .telemetry_max_line(16'd0),.telemetry_video_underflows(16'd0),.telemetry_uart_errors(16'd0),
        .service_valid(),.service_type(),.service_batch(),.service_payload(),.service_last(),
        .frame_error(),.crc_error());
    emergency_control_core #(.CLK_HZ(2000000),.REMOTE_EVENTS(1),.REMOTE_LINK_FRAMES(4),.LOCAL_FIRE(CHECK_ROLES)) terminal(
        .clk(ac),.rst(ar),.frame_tick(frame_tick),.first_active_pixel(frame_tick),
        .audio_sample_tick(au),.demo_alarm(demo),.flash_rate(2'd1),.flash_duty(2'd1),
        .local_fire_active(1'b0),.local_fire_confirmed(1'b0),.local_fire_evacuation(1'b0),
        .command_valid(cv),.command_opcode(op),.command_source(source),.command_kind(kind),
        .command_event_id(id),.command_sequence(seq),.command_level(cl),.command_drill(drill),
        .command_pending(pending),.command_region(regn),.command_time_trusted(trusted),
        .command_remaining_seconds(rem),.command_snapshot(metadata),.command_epoch_changed(epoch),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),.command_result_valid(rv),
        .command_result_code(result),.command_ready(cr),.alarm_active(alarm),.alarm_level(alarm_level),
        .alarm_kind(),.alarm_drill(),.alarm_pending(alarm_pending),.countdown_trusted(),
        .countdown_seconds(),.cancel_notice(),.flash_on(),.buzzer_on(),.blocked_set(blocked),
        .active_count(count),.authority_online(online),.latency_valid(latency),
        .pixel_latency_us(pixel_latency),.audio_latency_us(audio_latency),
        .finish_valid(finish),.finish_reason(finish_reason),.sample_count());
    wire rxv;wire [7:0] rxd;
    uart_rx_8n1 #(.CLK_HZ(4000000),.BAUD(100000)) rxb(
        .clk(bc),.rst(br),.rx(return_link ? atx : 1'b1),.data(rxd),.valid(rxv),.framing_error());
    console_reply_parser replies(.clk(bc),.rst(br),.byte_valid(rxv),.byte_data(rxd),.us_tick(bu==3),
        .ack_valid(reply_ack),.ack_result(reply_result),.ack_session(reply_session),.ack_sequence(reply_sequence),
        .heartbeat_valid(reply_heartbeat),.remote_alarm(),.remote_level(),.remote_active_count(),
        .remote_blocked_set(),.remote_boot_count(remote_boot),.remote_session(remote_session),
        .telemetry_valid(),.telemetry_last_line(),.telemetry_max_line(),.telemetry_video_underflows(),
        .telemetry_uart_errors(),.latency_valid(),.pixel_latency_us(),.audio_latency_us(),
        .finish_valid(),.finish_reason(),.frame_error(),.crc_error());
    integer acknowledgements=0,previous_acks,stage=0,boundary_hits=0;
    reg [3:0] last_result;
    always @(posedge bc)if(!br&&user_ack)begin acknowledgements=acknowledgements+1;last_result=user_result;end
    always @(posedge bc)if(!br&&request&&request_ready&&snap_valid&&snap_ready)
        boundary_hits=boundary_hits+1;
    task fail;input [8*120-1:0] reason;begin
        $display("TEST_FAIL event authority: %0s stage=%0d time=%0t count=%0d result=%0d",reason,stage,$time,count,last_result);$finish;
    end endtask
    task submit;begin
        previous_acks=acknowledgements;
        @(negedge bc);while(!request_ready)@(negedge bc);request=1;
        @(negedge bc);request=0;request_sequence=request_sequence+1;
    end endtask
    task transact;begin submit();wait(acknowledgements>previous_acks);@(negedge bc);end endtask
    initial begin
        repeat(12)@(negedge bc);ar=0;br=0;
        if(CHECK_ROLES)begin
            role=1;transact();if(last_result!=8||alarm)fail("B authority accepted unauthorized real alert");
            role=2;
        end
        stage=1;submit();
        wait(framer.position==17&&txb.bit_index==3&&txb.count==39);
        @(negedge bc);corrupt_wire=1;repeat(40)@(negedge bc);corrupt_wire=0;
        wait(endpoint.parser.crc_error);if(alarm)fail("corrupt snapshot was applied");
        stage=2;
        wait(acknowledgements>previous_acks);
        if(last_result!=0||!alarm||count!=1)fail("CRC retry/first publish/physical ACK");
        stage=3;event_id=16'h1002;level=2;transact();
        if(count!=2||alarm_level!=1)fail("B table primary arbitration");
        action=3;event_id=16'h1001;transact();
        if(last_result!=0||count!=1||alarm_level!=2)fail("cancel and next primary");
        action=1;region=3;transact();if(!blocked[3])fail("blocked set snapshot");
        stage=4;forward_link=0;wait(!online);#1;
        if(!alarm||count!=1||!alarm_pending)fail("link loss did not retain L0/suppress stale route");
        demo=1;repeat(4)@(negedge ac);if(!alarm||alarm_level!=1)fail("independent local alarm");
        demo=0;forward_link=1;wait(online);repeat(2)@(negedge ac);
        if(!alarm||alarm_level!=2)fail("reconnect lost retained primary");
        stage=5;return_link=0;action=0;event_id=16'h1003;level=1;remaining=500;
        submit();wait(count==2&&alarm_level==1);#3000000;
        if(authority.events.active_count!=2||acknowledgements!=previous_acks)
            fail("lost ACK duplicated event or falsely acknowledged output");
        event_id=16'h1005;submit();wait(count==3);
        if(acknowledgements!=previous_acks)fail("new request falsely acknowledged with return link lost");
        return_link=1;wait(acknowledgements>previous_acks);
        stage=6;
        @(negedge ac);ar=1;a_boot=2;repeat(8)@(negedge ac);ar=0;
        wait(online&&alarm&&count==3);if(alarm_level!=1)fail("A restart snapshot restore");
        stage=7;
        @(negedge bc);br=1;repeat(8)@(negedge bc);br=0;
        action=0;event_id=16'h1004;level=4;remaining=120;transact();
        if(last_result!=7||!recovery||!alarm||alarm_level!=1)
            fail("B restart silently replaced retained alarm");
        stage=8;action=3;transact();if(last_result!=0||alarm||count!=0||recovery)
            fail("explicit recovery clear failed");
        stage=9;action=0;event_id=16'h2001;remaining=0;level=4;
        while(!(snap_valid&&snap_ready))@(negedge bc);
        if(!request_ready)fail("new request not ready at snapshot boundary");
        previous_acks=acknowledgements;request=1;
        @(negedge bc);request=0;request_sequence=request_sequence+1;
        wait(acknowledgements>previous_acks);@(negedge bc);
        if(!alarm||count!=1)fail("expiry case was not published");
        wait(!alarm&&count==0);
        if(boundary_hits==0)fail("simultaneous request/snapshot case was not exercised");
        stage=10;forward_link=0;return_link=0;event_id=16'h2002;submit();
        wait(authority.events.primary_valid);
        wait(!authority.events.primary_valid);
        repeat(270000)@(negedge bc);
        if(authority.snapshot_payload[88]||authority.snapshot_payload[54:51]!=0)
            fail("expired event remained in retransmit snapshot");
        forward_link=1;return_link=1;
        repeat(200000)begin @(negedge bc);if(alarm)fail("reconnect replayed expired alarm");end
        $display("TEST_PASS event authority real UART, independent clocks, CRC retry, multi-event/cancel/block, lost ACK/new request, link loss, A/B reset, recovery, simultaneous send and expiry");
        $finish;
    end
    initial begin #150000000;fail("bounded timeout");end
endmodule

module tb_event_authority_roles_link;
    tb_event_authority_link #(.CHECK_ROLES(1)) test();
endmodule
