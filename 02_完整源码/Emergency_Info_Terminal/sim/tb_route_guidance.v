`timescale 1ns/1ps
module tb_route_guidance;
 reg clk=0,rst=1,alarm=0,enable=0,fresh=0,complete=0,consume=0,io_failed=0,configured=1;
 reg [2:0] exit_id=1;reg [1:0] status=0;reg [7:0] purpose=0;
 always #5 clk=~clk;
 wire request,voice,current;wire [3:0] index;wire [31:0] offset;
 human_stage_audio_requests #(.ROUTE_GUIDANCE(1),.ROUTE_STABLE_FRAMES(3)) dut(
  .clk(clk),.rst(rst),.frame_tick(1'b1),.ready(1'b1),.narration_enable(1'b0),
  .configuration_valid(configured),.image_index(4'd0),.configured_narration_index(4'd0),
  .alarm_active(alarm),.alarm_drill(1'b0),.alarm_pending(1'b0),.alarm_kind(3'd3),
  .route_enabled(enable),.route_fresh(fresh),.route_exit(exit_id),.route_status(status),
  .route_start_sample(offset),.route_speech_current(current),.release_request(1'b0),.daily_blocked(1'b0),
  .asset_complete(complete),.asset_purpose(purpose),.asset_samples(32'd3),.consume(consume),
  .asset_failed(1'b0),.io_failed(io_failed),.request(request),.asset_index(index),.voice_asset(voice));
 task await_route;input [31:0] expected;integer n;begin
  @(negedge clk);n=0;while(!(request&&index==15))begin @(negedge clk);n=n+1;if(n>20)$fatal(1,"route request timeout");end
  if(offset!=expected||!voice||!current)$fatal(1,"wrong route voice window");
 end endtask
 task finish;begin
  @(negedge clk);purpose=8'h30;complete=1;@(negedge clk);complete=0;consume=1;
  repeat(3)@(negedge clk);consume=0;
  if(index!=11||voice)$fatal(1,"route did not yield to alarm tone");
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;alarm=1;enable=1;fresh=1;await_route(0);finish();
  repeat(12)begin @(negedge clk);if(index==15)$fatal(1,"same route repeated indefinitely");end
  exit_id=2;await_route(240000);fresh=0;#1;if(current)$fatal(1,"stale voice still audible");
  @(negedge clk);if(voice||index!=11)$fatal(1,"stale voice not aborted");
  fresh=1;exit_id=3;await_route(480000);exit_id=1;#1;if(current)$fatal(1,"old exit still audible");
  await_route(0);finish();status=2;await_route(720000);
  io_failed=1;@(negedge clk);io_failed=0;if(voice||index!=11)$fatal(1,"missing route recording did not fall back");
  repeat(12)begin @(negedge clk);if(index==15)$fatal(1,"missing file request loop");end
  configured=0;@(negedge clk);configured=1;await_route(720000);
  alarm=0;enable=0;@(negedge clk);if(voice)$fatal(1,"alarm clear left guidance active");
  $display("TEST_PASS route speech offsets, debounce, once per route, stale/changed-route mute, IO fallback and permission recovery");$finish;
 end
 initial begin #100000;$fatal(1,"guidance timeout");end
endmodule
