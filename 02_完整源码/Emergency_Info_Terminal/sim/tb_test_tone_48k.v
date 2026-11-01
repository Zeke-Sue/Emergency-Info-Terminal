`timescale 1ns/1ps
module tb_test_tone_48k;
 reg clk=0,rst=1,en=0,tick=0;
 wire valid;wire signed [15:0] native,pcm;
 reg signed [15:0] period[0:47];
 integer i,cycles=0;
 always #5 clk=~clk;
 test_tone_48k dut(.clk(clk),.rst(rst),.enable(en),.output_tick(tick),
 .native_valid(valid),.native_sample(native),.output_sample(pcm));
 initial begin
 repeat(3)@(negedge clk);rst=0;en=1;
 for(i=0;i<48000;i=i+1)begin
   @(negedge clk);
   if(i<48)period[i]=pcm;
   else if(pcm!==period[i%48])$fatal(1,"tone period is not 48 samples");
   if(i%48==0)begin if(pcm!=0)$fatal(1,"phase zero");cycles=cycles+1;end
   if(i%48==12&&pcm!=4096)$fatal(1,"positive peak");
   if(i%48==36&&pcm!=-4096)$fatal(1,"negative peak");
   tick=1;@(negedge clk);tick=0;
   if(!valid)$fatal(1,"missing sample valid");
   repeat(2)@(negedge clk);
   if(valid)$fatal(1,"valid persists without tick");
 end
 if(cycles!=1000)$fatal(1,"1kHz frequency at 48kHz sample rate");
 en=0;@(negedge clk);if(pcm!=0||valid)$fatal(1,"disabled source not silent");
 en=1;@(negedge clk);if(pcm!=0)$fatal(1,"enable did not restart phase");
 $display("TEST_PASS 48000 PCM samples, 1000 exact sine periods, peak amplitude, sample enable and restart");$finish;
 end
endmodule
