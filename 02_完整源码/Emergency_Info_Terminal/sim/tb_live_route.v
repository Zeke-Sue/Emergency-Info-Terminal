`timescale 1ns/1ps
module tb_live_route;
 reg clk=0,rst=1,ready=0;always #10 clk=~clk;
 reg [7:0] blocked=0;wire request;wire [95:0] payload;
 live_route_packetizer #(.CLK_HZ(50000)) dut(.clk(clk),.rst(rst),.link_alive(1'b1),
 .blocked(blocked),.request_valid(request),.request_ready(ready),.request_payload(payload));
 integer a[0:31],b[0:31],cost[0:31],mask[0:31],dist[0:20],used[0:20];
 integer k,e,n,i,best,cur,candidate,expected_cost,ex,path_cost,node,next,steps;
 reg [31:0] edges,dirs;reg [7:0] key;reg [1:0] status;
 reg [4:0] gi=0;wire [31:0] gw;live_floor_graph graph(.index(gi),.edge_word(gw));
 task fail;input [255:0] msg;begin $display("TEST_FAIL route %0d %s",k,msg);$finish;end endtask
 initial begin
  for(e=0;e<32;e=e+1)begin gi=e;#1;a[e]=gw[4:0];b[e]=gw[9:5];cost[e]=gw[20:10];mask[e]=gw[28:21];end
  repeat(5)@(negedge clk);rst=0;
  for(k=0;k<256;k=k+1)begin
   blocked=k;wait(request&&payload[79:72]==blocked);#1;
   edges=payload[31:0];dirs=payload[63:32];ex=payload[66:64];status=payload[68:67];
   for(n=0;n<21;n=n+1)begin dist[n]=100000;used[n]=0;end dist[20]=0;
   for(i=0;i<21;i=i+1)begin
    best=100000;cur=-1;
    for(n=0;n<21;n=n+1)if(!used[n]&&dist[n]<best)begin best=dist[n];cur=n;end
    if(cur>=0)begin
     used[cur]=1;
     for(e=0;e<32;e=e+1)if((mask[e]&k)==0&&(a[e]==cur||b[e]==cur))begin
      n=a[e]==cur ? b[e] : a[e];candidate=dist[cur]+cost[e];if(candidate<dist[n])dist[n]=candidate;
     end
    end
   end
   expected_cost=100000;
   if(!(k&1)&&dist[0]<expected_cost)expected_cost=dist[0];
   if(!(k&2)&&dist[4]<expected_cost)expected_cost=dist[4];
   if(!(k&4)&&dist[19]<expected_cost)expected_cost=dist[19];
   if((k&7)==7)begin if(status!=1||edges!=0)fail("all exits blocked");end
   else if(expected_cost==100000)begin if(status!=2||edges!=0)fail("unreachable");end
   else begin
    if(status!=0||ex<1||ex>3||(k&(1<<(ex-1))))fail("exit/status");
    node=20;path_cost=0;steps=0;
    while(edges!=0&&steps<32)begin
     next=-1;
     for(e=0;e<32;e=e+1)if(edges[e]&&((!dirs[e]&&a[e]==node)||(dirs[e]&&b[e]==node)))next=e;
     if(next<0)fail("disconnected path");
     if(mask[next]&k)fail("blocked edge used");
     node=dirs[next] ? a[next] : b[next];path_cost=path_cost+cost[next];edges[next]=0;steps=steps+1;
    end
    if(path_cost!=expected_cost||node!=(ex==1 ? 0 : ex==2 ? 4 : 19))fail("shortest path mismatch");
   end
   @(negedge clk);ready=1;@(negedge clk);ready=0;repeat(5)@(negedge clk);
  end
  $display("TEST_PASS tb_live_route all 256 hazards compared with independent shortest-path reference");$finish;
 end
 initial begin #100000000;$display("TEST_FAIL route timeout");$finish;end
endmodule
