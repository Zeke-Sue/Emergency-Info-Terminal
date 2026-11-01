`timescale 1ns/1ps
module tb_human_daily_follow;
 reg clk=0,rst=1,enabled=1,ready=1,autoplay=1,blocked=0,restart=0,consumed=0,done=0;
 wire next_event;
 integer pulses=0,i;
 always #5 clk=~clk;
 human_daily_follow #(.CLK_HZ(10)) dut(.*);
 always @(posedge clk)if(next_event)pulses=pulses+1;
 task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
 task reset;begin rst=1;ticks(2);rst=0;pulses=0;end endtask
 initial begin
   reset();

   for(i=0;i<100;i=i+1)begin consumed=1;ticks(1);consumed=0;ticks(9);end
   if(pulses!=0)$fatal(1,"long narration truncated");
   done=1;ticks(1);done=0;ticks(10);autoplay=0;ticks(400);
   if(pulses!=0)$fatal(1,"paused dwell advanced");
   autoplay=1;ticks(22);if(pulses!=1)$fatal(1,"complete clip did not advance");
   reset();ticks(299);if(pulses!=0)$fatal(1,"early missing-audio timeout");
   ticks(3);if(pulses!=1)$fatal(1,"missing/rejected audio stalled display");
   reset();ticks(250);blocked=1;ticks(400);blocked=0;ticks(100);
   if(pulses!=0)$fatal(1,"alarm time counted as daily wait");
   restart=1;ticks(1);restart=0;ticks(299);
   if(pulses!=0)$fatal(1,"navigation failed to reset wait");
   ticks(3);if(pulses!=1)$fatal(1,"navigation fallback missing");
   reset();enabled=0;ticks(400);if(pulses!=0)$fatal(1,"timed mode double advanced");
   $display("TEST_PASS human daily follow: full clip, pause, dwell, timeout, alarm and manual navigation");$finish;
 end
endmodule
