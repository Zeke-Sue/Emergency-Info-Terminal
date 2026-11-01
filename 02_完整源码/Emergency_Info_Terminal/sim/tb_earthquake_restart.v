`timescale 1ns/1ps
module tb_earthquake_restart;
    reg clk=0,rst=1,enable=0,tick=0;
    wire signed [15:0] tone;wire ready,overrun;
    reg signed [15:0] golden[0:15];
    integer n,j,checks=0;
    always #5 clk=~clk;
    earthquake_tone_generator dut(.clk(clk),.rst(rst),.enable(enable),
        .sample_tick(tick),.tone(tone),.ready(ready),.overrun(overrun));
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tone restart: %0s offset=%0d sample=%0d",msg,j,n);$finish;end endtask
    task sample;
        begin
            tick=1;@(negedge clk);tick=0;repeat(63)@(negedge clk);
            if(!ready||dut.state!=1||overrun)fail("64-clock deadline");
        end
    endtask
    task restart;
        begin
            enable=0;repeat(2)@(negedge clk);
            if(tone!=0||ready)fail("disable must clear output");
            enable=1;repeat(22)@(negedge clk);
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;restart;
        for(n=0;n<16;n=n+1)begin sample;golden[n]=tone;end

        for(j=0;j<52;j=j+1)begin
            tick=1;@(negedge clk);tick=0;repeat(j)@(negedge clk);restart;
            for(n=0;n<16;n=n+1)begin
                sample;if(tone!==golden[n])fail("partial write leaked across restart");
                checks=checks+1;
            end
        end
        tick=1;@(negedge clk);tick=0;repeat(3)@(negedge clk);
        tick=1;@(negedge clk);tick=0;
        if(!overrun)fail("too-early tick not reported");
        rst=1;repeat(3)@(negedge clk);rst=0;repeat(22)@(negedge clk);
        for(n=0;n<16;n=n+1)begin sample;if(tone!==golden[n])fail("reset restart");end
        $display("TEST_PASS tone restart: %0d bit-exact samples, all 52 interruption offsets, overrun and reset recovery",checks);
        $finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
