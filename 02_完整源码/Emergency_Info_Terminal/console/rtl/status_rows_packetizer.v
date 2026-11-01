`timescale 1ns/1ps

module status_rows_packetizer #(parameter integer CLK_HZ=50000000)(
 input wire clk,rst,link_alive,input wire [63:0] context,
 output wire request_valid,input wire request_ready,output wire [95:0] request_payload);
 reg [63:0] snapshot;
 reg [103:0] rows;
 reg [3:0] row;
 reg [1:0] state;
 reg [7:0] sequence_id;
 reg [$clog2(CLK_HZ/20)-1:0] count;
 wire [7:0] descriptor;
 console_status_rows layout(.context(snapshot),.row(row),.descriptor(descriptor));
 assign request_valid=state>=2;
 assign request_payload={sequence_id,7'd0,state==3,16'd0,state==2 ? rows[63:0] : {24'd0,rows[103:64]}};
 always @(posedge clk or posedge rst)begin
  if(rst)begin snapshot<=0;rows<=0;row<=0;state<=0;sequence_id<=0;count<=0;end
  else begin
   if(count!=CLK_HZ/20-1)count<=count+1'b1;
   case(state)
    0:if(link_alive&&count==CLK_HZ/20-1)begin snapshot<=context;row<=0;state<=1;count<=0;end
    1:begin rows[row*8 +: 8]<=descriptor;
      if(row==12)begin state<=2;sequence_id<=sequence_id+1'b1;end else row<=row+1'b1;
     end
    2:if(request_ready)state<=3;
    3:if(request_ready)state<=0;
   endcase
  end
 end
endmodule
