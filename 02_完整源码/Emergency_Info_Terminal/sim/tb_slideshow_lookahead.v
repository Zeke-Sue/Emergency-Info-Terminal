`timescale 1ns/1ps

module tb_slideshow_lookahead;
 reg clk=0,rst=1;always #5 clk=~clk;
 integer cycle=0;always @(posedge clk)cycle<=cycle+1;
 wire frame_tick=cycle[0];
 reg [1:0] period=0;
 wire [3:0] desired,index,target,command_image;
 wire [1:0] command_slot,display_slot;
 wire [15:0] resident,failed;
 wire ready,command,slide,active,autoplay;
 wire [5:0] seconds;
 reg complete=0;
 image_cache_control #(.IMAGE_COUNT(16),.TRANSITION_PIN(1),.FAULT_CONTROL(1),
  .VIEWPORT_CACHE(1),.FAST_PREVIEW(1),.FORWARD_PREFETCH(1)) cache(
 .clk(clk),.rst(rst),.frame_tick(frame_tick),.sequential_mode(autoplay),
 .current_image(index),.requested_image(desired),.lookup_image(index),
 .pin_valid(slide),.pin_image(target),.second_lookup_image(target),
 .complete_toggle(complete),.load_failed(1'b0),.storage_fault(1'b0),
 .requested_view(8'd0),.command_toggle(command),.command_image(command_image),
 .command_slot(command_slot),.ready(ready),.resident(resident),
 .failed_images(failed),.display_slot(display_slot));
 player_control #(.CLK_HZ(120),.START_AUTOPLAY(1),.DEFAULT_PERIOD(0),
  .PERIOD_COUNT(3),.PERIOD_0(2),.PERIOD_1(5),.PERIOD_2(10),.PERIOD_3(10),
  .EXTERNAL_CONTROL(1),.USE_CACHE(1),.DUAL_SOURCE(1)) player(
 .clk(clk),.rst(rst),.ready(ready),.frame_tick(frame_tick),
 .next_event(1'b0),.previous_event(1'b0),.auto_event(1'b0),.period_event(1'b0),
 .target_enable(1'b0),.target_index(4'd0),.external_play(1'b1),
 .external_activity(1'b0),.external_period(period),.follow_narration(1'b0),
 .effect_select(3'd5),.resident(resident),.failed_images(failed),
 .emergency_abort(1'b0),.navigation_hold(1'b0),.transition_duration(2'd0),
 .transition_easing(1'b0),.desired_image(desired),.image_index(index),
 .transition_target(target),.slide_active(slide),.transition_active(active),
 .autoplay(autoplay),.period_seconds(seconds));

 reg seen=0;
 integer remaining=-1;
 reg [3:0] loading_image;
 reg [1:0] loading_slot;
 reg [3:0] stored_tag[0:3];
 reg [3:0] stored_valid=0;
 integer k;
 always @(posedge clk)begin
  if(rst)begin
   seen<=0;remaining<=-1;complete<=0;stored_valid<=0;
   for(k=0;k<4;k=k+1)stored_tag[k]<=0;
  end else if(command!=seen&&remaining<0)begin
   if(stored_valid[command_slot]&&
      (stored_tag[command_slot]==index||(slide&&stored_tag[command_slot]==target)))
    $fatal(1,"prefetch overwrote a visible transition source");
   seen<=command;loading_image<=command_image;loading_slot<=command_slot;
   stored_valid[command_slot]<=0;
   remaining<=command_image==8 ? 623 : command_image==11 ? 243 : 155;
  end else if(remaining==0)begin
   stored_tag[loading_slot]<=loading_image;stored_valid[loading_slot]<=1;
   complete<=seen;remaining<=-1;
  end else if(remaining>0)remaining<=remaining-1;
 end

 reg [3:0] old_desired=0,old_index=0;
 integer displayed_at=-1,changes=0,ninth_requests=0,wraps=0;
 reg started=0;
 always @(negedge clk)begin
  if(rst)begin
   old_desired=0;old_index=0;displayed_at=-1;changes=0;
   ninth_requests=0;wraps=0;started=0;
  end else begin
   if(ready)started=1;
   if(started&&!ready)$fatal(1,"prefetch evicted the displayed image");
   if(slide&&!resident[target])$fatal(1,"transition started before a complete target was resident");
   if(desired!=old_desired)begin
    if(!resident[desired])$fatal(1,"visible loading wait IMAGE%02d -> IMAGE%02d, period=%0d s",index+1,desired+1,seconds);
    if(displayed_at>=0&&cycle-displayed_at!=seconds*120)
     $fatal(1,"loading/transition consumed displayed dwell");
    if(desired==8)ninth_requests=ninth_requests+1;
   end
   if(index!=old_index)begin
    if(!stored_valid[display_slot]||stored_tag[display_slot]!=index)
     $fatal(1,"published image does not match completed SDRAM slot");
    displayed_at=cycle;changes=changes+1;
    if(index==0)wraps=wraps+1;
   end
   old_desired=desired;old_index=index;
  end
 end

 integer p;
 initial begin
  for(p=0;p<3;p=p+1)begin
   rst=1;period=p;repeat(4)@(negedge clk);rst=0;
   wait(changes>=32);@(posedge clk);#1;
   if(ninth_requests!=2||wraps!=2)$fatal(1,"did not cover repeated IMAGE08/09 and IMAGE16/01");
   $display("LOOKAHEAD period=%0d s: 32 changes, two IMAGE08/09 and two wraps; no visible loading wait",seconds);
  end
  $display("TEST_PASS three-page forward cache hides 4x-size IMAGE09 load at all 2/5/10 s dwell settings, with transition pinning and repeated wraps");
  $finish;
 end
 initial begin #1500000;$fatal(1,"lookahead timeout");end
endmodule
