`timescale 1ns/1ps
module tb_quality_manual_profile;
 reg clk=0,rst=1,frame_tick=0;
 reg [23:0] rgb=0;
 reg signed [8:0] brightness=0;
 reg [7:0] contrast=128;
 reg [1:0] gamma_mode=1,temperature_mode=1;
 wire [23:0] full_rgb,manual_rgb;
 wire [19:0] manual_hist,manual_column;
 integer b,c,g,t,n,checked=0;
 always #5 clk=~clk;
 `define QUALITY_COMMON .clk(clk),.rst(rst),.frame_tick(frame_tick),.pixel_valid(1'b1),.enable(1'b1),.alarm_bypass(1'b0),.rgb_in(rgb),.histogram_rgb(rgb),.histogram_valid(1'b1),.target_brightness(brightness),.target_contrast_q7(contrast),.gamma_mode(gamma_mode),.temperature_mode(temperature_mode),.auto_contrast_enable(1'b0),.histogram_query(8'd128),.histogram_column(6'd31)
 image_quality_engine #(.SMOOTH_PARAMETERS(0),.SEPARATE_STATS(1)) full_quality(
     `QUALITY_COMMON,.rgb_out(full_rgb));
 image_quality_engine #(.SMOOTH_PARAMETERS(0),.SEPARATE_STATS(1),.ENABLE_STATISTICS(0)) manual_quality(
     `QUALITY_COMMON,.rgb_out(manual_rgb),.histogram_value(manual_hist),.histogram_column_value(manual_column));
 `undef QUALITY_COMMON
 always @(negedge clk)if(!rst)begin
   rgb=rgb+24'h130b07;
   if(manual_rgb!==full_rgb)$fatal(1,"manual quality changed pixels at setting %d %d %d %d",b,c,g,t);
   if(manual_hist!==0||manual_column!==0)$fatal(1,"disabled statistics leaked values");
   checked=checked+1;
 end
 task frame;
 begin
   @(posedge clk);#1;frame_tick=1;
   @(posedge clk);#1;frame_tick=0;
   repeat(2998)@(posedge clk);
 end endtask
 initial begin
   repeat(4)@(posedge clk);#1;rst=0;
   repeat(1024)@(posedge clk);
   for(b=0;b<5;b=b+1)for(c=0;c<5;c=c+1)for(g=0;g<3;g=g+1)for(t=0;t<3;t=t+1)begin
     @(posedge clk);#1;
     brightness=(b-2)*16;contrast=96+c*16;gamma_mode=g;temperature_mode=t;
     frame();frame();
   end
   $display("TEST_PASS manual profile: all 225 production color settings, %0d pixel cycles, frame-atomic output identical",checked);$finish;
 end
endmodule
