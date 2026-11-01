`timescale 1ns/1ps
module page_test_tone_48k(input wire clk,rst,enable,output_tick,input wire [4:0] page,
 output reg native_valid,output wire signed [15:0] native_sample,output_sample);
 reg [15:0] phase,step;reg [4:0] last_page;reg signed [15:0] sample;
 always @* case(page)
 5'd0:step=16'd683;
 5'd1:step=16'd1024;
 5'd2:step=16'd1365;
 5'd3:step=16'd1707;
 5'd4:step=16'd2048;
 5'd5:step=16'd2389;
 5'd6:step=16'd2731;
 5'd7:step=16'd3072;
 5'd8:step=16'd3413;
 5'd9:step=16'd3755;
 5'd10:step=16'd4096;
 5'd11:step=16'd4437;
 5'd12:step=16'd4779;
 5'd13:step=16'd5120;
 5'd14:step=16'd5461;
 5'd15:step=16'd5803;
 5'd16:step=16'd6144;
 5'd17:step=16'd6485;
 5'd18:step=16'd6827;
 5'd19:step=16'd7168;
 5'd20:step=16'd7509;
 default:step=16'd683;
 endcase
 always @* case(phase[15:10])
 6'd0:sample=16'sd0;
 6'd1:sample=16'sd401;
 6'd2:sample=16'sd799;
 6'd3:sample=16'sd1189;
 6'd4:sample=16'sd1567;
 6'd5:sample=16'sd1931;
 6'd6:sample=16'sd2276;
 6'd7:sample=16'sd2598;
 6'd8:sample=16'sd2896;
 6'd9:sample=16'sd3166;
 6'd10:sample=16'sd3406;
 6'd11:sample=16'sd3612;
 6'd12:sample=16'sd3784;
 6'd13:sample=16'sd3920;
 6'd14:sample=16'sd4017;
 6'd15:sample=16'sd4076;
 6'd16:sample=16'sd4096;
 6'd17:sample=16'sd4076;
 6'd18:sample=16'sd4017;
 6'd19:sample=16'sd3920;
 6'd20:sample=16'sd3784;
 6'd21:sample=16'sd3612;
 6'd22:sample=16'sd3406;
 6'd23:sample=16'sd3166;
 6'd24:sample=16'sd2896;
 6'd25:sample=16'sd2598;
 6'd26:sample=16'sd2276;
 6'd27:sample=16'sd1931;
 6'd28:sample=16'sd1567;
 6'd29:sample=16'sd1189;
 6'd30:sample=16'sd799;
 6'd31:sample=16'sd401;
 6'd32:sample=16'sd0;
 6'd33:sample=-16'sd401;
 6'd34:sample=-16'sd799;
 6'd35:sample=-16'sd1189;
 6'd36:sample=-16'sd1567;
 6'd37:sample=-16'sd1931;
 6'd38:sample=-16'sd2276;
 6'd39:sample=-16'sd2598;
 6'd40:sample=-16'sd2896;
 6'd41:sample=-16'sd3166;
 6'd42:sample=-16'sd3406;
 6'd43:sample=-16'sd3612;
 6'd44:sample=-16'sd3784;
 6'd45:sample=-16'sd3920;
 6'd46:sample=-16'sd4017;
 6'd47:sample=-16'sd4076;
 6'd48:sample=-16'sd4096;
 6'd49:sample=-16'sd4076;
 6'd50:sample=-16'sd4017;
 6'd51:sample=-16'sd3920;
 6'd52:sample=-16'sd3784;
 6'd53:sample=-16'sd3612;
 6'd54:sample=-16'sd3406;
 6'd55:sample=-16'sd3166;
 6'd56:sample=-16'sd2896;
 6'd57:sample=-16'sd2598;
 6'd58:sample=-16'sd2276;
 6'd59:sample=-16'sd1931;
 6'd60:sample=-16'sd1567;
 6'd61:sample=-16'sd1189;
 6'd62:sample=-16'sd799;
 6'd63:sample=-16'sd401;
 endcase
 assign native_sample=enable ? sample : 16'sd0;
 assign output_sample=native_sample;
 always @(posedge clk or posedge rst)
  if(rst)begin phase<=0;last_page<=0;native_valid<=0;end
  else begin
   last_page<=page;native_valid<=enable&&output_tick;
   if(!enable||page!=last_page)phase<=0;
   else if(output_tick)phase<=phase+step;
  end
endmodule
