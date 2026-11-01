`timescale 1ns/1ps
module tb_page_tones;
 reg clk=0,rst=1,enable=0,tick=0;reg [4:0] page=0;
 always #5 clk=~clk;
 wire signed [15:0] sample;wire valid;
 page_test_tone_48k dut(.clk(clk),.rst(rst),.enable(enable),.output_tick(tick),.page(page),
 .native_valid(valid),.native_sample(sample),.output_sample());
 integer p,n,crossings,previous,hz;
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(p=0;p<21;p=p+1)begin
   @(negedge clk);page=p;enable=0;repeat(3)@(negedge clk);enable=1;
   crossings=0;previous=0;
   for(n=0;n<9600;n=n+1)begin
    @(negedge clk);tick=1;
    if(sample>4096||sample< -4096)begin $display("TEST_FAIL amplitude");$finish;end
    if(previous<0&&sample>=0)crossings=crossings+1;
    previous=sample;@(negedge clk);tick=0;
   end
   hz=crossings*5;
   if(hz<500+250*p-10||hz>500+250*p+10)begin $display("TEST_FAIL tone %d %d",p,hz);$finish;end
  end
  $display("TEST_PASS tb_page_tones all 21 distinct 48 kHz sampled tones, 500 to 5500 Hz");$finish;
 end
endmodule
