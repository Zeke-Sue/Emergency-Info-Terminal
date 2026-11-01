`timescale 1ns/1ps
module tb_remote_ui;
 reg clk=0,rst=1,frame=0,msg=0;always #5 clk=~clk;
 reg [63:0] ctx=0;reg [3:0] row=0;wire [7:0] desc;
 reg [103:0] desired=0;wire [103:0] active;wire valid;
 reg [95:0] payload=0;reg [10:0] x=0,y=0;wire [23:0] before_rgb,after_rgb;
 reg [10:0] dx,dy;always @(posedge clk)begin dx<=x;dy<=y;end
 console_status_rows layout(.context(ctx),.row(row),.descriptor(desc));
 remote_status_rows receiver(.clk(clk),.rst(rst),.frame_tick(frame),.message_valid(msg),
 .message_type(8'h27),.payload(payload),.rows(active),.valid(valid));
 local_status_overlay_before_extension #(.REGISTERED(1),.MODERN_UI(1),.SIMPLE_DEMO(1)) reference(
 .clk(clk),.x(dx),.y(dy),.enable(ctx[56]),.fire_visible(ctx[57]),.media_fault(ctx[58]),
 .remote_evacuation_selected(ctx[59]),.waveform_status(ctx[61:60]),.remote_confirmation(ctx[55:48]),
 .panel_status(ctx[47:32]),.quality_status(ctx[31:16]),.status(ctx[15:0]),.rgb_in({dx[7:0],dy[7:0],8'h30}),.rgb_out(before_rgb));
 remote_status_overlay dut(.clk(clk),.x(x),.y(y),.enable(ctx[56]),
 .remote_confirmation(ctx[55:48]),.remote_rows(active),.rgb_in({dx[7:0],dy[7:0],8'h30}),.rgb_out(after_rgb));
 integer i,j,k,xx,yy;
 task pulse;input [7:0] seq,chunk;input [63:0] data;begin
  @(negedge clk);payload={seq,chunk,16'd0,data};msg=1;@(negedge clk);msg=0;
 end endtask
 task commit;begin @(negedge clk);frame=1;@(negedge clk);frame=0;end endtask
 task fail;input [255:0] why;begin $display("TEST_FAIL ui k=%d x=%d y=%d %s %h %h",k,x,y,why,before_rgb,after_rgb);$finish;end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  pulse(1,1,64'hffffffffffffffff);commit;if(valid)fail("out of order accepted");
  for(k=0;k<36;k=k+1)begin
   ctx=64'h0100000000000000;
   if(k<7)ctx[47:32]={1'b1,1'b1,k[3:0],3'd2,1'b1,1'b0,5'd0};
   else if(k<11)ctx[47:32]={1'b1,1'b0,4'd0,3'd1,1'b1,1'b0,5'd0};
   else if(k<27)begin ctx[31:16]=16'h8000;ctx[30:27]=k-11;end
   else begin ctx[15:0]=16'h0010|((k-27)<<6)|((k-27)<<10);end
   if(k==33)begin ctx[15:0]=0;ctx[61:60]=3;end
   if(k==34)begin ctx[15:0]=0;ctx[57]=1;end
   if(k==35)begin ctx[15:0]=0;ctx[55:48]=8'hb3;ctx[58]=1;end
   for(i=0;i<13;i=i+1)begin row=i;#1;desired[i*8 +: 8]=desc;end
   pulse(k,0,desired[63:0]);pulse(k,1,{24'd0,desired[103:64]});commit;
   if(active!==desired)fail("atomic publish");repeat(3)@(negedge clk);
   for(yy=32;yy<416;yy=yy+2)for(xx=24;xx<616;xx=xx+2)begin
    @(negedge clk);x=xx;y=yy;@(posedge clk);#1;
    if(before_rgb!==after_rgb)fail("pixel differs from baseline");
   end
  end
  repeat(32)commit;if(valid||active!=0)fail("stale UI not hidden");
  $display("TEST_PASS tb_remote_ui atomic updates, out-of-order rejection, timeout and baseline pixel equivalence");$finish;
 end
 initial begin #100000000;fail("timeout");end
endmodule
