`timescale 1ns/1ps
module tb_usability_map;
 reg clk=0,rst=1,enable=1,frame=0;always #5 clk=~clk;
 reg [10:0] x=0,y=0,px=0,py=0;reg [7:0] blocked=0;
 wire [23:0] rgb;
 live_route_overlay #(.FLOORPLAN(1),.EXTERNAL_RESULT(1)) dut(.clk(clk),.rst(rst),.frame_tick(frame),
 .message_valid(1'b0),.message_type(8'd0),.payload(96'd0),.pre_x(px),.pre_y(py),
 .route_result({16'h5002,8'd0,3'd0,2'd0,3'd3,32'd0,32'h8000c000}),.route_fresh(1'b1),
 .blocked(blocked),.enable(enable),.flash_on(1'b1),.x(x),.y(y),.rgb_in(24'h123456),.rgb_out(rgb));
 integer file,ix,iy,ink_count=0;reg [23:0] before_color;
 reg [4:0] edge_id=0;wire [31:0] edge_word;live_floor_graph graph(.index(edge_id),.edge_word(edge_word));
 integer e,expected_mask;
 task pixel;input integer a,b;begin @(negedge clk);px=a;py=b;@(negedge clk);x=a;y=b;#1;end endtask
 initial begin
 repeat(3)@(negedge clk);rst=0;
 for(e=0;e<32;e=e+1)begin
  edge_id=e;#1;
  expected_mask=e<16 ? (e<8 ? 64 : 128) : e==31 ? 0 : ((e-16)%5<2 ? 8 : (e-16)%5==2 ? 16 : 32);
  if(edge_word[28:21]!=expected_mask)$fatal(1,"spatial hazard mismatch edge %d",e);
 end
 file=$fopen("floor_rtl.ppm","wb");$fwrite(file,"P6\n640 480\n255\n");
 for(iy=0;iy<480;iy=iy+1)for(ix=0;ix<640;ix=ix+1)begin
  pixel(ix,iy);$fwrite(file,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
  if(dut.font_ink)ink_count=ink_count+1;
 end
 $fclose(file);if(ink_count<500)$fatal(1,"Chinese labels missing");
 enable=0;pixel(120,120);if(rgb!=24'h123456)$fatal(1,"map leaked into daily display");enable=1;
 pixel(360,380);before_color=rgb;
 repeat(8)begin @(negedge clk);frame=1;@(negedge clk);frame=0;end
 #1;if(rgb==before_color)$fatal(1,"route highlight did not move");
 blocked=8'h80;#1;if(rgb!=24'hff4040&&rgb!=24'h802020)$fatal(1,"blocked corridor unmarked");
 $display("TEST_PASS floor spatial hazards, Chinese ROM, disabled pass-through, moving route and blocked corridor; floor_rtl.ppm");$finish;
 end
 initial begin #20000000;$fatal(1,"map timeout");end
endmodule
