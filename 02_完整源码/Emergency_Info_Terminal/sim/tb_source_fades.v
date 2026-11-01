`timescale 1ns/1ps
module tb_source_fades #(parameter FADE=240);
    reg clk=0,rst=1,tick=0,alarm=0,ext=0;
    always #5 clk=~clk;
    wire signed [17:0] mixed;wire valid,overrun;
    integer n,expected;
    emergency_audio_mixer #(.ENABLE_EXTERNAL_ALARM(1),.SOURCE_FADES(1),.FADE_SAMPLES(FADE)) dut(
        .clk(clk),.rst(rst),.sample_valid(tick),.normal_sample(16'sd12000),
        .alarm_active(alarm),.alarm_kind(3'd0),.voice_valid(1'b0),.voice_sample(16'sd0),
        .prompt_valid(1'b0),.prompt_sample(16'sd0),.external_alarm_valid(ext),
        .external_alarm_sample(-16'sd24000),.unlimited_sample(mixed),.output_valid(valid),.alarm_overrun(overrun));
    task sample;begin
        repeat(64)@(negedge clk);tick=1;@(negedge clk);tick=0;
        if(!valid||mixed!==expected||overrun)begin
            $display("TEST_FAIL source fades: n=%d got=%d expected=%d overrun=%b",n,mixed,expected,overrun);$finish;
        end
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        for(n=1;n<=FADE;n=n+1)begin expected=12000*n/FADE;sample();end
        alarm=1;ext=1;
        for(n=1;n<=FADE;n=n+1)begin expected=(12000*(FADE-n)-24000*n)/FADE;sample();end
        alarm=0;ext=0;
        for(n=1;n<=FADE;n=n+1)begin expected=(12000*n-24000*(FADE-n))/FADE;sample();end
        expected=12000;sample();
        $display("TEST_PASS source fades: %0d-sample startup, signed normal/alarm crossfade, held valid source release, no step at endpoints",FADE);$finish;
    end
    initial begin #1000000;$display("TEST_FAIL source fades timeout");$finish;end
endmodule
module tb_source_fades_power2;
    tb_source_fades #(.FADE(256)) test();
endmodule
