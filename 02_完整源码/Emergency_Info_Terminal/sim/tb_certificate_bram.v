`timescale 1ns/1ps
module tb_certificate_bram;
    reg clk=0,rst=1,frame=0,message=0,last=0;
    always #5 clk=~clk;
    reg [7:0] kind=0;
    reg [95:0] payload=0;
    reg [3:0] lookup=0;
    wire [95:0] certificate;
    wire ready,message_ready;
    wire [15:0] bitmap;
    reg [95:0] expected[0:9];
    integer i;
    v41_resync_receiver dut(.clk(clk),.rst(rst),.frame_tick(frame),
        .msg_valid(message),.msg_type(kind),.msg_batch(16'd1),.msg_payload(payload),
        .msg_last(last),.msg_ready(message_ready),.certificate_lookup_index(lookup),.active_certificate(certificate),
        .active_certificate_valid_bitmap(bitmap),.certificate_ready(ready));
    task send;
        input [7:0] t;input [95:0] p;input tail;
        begin
            @(negedge clk);while(!message_ready)@(negedge clk);
            message=1;kind=t;payload=p;last=tail;
            @(negedge clk);message=0;last=0;
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        send(8'h0c,96'd0,0);send(8'h0d,96'd0,0);send(8'h0b,96'd0,0);
        for(i=0;i<10;i=i+1)begin
            expected[i]={3'd0,16'h1234,4'd0,1'b1,32'ha5a5a5a5^i,32'd96000+i,8'h21+i[7:0]};
            send(8'h0e,expected[i],i==9);
        end
        if(ready || bitmap!=0)begin $display("TEST_FAIL early certificate bank");$finish;end
        while(!dut.commit_ready)@(negedge clk);
        frame=1;@(negedge clk);frame=0;
        if(bitmap!=16'h03ff)begin $display("TEST_FAIL bank bitmap");$finish;end
        for(i=9;i>=0;i=i-1)begin
            lookup=i;#1;
            if(ready || certificate!=0)begin $display("TEST_FAIL stale certificate visible");$finish;end
            repeat(9)@(posedge clk);#1;
            if(!ready || certificate!==expected[i])begin $display("TEST_FAIL BRAM lookup %0d",i);$finish;end
            @(negedge clk);
        end
        lookup=15;repeat(2)@(posedge clk);#1;
        if(ready||certificate!=0)begin $display("TEST_FAIL out-of-range certificate");$finish;end
        $display("TEST_PASS certificate BRAM ten records and stale-index isolation");$finish;
    end
endmodule
