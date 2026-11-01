// 有界串行Dijkstra求解器，复用节点RAM与边RAM。
// 正权边、严格小于比较和递增扫描顺序保证结果可重复。
`timescale 1ns/1ps

module n10_graph_solver #(parameter integer SINGLE_QUERY=0)(
    input wire [7:0] query_blocked,
    input wire clk,rst,cfg_clear,cfg_write,
    input wire [4:0] cfg_index,cfg_a,cfg_b,
    input wire [10:0] cfg_cost,input wire [7:0] cfg_block_mask,
    input wire start,input wire [5:0] node_count,edge_count,
    input wire [4:0] source_node,
    input wire [14:0] exit_nodes,input wire [23:0] exit_block_masks,
    output reg busy,done,error,
    output wire entry_valid,input wire entry_ready,
    output reg [7:0] blocked_key,
    output reg [31:0] segments,directions,
    output reg [2:0] selected_exit,output reg [1:0] status,
    output reg [15:0] path_cost
);
    localparam IDLE=0,CHECK_REQ=1,CHECK_EDGE=2,INIT=3,MIN_INIT=4,
        MIN_REQ=5,MIN_EVAL=6,PICK=7,EDGE_REQ=8,EDGE_EVAL=9,
        RELAX_REQ=10,RELAX_EVAL=11,RELAX_WRITE=12,EDGE_NEXT=13,
        TRACE_REQ=14,TRACE_EVAL=15,OUTPUT=16,NEXT_SET=17,FAIL=18;
    reg [4:0] state;
    reg [31:0] written,visited;
    reg [5:0] nodes,edges;
    reg [4:0] source,scan_node,best_node,current_node,edge_index,target,trace_node;
    reg [14:0] exits;
    reg [23:0] exit_masks;
    reg [15:0] best_distance,current_distance,candidate_distance;
    reg best_valid,reverse_edge;
    reg [5:0] trace_steps;
    wire [31:0] edge_q;
    buffer_ram #(.DATA_WIDTH(32),.ADDR_WIDTH(5)) edge_memory(
        .clk(clk),.we(cfg_write&&!busy),.wa(cfg_index),.ra(edge_index),
        .d({3'd0,cfg_block_mask,cfg_cost,cfg_b,cfg_a}),.q(edge_q));
    wire [4:0] edge_a=edge_q[4:0],edge_b=edge_q[9:5];
    wire [10:0] edge_cost=edge_q[20:10];
    wire edge_usable=(edge_q[28:21]&blocked_key)==0;
    wire adjacent=edge_a==current_node||edge_b==current_node;
    wire [4:0] neighbor=edge_a==current_node ? edge_b : edge_a;
    wire [31:0] node_q;
    wire [4:0] node_ra=(state==MIN_REQ||state==MIN_EVAL) ? scan_node :
        (state==TRACE_REQ||state==TRACE_EVAL ? trace_node : target);
    wire [31:0] node_write_data=state==INIT ?
        (scan_node==source ? 32'h08000000 : 32'h0000ffff) :
        {4'd0,1'b1,reverse_edge,edge_index,current_node,candidate_distance};
    buffer_ram #(.DATA_WIDTH(32),.ADDR_WIDTH(5)) node_memory(
        .clk(clk),.we(state==INIT||state==RELAX_WRITE),
        .wa(state==INIT ? scan_node : target),.ra(node_ra),
        .d(node_write_data),.q(node_q));
    wire [15:0] node_distance=node_q[15:0];
    wire [4:0] predecessor=node_q[20:16],predecessor_edge=node_q[25:21];
    wire predecessor_reverse=node_q[26],node_reached=node_q[27];
    wire exit0_open=(blocked_key&exit_masks[7:0])==0;
    wire exit1_open=(blocked_key&exit_masks[15:8])==0;
    wire exit2_open=(blocked_key&exit_masks[23:16])==0;
    wire [2:0] best_exit=best_node==exits[4:0]&&exit0_open ? 3'd1 :
        best_node==exits[9:5]&&exit1_open ? 3'd2 :
        best_node==exits[14:10]&&exit2_open ? 3'd3 : 3'd0;
    assign entry_valid=state==OUTPUT;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=IDLE;written<=0;visited<=0;busy<=0;done<=0;error<=0;
            nodes<=0;edges<=0;source<=0;exits<=0;exit_masks<=0;
            scan_node<=0;best_node<=0;current_node<=0;edge_index<=0;target<=0;trace_node<=0;
            best_distance<=0;current_distance<=0;candidate_distance<=0;
            best_valid<=0;reverse_edge<=0;trace_steps<=0;
            blocked_key<=0;segments<=0;directions<=0;selected_exit<=0;status<=3;path_cost<=0;
        end else begin
            done<=0;
            if(cfg_clear&&!busy)written<=0;
            else if(cfg_write&&!busy)written[cfg_index]<=1;
            case(state)
                IDLE:if(start)begin
                    busy<=1;error<=0;nodes<=node_count;edges<=edge_count;source<=source_node;
                    exits<=exit_nodes;exit_masks<=exit_block_masks;blocked_key<=SINGLE_QUERY ? query_blocked : 0;edge_index<=0;
                    if(node_count==0||node_count>32||edge_count==0||edge_count>32||
                            source_node>=node_count||exit_nodes[4:0]>=node_count||
                            exit_nodes[9:5]>=node_count||exit_nodes[14:10]>=node_count||
                            exit_nodes[4:0]==exit_nodes[9:5]||exit_nodes[4:0]==exit_nodes[14:10]||
                            exit_nodes[9:5]==exit_nodes[14:10])state<=FAIL;
                    else state<=CHECK_REQ;
                end
                CHECK_REQ:state<=CHECK_EDGE;
                CHECK_EDGE:begin
                    if(!written[edge_index]||edge_a>=nodes||edge_b>=nodes||edge_a==edge_b||edge_cost==0)
                        state<=FAIL;
                    else if({1'b0,edge_index}+1==edges)state<=NEXT_SET;
                    else begin edge_index<=edge_index+1'b1;state<=CHECK_REQ;end
                end
                NEXT_SET:begin
                    visited<=0;scan_node<=0;segments<=0;directions<=0;selected_exit<=0;path_cost<=0;
                    status<=0;trace_steps<=0;
                    if(!(exit0_open||exit1_open||exit2_open))begin status<=1;state<=OUTPUT;end
                    else state<=INIT;
                end
                INIT:begin
                    if({1'b0,scan_node}+1==nodes)state<=MIN_INIT;
                    else scan_node<=scan_node+1'b1;
                end
                MIN_INIT:begin scan_node<=0;best_valid<=0;best_distance<=16'hffff;state<=MIN_REQ;end
                MIN_REQ:state<=MIN_EVAL;
                MIN_EVAL:begin

                    if(!visited[scan_node]&&node_reached&&node_distance<best_distance)begin
                        best_valid<=1;best_distance<=node_distance;best_node<=scan_node;
                    end
                    if({1'b0,scan_node}+1==nodes)state<=PICK;
                    else begin scan_node<=scan_node+1'b1;state<=MIN_REQ;end
                end
                PICK:begin
                    if(!best_valid)begin status<=2;state<=OUTPUT;end
                    else if(best_exit!=0)begin
                        selected_exit<=best_exit;path_cost<=best_distance;trace_node<=best_node;state<=TRACE_REQ;
                    end else begin
                        visited[best_node]<=1;current_node<=best_node;current_distance<=best_distance;
                        edge_index<=0;state<=EDGE_REQ;
                    end
                end
                EDGE_REQ:state<=EDGE_EVAL;
                EDGE_EVAL:begin
                    if(adjacent&&edge_usable&&!visited[neighbor])begin
                        target<=neighbor;reverse_edge<=edge_b==current_node;
                        candidate_distance<=current_distance+edge_cost;state<=RELAX_REQ;
                    end else state<=EDGE_NEXT;
                end
                RELAX_REQ:state<=RELAX_EVAL;
                RELAX_EVAL:begin
                    if(!node_reached||candidate_distance<node_distance)state<=RELAX_WRITE;
                    else state<=EDGE_NEXT;
                end
                RELAX_WRITE:state<=EDGE_NEXT;
                EDGE_NEXT:begin
                    if({1'b0,edge_index}+1==edges)state<=MIN_INIT;
                    else begin edge_index<=edge_index+1'b1;state<=EDGE_REQ;end
                end
                TRACE_REQ:begin
                    if(trace_node==source)state<=OUTPUT;
                    else state<=TRACE_EVAL;
                end
                TRACE_EVAL:begin
                    if(!node_reached||trace_steps>=nodes||predecessor==trace_node||
                            predecessor>=nodes||{1'b0,predecessor_edge}>=edges||segments[predecessor_edge])state<=FAIL;
                    else begin
                        segments[predecessor_edge]<=1;directions[predecessor_edge]<=predecessor_reverse;
                        trace_node<=predecessor;trace_steps<=trace_steps+1'b1;state<=TRACE_REQ;
                    end
                end
                OUTPUT:if(entry_ready)begin
                    if(SINGLE_QUERY||blocked_key==255)begin busy<=0;done<=1;state<=IDLE;end
                    else begin blocked_key<=blocked_key+1'b1;state<=NEXT_SET;end
                end
                FAIL:begin error<=1;busy<=0;done<=1;state<=IDLE;end
                default:state<=FAIL;
            endcase
            if(busy&&(cfg_write||cfg_clear))state<=FAIL;
        end
    end
endmodule
