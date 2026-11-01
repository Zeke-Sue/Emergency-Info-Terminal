`timescale 1ns/1ps
module tb_v5_console_confirmation;
    reg clk=0,rst=1,tick=0;always #5 clk=~clk;
    reg [3:0] press=0,long_press=0,held=0,switches=14;
    reg heartbeat=0,remote_alarm=0,ready=0,ack=0;
    wire request,armed,expired,denied,alive,pending;
    wire [4:0] progress;wire [1:0] request_role;wire [31:0] session,seq;
    wire [3:0] result;wire [2:0] region;
    integer sent=0;
    duty_console_core #(.V5_CONTROLS(1),.CONFIRM_HOLD_MS(40),.CONFIRM_TIMEOUT_MS(100),
        .LINK_TIMEOUT_MS(200),.ACK_TIMEOUT_MS(60),.MAX_RETRIES(1)) dut(
        .clk(clk),.rst(rst),.ms_tick(tick),.key_press(press),.key_long_press(long_press),
        .key_held(held),.switches(switches),.request_valid(request),.request_ready(ready),
        .request_session(session),.request_sequence(seq),.request_role(request_role),
        .request_region(region),.confirmation_armed(armed),.confirmation_progress(progress),
        .confirmation_expired(expired),.ack_valid(ack),.ack_result(4'd0),
        .ack_session(session),.ack_sequence(seq),.heartbeat_valid(heartbeat),
        .heartbeat_alarm(remote_alarm),.heartbeat_level(3'd1),.heartbeat_active_count(4'd0),
        .heartbeat_blocked_set(8'd0),.rx_frame_error(1'b0),.rx_crc_error(1'b0),
        .permission_denied(denied),.link_alive(alive),.ack_pending(pending),.last_ack_result(result));
    always @(posedge clk)if(request&&ready)sent=sent+1;
    task fail;input [799:0] why;begin $display("TEST_FAIL V5 confirm %0s",why);$finish;end endtask
    task key;input [3:0] mask;begin press=mask;@(negedge clk);press=0;@(negedge clk);end endtask
    task ms;input integer n;integer j;begin
        for(j=0;j<n;j=j+1)begin tick=1;@(negedge clk);tick=0;@(negedge clk);end
    end endtask
    task heartbeat_pulse;begin heartbeat=1;@(negedge clk);heartbeat=0;@(negedge clk);end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;@(negedge clk);
        key(8);held=8;ms(40);held=0;
        if(request||armed||!denied)fail("offline command authorized");
        heartbeat_pulse();key(8);if(!armed)fail("online arm");
        held=8;ms(40);if(request||progress!=19)fail("early send");
        held=0;ms(1);if(progress!=0)fail("release not reset");
        held=8;ms(41);held=0;repeat(3)@(negedge clk);
        if(!request||request_role!=2||pending)fail("completed hold did not latch request");
        switches=15;repeat(3)@(negedge clk);
        if(!request||request_role!=2)fail("queued role changed with switches");
        ready=1;@(negedge clk);ready=0;@(negedge clk);
        if(!pending||sent!=1||result!=14)fail("sent command presented as success");
        ack=1;@(negedge clk);ack=0;@(negedge clk);
        if(pending||result!=0)fail("ack not applied");switches=14;
        key(8);held=8;ms(39);key(2);ms(1);held=0;
        if(request||armed)fail("selection changed on final tick");
        key(8);held=8;ms(39);switches=15;ms(1);held=0;
        if(request||armed)fail("role changed on final tick");switches=14;
        heartbeat_pulse();key(8);ms(100);
        if(armed||!expired||request)fail("10s-equivalent timeout");
        heartbeat_pulse();key(8);held=8;ms(20);remote_alarm=1;heartbeat_pulse();ms(20);held=0;
        if(armed||request)fail("new alarm failed to preempt dialog");
        heartbeat_pulse();key(8);key(8);if(armed)fail("back/cancel");
        ms(200);key(8);if(armed||request)fail("expired link allowed send");
        $display("TEST_PASS V5 B confirmation: offline refusal, exact hold, role/payload pinning, pending versus ACK, selection/role/alarm cancel, timeout, cancel, lost link");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
