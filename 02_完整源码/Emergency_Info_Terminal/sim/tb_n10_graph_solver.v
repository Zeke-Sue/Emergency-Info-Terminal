`timescale 1ns/1ps
module tb_n10_graph_solver;
    reg clk=0,rst=1,clear=0,we=0,start=0,ready=0;
    reg [4:0] index=0;
    wire [31:0] word;
    wire busy,done,error,valid;
    wire [7:0] key;
    wire [31:0] segments,directions;
    wire [2:0] exit_id;wire [1:0] status;wire [15:0] cost;
    integer ea[0:31],eb[0:31],ec[0:31],em[0:31];
    integer distance[0:440];
    integer i,j,k,m,n,expected_cost,expected_exit,current,next,steps,total,count=0,run;
    integer reachable_count=0,blocked_count=0,unreachable_count=0;
    reg [31:0] unused,seen_nodes;
    reg [71:0] first_run[0:255];
    reg [31:0] hold_segments,hold_directions;reg [7:0] hold_key;
    always #5 clk=~clk;
    n10_demo_graph graph(.index(index),.edge_word(word));
    n10_graph_solver dut(.clk(clk),.rst(rst),.cfg_clear(clear),.cfg_write(we),.cfg_index(index),
        .cfg_a(word[4:0]),.cfg_b(word[9:5]),.cfg_cost(word[20:10]),.cfg_block_mask(word[28:21]),
        .start(start),.node_count(6'd21),.edge_count(6'd32),.source_node(5'd20),
        .exit_nodes({5'd19,5'd4,5'd0}),.exit_block_masks(24'h040201),
        .busy(busy),.done(done),.error(error),.entry_valid(valid),.entry_ready(ready),
        .blocked_key(key),.segments(segments),.directions(directions),
        .selected_exit(exit_id),.status(status),.path_cost(cost));
    task fail;input [8*100-1:0] s;begin
        $display("TEST_FAIL graph: %0s key=%0d status=%d exit=%d cost=%d segments=%h dirs=%h",
            s,key,status,exit_id,cost,segments,directions);$finish;end endtask
    task check_entry;
        begin

            for(i=0;i<21;i=i+1)for(j=0;j<21;j=j+1)distance[i*21+j]=i==j ? 0 : 1000000;
            for(i=0;i<32;i=i+1)if((em[i]&key)==0)begin
                distance[ea[i]*21+eb[i]]=ec[i];distance[eb[i]*21+ea[i]]=ec[i];end
            for(k=0;k<21;k=k+1)for(i=0;i<21;i=i+1)for(j=0;j<21;j=j+1)
                if(distance[i*21+k]+distance[k*21+j]<distance[i*21+j])
                    distance[i*21+j]=distance[i*21+k]+distance[k*21+j];
            expected_cost=1000000;expected_exit=0;
            for(i=0;i<3;i=i+1)begin
                n=i==0 ? 0 : (i==1 ? 4 : 19);
                if(!(key&(1<<i))&&distance[20*21+n]<expected_cost)begin
                    expected_cost=distance[20*21+n];expected_exit=i+1;end
            end
            if((key&7)==7)begin
                if(status!=1||segments||directions||exit_id)fail("all exits blocked classification");
                blocked_count=blocked_count+1;
            end else if(expected_exit==0)begin
                if(status!=2||segments||directions||exit_id)fail("unreachable classification");
                unreachable_count=unreachable_count+1;
            end else begin
                if(status!=0||exit_id!=expected_exit||cost!=expected_cost)fail("shortest cost/exit tie");
                current=20;unused=segments;seen_nodes=0;total=0;steps=0;
                while(unused!=0&&steps<32)begin
                    next=-1;
                    for(i=0;i<32;i=i+1)if(unused[i])begin
                        if((!directions[i]&&ea[i]==current)||(directions[i]&&eb[i]==current))begin
                            if(next!=-1)fail("branch in path");next=i;
                        end
                    end
                    if(next<0||seen_nodes[current]||(key&em[next]))fail("disconnected/cyclic/blocked path");
                    seen_nodes[current]=1;unused[next]=0;total=total+ec[next];
                    current=directions[next] ? ea[next] : eb[next];steps=steps+1;
                end
                if(unused||total!=cost||current!=(exit_id==1 ? 0 : exit_id==2 ? 4 : 19))fail("path endpoint/cost");
                if((directions&~segments)!=0)fail("direction outside path");
                reachable_count=reachable_count+1;
            end
            if(run==0)first_run[key]={3'd0,status,exit_id,directions,segments};
            else if(first_run[key]!=={3'd0,status,exit_id,directions,segments})fail("nondeterministic restart");
        end
    endtask
    initial begin
        for(i=0;i<16;i=i+1)begin ea[i]=(i/4)*5+i%4;eb[i]=ea[i]+1;ec[i]=120;em[i]=1<<(3+i%5);end
        for(i=16;i<31;i=i+1)begin ea[i]=i-16;eb[i]=ea[i]+5;ec[i]=100;em[i]=1<<(3+(i-16)%5);end
        ea[31]=20;eb[31]=17;ec[31]=60;em[31]=128;
        repeat(3)@(negedge clk);rst=0;clear=1;
        @(negedge clk);clear=0;
        for(m=0;m<32;m=m+1)begin
            index=m;we=1;#1;
            if(word[4:0]!=ea[m]||word[9:5]!=eb[m]||word[20:10]!=ec[m]||word[28:21]!=em[m])
                fail("ROM differs from geometric graph");
            @(negedge clk);
        end
        we=0;
        for(run=0;run<2;run=run+1)begin
            start=1;@(negedge clk);start=0;
            for(count=0;count<256;count=count+1)begin
                while(!valid&&!error)@(negedge clk);
                if(error||key!=count)fail("solver fault/order");
                check_entry();hold_segments=segments;hold_directions=directions;hold_key=key;
                repeat(count%7+1)@(negedge clk);
                if(!valid||segments!=hold_segments||directions!=hold_directions||key!=hold_key)fail("output backpressure");
                ready=1;@(negedge clk);ready=0;
            end
            if(!done||busy)fail("completion");@(negedge clk);
        end
        if(reachable_count==0||blocked_count==0||unreachable_count==0)fail("missing status coverage");
        $display("TEST_PASS B serial graph, 32 edges/3 exits, 256 blocked sets twice, Floyd-Warshall/path/direction/ties/backpressure; counts %0d/%0d/%0d",
            reachable_count,blocked_count,unreachable_count);$finish;
    end
    initial begin #50000000;fail("bounded completion timeout");end
endmodule
