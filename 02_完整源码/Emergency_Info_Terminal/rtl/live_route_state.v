// 校验路线消息与当前地图、封锁集合的一致性，并管理路线有效期。
`timescale 1ns/1ps

module live_route_state(input wire clk,rst,frame_tick,message_valid,
 input wire [7:0] message_type,input wire [95:0] payload,input wire [7:0] blocked,
 output reg [95:0] active,output wire fresh);
 reg [95:0] pending;reg dirty,valid;reg [5:0] age;
 assign fresh=valid&&active[79:72]==blocked;
 always @(posedge clk or posedge rst)begin
  if(rst)begin active<=0;pending<=0;dirty<=0;valid<=0;age<=0;end
  else begin
   if(frame_tick)begin
    if(age<30)age<=age+1'b1;else valid<=0;
    if(dirty)begin active<=pending;dirty<=0;valid<=1;age<=0;end
   end
   if(message_valid&&message_type==8'h29&&payload[95:80]==16'h5002)begin pending<=payload;dirty<=1;end
  end
 end
endmodule
