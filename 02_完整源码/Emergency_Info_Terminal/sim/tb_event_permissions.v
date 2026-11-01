`timescale 1ns/1ps
module tb_event_permissions;
    reg clk=0,rst=1,frame=0,valid=0,drill=0;
    reg [2:0] op=0,kind=1;reg [1:0] role=2;
    reg [7:0] seq=1;reg [31:0] now=0;
    always #5 clk=~clk;
    wire ready,done,primary;wire [3:0] code,count;wire [2:0] primary_kind;
    wire [7:0] blocked;wire settled;
    event_manager #(.CHECK_ROLE(1)) dut(.clk(clk),.rst(rst),.frame_tick(frame),.now_seconds(now),
        .cmd_valid(valid),.cmd_opcode(op),.cmd_source(2'd2),.cmd_kind(kind),.cmd_event_id(16'd123),
        .cmd_sequence(seq),.cmd_level(3'd1),.cmd_drill(drill),.cmd_pending(1'b0),.cmd_region(3'd2),
        .cmd_time_trusted(1'b0),.cmd_remaining_seconds(16'd0),.cmd_role(role),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),.cmd_ready(ready),.result_valid(done),
        .result_code(code),.primary_valid(primary),.primary_kind(primary_kind),
        .active_count(count),.blocked_set(blocked),.settled(settled));
    reg snapshot_valid=0,snapshot_frame=0;
    reg [32:0] snapshot=0;reg [15:0] snapshot_id=1;
    wire snapshot_ready,snapshot_done,snapshot_primary;
    wire [3:0] snapshot_result;wire [15:0] primary_id;
    event_snapshot_sink #(.CHECK_ROLE(1)) sink(.clk(clk),.rst(rst),.frame_tick(snapshot_frame),
        .command_valid(snapshot_valid),.command_opcode(3'd6),.command_kind(3'd3),
        .command_level(3'd1),.command_region(3'd2),.command_event_id(snapshot_id),
        .command_remaining(16'd0),.command_sequence(8'd1),.command_drill(1'b0),
        .command_pending(1'b0),.command_trusted(1'b0),.epoch_changed(1'b0),.snapshot(snapshot),
        .command_ready(snapshot_ready),.result_valid(snapshot_done),.result_code(snapshot_result),
        .primary_valid(snapshot_primary),.primary_event_id(primary_id));
    task fail;input [799:0] msg;begin $display("TEST_FAIL permissions: %0s code=%d primary=%b kind=%d count=%d blocked=%h state=%d",msg,code,primary,primary_kind,count,blocked,dut.state);$finish;end endtask
    task command;input [3:0] expected;begin
        wait(ready);@(negedge clk);valid=1;@(negedge clk);valid=0;wait(done);#1;
        if(code!=expected)fail("unexpected execution permission");
        @(negedge clk);frame=1;@(negedge clk);frame=0;
        @(negedge clk);while(!settled)@(negedge clk);seq=seq+1'b1;
    end endtask
    task apply_snapshot;input [7:0] tag;input [3:0] expected;begin
        wait(snapshot_ready);@(negedge clk);snapshot={tag,25'h21};snapshot_valid=1;
        @(negedge clk);snapshot_valid=0;repeat(5)@(negedge clk);
        if(snapshot_done)fail("snapshot ACK before frame commit");
        snapshot_frame=1;@(negedge clk);snapshot_frame=0;
        if(!snapshot_done||snapshot_result!=expected)fail("A execution permission");
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;command(0);
        if(!primary||blocked!=4)fail("commander fire missing");
        role=1;drill=1;command(8);op=1;command(8);
        if(!primary||count!=1)fail("role spoof downgraded or cleared real event");
        role=3;drill=0;command(8);
        role=2;op=0;kind=3;command(0);
        now=1000000;@(negedge clk);frame=1;@(negedge clk);frame=0;
        @(negedge clk);while(!settled)@(negedge clk);
        if(!primary||primary_kind!=3||blocked!=4)fail("evacuation lost fire blockage or auto expired");
        op=1;command(0);if(primary||count)fail("authorized cancellation");
        apply_snapshot(8'h00,8);if(snapshot_primary)fail("legacy untagged mutation accepted");
        apply_snapshot(8'ha6,8);if(snapshot_primary)fail("duty authorized evacuation");
        apply_snapshot(8'hc6,0);if(!snapshot_primary||primary_id!=1)fail("commander commit");
        snapshot_id=2;apply_snapshot(8'he6,8);if(primary_id!=1)fail("rejected snapshot replaced visible event");
        $display("TEST_PASS permissions: B stored-event checks, forged drill rejection, latched fire/evacuation, A frame-time role checks and unchanged state after denial");$finish;
    end
    initial begin #500000;fail("timeout");end
endmodule
