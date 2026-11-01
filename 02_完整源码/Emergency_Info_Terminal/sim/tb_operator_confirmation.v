`timescale 1ns/1ps
module tb_operator_confirmation;
    reg clk=0,rst=1,tick=0,arm=0,cancel=0,held=0,eligible=1;
    reg [15:0] context=16'h1234;
    always #5 clk=~clk;
    wire armed,confirmed,expired,denied;wire [4:0] progress;
    integer sends=0,i;
    operator_confirmation #(.HOLD_MS(40),.TIMEOUT_MS(100)) dut(
        .clk(clk),.rst(rst),.ms_tick(tick),.arm(arm),.cancel(cancel),
        .held(held),.eligible(eligible),.context(context),.armed(armed),
        .confirmed(confirmed),.expired(expired),.denied(denied),.progress(progress));
    always @(posedge clk)if(confirmed)sends=sends+1;
    task fail;input [799:0] why;begin $display("TEST_FAIL confirmation %0s",why);$finish;end endtask
    task select;begin arm=1;@(negedge clk);arm=0;@(negedge clk);end endtask
    task milliseconds;input integer n;integer j;begin
        for(j=0;j<n;j=j+1)begin tick=1;@(negedge clk);tick=0;@(negedge clk);end
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;@(negedge clk);
        held=1;milliseconds(50);if(sends!=0||armed)fail("unarmed hold sent");held=0;
        select();if(!armed)fail("arm");held=1;milliseconds(40);
        if(sends!=0||progress!=19)fail("early execute/progress");
        held=0;milliseconds(1);if(progress!=0)fail("release retained progress");
        held=1;milliseconds(40);if(sends!=0)fail("noncontinuous hold counted");
        milliseconds(1);if(sends!=1||armed||progress!=20)fail("exact hold threshold");
        milliseconds(20);if(sends!=1)fail("repeated execution");held=0;
        select();milliseconds(100);if(armed||!expired||sends!=1)fail("deadline");
        select();held=1;milliseconds(39);context=context+1'b1;milliseconds(1);
        if(armed||sends!=1)fail("changed payload executed");held=0;
        eligible=0;select();if(armed||!denied)fail("unauthorized arm");eligible=1;
        select();held=1;milliseconds(39);eligible=0;milliseconds(1);
        if(armed||!denied||sends!=1)fail("permission changed on final tick");eligible=1;held=0;
        select();select();if(armed)fail("second selection did not cancel");
        select();held=1;milliseconds(39);cancel=1;milliseconds(1);cancel=0;
        if(armed||sends!=1)fail("cancel did not win over execute");
        $display("TEST_PASS confirmation exact hold, release reset, 10s-equivalent timeout, payload/permission changes, cancel priority, no duplicate execution");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
