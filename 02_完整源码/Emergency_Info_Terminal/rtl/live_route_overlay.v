// 将有效路径和行进方向叠加到楼层图，失效时撤下路径。
`timescale 1ns/1ps

module live_route_overlay #(parameter integer FLOORPLAN=0,EXTERNAL_RESULT=0)(input wire clk,rst,frame_tick,message_valid,
 input wire [10:0] pre_x,pre_y,input wire [95:0] route_result,input wire route_fresh,
 input wire [7:0] message_type,input wire [95:0] payload,
 input wire [7:0] blocked,input wire enable,flash_on,
 input wire [10:0] x,y,input wire [23:0] rgb_in,output wire [23:0] rgb_out);
 wire [95:0] active;wire fresh;
 generate if(EXTERNAL_RESULT)begin assign active=route_result;assign fresh=route_fresh;end
 else begin live_route_state cache(.clk(clk),.rst(rst),.frame_tick(frame_tick),.message_valid(message_valid),
 .message_type(message_type),.payload(payload),.blocked(blocked),.active(active),.fresh(fresh));end endgenerate
 reg [4:0] animation;always @(posedge clk or posedge rst)
  if(rst)animation<=0;else if(frame_tick)animation<=animation+1'b1;
 wire [5:0] segment;wire [7:0] phase;wire [1:0] distance;wire blocked_pixel;
 n10_demo_segment_map geometry(.x(x),.y(y),.blocked_set(blocked),
 .segment_id(segment),.segment_phase(phase),.segment_distance(distance),.blocked_exit_pixel(blocked_pixel));
 wire [23:0] base;wire foreground;
 n10_demo_map_renderer background(.x(x),.y(y),.enable(enable),.segment_id(segment),
 .route_valid(fresh),.status(active[68:67]),.selected_exit(active[66:64]),
 .rgb_in(rgb_in),.rgb_out(base),.foreground(foreground));
 wire selected=segment!=0&&active[segment-1'b1]&&fresh&&active[68:67]==0;
 wire reverse_direction=segment!=0&&active[32+segment-1'b1];
 wire [4:0] moving_phase=(reverse_direction ? ~phase[4:0] : phase[4:0])-animation;
 wire arrow=moving_phase<8&&distance<=(7-moving_phase)/2;
 wire font_ink;
 generate if(FLOORPLAN)begin floor_labels_rom labels(.clk(clk),.pre_x(pre_x),.pre_y(pre_y),.ink(font_ink));end
 else begin assign font_ink=0;end endgenerate

 wire room_x=(x>=92&&x<188)||(x>=212&&x<308)||(x>=332&&x<428)||(x>=452&&x<548);
 wire room_y=(y>=94&&y<166)||(y>=194&&y<266)||(y>=294&&y<366);
 wire [2:0] corridor_zone=segment<=16 ? (segment<=8 ? 3'd6 : 3'd7) :
   x<260 ? 3'd3 : x<380 ? 3'd4 : 3'd5;
 wire corridor_blocked=segment!=0&&segment!=32&&blocked[corridor_zone];
 wire in_map=x>=32&&x<608&&y>=28&&y<476;
 wire old_title=(y>=32&&y<46&&x<272)||(y>=434&&y<448&&x>=344);
 wire [23:0] floor_base=enable&&FLOORPLAN&&in_map ?
   font_ink ? 24'he9f1f8 : old_title ? 24'h182020 : room_x&&room_y ? 24'h24384a : base : base;
 assign rgb_out=enable&&blocked_pixel ? (flash_on ? 24'hff4040 : 24'h802020) :
  enable&&FLOORPLAN&&corridor_blocked ? (phase[3] ? 24'hff4040 : 24'h802020) :
  enable&&selected&&!foreground ? (arrow ? 24'h80ffd0 : 24'h00b878) : floor_base;
endmodule
