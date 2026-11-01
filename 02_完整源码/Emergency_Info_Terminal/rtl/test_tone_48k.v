`timescale 1ns/1ps
module test_tone_48k(
 input wire clk,rst,enable,output_tick,
 output reg native_valid,
 output wire signed [15:0] native_sample,output_sample
);
 reg [5:0] phase;
 reg signed [15:0] sample;
 assign output_sample=enable ? sample : 16'sd0;
 assign native_sample=output_sample;
 always @* case(phase)
 6'd0:sample=16'sd0;
 6'd1:sample=16'sd535;
 6'd2:sample=16'sd1060;
 6'd3:sample=16'sd1567;
 6'd4:sample=16'sd2048;
 6'd5:sample=16'sd2493;
 6'd6:sample=16'sd2896;
 6'd7:sample=16'sd3250;
 6'd8:sample=16'sd3547;
 6'd9:sample=16'sd3784;
 6'd10:sample=16'sd3956;
 6'd11:sample=16'sd4061;
 6'd12:sample=16'sd4096;
 6'd13:sample=16'sd4061;
 6'd14:sample=16'sd3956;
 6'd15:sample=16'sd3784;
 6'd16:sample=16'sd3547;
 6'd17:sample=16'sd3250;
 6'd18:sample=16'sd2896;
 6'd19:sample=16'sd2493;
 6'd20:sample=16'sd2048;
 6'd21:sample=16'sd1567;
 6'd22:sample=16'sd1060;
 6'd23:sample=16'sd535;
 6'd24:sample=16'sd0;
 6'd25:sample=-16'sd535;
 6'd26:sample=-16'sd1060;
 6'd27:sample=-16'sd1567;
 6'd28:sample=-16'sd2048;
 6'd29:sample=-16'sd2493;
 6'd30:sample=-16'sd2896;
 6'd31:sample=-16'sd3250;
 6'd32:sample=-16'sd3547;
 6'd33:sample=-16'sd3784;
 6'd34:sample=-16'sd3956;
 6'd35:sample=-16'sd4061;
 6'd36:sample=-16'sd4096;
 6'd37:sample=-16'sd4061;
 6'd38:sample=-16'sd3956;
 6'd39:sample=-16'sd3784;
 6'd40:sample=-16'sd3547;
 6'd41:sample=-16'sd3250;
 6'd42:sample=-16'sd2896;
 6'd43:sample=-16'sd2493;
 6'd44:sample=-16'sd2048;
 6'd45:sample=-16'sd1567;
 6'd46:sample=-16'sd1060;
 6'd47:sample=-16'sd535;
 default:sample=0;
 endcase
 always @(posedge clk or posedge rst)
  if(rst)begin phase<=0;native_valid<=0;end
  else if(!enable)begin phase<=0;native_valid<=0;end
  else begin
   native_valid<=output_tick;
   if(output_tick)phase<=phase==47 ? 0 : phase+1'b1;
  end
endmodule
