`timescale 1ns/1ps

module n10_route_packetizer(
    input wire clk,rst,refresh,
    output wire request_valid,input wire request_ready,
    output reg [7:0] request_type,output reg [95:0] request_payload,
    output wire busy,output reg error
);
    localparam LOAD=0,WAIT=1,BEGIN_BATCH=2,START_SOLVER=3,SEND_ENTRY=4,CRC=5,END_BATCH=6;
    reg [2:0] state;
    reg [4:0] load_index;
    reg pending,final_entry;
    reg [15:0] batch;
    reg [31:0] crc;
    reg [79:0] crc_word;
    reg [3:0] crc_left;
    wire [31:0] edge_word;
    wire solver_busy,solver_done,solver_error,entry_valid;
    wire [7:0] key;wire [31:0] segments,directions;
    wire [2:0] exit_id;wire [1:0] status;wire [15:0] cost;
    wire [71:0] entry={3'd0,status,exit_id,directions,segments};
    n10_demo_graph graph(.index(load_index),.edge_word(edge_word));
    n10_graph_solver solver(.clk(clk),.rst(rst),.cfg_clear(1'b0),.cfg_write(state==LOAD),
        .cfg_index(load_index),.cfg_a(edge_word[4:0]),.cfg_b(edge_word[9:5]),
        .cfg_cost(edge_word[20:10]),.cfg_block_mask(edge_word[28:21]),
        .start(state==START_SOLVER),.node_count(6'd21),.edge_count(6'd32),.source_node(5'd20),
        .exit_nodes({5'd19,5'd4,5'd0}),.exit_block_masks(24'h040201),
        .busy(solver_busy),.done(solver_done),.error(solver_error),
        .entry_valid(entry_valid),.entry_ready(state==SEND_ENTRY&&request_ready),
        .blocked_key(key),.segments(segments),.directions(directions),
        .selected_exit(exit_id),.status(status),.path_cost(cost));
    assign busy=state!=WAIT;
    assign request_valid=state==BEGIN_BATCH||state==END_BATCH||(state==SEND_ENTRY&&entry_valid);
    function [31:0] crc_byte;
        input [31:0] old;input [7:0] b;integer i;reg [31:0] c;
        begin c=old^b;for(i=0;i<8;i=i+1)c=c[0] ? (c>>1)^32'hedb88320 : c>>1;
            crc_byte=c;end
    endfunction
    always @* begin
        request_type=8'h24;request_payload={batch,key,entry};
        if(state==BEGIN_BATCH)begin
            request_type=8'h23;request_payload={16'h5001,batch,32'hc6ef49a1,16'd21,8'd32,8'd3};
        end else if(state==END_BATCH)begin
            request_type=8'h25;request_payload={16'h5001,batch,~crc,32'hc6ef49a1};
        end
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=LOAD;load_index<=0;pending<=1;batch<=0;error<=0;
            crc<=32'hffffffff;crc_word<=0;crc_left<=0;final_entry<=0;
        end else begin
            if(refresh)pending<=1;
            case(state)
                LOAD:if(load_index==31)state<=WAIT;else load_index<=load_index+1'b1;
                WAIT:if(pending)begin
                    pending<=refresh;batch<=batch+1'b1;crc<=32'hffffffff;
                    state<=BEGIN_BATCH;error<=0;
                end
                BEGIN_BATCH:if(request_ready)state<=START_SOLVER;
                START_SOLVER:state<=SEND_ENTRY;
                SEND_ENTRY:if(entry_valid&&request_ready)begin
                    crc_word<={key,entry};crc_left<=10;final_entry<=key==255;state<=CRC;
                end
                CRC:begin
                    crc<=crc_byte(crc,crc_word[7:0]);crc_word<=crc_word>>8;
                    crc_left<=crc_left-1'b1;
                    if(crc_left==1)state<=final_entry ? END_BATCH : SEND_ENTRY;
                end
                END_BATCH:if(request_ready)state<=WAIT;
                default:state<=WAIT;
            endcase
            if(solver_error&&(state==SEND_ENTRY||state==CRC||state==END_BATCH))begin
                error<=1;state<=WAIT;
            end
        end
    end
endmodule
