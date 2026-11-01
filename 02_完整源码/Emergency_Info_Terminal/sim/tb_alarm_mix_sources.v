`timescale 1ns/1ps
module tb_alarm_mix_sources;
    reg clk=0,rst=1,tick=0,external_valid=0,voice=0,alarm=0;
    wire signed [15:0] mixed;wire overrun;
    always #5 clk=~clk;
    emergency_audio_mixer #(.ENABLE_EXTERNAL_ALARM(1)) dut(
        .clk(clk),.rst(rst),.sample_valid(tick),.normal_sample(16'sd1234),
        .alarm_active(alarm),.voice_valid(voice),.voice_sample(16'sd6000),
        .prompt_valid(1'b0),.prompt_sample(16'sd0),
        .external_alarm_valid(external_valid),.external_alarm_sample(16'sd12000),
        .mixed_sample(mixed),.alarm_overrun(overrun));
    task check;input signed [15:0] expected;
        begin
            tick=1;@(negedge clk);tick=0;
            if(mixed!==expected)begin $display("TEST_FAIL mix got=%0d expected=%0d",mixed,expected);$finish;end
            repeat(64)@(negedge clk);
        end
    endtask
    integer i;
    initial begin
        repeat(3)@(negedge clk);rst=0;check(1234);
        alarm=1;external_valid=1;repeat(22)@(negedge clk);check(12000);
        voice=1;check(9000);
        external_valid=0;voice=0;
        for(i=0;i<12;i=i+1)check(dut.tone_sum);
        if(overrun)begin $display("TEST_FAIL mixer deadline");$finish;end
        alarm=0;check(1234);
        $display("TEST_PASS tb_alarm_mix_sources external alarm, 6dB ducking, L0 fallback and normal restore");$finish;
    end
endmodule
