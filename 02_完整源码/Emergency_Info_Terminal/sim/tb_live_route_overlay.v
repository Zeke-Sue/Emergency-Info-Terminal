`timescale 1ns/1ps
module tb_live_route_overlay;
 reg clk=0,rst=1,frame=0,message=0;always #5 clk=~clk;
 reg [7:0] blocked=0;reg [95:0] payload=0;reg [10:0] x=320,y=410;
 wire [23:0] rgb;
 live_route_overlay dut(.clk(clk),.rst(rst),.frame_tick(frame),.message_valid(message),
 .message_type(8'h29),.payload(payload),.blocked(blocked),.enable(1'b1),.flash_on(1'b1),
 .x(x),.y(y),.rgb_in(24'h102030),.rgb_out(rgb));
 task fail;input [255:0] m;begin $display("TEST_FAIL route overlay %s rgb=%h",m,rgb);$finish;end endtask
 task commit;begin @(negedge clk);frame=1;@(negedge clk);frame=0;#1;end endtask
 task send;input [7:0] key;input [1:0] status;begin
  @(negedge clk);payload={16'h5002,key,3'd0,status,3'd1,32'd0,32'h80000000};message=1;
  @(negedge clk);message=0;#1;
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;send(0,0);
  if(rgb!=24'h526464)fail("route published mid-frame");commit;
  if(rgb!=24'h00b878&&rgb!=24'h80ffd0)fail("valid route invisible");
  blocked=1;#1;if(rgb!=24'h526464)fail("obsolete route survived hazard change");
  send(1,0);commit;if(rgb!=24'h00b878&&rgb!=24'h80ffd0)fail("updated route invisible");
  repeat(32)commit;if(rgb!=24'h526464)fail("stale route survived timeout");
  send(1,1);commit;if(rgb!=24'h526464)fail("blocked status displayed green route");
  x=80;y=80;#1;if(rgb!=24'hff4040)fail("blocked exit marker missing");
  $display("TEST_PASS tb_live_route_overlay atomic frames, hazard invalidation, timeout, blocked exit marker");$finish;
 end
endmodule
