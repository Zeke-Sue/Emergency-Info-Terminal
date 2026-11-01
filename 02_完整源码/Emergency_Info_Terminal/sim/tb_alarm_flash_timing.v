`timescale 1ns/1ps
module tb_alarm_flash_timing;
    reg clk=0,rst=1,tick=0,frame=0,enable=0,steady=0;
    reg [1:0] rate=1,duty=1;
    wire flash;
    integer r,d,i,phase,step,limit,edges,high_ticks;
    reg previous,expected;
    always #1 clk=~clk;
    alarm_flash_timing #(.TICKS_PER_MINUTE(60000)) dut(.clk(clk),.rst(rst),
        .tick(tick),.frame_tick(frame),.enable(enable),.steady(steady),
        .rate_select(rate),.duty_select(duty),.flash_on(flash));
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(r=0;r<3;r=r+1)for(d=0;d<3;d=d+1)begin
            enable=0;tick=0;frame=1;rate=r;duty=d;
            repeat(2)@(negedge clk);
            enable=1;tick=1;phase=0;edges=0;high_ticks=0;previous=0;
            step=r==0 ? 40 : r==1 ? 45 : 50;
            limit=60000/(d+4);
            for(i=0;i<60000;i=i+1)begin
                @(negedge clk);expected=phase<limit;
                if(flash!==expected)$fatal(1,"TEST_FAIL rate/duty %0d/%0d phase %0d",r,d,phase);
                if(flash&&!previous)edges=edges+1;
                if(flash)high_ticks=high_ticks+1;
                previous=flash;phase=(phase+step)%60000;
            end
            if(edges!=step||high_ticks<limit-step||high_ticks>limit+step)
                $fatal(1,"TEST_FAIL minute count/duty %0d %0d",edges,high_ticks);
        end

        frame=0;expected=flash;rate=0;duty=0;
        repeat(2000)begin @(negedge clk);if(flash!==expected)$fatal(1,"TEST_FAIL mid-frame flash");end
        steady=1;frame=1;@(negedge clk);
        if(!flash)$fatal(1,"TEST_FAIL steady phase");
        enable=0;@(negedge clk);if(flash)$fatal(1,"TEST_FAIL disable");
        $display("TEST_PASS flash 40/45/50 per minute, 1:3/1:4/1:5 duty, frame atomicity");$finish;
    end
    initial begin #2000000;$fatal(1,"TEST_FAIL flash timeout");end
endmodule
