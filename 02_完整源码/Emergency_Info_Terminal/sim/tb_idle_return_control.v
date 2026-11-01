`timescale 1ns/1ps
module tb_idle_return_control;
 reg clk=0,rst=1,enable=0,activity=0,held=0;
 wire timeout_event;
 always #5 clk=~clk;
 idle_return_control #(.CLK_HZ(4),.TIMEOUT_SECONDS(3)) dut(
 .clk(clk),.rst(rst),.enable(enable),.activity(activity),.key_held(held),.timeout_event(timeout_event));
 integer pulses=0;
 always @(posedge clk)if(!rst && timeout_event)pulses=pulses+1;
 task step;input integer n;repeat(n)@(negedge clk);endtask
 task fail;input [511:0] why;begin $display("TEST_FAIL tb_idle_return_control %0s",why);$finish;end endtask
 initial begin
 step(2);rst=0;step(30);if(pulses!=0)fail("disabled");enable=1;
 step(11);if(timeout_event || pulses)fail("early expiry");step(1);if(!timeout_event)fail("exact expiry");step(30);if(pulses!=1)fail("one shot");
 held=1;step(30);held=0;step(11);if(pulses!=1)fail("held did not reset");
 activity=1;step(1);activity=0;step(12);if(!timeout_event)fail("activity reset");step(2);if(pulses!=2)fail("rearm");
 enable=0;step(2);enable=1;step(11);activity=1;step(1);activity=0;if(timeout_event)fail("activity at deadline priority");
 $display("TEST_PASS tb_idle_return_control exact deadline, disable, held activity, one-shot and rearm");$finish;
 end
endmodule
