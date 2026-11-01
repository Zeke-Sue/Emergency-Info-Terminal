`timescale 1ns/1ps
module tb_duty_console;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg ms_tick=0;reg [3:0] press=0,long_press=0,switches=0;
    wire request,request_ready;wire [1:0] action,source;
    wire [31:0] session,sequence;wire [15:0] event_id,remaining;
    wire [7:0] event_sequence;wire [2:0] level,region,kind;
    wire drill,pending,trusted;
    reg ack_valid=0;reg [3:0] ack_result=0;
    reg [31:0] ack_session=0,ack_sequence=0;
    reg heartbeat=0,heartbeat_alarm=0;reg [2:0] heartbeat_level=0;
    reg [3:0] heartbeat_count=0;reg [7:0] heartbeat_blocked=0;
    wire [2:0] selected_level,selected_region,remote_level;
    wire [1:0] selected_action,role;
    wire link_alive,ack_pending,permission_denied,error_latched,remote_alarm;
    wire [3:0] last_ack,remote_count;wire [7:0] remote_blocked;
    duty_console_core #(.LINK_TIMEOUT_MS(5),.ACK_TIMEOUT_MS(4),.MAX_RETRIES(1)) dut(
        .clk(clk),.rst(rst),.ms_tick(ms_tick),.key_press(press),
        .key_long_press(long_press),.switches(switches),.request_valid(request),
        .request_ready(request_ready),.request_action(action),.request_source(source),
        .request_session(session),.request_sequence(sequence),.request_event_id(event_id),
        .request_event_sequence(event_sequence),.request_level(level),.request_drill(drill),
        .request_pending(pending),.request_region(region),.request_time_trusted(trusted),
        .request_remaining_seconds(remaining),.request_kind(kind),.ack_valid(ack_valid),
        .ack_result(ack_result),.ack_session(ack_session),.ack_sequence(ack_sequence),
        .heartbeat_valid(heartbeat),.heartbeat_alarm(heartbeat_alarm),
        .heartbeat_level(heartbeat_level),.heartbeat_active_count(heartbeat_count),
        .heartbeat_blocked_set(heartbeat_blocked),.rx_frame_error(1'b0),
        .rx_crc_error(1'b0),.selected_level(selected_level),
        .selected_region(selected_region),.selected_action(selected_action),
        .selected_role(role),.link_alive(link_alive),.ack_pending(ack_pending),
        .last_ack_result(last_ack),.permission_denied(permission_denied),
        .error_latched(error_latched),.remote_alarm(remote_alarm),
        .remote_level(remote_level),.remote_active_count(remote_count),
        .remote_blocked_set(remote_blocked));
    wire byte_valid;reg byte_ready=1;wire [7:0] byte_data;
    console_command_framer frame(.clk(clk),.rst(rst),.request_valid(request),
        .request_ready(request_ready),.request_action(action),.request_source(source),
        .request_session(session),.request_sequence(sequence),.request_event_id(event_id),
        .request_event_sequence(event_sequence),.request_level(level),.request_drill(drill),
        .request_pending(pending),.request_region(region),.request_time_trusted(trusted),
        .request_remaining_seconds(remaining),.request_kind(kind),.byte_valid(byte_valid),
        .byte_ready(byte_ready),.byte_data(byte_data));
    reg [7:0] captured [0:31];integer count=0,i,n;reg [15:0] crc;
    reg [31:0] expected_sequence;
    always @(posedge clk)if(byte_valid&&byte_ready)begin captured[count]=byte_data;count=count+1;end
    function [15:0] crc_next;input [15:0] current;input [7:0] value;
        integer b;reg [15:0] w;begin w=current^{value,8'h00};
        for(b=0;b<8;b=b+1)w=w[15]?(w<<1)^16'h1021:w<<1;crc_next=w;end endfunction
    task fail;input [8*120-1:0] reason;begin
        $display("TEST_FAIL tb_duty_console: %0s",reason);$finish;
    end endtask
    task pulse_press;input integer bit_number;begin
        @(negedge clk);press[bit_number]=1;@(negedge clk);press=0;
    end endtask
    task pulse_long;begin
        @(negedge clk);long_press[3]=1;@(negedge clk);long_press=0;
    end endtask
    task pulse_ms;begin @(negedge clk);ms_tick=1;@(negedge clk);ms_tick=0;end endtask
    task acknowledge;begin
        @(negedge clk);ack_session=session;ack_sequence=sequence;ack_result=0;ack_valid=1;
        @(negedge clk);ack_valid=0;#1;
        if(ack_pending)fail("sequence test ACK not consumed");
    end endtask
    task check_sequence;input [31:0] expected;begin
        if(sequence!==expected||event_sequence!==expected[7:0])
            fail("new command/retry sequence mismatch");
        if({captured[9],captured[10],captured[11],captured[12]}!==expected)
            fail("wire sequence mismatch");
    end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        switches=4'b0100;pulse_long;
        if(!permission_denied||request)fail("unauthorized real command not rejected");
        switches=4'b0110;
        pulse_press(0);pulse_press(0);pulse_press(0);
        pulse_press(1);pulse_press(1);
        if(selected_level!=4||selected_region!=2)fail("level/region selection");
        pulse_long;wait(count==25);@(negedge clk);
        check_sequence(32'd1);
        if(captured[0]!=8'ha5||captured[1]!=8'h5a||captured[3]!=8'h01||
           captured[4]!=2||captured[13]!=9)fail("publish frame header");
        if(captured[17]!=4||captured[18][0]!=0||captured[19]!=2)
            fail("publish frame payload");
        crc=16'hffff;for(i=2;i<23;i=i+1)crc=crc_next(crc,captured[i]);
        if(captured[23]!=crc[15:8]||captured[24]!=crc[7:0])fail("command CRC");
        if(!ack_pending)fail("ACK pending not armed");
        @(negedge clk);ack_session=session;ack_sequence=sequence;ack_result=0;ack_valid=1;
        @(negedge clk);ack_valid=0;#1;
        if(ack_pending||!link_alive||last_ack!=0)fail("matching ACK handling");
        @(negedge clk);heartbeat_alarm=1;heartbeat_level=2;heartbeat_count=3;
        heartbeat_blocked=8'h04;heartbeat=1;@(negedge clk);heartbeat=0;#1;
        if(!remote_alarm||remote_level!=2||remote_count!=3||remote_blocked!=8'h04)
            fail("heartbeat status capture");
        repeat(5)pulse_ms;#1;
        if(link_alive||!error_latched)fail("link timeout indication");
        expected_sequence=1;
        for(n=0;n<260;n=n+1)begin
            @(negedge clk);count=0;
            pulse_long;wait(count==25);@(negedge clk);
            expected_sequence=expected_sequence+1;
            check_sequence(expected_sequence);
            if(n==3)begin
                count=0;repeat(4)pulse_ms;
                wait(count==25);@(negedge clk);check_sequence(expected_sequence);
            end
            acknowledge;
        end

        @(negedge clk);dut.request_sequence=32'hffffffff;count=0;
        pulse_long;wait(count==25);@(negedge clk);check_sequence(32'd0);
        acknowledge;
        $display("TEST_PASS tb_duty_console permission, CRC, ACK, timeout, 260 commands, retry and sequence wraps");
        $finish;
    end
    initial begin #1000000;fail("timeout");end
endmodule
