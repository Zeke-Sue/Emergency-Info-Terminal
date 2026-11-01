`timescale 1ns/1ps
module tb_p3_event_manager;
    reg clk=0,rst=1,frame_tick=0,cmd_valid=0;
    always #5 clk=~clk;
    reg [31:0] now_seconds=100;
    reg [2:0] opcode=0,kind=0,level=4,region=0;
    reg [1:0] source=0;
    reg [15:0] event_id=0,remaining=0;
    reg [7:0] sequence=0;
    reg drill=0,pending=0,time_trusted=0;
    wire cmd_ready,result_valid,primary_valid,primary_drill,primary_time_trusted,cancel_notice,full_urgent;
    wire [3:0] result_code,active_count;
    wire [4:0] tombstone_count;
    wire [2:0] primary_level,primary_kind,primary_region;wire [7:0] primary_sequence;
    wire [1:0] primary_source;wire [15:0] primary_event_id,primary_remaining;wire [7:0] blocked;
    event_manager #(.CANCEL_FRAMES(3)) dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),.now_seconds(now_seconds),
        .cmd_valid(cmd_valid),.cmd_opcode(opcode),.cmd_source(source),.cmd_kind(kind),.cmd_event_id(event_id),
        .cmd_sequence(sequence),.cmd_level(level),.cmd_drill(drill),.cmd_pending(pending),.cmd_region(region),
        .cmd_time_trusted(time_trusted),.cmd_remaining_seconds(remaining),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .cmd_ready(cmd_ready),.result_valid(result_valid),
        .result_code(result_code),.primary_valid(primary_valid),.primary_source(primary_source),
        .primary_kind(primary_kind),.primary_event_id(primary_event_id),
        .primary_sequence(primary_sequence),.primary_level(primary_level),
        .primary_drill(primary_drill),.primary_time_trusted(primary_time_trusted),
        .primary_remaining_seconds(primary_remaining),.primary_region(primary_region),.active_count(active_count),
        .tombstone_count(tombstone_count),.blocked_set(blocked),.cancel_notice(cancel_notice),.full_urgent(full_urgent));
    task fail;input [8*120-1:0] reason;begin $display("TEST_FAIL tb_p3_event_manager: %0s",reason);$finish;end endtask
    task frame;begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;
        wait(dut.state==0 && !dut.summary_waiting);@(posedge clk);#1;end endtask
    task command;input [2:0] op;input [1:0] src;input [15:0] id;input [7:0] seq;input [2:0] lev;
        input is_drill;input [2:0] k;input [2:0] r;
        begin wait(cmd_ready);@(negedge clk);opcode=op;source=src;event_id=id;sequence=seq;level=lev;drill=is_drill;kind=k;region=r;
            cmd_valid=1;@(negedge clk);cmd_valid=0;wait(result_valid);#1;end
    endtask
    integer i;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        command(0,0,16'h10,1,3,1,0,0);if(result_code!=0)fail("drill insert");
        command(0,1,16'h20,1,3,0,0,0);frame();
        if(!primary_valid||primary_event_id!=16'h20||primary_drill)fail("real event did not outrank drill");
        command(0,1,16'h20,1,3,0,0,0);if(result_code!=1)fail("duplicate sequence");
        command(0,1,16'h20,0,2,0,0,0);if(result_code!=2)fail("stale sequence");
        remaining=20;command(0,1,16'h20,2,3,0,0,0);frame();
        if(primary_sequence!=2||primary_remaining!=20)fail("renewal did not commit");
        command(0,2,16'h30,1,2,0,1,5);frame();
        if(!blocked[5]||primary_event_id!=16'h30)fail("fire block or severity arbitration");
        command(1,2,16'h30,2,2,0,1,5);if(result_code!=0)fail("cancel primary");frame();
        if(!cancel_notice||blocked[5])fail("cancel notice/tombstone frame commit");
        command(0,2,16'h30,3,1,0,1,5);if(result_code!=3)fail("cancelled event resurrected");
        command(5,0,0,0,4,0,0,0);frame();
        remaining=0;command(0,0,16'h40,1,3,0,0,0);now_seconds=200;frame();
        if(active_count!=0||primary_valid||tombstone_count==0)fail("expiry/tombstone rule");
        command(5,0,0,0,4,0,0,0);frame();now_seconds=100;remaining=0;
        for(i=0;i<8;i=i+1) command(0,i[1:0],16'h100+i,i+1,1,0,0,0);
        frame();if(active_count!=8)fail("protected table fill");
        command(0,0,16'h200,1,1,0,0,0);
        if(result_code!=4||!full_urgent)fail("full protected table rule");
        repeat(3)begin frame();if(!full_urgent)fail("urgent overflow lost across frame");end
        now_seconds=200;frame();
        if(active_count||primary_valid||!full_urgent)fail("overflow lost after recorded events expired");
        command(5,0,0,0,4,0,0,0);frame();
        if(full_urgent)fail("protected clear did not clear urgent overflow");
        $display("TEST_PASS tb_p3_event_manager arbitration, duplicate/stale, tombstone, block set and latched protected-full fallback");$finish;
    end
    initial begin #500000;fail("timeout");end
endmodule
