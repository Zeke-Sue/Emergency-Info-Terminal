`timescale 1ns/1ps
module tb_filming_cadence;
 reg clk=0,rst=1,play=1,follow=0,hold_view=0,abort_event=0;
 always #5 clk=~clk;
 integer cycle=0;always @(posedge clk)cycle<=cycle+1;
 wire frame_tick=cycle[0];
 reg [1:0] period=0,duration=0;
 reg [15:0] resident=16'hffff;
 wire [3:0] desired,index;wire active,autoplay;wire [5:0] seconds;
 player_control #(.CLK_HZ(120),.START_AUTOPLAY(1),.DEFAULT_PERIOD(0),
  .PERIOD_COUNT(3),.PERIOD_0(2),.PERIOD_1(5),.PERIOD_2(10),.PERIOD_3(10),
  .EXTERNAL_CONTROL(1),.USE_CACHE(1),.DUAL_SOURCE(1),.NAVIGATION_HOLD(1)) dut(
 .clk(clk),.rst(rst),.ready(1'b1),.frame_tick(frame_tick),
 .next_event(1'b0),.previous_event(1'b0),.auto_event(1'b0),.period_event(1'b0),
 .target_enable(1'b0),.target_index(4'd0),.external_play(play),
 .external_activity(1'b0),.external_period(period),.follow_narration(follow),
 .effect_select(3'd5),.resident(resident),.failed_images(16'd0),
 .emergency_abort(abort_event),.navigation_hold(hold_view),
 .transition_duration(duration),.transition_easing(1'b0),
 .desired_image(desired),.image_index(index),.transition_active(active),
 .autoplay(autoplay),.period_seconds(seconds));
 task restart;
 begin
  rst=1;play=1;follow=0;hold_view=0;abort_event=0;resident=16'hffff;
  repeat(3)@(negedge clk);rst=0;
 end endtask
 task full_dwell;
 input [3:0] displayed;
 integer ticks,start_cycle,n;
 begin
  start_cycle=cycle;ticks=seconds*120;
  for(n=1;n<ticks;n=n+1)begin
   @(negedge clk);
   if(desired!=displayed||index!=displayed||active)
    $fatal(1,"page %0d lost full displayed dwell at %0d of %0d clocks",displayed,cycle-start_cycle,ticks);
  end
  @(negedge clk);
  if(desired!=(displayed+1'b1)||cycle-start_cycle!=ticks)
   $fatal(1,"next request did not follow complete displayed dwell: %0d / %0d",cycle-start_cycle,ticks);
 end endtask
 integer p,d;
 initial begin

  for(p=0;p<3;p=p+1)for(d=0;d<3;d=d+1)begin
   period=p;duration=d;restart;
   wait(index==1&&!active);@(negedge clk);full_dwell(1);
   wait(index==2&&!active);@(negedge clk);full_dwell(2);
  end

  period=3;duration=0;restart;
  wait(index==1&&!active);@(negedge clk);
  if(seconds!=2)$fatal(1,"invalid external period exposed a fourth setting");
  full_dwell(1);
  period=0;duration=2;restart;resident=16'h0001;
  repeat(700)@(negedge clk);
  if(desired!=1||index!=0||!active)$fatal(1,"slow storage skipped or displayed an incomplete image");
  resident=16'hffff;
  wait(index==1&&!active);@(negedge clk);full_dwell(1);
  wait(index==2&&!active);@(negedge clk);play=0;
  wait(!autoplay);repeat(500)@(negedge clk);
  if(index!=2||desired!=2)$fatal(1,"pause did not hold");
  play=1;wait(autoplay);@(negedge clk);full_dwell(2);
  wait(index==3&&!active);@(negedge clk);follow=1;
  repeat(500)@(negedge clk);
  if(index!=3||desired!=3)$fatal(1,"narration follow advanced on the fixed timer");
  follow=0;full_dwell(3);
  wait(index==4&&!active);@(negedge clk);hold_view=1;
  repeat(500)@(negedge clk);
  if(index!=4||desired!=4)$fatal(1,"zoom hold advanced");
  hold_view=0;full_dwell(4);
  $display("TEST_PASS full displayed dwell 2/5/10 s with 16/32/64-frame blinds; invalid fourth selection, late load, pause/resume, narration and zoom hold");$finish;
 end
 initial begin #1000000;$fatal(1,"display dwell timeout");end
endmodule
