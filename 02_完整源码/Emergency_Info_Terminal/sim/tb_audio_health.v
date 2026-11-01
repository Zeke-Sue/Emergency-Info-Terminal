`timescale 1ns/1ps
module tb_audio_health;
 reg clk=0,rst=1,alive=1,sv=0,td=0,ready=1,test_on=1;
 reg [4:0] page=0;reg signed [15:0] sample=10000;reg [23:0] peak=500*256;
 always #5 clk=~clk;
 wire request;wire [95:0] payload;
 audio_health_packetizer #(.CLK_HZ(50000),.SETTLE_SAMPLES(1200)) dut(
  .clk(clk),.rst(rst),.link_alive(alive),.sample_valid(sv),.sample(sample),
  .test_active(test_on),.page(page),.transform_done(td),.peak_frequency_q8(peak),
  .request_valid(request),.request_ready(ready),.request_payload(payload));
 reg frame=0,msg=0;reg [95:0] rxpayload=0;wire fresh;wire [47:0] health;
 audio_health_state receiver(.clk(clk),.rst(rst),.frame_tick(frame),.message_valid(msg),
  .message_type(8'h2a),.payload(rxpayload),.page(page),.health(health),.fresh(fresh));
 task measure;input [15:0] amplitude;input integer hz;begin
  @(negedge clk);sv=1;sample=amplitude;repeat(2500)@(negedge clk);sv=0;
  peak=hz*256;td=1;@(negedge clk);td=0;
 end endtask
 task expect_status;input [7:0] wanted;integer n;begin
  n=0;while(!(request&&payload[31:24]==wanted&&payload[76:72]==page))begin @(negedge clk);n=n+1;if(n>25000)$fatal(1,"health status wanted %d got %d",wanted,payload[31:24]);end
 end endtask
 task commit;begin @(negedge clk);frame=1;@(negedge clk);frame=0;end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;measure(10000,469);expect_status(1);
  if(payload[71:56]!=16'h0500||payload[55:40]!=16'h0469||payload[39:32]!=8'h19)$fatal(1,"health BCD format");
  ready=0;rxpayload=payload;msg=1;@(negedge clk);msg=0;
  if(fresh)$fatal(1,"mid-frame health update");commit();if(!fresh)$fatal(1,"health not committed");
  repeat(32)commit();if(fresh)$fatal(1,"stale health retained");
  msg=1;@(negedge clk);msg=0;commit();if(!fresh)$fatal(1,"health recovery");
  page=1;#1;if(fresh)$fatal(1,"old-page result accepted");
  ready=1;@(negedge clk);measure(10000,750);expect_status(1);
  if(payload[71:56]!=16'h0750||payload[55:40]!=16'h0750)$fatal(1,"page frequency");
  measure(10000,1000);expect_status(2);
  measure(0,1000);expect_status(3);
  measure(32767,750);expect_status(4);
  alive=0;expect_status(5);
  alive=1;test_on=0;expect_status(0);
  $display("TEST_PASS PCM self-test expected/measured BCD, tolerance, silence, clipping, page invalidation, timeout and recovery");$finish;
 end
 initial begin #3000000;$fatal(1,"health timeout");end
endmodule
