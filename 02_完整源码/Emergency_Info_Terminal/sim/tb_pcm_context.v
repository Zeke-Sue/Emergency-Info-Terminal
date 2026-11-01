`timescale 1ns/1ps
module tb_pcm_context;
 reg aclk=0,bclk=0,rst=1,tick=0,disconnect=0;
 always #20 aclk=~aclk;always #10.003 bclk=~bclk;
 reg [15:0] sample=0;reg [127:0] context=128'hfedcba98765432100123456789abcdef;
 wire serial,overrun,valid,ctx_valid,alive,gap;wire [15:0] received;wire [127:0] ctx;
 pcm_context_tx tx(.clk(aclk),.rst(rst),.sample_valid(tick),.sample(sample),.context(context),.tx(serial),.overrun(overrun));
 pcm_context_rx rx(.clk(bclk),.rst(rst),.rx(disconnect ? 1'b1 : serial),
 .sample_valid(valid),.sample(received),.context(ctx),.context_valid(ctx_valid),.link_alive(alive),.discontinuity(gap));
 integer sent=0,seen=0,contexts=0,i;reg check_order=1;
 always @(posedge bclk)if(!rst)begin
  if(valid)begin
   if(check_order&&received!==((seen*997+123)&65535))begin $display("TEST_FAIL PCM order %d %h",seen,received);$finish;end
   seen=seen+1;
  end
  if(ctx_valid)begin
   if(ctx!==128'hfedcba98765432100123456789abcdef&&ctx!==128'h112233445566778899aabbccddeeff00)begin
    $display("TEST_FAIL torn context %h",ctx);$finish;end
   contexts=contexts+1;
  end
 end
 task send_sample;begin
  @(negedge aclk);sample=(sent*997+123)&65535;tick=1;sent=sent+1;
  @(negedge aclk);tick=0;repeat(519)@(negedge aclk);
 end endtask
 initial begin
  repeat(5)@(negedge aclk);rst=0;
  for(i=0;i<128;i=i+1)begin if(i==23)context=128'h112233445566778899aabbccddeeff00;send_sample;end
  repeat(10)@(negedge aclk);
  if(overrun||seen!=128||contexts<7)begin $display("TEST_FAIL loss %d %d %b",seen,contexts,overrun);$finish;end
  check_order=0;disconnect=1;repeat(540)send_sample;
  if(alive)begin $display("TEST_FAIL link timeout");$finish;end
  disconnect=0;repeat(40)send_sample;
  if(!alive||ctx!==context||overrun)begin $display("TEST_FAIL reconnect");$finish;end
  $display("TEST_PASS tb_pcm_context PCM order, drift, atomic metadata, disconnect and recovery");$finish;
 end
 initial begin #30000000;$display("TEST_FAIL timeout");$finish;end
endmodule
