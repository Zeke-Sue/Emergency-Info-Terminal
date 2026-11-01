`timescale 1ns/1ps
module tb_museum_ui;
 reg clk=0,rst=1,frame_tick=0,ready=0,busy=0;
 reg [3:0] short_event=0,long_event=0,error_code=0;
 reg timeout_event=0;
 always #5 clk=~clk;
 wire previous,next,confirm,back,home,activity,idle_enable;
 wire [3:0] page;
 wire [2:0] selection,bri,con,sat;
 wire playing,zoom,mono,prev_cmd,next_cmd,reload_cmd;
 wire [1:0] period;
 museum_ui_control keys(.clk(clk),.rst(rst),.short_event(short_event),.long_event(long_event),
  .previous(previous),.next(next),.confirm(confirm),.back(back),.home(home),.activity(activity));
 museum_menu_fsm dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),.resource_ready(ready),.error_code(error_code),
  .previous(previous),.next(next),.confirm(confirm),.back(back),.home(home),.activity(activity),
  .timeout_event(timeout_event),.video_busy(busy),.page(page),.selection(selection),.playing(playing),
  .brightness(bri),.contrast(con),.saturation(sat),.zoom(zoom),.mono(mono),.period_select(period),
  .previous_event(prev_cmd),.next_event(next_cmd),.reload_event(reload_cmd),.idle_enable(idle_enable));
 task fail;input [1023:0] reason;begin $display("TEST_FAIL tb_museum_ui: %0s",reason);$finish;end endtask
 task step;input integer n;begin repeat(n) @(negedge clk);end endtask
 task frame;begin frame_tick=1;step(1);frame_tick=0;step(1);end endtask
 task key;input [3:0] s;input [3:0] l;begin short_event=s;long_event=l;step(1);short_event=0;long_event=0;step(1);end endtask
 task enter;input integer item;integer j;begin
  key(0,8);frame();for(j=0;j<item;j=j+1)key(2,0);key(4,0);frame();
 end endtask
 integer prev_count=0,next_count=0,reload_count=0,confirm_count=0,i,seed=101;
 reg [26:0] last_visible;
 reg boundary_previous;
 wire [26:0] visible={page,selection,playing,bri,con,sat,zoom,mono,period,5'd0};
 always @(posedge clk) begin
  if(rst)begin last_visible<=visible;boundary_previous<=1;end
  else begin
   if(visible!==last_visible && !boundary_previous)fail("state changed outside frame boundary");
   last_visible<=visible;boundary_previous<=frame_tick;
   if(prev_cmd)prev_count=prev_count+1;
   if(next_cmd)next_count=next_count+1;
   if(reload_cmd)reload_count=reload_count+1;
   if(confirm)confirm_count=confirm_count+1;
   if(prev_cmd && next_cmd)fail("conflicting manual commands");
   if(playing && (prev_cmd || next_cmd))fail("automatic/manual collision");
   if(page>8 || selection>4 || bri>4 || con>4 || sat>4)fail("state/parameter range");
  end
 end
 initial begin
  $dumpfile("tb_museum_ui.vcd");$dumpvars(0,tb_museum_ui);
  step(3);rst=0;step(2);frame();if(page!=1)fail("loading page");
  key(0,8);frame();if(page!=2)fail("home during loading");
  key(4,0);frame();if(page!=1)fail("cannot enter unready guide");
  ready=1;step(2);frame();if(page!=2)fail("ready main page");
  key(1,0);frame();if(selection!=4)fail("previous wraps menu");
  key(2,0);frame();if(selection!=0)fail("next wraps menu");
  short_event=4;step(8);short_event=0;step(2);frame();
  if(page!=3 || !playing || confirm_count!=2)fail("stretched confirm repeated");
  key(0,4);frame();if(!playing)fail("long confirm must not short-confirm");
  key(4,0);frame();if(playing)fail("pause");
  key(4,0);frame();if(!playing)fail("resume");
  key(2,0);frame();if(playing || next_count!=1)fail("manual pauses guide atomically");
  busy=1;key(1,0);frame();if(prev_count!=0)fail("busy command was not suppressed");busy=0;
  key(1,0);key(0,8);frame();if(prev_count!=0 || page!=2)fail("home cancels pending command");
  enter(1);if(page!=4)fail("browse");key(4,0);frame();if(page!=5)fail("browse detail");
  key(2,0);if(zoom)fail("zoom changed midframe");frame();if(!zoom)fail("2x zoom");
  key(1,0);frame();if(zoom)fail("1x zoom");key(8,0);frame();if(page!=4)fail("nested return");
  enter(2);if(page!=5)fail("direct detail");key(8,0);frame();if(page!=2)fail("direct detail return");
  enter(3);if(page!=6)fail("enhance");
  for(i=0;i<8;i=i+1)key(2,0);if(bri!=2)fail("brightness changed midframe");frame();if(bri!=4)fail("brightness clamp high");
  for(i=0;i<8;i=i+1)key(1,0);frame();if(bri!=0)fail("brightness clamp low");
  key(4,0);key(2,0);frame();if(con!=3 || selection!=1)fail("contrast change");
  key(4,0);key(1,0);frame();if(sat!=1 || selection!=2)fail("saturation change");
  key(4,0);key(2,0);frame();if(!mono)fail("mono on");key(1,0);frame();if(mono)fail("mono off");
  enter(4);if(page!=7)fail("settings");key(4,0);frame();if(period!=3)fail("period");
  key(2,0);key(4,0);frame();if(reload_count!=1 || page!=1)fail("reload command");
  step(5);frame();if(page!=1)fail("stale ready escaped reload wait");
  ready=0;step(2);ready=1;step(2);frame();if(page!=2)fail("reload complete");
  error_code=5;step(2);frame();if(page!=8 || playing)fail("error page");
  key(8,0);frame();if(page!=2)fail("return from persistent error");frame();if(page!=2)fail("error trapped navigation");
  error_code=0;step(2);error_code=6;step(2);frame();if(page!=8)fail("new error detection");
  key(4,0);frame();if(reload_count!=2)fail("error retry");
  ready=0;error_code=0;step(2);ready=1;step(2);frame();
  enter(3);timeout_event=1;step(1);timeout_event=0;frame();if(page!=3 || !playing)fail("idle return");
  key(8,0);frame();timeout_event=1;short_event=2;step(1);timeout_event=0;short_event=0;step(1);frame();
  if(page!=2 || selection!=1)fail("user activity must beat timeout");
  key(12,0);frame();if(page!=2)fail("BACK priority over confirm chord");
  key(3,0);frame();if(selection!=0)fail("opposite direction chord must cancel");

  for(i=0;i<250;i=i+1)begin
   case(($random(seed)&32'h7fffffff)%6)
    0:key(1,0);1:key(2,0);2:key(4,0);3:key(8,0);4:key(0,8);5:key(0,4);
   endcase
   if(i%3==0)frame();
  end
  key(0,8);frame();if(page!=2 || playing)fail("stress home");
  $display("TEST_PASS tb_museum_ui all pages, hierarchy, rapid/long/chord input, frame atomicity, clamp, reload, errors, idle priority and 250 stress events");$finish;
 end
 initial begin #1000000;fail("timeout");end
endmodule
