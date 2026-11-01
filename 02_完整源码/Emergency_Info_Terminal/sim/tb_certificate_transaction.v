`timescale 1ns/1ps
module tb_certificate_transaction;
    reg clk=0,rst=1,frame=0,msg=0,last=0,complete=0;
    reg [7:0] kind=0;
    reg [15:0] batch=0;
    reg [95:0] payload=0;
    reg must_allow=0;
    wire input_ready,commit_ready,ready,allowed,error;
    wire [95:0] certificate;
    wire [15:0] active_batch,bitmap;
    integer i,errors=0;
    always #5 clk=~clk;
    v41_resync_receiver #(.CERTIFICATE_COUNT(12)) dut(.clk(clk),.rst(rst),.frame_tick(frame),
        .msg_valid(msg),.msg_type(kind),.msg_batch(batch),.msg_payload(payload),.msg_last(last),
        .msg_ready(input_ready),.commit_ready(commit_ready),.certificate_lookup_index(4'd0),
        .active_certificate(certificate),.certificate_ready(ready),
        .active_certificate_valid_bitmap(bitmap),.batch_error(error),.active_batch(active_batch));
    admission_certificate_gate #(.LIVE_CERTIFICATE(1)) gate(.clk(clk),.rst(rst),
        .load_begin(1'b0),.load_complete(complete),.file_purpose(8'h21),
        .file_length(32'd2000),.file_crc32(32'h12345678),
        .certificate_valid(ready),.certificate_purpose(certificate[7:0]),
        .certificate_length(certificate[39:8]),.certificate_crc32(certificate[71:40]),
        .certificate_pass(certificate[72]),.certificate_version(certificate[92:77]),
        .use_external(allowed));
    always @(negedge clk)begin
        if(error)errors=errors+1;
        if(must_allow&&!allowed)begin
            $display("TEST_FAIL live certificate interrupted during inactive-bank update");$finish;
        end
    end
    task send;
        input [7:0] t;input [95:0] p;input tail;
        begin
            @(negedge clk);while(!input_ready)@(negedge clk);
            msg=1;kind=t;payload=p;last=tail;
            @(negedge clk);msg=0;last=0;
        end
    endtask
    task header;
        input [15:0] b;
        begin batch=b;send(8'h0c,b,0);send(8'h0d,96'd0,0);send(8'h0b,96'd0,0);end
    endtask
    function [95:0] record;
        input integer n;input revoke;
        begin record={3'd0,(revoke&&n==0 ? 16'd0 : 16'h0500),4'd0,1'b1,
            32'h12345678,32'd2000,8'h21+n[7:0]};end
    endfunction
    task commit;
        begin
            while(!commit_ready)@(negedge clk);
            @(negedge clk);frame=1;@(negedge clk);frame=0;#1;
        end
    endtask
    task pulse_frame;
        begin @(negedge clk);frame=1;@(negedge clk);frame=0;#1;end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;complete=1;
        @(negedge clk);complete=0;
        header(1);for(i=0;i<12;i=i+1)send(8'h0e,record(i,0),i==11);

        pulse_frame();if(active_batch!=0)begin $display("TEST_FAIL early commit");$finish;end
        commit();if(!allowed||bitmap!=16'h0fff)begin $display("TEST_FAIL initial authorization");$finish;end
        must_allow=1;
        header(2);for(i=0;i<12;i=i+1)send(8'h0e,record(i,0),i==11);
        commit();if(active_batch!=2)begin $display("TEST_FAIL replacement batch");$finish;end
        header(3);for(i=0;i<12;i=i+1)send(8'h0e,record(i,1),i==11);
        while(!commit_ready)@(negedge clk);
        must_allow=0;commit();
        if(allowed||ready||certificate!=0||bitmap[0])begin
            $display("TEST_FAIL empty slot did not revoke live authorization");$finish;end
        header(4);for(i=0;i<11;i=i+1)send(8'h0e,record(i,0),i==10);
        repeat(20)@(negedge clk);pulse_frame();
        if(active_batch!=3||allowed||commit_ready)begin $display("TEST_FAIL incomplete batch committed");$finish;end
        header(5);for(i=0;i<12;i=i+1)send(8'h0e,record(i,0),0);
        send(8'h7f,96'd0,1);repeat(20)@(negedge clk);pulse_frame();
        if(active_batch!=3||allowed||commit_ready)begin $display("TEST_FAIL malformed last record committed");$finish;end
        header(6);send(8'h0e,record(0,0),0);

        msg=1;kind=8'h0e;payload=record(1,0);last=1;
        @(negedge clk);msg=0;last=0;repeat(20)@(negedge clk);pulse_frame();
        if(active_batch!=3||allowed||commit_ready)begin $display("TEST_FAIL overrun batch committed");$finish;end
        header(7);for(i=0;i<12;i=i+1)send(8'h0e,record(i,0),i==11);
        commit();if(!allowed||active_batch!=7||errors<3)begin $display("TEST_FAIL recovery or diagnostics");$finish;end
        $display("TEST_PASS atomic 12-slot narrow RAM, seamless renewal, live revocation, malformed/partial/overrun rejection and recovery");
        $finish;
    end
    initial begin #100000;$display("TEST_FAIL certificate transaction timeout");$finish;end
endmodule
