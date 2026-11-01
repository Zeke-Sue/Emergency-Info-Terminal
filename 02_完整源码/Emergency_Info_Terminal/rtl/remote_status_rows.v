`timescale 1ns/1ps

module remote_status_rows(input wire clk,rst,frame_tick,message_valid,
 input wire [7:0] message_type,input wire [95:0] payload,
 output reg [103:0] rows,output reg valid);
 reg [103:0] pending;reg [7:0] sequence_id;reg started,complete;
 reg [5:0] age;
 always @(posedge clk or posedge rst)begin
  if(rst)begin rows<=0;pending<=0;sequence_id<=0;started<=0;complete<=0;age<=0;valid<=0;end
  else begin
   if(frame_tick)begin
    if(age<30)age<=age+1'b1;
    else begin valid<=0;rows<=0;started<=0;end
    if(complete)begin rows<=pending;complete<=0;valid<=1;age<=0;end
   end
   if(message_valid&&message_type==8'h27)begin
    if(payload[87:80]==0)begin
     pending[63:0]<=payload[63:0];sequence_id<=payload[95:88];started<=1;complete<=0;
    end else if(payload[87:80]==1&&started&&payload[95:88]==sequence_id)begin
     pending[103:64]<=payload[39:0];complete<=1;started<=0;
    end else started<=0;
   end
  end
 end
endmodule
