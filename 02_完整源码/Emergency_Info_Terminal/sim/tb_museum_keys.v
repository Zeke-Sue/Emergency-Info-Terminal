`timescale 1ns/1ps
module tb_museum_keys;
 reg clk=0,rst=1;
 reg [3:0] key_n=15;
 wire [3:0] s,l,p,h;
 wire previous,next,confirm,back,home,activity;
 always #5 clk=~clk;
 genvar i;
 generate for(i=0;i<4;i=i+1)begin: filters
 key_events #(.DEBOUNCE_CYCLES(3),.LONG_CYCLES(16)) filter(.clk(clk),.rst(rst),.key_n(key_n[i]),
 .press(p[i]),.short_release(s[i]),.long_press(l[i]),.held(h[i]));end endgenerate
 museum_ui_control dut(.clk(clk),.rst(rst),.short_event(s),.long_event(l),.previous(previous),.next(next),.confirm(confirm),.back(back),.home(home),.activity(activity));
 integer confirms=0,homes=0,backs=0,prevs=0,nexts=0;
 always @(posedge clk)if(!rst)begin
 if(confirm)confirms=confirms+1;if(home)homes=homes+1;if(back)backs=backs+1;if(previous)prevs=prevs+1;if(next)nexts=nexts+1;end
 task step;input integer n;repeat(n)@(negedge clk);endtask
 task fail;input [511:0] why;begin $display("TEST_FAIL tb_museum_keys %0s",why);$finish;end endtask
 task tap;input integer bitno;begin key_n[bitno]=0;step(9);key_n[bitno]=1;step(9);end endtask
 initial begin
 step(3);rst=0;step(3);
 key_n[2]=0;step(1);key_n[2]=1;step(1);key_n[2]=0;step(1);key_n[2]=1;step(8);
 if(confirms)fail("bounce confirmed");
 tap(2);tap(2);if(confirms!=2)fail("continuous short presses");
 key_n[2]=0;step(50);key_n[2]=1;step(10);if(confirms!=2)fail("long KEY3 confirmed");
 key_n[3]=0;step(80);key_n[3]=1;step(10);if(homes!=1 || backs)fail("long KEY4 repeated or short release");
 tap(3);tap(0);tap(1);if(backs!=1 || prevs!=1 || nexts!=1)fail("physical mapping");
 $display("TEST_PASS tb_museum_keys debounce bounce, continuous press, release-only confirm, long BACK once and physical mapping");$finish;
 end
endmodule
