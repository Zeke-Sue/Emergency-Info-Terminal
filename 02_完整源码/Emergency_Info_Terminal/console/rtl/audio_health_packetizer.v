`timescale 1ns/1ps

module audio_health_packetizer #(parameter integer CLK_HZ=50000000,SETTLE_SAMPLES=4800)(
 input wire clk,rst,link_alive,sample_valid,input wire signed [15:0] sample,
 input wire test_active,input wire [4:0] page,
 input wire transform_done,input wire [23:0] peak_frequency_q8,
 output reg request_valid,input wire request_ready,output reg [95:0] request_payload);
 reg [4:0] previous_page;reg previous_test;
 reg [12:0] stable_samples;reg [9:0] level_count;
 reg [15:0] peak_acc,level_peak,measured;
 reg measured_valid;
 wire [15:0] magnitude=sample[15] ? (~sample+16'd1) : sample;
 wire [15:0] expected=16'd500+page*16'd250;
 wire [15:0] difference=measured>expected ? measured-expected : expected-measured;
 wire [7:0] status=!link_alive ? 8'd5 : !test_active||!measured_valid ? 8'd0 :
     level_peak<64 ? 8'd3 : level_peak>=32760 ? 8'd4 : difference<=100 ? 8'd1 : 8'd2;
 reg [$clog2(CLK_HZ/5)-1:0] timer;
 reg [31:0] binary_pair,bcd_pair;reg [4:0] digit_step;
 reg converting;reg [7:0] captured_context,captured_status,captured_level;
 function [15:0] adjust;
  input [15:0] v;integer n;begin
   adjust=v;for(n=0;n<4;n=n+1)if(v[n*4+:4]>=5)adjust[n*4+:4]=v[n*4+:4]+3;
  end
 endfunction
 wire [15:0] bcd_e=adjust(bcd_pair[31:16]),bcd_m=adjust(bcd_pair[15:0]);
 wire [7:0] level=level_peak[15:9];
 always @(posedge clk or posedge rst)begin
  if(rst)begin previous_page<=0;previous_test<=0;stable_samples<=0;level_count<=0;
   peak_acc<=0;level_peak<=0;measured<=0;measured_valid<=0;timer<=0;request_valid<=0;
   request_payload<=0;binary_pair<=0;bcd_pair<=0;digit_step<=0;converting<=0;
   captured_context<=0;captured_status<=0;captured_level<=0;end
  else begin
   previous_page<=page;previous_test<=test_active;
   if(!link_alive||previous_page!=page||previous_test!=test_active)begin
    stable_samples<=0;level_count<=0;peak_acc<=0;level_peak<=0;measured_valid<=0;
   end else begin
    if(sample_valid)begin
     if(stable_samples<SETTLE_SAMPLES)stable_samples<=stable_samples+1'b1;
     if(level_count==1023)begin
      level_count<=0;level_peak<=magnitude>peak_acc ? magnitude : peak_acc;peak_acc<=0;
     end else begin level_count<=level_count+1'b1;if(magnitude>peak_acc)peak_acc<=magnitude;end
    end
    if(transform_done&&stable_samples==SETTLE_SAMPLES)begin
     measured<=peak_frequency_q8[23:8];measured_valid<=1;
    end
   end
   if(timer!=CLK_HZ/5-1)timer<=timer+1'b1;
   if(request_valid&&request_ready)request_valid<=0;
   if(!request_valid&&!converting&&timer==CLK_HZ/5-1)begin
    timer<=0;converting<=1;digit_step<=0;bcd_pair<=0;
    binary_pair<={expected,measured};captured_context<={2'd0,test_active,page};
    captured_status<=status;
    captured_level<=((level/10)<<4)|(level%10);
   end else if(converting)begin
    bcd_pair<={bcd_e[14:0],binary_pair[31],bcd_m[14:0],binary_pair[15]};
    binary_pair<={binary_pair[30:16],1'b0,binary_pair[14:0],1'b0};
    if(digit_step==15)begin
     converting<=0;request_valid<=1;
     request_payload<={16'h2101,captured_context,bcd_e[14:0],binary_pair[31],
       bcd_m[14:0],binary_pair[15],captured_level,captured_status,24'd0};
    end else digit_step<=digit_step+1'b1;
   end
  end
 end
endmodule
