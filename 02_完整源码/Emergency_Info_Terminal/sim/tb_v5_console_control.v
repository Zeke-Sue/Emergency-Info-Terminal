`timescale 1ns/1ps
module tb_v5_console_control;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg [3:0] press=0,long_press=0,switches=14;
    reg ack=0;reg [31:0] ack_session=0,ack_seq=0;
    wire request,denied,evac;wire [2:0] kind,level,region;
    wire [15:0] id;wire [31:0] session,seq;
    reg [15:0] first_id;reg [2:0] first_level,first_region;
    duty_console_core #(.V5_CONTROLS(1),.CONFIRM_UI(0)) dut(.clk(clk),.rst(rst),.ms_tick(1'b0),
        .key_press(press),.key_long_press(long_press),.switches(switches),.request_valid(request),
        .request_ready(1'b1),.request_session(session),.request_sequence(seq),.request_event_id(id),
        .request_kind(kind),.request_level(level),.request_region(region),.selected_evacuation(evac),
        .ack_valid(ack),.ack_result(4'd0),.ack_session(ack_session),.ack_sequence(ack_seq),
        .heartbeat_valid(1'b0),.heartbeat_alarm(1'b0),.heartbeat_level(3'd0),
        .heartbeat_active_count(4'd0),.heartbeat_blocked_set(8'd0),
        .rx_frame_error(1'b0),.rx_crc_error(1'b0),.permission_denied(denied));
    task fail;input [799:0] why;begin $display("TEST_FAIL V5 console: %0s",why);$finish;end endtask
    task hold;input [3:0] mask;begin long_press=mask;@(negedge clk);long_press=0;end endtask
    task acknowledge;begin
        ack_session=session;ack_seq=seq;@(negedge clk);ack=1;@(negedge clk);ack=0;@(negedge clk);
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;@(negedge clk);
        hold(1);hold(8);if(request||!denied)fail("evacuation before accepted fire");
        hold(1);hold(8);if(!request||kind!=1)fail("fire publish");
        first_id=id;first_level=level;first_region=region;acknowledge();
        press=3;@(negedge clk);press=0;hold(1);hold(8);
        if(!request||kind!=3||id!=first_id||level!=first_level||region!=first_region)
            fail("explicit evacuation changed event identity or location");
        acknowledge();switches=15;hold(8);if(request||!denied)fail("maintainer acted as commander");
        switches=13;hold(8);if(request||!denied)fail("duty officer authorized evacuation");
        $display("TEST_PASS V5 console: commander-only explicit evacuation, accepted-fire prerequisite, retained event identity/region/level, maintainer/duty denial");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
