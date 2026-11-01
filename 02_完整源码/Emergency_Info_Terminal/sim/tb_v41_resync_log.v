`timescale 1ns/1ps
module tb_v41_resync_log;
    reg clk=0,rst=1,heartbeat=0,force_sync=0,frame_tick=0;
    wire msg_ready,certificate_ready;
    reg [31:0] boot=0,parameters=32'h11223344;reg [63:0] event_state=64'h0123456789abcdef;
    reg [7:0] blocked=8'h24;
    reg [95:0] certificate={3'd0,16'h0401,4'd0,1'b1,
        32'ha1b2c3d4,32'd32,8'h21};
    reg certificate_update=0;reg [3:0] certificate_update_index=0;
    wire msg_valid,msg_last,resync_active,resync_done;wire [7:0] msg_type;
    wire [15:0] msg_batch;wire [95:0] msg_payload;
    wire [31:0] active_parameters;wire [63:0] active_event;wire [7:0] active_blocked;
    wire [95:0] active_certificate;wire [15:0] active_certificate_valid_bitmap;
    wire state_valid,apply_pulse,batch_error;wire [15:0] active_batch;
    reg push=0,fetch=0;reg [7:0] push_type=0;reg [63:0] push_data=0;reg [23:0] stamp=0;
    reg [15:0] fetch_seq=0;wire fetch_done,fetch_found;wire [7:0] fetch_type;
    wire [63:0] fetch_data;wire [23:0] fetch_stamp;wire [15:0] oldest,next,count;
    wire [31:0] overwritten;
    integer k;
    always #5 clk=~clk;
    v41_resync_sender sender(.clk(clk),.rst(rst),.heartbeat_valid(heartbeat),
        .remote_boot_count(boot),.force_resync(force_sync),.parameters(parameters),
        .event_state(event_state),.blocked_set(blocked),
        .certificate_update_valid(certificate_update),
        .certificate_update_index(certificate_update_index),
        .certificate_update(certificate),
        .msg_valid(msg_valid),.msg_ready(msg_ready),.msg_type(msg_type),
        .msg_batch(msg_batch),.msg_payload(msg_payload),.msg_last(msg_last),
        .resync_active(resync_active),.resync_done(resync_done));
    v41_resync_receiver receiver(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .msg_valid(msg_valid&&msg_ready),.msg_type(msg_type),.msg_batch(msg_batch),
        .msg_payload(msg_payload),.msg_last(msg_last),.msg_ready(msg_ready),
        .certificate_ready(certificate_ready),.certificate_lookup_index(4'd0),
        .active_parameters(active_parameters),
        .active_event(active_event),.active_blocked(active_blocked),
        .active_certificate(active_certificate),
        .active_certificate_valid_bitmap(active_certificate_valid_bitmap),
        .state_valid(state_valid),
        .apply_pulse(apply_pulse),.batch_error(batch_error),.active_batch(active_batch));
    v41_event_log_ring log_ring(.clk(clk),.rst(rst),.push_valid(push),.push_type(push_type),
        .push_data(push_data),.timestamp(stamp),.fetch_valid(fetch),
        .fetch_sequence(fetch_seq),.fetch_done(fetch_done),.fetch_found(fetch_found),
        .fetch_type(fetch_type),.fetch_data(fetch_data),.fetch_timestamp(fetch_stamp),
        .oldest_sequence(oldest),.next_sequence(next),.retained_count(count),
        .overwritten_count(overwritten));
    task fail;input [8*100-1:0] msg;begin $display("TEST_FAIL tb_v41_resync_log: %0s",msg);$finish;end endtask
    task pulse_fetch;input [15:0] seq;begin @(negedge clk);fetch_seq=seq;fetch=1;@(negedge clk);fetch=0;#1;end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        @(negedge clk);certificate_update=1;
        @(negedge clk);certificate_update=0;
        @(negedge clk);boot=32'h1;heartbeat=1;@(negedge clk);heartbeat=0;
        wait(resync_done);#1;
        if(state_valid||active_parameters!=0)fail("partial resync became active");
        while(!receiver.commit_ready)@(negedge clk);
        @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;#1;
        if(!state_valid||active_parameters!=parameters||active_event!=event_state||
           active_blocked!=blocked||
           active_certificate_valid_bitmap!=1||!apply_pulse)
            fail("atomic resync contents");
        while(!certificate_ready)@(negedge clk);
        #1;
        if(active_certificate!==certificate)begin
            $display("certificate got=%h expected=%h",active_certificate,certificate);
            fail("serialized certificate lookup");
        end
        parameters=32'h55667788;boot=2;
        @(negedge clk);heartbeat=1;@(negedge clk);heartbeat=0;
        wait(resync_done);while(!receiver.commit_ready)@(negedge clk);
        @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;#1;
        if(active_parameters!=32'h55667788||active_batch!=2)fail("boot-change resync");
        for(k=0;k<36;k=k+1)begin
            @(negedge clk);push=1;push_type=k;push_data=64'h1000+k;stamp=k;
            @(negedge clk);push=0;
        end
        #1;if(oldest!=4||next!=36||count!=32||overwritten!=4)fail("log wrap accounting");
        pulse_fetch(3);if(fetch_found)fail("overwritten log returned");
        pulse_fetch(4);if(!fetch_found||fetch_type!=4||fetch_data!=64'h1004||fetch_stamp!=4)fail("retained log fetch");
        $display("TEST_PASS tb_v41_resync_log boot-detected atomic resync and 32-entry recoverable log ring");$finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
