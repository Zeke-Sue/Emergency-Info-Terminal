`timescale 1ns/1ps
module tb_audio_sample_fifo;
    reg wc=0,rc=0,wrst=1,rrst=1,flush=0,wvalid=0,rready=0;
    reg signed [15:0] data=0;
    wire wready,rvalid,overflow;wire signed [15:0] q;
    integer i,expected,received=0;
    reg checking=0;
    always #5 wc=~wc;
    always #17 rc=~rc;
    audio_sample_fifo #(.AW(3)) dut(.wr_clk(wc),.wr_rst(wrst),.wr_flush(flush),
        .wr_valid(wvalid),.wr_data(data),.wr_ready(wready),.wr_overflow(overflow),
        .rd_clk(rc),.rd_rst(rrst),.rd_ready(rready),.rd_valid(rvalid),.rd_data(q));
    task fail;input [8*100-1:0] message;begin
        $display("TEST_FAIL tb_audio_sample_fifo %0s q=%0d expected=%0d",message,q,expected);$finish;
    end endtask
    task put;input integer value;begin
        @(negedge wc);while(!wready)@(negedge wc);
        data=value;wvalid=1;@(negedge wc);wvalid=0;
    end endtask
    always @(posedge rc)if(rready&&rvalid&&checking)begin
        if(q!==expected)fail("stale, duplicated or reordered sample");
        expected=expected+1;received=received+1;
    end
    initial begin
        repeat(4)@(negedge wc);wrst=0;rrst=0;
        repeat(8)@(negedge rc);
        for(i=0;i<6;i=i+1)put(i);
        repeat(5)@(negedge rc);
        if(!rvalid||q!=0)fail("prefetch");
        @(negedge wc);flush=1;@(negedge wc);flush=0;
        wait(wready);repeat(4)@(negedge rc);
        if(rvalid)fail("old data exposed after flush");
        expected=100;checking=1;rready=1;
        for(i=100;i<180;i=i+1)put(i);
        wait(received==80);repeat(5)@(negedge rc);
        if(rvalid||overflow)fail("wrap/full accounting");
        @(negedge rc);checking=0;rready=0;
        for(i=0;i<6;i=i+1)put(i);

        @(negedge wc);wrst=1;repeat(3)@(negedge wc);wrst=0;
        repeat(8)@(negedge rc);if(rvalid)fail("one-sided reset left valid data");
        expected=200;checking=1;rready=1;
        for(i=200;i<220;i=i+1)put(i);
        wait(received==100);repeat(5)@(negedge rc);
        if(rvalid||overflow)fail("reset recovery");
        $display("TEST_PASS tb_audio_sample_fifo asynchronous clocks, flush handshake, wrap, full and one-sided reset");$finish;
    end
    initial begin #1000000;fail("timeout");end
endmodule
