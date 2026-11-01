`timescale 1ns/1ps
module tb_site_notice_tone;
    reg clk=0,rst=1,enable=0,tick=0;always #5 clk=~clk;
    wire signed [15:0] tone;
    integer n,crossings0=0,crossings1=0,previous=0;
    site_notice_tone dut(.clk(clk),.rst(rst),.enable(enable),.sample_tick(tick),.tone(tone));
    task fail;input [799:0] why;begin $display("TEST_FAIL site tone: %0s",why);$finish;end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;enable=1;
        for(n=0;n<48000;n=n+1)begin
            tick=1;@(negedge clk);tick=0;
            if(tone>8192||tone< -8192)fail("fallback amplitude");
            if(tone>0&&previous<=0)begin
                if(n<24000)crossings0=crossings0+1;else crossings1=crossings1+1;
            end
            previous=tone;@(negedge clk);
        end
        if(crossings0<499||crossings0>501||crossings1<749||crossings1>751||dut.high_tone)
            fail("48k sample frequency or half-period");
        enable=0;@(negedge clk);if(tone!=0||dut.phase!=0)fail("disable/reset");
        $display("TEST_PASS site tone: separate 1k/1.5kHz fallback, 24000-sample halves, bounded amplitude and deterministic restart");$finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
