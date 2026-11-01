// 以2.5 Mbit/s串行链路发送实际输出PCM样本及关联页面状态。
`timescale 1ns/1ps

module pcm_context_tx(input wire clk,rst,sample_valid,
 input wire [15:0] sample,input wire [127:0] context,
 output wire tx,output reg overrun);
 reg [127:0] snapshot;
 reg [3:0] sequence_id;
 reg [2:0] index;
 reg busy;
 reg [39:0] packet;
 wire ready;
 function [7:0] crc_byte;
 input [7:0] old,b;integer i;reg [7:0] c;
 begin c=old^b;for(i=0;i<8;i=i+1)c=c[7] ? (c<<1)^8'h07 : c<<1;crc_byte=c;end
 endfunction
 wire [7:0] header={4'ha,sequence_id};
 wire [7:0] metadata=sequence_id==0 ? context[7:0] : snapshot[sequence_id*8 +: 8];
 wire [7:0] checksum=crc_byte(crc_byte(crc_byte(crc_byte(0,header),sample[7:0]),sample[15:8]),metadata);
 uart_tx_8n1 #(.CLK_HZ(25000000),.BAUD(2500000)) serial(
 .clk(clk),.rst(rst),.data(packet[7:0]),.valid(busy),.ready(ready),.tx(tx));
 always @(posedge clk or posedge rst)begin
  if(rst)begin snapshot<=0;sequence_id<=0;index<=0;busy<=0;packet<=0;overrun<=0;end
  else begin
   if(busy&&ready)begin
    packet<={8'd0,packet[39:8]};
    if(index==4)begin busy<=0;index<=0;end else index<=index+1'b1;
   end
   if(sample_valid)begin
    if(busy||!ready)overrun<=1;
    else begin
     if(sequence_id==0)snapshot<=context;
     packet<={checksum,metadata,sample,header};index<=0;busy<=1;
     sequence_id<=sequence_id+1'b1;
    end
   end
  end
 end
endmodule
