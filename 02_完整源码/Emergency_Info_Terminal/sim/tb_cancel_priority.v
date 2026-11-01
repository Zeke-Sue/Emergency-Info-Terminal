`timescale 1ns/1ps
module tb_cancel_priority;
    reg clk=0,rst=1,frame=0,scene_tick=0,cmd=0,demo=0;
    reg [2:0] opcode=0,kind=1,level=1;reg [15:0] id=1;
    wire ready,result_valid,alarm,cancel,drill,pending,trusted,flash,visible,scene_cancel;
    wire [3:0] result;wire [2:0] alarm_kind,alarm_level;wire [15:0] seconds;
    wire [6:0] opacity;
    always #5 clk=~clk;
    emergency_control_core #(.CLK_HZ(1000000)) dut(.clk(clk),.rst(rst),.frame_tick(frame),
        .first_active_pixel(1'b0),.audio_sample_tick(1'b0),.demo_alarm(demo),
        .flash_rate(2'd0),.flash_duty(2'd0),.command_valid(cmd),.command_ready(ready),
        .command_opcode(opcode),.command_source(2'd0),.command_kind(kind),.command_event_id(id),
        .command_sequence(8'd1),.command_level(level),.command_drill(1'b0),.command_pending(1'b0),
        .command_region(3'd0),.command_time_trusted(1'b1),.command_remaining_seconds(16'd100),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),.command_result_valid(result_valid),
        .command_result_code(result),.alarm_active(alarm),.alarm_level(alarm_level),
        .alarm_kind(alarm_kind),.alarm_drill(drill),.alarm_pending(pending),
        .countdown_trusted(trusted),.countdown_seconds(seconds),.cancel_notice(cancel),.flash_on(flash));
    alarm_scene_control scene(.clk(clk),.rst(rst),.scene_tick(scene_tick),.alarm_active(alarm),
        .alarm_kind(alarm_kind),.alarm_level(alarm_level),.alarm_drill(drill),.cancel_notice(cancel),
        .flash_on(flash),.countdown_trusted(trusted),.countdown_seconds(seconds),
        .opacity(opacity),.cancel(scene_cancel),.visible(visible));
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL cancel priority: %0s raw=%b alarm=%b cancel=%b level=%d alpha=%d scene_cancel=%b primary=%h count=%d",
            msg,dut.event_cancel_notice,alarm,cancel,alarm_level,opacity,scene_cancel,dut.primary_event_id,dut.active_count);
        $finish;end endtask
    task send;input [2:0] op,k,l;input [15:0] event_id;
        begin
            wait(ready);@(negedge clk);opcode=op;kind=k;level=l;id=event_id;cmd=1;
            @(negedge clk);cmd=0;wait(result_valid);#1;if(result!=0)fail("command rejected");
            @(negedge clk);
        end
    endtask
    task commit;
        begin
            @(negedge clk);frame=1;@(negedge clk);frame=0;
            wait(dut.local_events.events.state==0&&!dut.local_events.events.summary_waiting);
            @(negedge clk);scene_tick=1;@(negedge clk);scene_tick=0;
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        send(0,1,1,1);send(0,1,2,2);commit();
        if(!alarm||cancel||alarm_level!=1||opacity!=64||scene_cancel)fail("primary selection");
        send(1,1,1,1);commit();
        if(!alarm||cancel||alarm_level!=2||opacity!=64||scene_cancel)
            fail("release hid remaining event");
        send(1,1,2,2);commit();
        if(!cancel||!scene_cancel||opacity!=62)fail("last event did not release");
        send(0,0,1,3);commit();
        if(cancel||scene_cancel||opacity!=64||alarm_kind!=0)fail("new urgent event did not preempt release");
        send(1,0,1,3);commit();
        if(!cancel||!scene_cancel)fail("second release");
        demo=1;#1;if(cancel||!alarm)fail("local L0 hidden by release");
        @(negedge clk);scene_tick=1;@(negedge clk);scene_tick=0;
        if(scene_cancel||opacity!=64)fail("local L0 did not hard cut");
        $display("TEST_PASS cancel priority: remaining primary/new urgent/local L0 override old release; last event fades");$finish;
    end
    initial begin #1000000;fail("bounded timeout");end
endmodule
