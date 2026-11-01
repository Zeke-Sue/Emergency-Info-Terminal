`timescale 1ns/1ps
module tb_mixer_pipeline;
 reg clk=0,rst=1,sample_valid=0,alarm_active=0,voice_valid=0,prompt_valid=0,external_alarm_valid=0;
 reg [2:0] alarm_kind=0;
 reg signed [15:0] normal_sample=0,voice_sample=0,prompt_sample=0,external_alarm_sample=0;
 wire signed [15:0] old_mixed,new_mixed;
 wire signed [17:0] old_full,new_full;
 wire old_valid,new_valid;
 reg signed [15:0] delayed_mixed;
 reg signed [17:0] delayed_full;
 reg delayed_valid;
 integer n,checked=0;
 always #5 clk=~clk;
 `define MIX_PORTS .clk(clk),.rst(rst),.sample_valid(sample_valid),.normal_sample(normal_sample),.alarm_active(alarm_active),.alarm_kind(alarm_kind),.voice_valid(voice_valid),.voice_sample(voice_sample),.prompt_valid(prompt_valid),.prompt_sample(prompt_sample),.external_alarm_valid(external_alarm_valid),.external_alarm_sample(external_alarm_sample)
 emergency_audio_mixer #(.ENABLE_EXTERNAL_ALARM(1),.SOURCE_FADES(1),.FADE_SAMPLES(256)) reference_mix(
     `MIX_PORTS,.mixed_sample(old_mixed),.unlimited_sample(old_full),.output_valid(old_valid));
 emergency_audio_mixer #(.ENABLE_EXTERNAL_ALARM(1),.SOURCE_FADES(1),.FADE_SAMPLES(256),.PIPELINED_MIX(1)) pipelined_mix(
     `MIX_PORTS,.mixed_sample(new_mixed),.unlimited_sample(new_full),.output_valid(new_valid));
 `undef MIX_PORTS
 always @(posedge clk or posedge rst)
   if(rst)begin delayed_mixed<=0;delayed_full<=0;delayed_valid<=0;end
   else begin delayed_mixed<=old_mixed;delayed_full<=old_full;delayed_valid<=old_valid;end
 always @(negedge clk)if(!rst)begin
   if(new_valid!==delayed_valid||new_mixed!==delayed_mixed||new_full!==delayed_full)
     $fatal(1,"mixer pipeline changed a sample, count or latency");
   if(new_valid)checked=checked+1;
 end
 initial begin
   repeat(4)@(posedge clk);#1;rst=0;
   for(n=0;n<4096;n=n+1)begin
     @(posedge clk);#1;
     alarm_active=(n/256)%2;voice_valid=(n/128)%2;prompt_valid=(n/64)%2;
     external_alarm_valid=(n/512)%2;alarm_kind=(n/1024)%4;
     normal_sample=n*331+123;voice_sample=n*517-16384;
     prompt_sample=32767-n*139;external_alarm_sample=n*73-32768;
     sample_valid=1;@(posedge clk);#1;sample_valid=0;
     repeat(62)@(posedge clk);
   end
   repeat(4)@(posedge clk);
   if(checked!=4096)$fatal(1,"sample lost or duplicated");
   $display("TEST_PASS mixer pipeline: 4096 signed mixed samples, exact one-clock latency, no loss/duplication");$finish;
 end
endmodule
