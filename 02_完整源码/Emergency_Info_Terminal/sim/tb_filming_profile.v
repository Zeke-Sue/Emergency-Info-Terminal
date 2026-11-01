`timescale 1ns/1ps
module tb_filming_profile;
 reg [2:0] mode=0;reg [6:0] progress=0;reg [10:0] x=0,y=0;
 wire [52:0] full_result,film_result;
 transition_coordinate_generator full(.mode(mode),.progress(progress),.x(x),.y(y),
 .select_new(full_result[52]),.new_alpha(full_result[51:44]),.old_x(full_result[43:33]),
 .old_y(full_result[32:22]),.new_x(full_result[21:11]),.new_y(full_result[10:0]));
 transition_coordinate_generator #(.BASIC_ONLY(1)) film(.mode(mode),.progress(progress),.x(x),.y(y),
 .select_new(film_result[52]),.new_alpha(film_result[51:44]),.old_x(film_result[43:33]),
 .old_y(film_result[32:22]),.new_x(film_result[21:11]),.new_y(film_result[10:0]));
 reg clk=0,rst=1,menu=0,next_item=0,plus=0,minus=0;always #5 clk=~clk;
 wire [2:0] effect;wire [3:0] selection;
 daily_control #(.V5_CONTROLS(1),.DIRECT_MENU(1),.FILMING_EFFECTS(1),.MAX_EFFECT_MODE(5)) controls(
 .clk(clk),.rst(rst),.frame_tick(1'b1),.maintenance_enable(menu),.grayscale_switch(1'b0),
 .key1_short(minus),.key1_long(1'b0),.key2_short(plus),.key3_short(next_item),
 .key3_long(1'b0),.key4_long(1'b0),.key4_short(1'b0),.night_switch(1'b0),
 .follow_switch(1'b0),.period_select(2'd0),.effect_mode(effect),.maintenance_selection(selection));
 integer m,p,a,b;
 initial begin
 for(m=0;m<4;m=m+1)for(p=0;p<=64;p=p+1)for(b=0;b<4;b=b+1)for(a=0;a<640;a=a+1)begin
  mode=m==3 ? 5 : m;progress=p;x=a;y=b*159;#1;
  if(full_result!==film_result)$fatal(1,"retained transition differs mode=%0d progress=%0d x=%0d y=%0d",m,p,a,y);
 end
 repeat(4)@(negedge clk);rst=0;menu=1;repeat(3)@(negedge clk);
 repeat(5)begin next_item=1;@(negedge clk);next_item=0;@(negedge clk);end
 if(selection!=5)$fatal(1,"effect menu unreachable");
 repeat(10)begin plus=1;@(negedge clk);plus=0;@(negedge clk);if(effect==3||effect==4||effect==6)$fatal(1,"removed effect reached");end
 if(effect!=5)$fatal(1,"menu exposes removed effect");
 repeat(10)begin minus=1;@(negedge clk);minus=0;@(negedge clk);if(effect==3||effect==4||effect==6)$fatal(1,"removed effect reached");end
 if(effect!=0)$fatal(1,"cannot return crossfade");
 $display("TEST_PASS filming retained 4 transitions pixel-equivalent for 65 phases and full width; menu restricted to 0/1/2/5");$finish;
 end
endmodule
