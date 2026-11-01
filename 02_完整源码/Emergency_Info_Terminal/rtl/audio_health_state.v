`timescale 1ns/1ps

module audio_health_state(input wire clk,rst,frame_tick,message_valid,
 input wire [7:0] message_type,input wire [95:0] payload,
 input wire [4:0] page,output reg [47:0] health,output wire fresh);
 reg [55:0] pending,active;reg dirty,valid;reg [5:0] age;
 assign fresh=valid&&active[53]&&active[52:48]==page;
 always @(posedge clk or posedge rst)begin
  if(rst)begin pending<=0;active<=0;dirty<=0;valid<=0;age<=63;health<=0;end
  else begin
   if(frame_tick)begin
    if(dirty)begin active<=pending;health<=pending[47:0];valid<=1;age<=0;dirty<=0;end
    else if(age<30)age<=age+1'b1;else valid<=0;
   end
   if(message_valid&&message_type==8'h2a&&payload[95:80]==16'h2101)begin
    pending<=payload[79:24];dirty<=1;
   end
  end
 end
endmodule
