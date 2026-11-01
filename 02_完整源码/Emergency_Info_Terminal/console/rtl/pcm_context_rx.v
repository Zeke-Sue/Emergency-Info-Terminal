// 接收PCM样本及页面状态，检查帧同步与接收超时。
`timescale 1ns/1ps
module pcm_context_rx #(parameter integer CLK_HZ=50000000)(
 input wire clk,rst,rx,output reg sample_valid,output reg [15:0] sample,
 output reg [127:0] context,output reg context_valid,output reg link_alive,
 output reg discontinuity);
 wire [7:0] data;wire valid,framing;
 uart_rx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(2500000)) serial(
 .clk(clk),.rst(rst),.rx(rx),.data(data),.valid(valid),.framing_error(framing));
 reg [39:0] window;
 reg [2:0] fill;
 reg [3:0] expected;
 reg locked,collecting;
 reg [127:0] pending;
 reg [$clog2(CLK_HZ/100+1)-1:0] timeout;
 function [7:0] crc_byte;
 input [7:0] old,b;integer i;reg [7:0] c;
 begin c=old^b;for(i=0;i<8;i=i+1)c=c[7] ? (c<<1)^8'h07 : c<<1;crc_byte=c;end
 endfunction
 wire [7:0] checksum=crc_byte(crc_byte(crc_byte(crc_byte(0,window[31:24]),window[23:16]),window[15:8]),window[7:0]);
 wire candidate=fill>=4&&window[31:28]==4'ha&&checksum==data;
 always @(posedge clk or posedge rst)begin
  if(rst)begin window<=0;fill<=0;expected<=0;locked<=0;collecting<=0;
   pending<=0;context<=0;context_valid<=0;link_alive<=0;timeout<=0;
   discontinuity<=0;sample<=0;sample_valid<=0;end
  else begin
   sample_valid<=0;context_valid<=0;discontinuity<=0;
   if(timeout<CLK_HZ/100)timeout<=timeout+1'b1;
   else if(link_alive)begin link_alive<=0;locked<=0;collecting<=0;discontinuity<=1;end
   if(framing)begin locked<=0;collecting<=0;discontinuity<=1;fill<=0;end
   else if(valid)begin
    window<={window[31:0],data};if(fill<5)fill<=fill+1'b1;
    if(candidate)begin

     fill<=0;timeout<=0;link_alive<=1;
     sample<={window[15:8],window[23:16]};sample_valid<=1;
     if(!locked||window[27:24]!=expected)begin collecting<=0;discontinuity<=1;end
     locked<=1;expected<=window[27:24]+1'b1;
     if(window[27:24]==0)begin pending[7:0]<=window[7:0];collecting<=1;end
     else if(collecting&&locked&&window[27:24]==expected)begin
      pending[window[27:24]*8 +: 8]<=window[7:0];
      if(window[27:24]==15)begin context<={window[7:0],pending[119:0]};context_valid<=1;collecting<=0;end
     end
    end
   end
  end
 end
endmodule
