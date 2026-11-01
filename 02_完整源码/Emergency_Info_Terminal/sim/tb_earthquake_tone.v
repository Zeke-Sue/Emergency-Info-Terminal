`timescale 1ns/1ps
module tb_earthquake_tone;
    reg clk=0,rst=1,enable=0,tick=0;
    always #5 clk=~clk;
    wire signed [15:0] tone;wire ready,overrun;
    earthquake_tone_generator dut(.clk(clk),.rst(rst),.enable(enable),
        .sample_tick(tick),.tone(tone),.ready(ready),.overrun(overrun));
    integer hz[0:14];integer duration[0:2];
    reg [31:0] phases[0:4];
    integer increments[0:4];integer slopes[0:14];
    integer n,k,seg,local_sample,expected_sum,expected_voice,checked,s,anchor;
    real ideal_frequency,actual_frequency,wave;
    task fail;input [511:0] why;
        begin $display("TEST_FAIL tb_earthquake_tone n=%0d voice=%0d %0s",n,k,why);$finish;end
    endtask
    always @(posedge clk)if(!rst && enable && dut.state==3)begin
        k=dut.voice;
        if(k!=expected_voice)fail("voice scheduling");
        if(k==0)expected_sum=0;
        seg=dut.period_sample<14400 ? 0 : (dut.period_sample<67200 ? 1 : 2);
        local_sample=dut.period_sample-(seg==0 ? 0 : (seg==1 ? 14400 : 67200));
        ideal_frequency=hz[k*3+seg]+(hz[k*3+(seg+1)%3]-hz[k*3+seg])*1.0*local_sample/duration[seg];
        actual_frequency=dut.step*48000.0/4294967296.0;
        if(actual_frequency-ideal_frequency>0.30 || ideal_frequency-actual_frequency>0.30)
            fail("frequency error above 0.30 Hz");
        if(dut.phase!==phases[k] || dut.step!==increments[k])fail("phase/increment reference");
        wave=32767.0*$sin(6.283185307179586*phases[k]/4294967296.0)/8.0;
        expected_sum=expected_sum+$rtoi(wave);
        phases[k]=phases[k]+increments[k];
        if(dut.period_sample==14399 || dut.period_sample==67199 || dut.period_sample==95999)
            increments[k]=$rtoi(hz[k*3+(seg+1)%3]*4294967296.0/48000.0+0.5);
        else increments[k]=increments[k]+slopes[k*3+seg];
        expected_voice=k==4 ? 0 : k+1;
        if(k==4)begin
            checked=checked+1;
            #1;
            if(tone-expected_sum>270 || expected_sum-tone>270)fail("sine/voice summation error");
        end
    end
    initial begin
        hz[0]=1064;hz[1]=5288;hz[2]=4828;
        hz[3]=840;hz[4]=4175;hz[5]=3812;
        hz[6]=616;hz[7]=3061;hz[8]=2795;
        hz[9]=392;hz[10]=1948;hz[11]=1779;
        hz[12]=140;hz[13]=696;hz[14]=635;
        duration[0]=14400;duration[1]=52800;duration[2]=28800;
        for(k=0;k<5;k=k+1)begin
            phases[k]=0;increments[k]=$rtoi(hz[k*3]*4294967296.0/48000.0+0.5);
            for(s=0;s<3;s=s+1)begin
                wave=(hz[k*3+(s+1)%3]-hz[k*3+s])*4294967296.0/48000.0/duration[s];
                slopes[k*3+s]=$rtoi(wave+(wave<0 ? -0.5 : 0.5));
            end
        end
        checked=0;expected_voice=0;
        repeat(3)@(negedge clk);rst=0;enable=1;repeat(22)@(negedge clk);
        for(n=0;n<192000;n=n+1)begin
            tick=1;@(negedge clk);tick=0;repeat(63)@(negedge clk);
            if(overrun || !ready || dut.period_sample!=(n+1)%96000)fail("sample period/deadline");
        end
        if(checked!=192000)fail("missing output samples");
        enable=0;@(negedge clk);
        if(tone!=0 || ready)fail("disabled tone did not clear");
        $display("TEST_PASS tb_earthquake_tone 192000 samples, five table-3 trajectories, <0.30 Hz DDS error, sine reference, 64-clock budget (hardware >=520)");
        $finish;
    end
    initial begin #160000000;fail("timeout");end
endmodule
