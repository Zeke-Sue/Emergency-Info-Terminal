`timescale 1ns/1ps
module tb_audio_permission_probe;
    reg clk=0,rst=1,valid=0,last=0,frame=0,crc_bad=0,frame_bad=0;
    always #5 clk=~clk;
    reg [7:0] kind=0;
    reg [15:0] batch=0;
    reg [95:0] payload=0;
    wire apply,state_valid,allowed,batch_error;
    wire [31:0] active_parameters,last_parameters;
    wire [19:0] status;
    v41_resync_receiver #(.ENABLE_CERTIFICATES(0)) receiver(
        .clk(clk),.rst(rst),.frame_tick(frame),.msg_valid(valid&&kind<8'h20),
        .msg_last(last),.msg_type(kind),.msg_batch(batch),.msg_payload(payload),
        .certificate_lookup_index(4'd0),.apply_pulse(apply),.state_valid(state_valid),
        .active_parameters(active_parameters),.batch_error(batch_error));
    audio_play_permission #(.TIMEOUT_FRAMES(4)) permission(
        .clk(clk),.rst(rst),.frame_tick(frame),.snapshot_apply(apply),
        .parameters(active_parameters),.allowed(allowed));
    audio_permission_probe probe(.clk(clk),.rst(rst),.service_valid(valid),
        .service_last(last),.service_type(kind),.service_batch(batch),.service_payload(payload),
        .apply(apply),.state_valid(state_valid),.allowed(allowed),.batch_error(batch_error),
        .crc_error(crc_bad),.frame_error(frame_bad),.active_parameters(active_parameters),
        .status(status),.last_parameters(last_parameters));
    task record;
        input [7:0] k;input [15:0] b;input [31:0] p;input l;
        begin
            @(negedge clk);valid=1;kind=k;batch=b;payload=p;last=l;
            @(negedge clk);valid=0;last=0;repeat(3)@(negedge clk);
        end
    endtask
    task tick;
        begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(4)@(negedge clk);end
    endtask
    task snapshot;
        input [15:0] b;input [31:0] p;
        begin record(8'h0c,b,p,0);record(8'h0d,b,0,0);record(8'h0b,b,0,1);tick();end
    endtask
    integer n;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        record(8'h20,0,0,1);
        if(status!==20'h80000||allowed)$fatal(1,"status alone must not look like audio permission");
        record(8'h0c,1,32'ha6100001,0);record(8'h0b,1,0,1);tick();
        if(allowed||status[19:16]!=4'hd||status[15:12]!=4'he||status[7:4]!=0||!status[3])
            $fatal(1,"incomplete batch not diagnosed: %h",status);
        snapshot(2,32'ha6180641);
        if(!allowed||status!==20'hfff18||last_parameters!==32'ha6180641)
            $fatal(1,"complete grant not diagnosed: %h raw=%h",status,last_parameters);
        snapshot(3,32'ha6180640);
        if(allowed||status[11:8]!=4'hc||status[15:12]!=4'hb)
            $fatal(1,"explicit revoke not diagnosed: %h",status);
        snapshot(4,32'ha6100001);
        repeat(5)tick();
        if(allowed||status[11:8]!=4'he||!status[12])$fatal(1,"lease expiry history lost: %h",status);
        record(8'h0d,99,0,0);
        @(negedge clk);crc_bad=1;frame_bad=1;
        @(negedge clk);crc_bad=0;frame_bad=0;
        if(status[3:0]!=4'hf)$fatal(1,"sticky protocol errors missing");
        for(n=5;n<24;n=n+1)snapshot(n,32'ha6100001);
        if(status[7:4]!=15)$fatal(1,"commit counter did not saturate");
        $display("TEST_PASS permission probe distinguishes status-only, incomplete batch, grant, revoke, expiry, mismatched batch and CRC/frame errors");
        $finish;
    end
    initial begin #100000;$fatal(1,"probe timeout");end
endmodule
