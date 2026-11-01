// 对当前封锁集合求解路线，回传地图标识、方向、路段及出口。
`timescale 1ns/1ps

module live_route_packetizer #(parameter integer CLK_HZ=50000000)(
 input wire clk,rst,link_alive,input wire [7:0] blocked,
 output wire request_valid,input wire request_ready,output wire [95:0] request_payload);
 reg [2:0] state;reg [4:0] load_index;reg [7:0] query;
 reg [$clog2(CLK_HZ/5)-1:0] timer;
 wire [31:0] edge_word,segments,directions;
 wire busy,done,error,entry_valid;wire [7:0] key;
 wire [2:0] exit_id;wire [1:0] status;wire [15:0] cost;
 live_floor_graph graph(.index(load_index),.edge_word(edge_word));
 n10_graph_solver #(.SINGLE_QUERY(1)) solver(.clk(clk),.rst(rst),.query_blocked(query),
 .cfg_clear(1'b0),.cfg_write(state==0),.cfg_index(load_index),
 .cfg_a(edge_word[4:0]),.cfg_b(edge_word[9:5]),.cfg_cost(edge_word[20:10]),.cfg_block_mask(edge_word[28:21]),
 .start(state==2),.node_count(6'd21),.edge_count(6'd32),.source_node(5'd20),
 .exit_nodes({5'd19,5'd4,5'd0}),.exit_block_masks(24'h040201),
 .busy(busy),.done(done),.error(error),.entry_valid(entry_valid),.entry_ready(request_ready&&state==3),
 .blocked_key(key),.segments(segments),.directions(directions),.selected_exit(exit_id),.status(status),.path_cost(cost));
 assign request_valid=state==3&&entry_valid&&link_alive;
 assign request_payload={16'h5002,key,3'd0,status,exit_id,directions,segments};
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=0;load_index<=0;query<=0;timer<=0;end
  else begin
   if(timer<CLK_HZ/5-1)timer<=timer+1'b1;
   case(state)
    0:if(load_index==31)state<=1;else load_index<=load_index+1'b1;
    1:if(link_alive&&(timer==CLK_HZ/5-1||query!=blocked))begin query<=blocked;state<=2;timer<=0;end
    2:state<=3;
    3:if(done)state<=1;
   endcase
  end
 end
endmodule
