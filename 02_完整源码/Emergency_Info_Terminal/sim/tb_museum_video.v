`timescale 1ns/1ps
module museum_video_check #(parameter FIXED=1)(output reg done=0);
 reg clk=0,rst=1,ready=1;
 always #5 clk=~clk;
 wire valid,user,last,frame_tick,req,underflow,overflow;
 wire [23:0] rgb;
 reg [2:0] ack_pipe=0;
 reg [3:0] page=2;
 integer cycle=0,frames=0,sx=0,sy=0;
 reg checking=0,held=0;
 reg [25:0] held_word;
 always @(negedge clk)begin cycle=cycle+1;ready=cycle%17>=3;end
 always @(posedge clk)begin
  if(rst)ack_pipe<=0;else ack_pipe<={ack_pipe[1:0],req};
  if(!rst && frame_tick && frames>=1)page<=3;
 end
 video_scanout #(.FIXED_RATE_AXIS(FIXED),.MUSEUM_UI(1),.ENABLE_EFFECTS(0)) dut(
 .clk(clk),.rst(rst),.cache_ready(1'b1),.image_index(2'd0),.fade_gain(5'd16),
 .zoom_mode(1'b0),.zoom_scale(2'd0),.zoom_pan_x(11'd320),.zoom_pan_y(11'd240),
 .grayscale_enable(1'b0),.overlay_enable(1'b0),
 .transition_mode(3'd0),.transition_target(3'd0),.slide_progress(5'd0),.slide_active(1'b0),
 .brightness_level(3'd2),.contrast_level(3'd2),.saturation_level(3'd2),.osd_visible(1'b0),
 .quality_auto_enable(1'b0),.analysis_view(2'd0),.narration_subtitle(8'd0),
 .e5_peak_frequency_q8(24'd0),.e5_waterfall_value(8'd0),
 .museum_page(page),.museum_error(4'd0),.museum_selection(3'd1),.museum_period(2'd2),
 .museum_playing(1'b1),.museum_narration_ready(1'b1),.museum_progress(8'd50),.museum_subtitle(8'd1),
 .audio_sample_valid(1'b0),.audio_sample(16'd0),
 .console_proxy_valid(1'b0),.console_proxy_status(96'd0),
 .alarm_active(1'b0),.alarm_level(3'd4),.alarm_drill(1'b0),
 .alarm_cancel_notice(1'b0),.alarm_flash_on(1'b0),.alarm_countdown_trusted(1'b0),
 .alarm_countdown_seconds(16'd0),.alarm_latency_valid(1'b0),
 .alarm_pixel_latency_us(24'd0),.alarm_audio_latency_us(24'd0),.frame_tick(frame_tick),
 .line_req_toggle(req),.line_ack_toggle(ack_pipe[2]),.line_ram_q(24'h203040),
 .axis_valid(valid),.axis_user(user),.axis_last(last),.axis_data(rgb),.axis_ready(ready),
 .underflow(underflow),.overflow(overflow),.e5_waterfall_query_age(),.e5_waterfall_query_bin());
 reg [10:0] ref_x=0,ref_y=0;
 reg [3:0] ref_page=2;
 wire [23:0] expected;
 museum_osd reference_osd(.x(ref_x),.y(ref_y),.rgb_in(24'h203040),.page(ref_page),.error_code(4'd0),
 .selection(3'd1),.brightness(3'd2),.contrast(3'd2),.saturation(3'd2),.exhibit_index(2'd0),.period_select(2'd2),
 .playing(1'b1),.zoom(1'b0),.mono(1'b0),.narration_ready(1'b1),.progress(8'd50),.subtitle_id(8'd1),.rgb_out(expected));
 task fail;input [511:0] why;begin $display("TEST_FAIL tb_museum_video fixed=%0d x=%0d y=%0d %0s",FIXED,sx,sy,why);$finish;end endtask
 reg [23:0] sampled;
 always @(posedge clk) if(!rst && !done) begin
  if(underflow || overflow)fail("buffer fault");
  if(!FIXED)begin
   if(held && (!valid || {user,last,rgb}!==held_word))fail("payload changed under backpressure");
   held=valid&&!ready;held_word={user,last,rgb};
  end
  if(valid && (FIXED || ready))begin
   if(user)begin sx=0;sy=0;checking=dut.display_enabled;ref_page=page;end
   if(checking)begin
    if(last!==(sx==639) || user!==((sx==0)&&(sy==0)))fail("marker geometry");
    sampled=rgb;ref_x=sx;ref_y=sy;#1;
    if(sampled!==expected)begin $display("got %h expected %h",sampled,expected);fail("OSD/video pipeline alignment");end
    if(sx==639)begin sx=0;if(sy==479)begin frames=frames+1;checking=0;if(frames==2)done=1;end else sy=sy+1;end
    else sx=sx+1;
   end
  end
 end
 initial begin repeat(5)@(negedge clk);rst=0;end
endmodule
module tb_museum_video;
 wire fixed_done,elastic_done;
 museum_video_check #(.FIXED(1)) fixed_check(.done(fixed_done));
 museum_video_check #(.FIXED(0)) elastic_check(.done(elastic_done));
 initial begin wait(fixed_done && elastic_done);$display("TEST_PASS tb_museum_video four full 640x480 OSD frames, fixed-rate ready ignored, elastic backpressure, exact markers and zero buffer faults");$finish;end
 initial begin #20000000;$display("TEST_FAIL tb_museum_video timeout");$finish;end
endmodule
