`timescale 1ns/1ps
module tb_usability_periods;
 reg clk=0,rst=1,period_event=0,follow=0;always #5 clk=~clk;
 wire [5:0] seconds;wire [3:0] desired;integer p,n,expected;
 player_control #(.CLK_HZ(16),.START_AUTOPLAY(1),.DEFAULT_PERIOD(0),
 .PERIOD_COUNT(3),.PERIOD_0(2),.PERIOD_1(5),.PERIOD_2(10),.PERIOD_3(10)) dut(
 .clk(clk),.rst(rst),.ready(1'b1),.frame_tick(1'b0),.next_event(1'b0),.previous_event(1'b0),
 .auto_event(1'b0),.period_event(period_event),.follow_narration(follow),.effect_select(3'd0),
 .external_play(1'b0),.external_activity(1'b0),.external_period(2'd0),.resident(16'hffff),
 .emergency_abort(1'b0),.period_seconds(seconds),.desired_image(desired));
 initial begin
 for(p=0;p<6;p=p+1)begin
  rst=1;repeat(3)@(negedge clk);rst=0;
  repeat(p)begin period_event=1;@(negedge clk);period_event=0;end
  expected=(p%3)==0 ? 2 : (p%3)==1 ? 5 : 10;
  #1;if(seconds!=expected)$fatal(1,"wrong production period");
  for(n=1;n<expected*16;n=n+1)begin @(negedge clk);if(desired!=0)$fatal(1,"early autoplay at %d/%d",n,expected*16);end
  @(negedge clk);if(desired!=1)$fatal(1,"late autoplay %d",expected);
 end
 rst=1;repeat(3)@(negedge clk);follow=1;rst=0;
 repeat(16*12)@(negedge clk);if(desired!=0)$fatal(1,"timer cut off narration-follow mode");
 $display("TEST_PASS exact displayed dwell 2/5/10 s, repeated three-setting wrap and narration-follow timer suppression");$finish;
 end
endmodule
