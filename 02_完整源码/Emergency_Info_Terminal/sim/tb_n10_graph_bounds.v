`timescale 1ns/1ps
module tb_n10_graph_bounds;
    reg clk=0,rst=1,clear=0,we=0,start=0,ready=0;
    reg [4:0] index=0,a=0,b=0,source=0;
    reg [10:0] weight=2047;reg [7:0] mask=0;
    reg [5:0] nodes=32,edges=31;
    reg [14:0] exits={5'd31,5'd30,5'd29};
    wire busy,done,error,valid;wire [7:0] key;
    wire [31:0] segments,directions;wire [2:0] exit_id;
    wire [1:0] status;wire [15:0] cost;
    integer i,k,expected_node,expected_exit,faults=0;
    always #5 clk=~clk;
    n10_graph_solver dut(.clk(clk),.rst(rst),.cfg_clear(clear),.cfg_write(we),.cfg_index(index),
        .cfg_a(a),.cfg_b(b),.cfg_cost(weight),.cfg_block_mask(mask),.start(start),
        .node_count(nodes),.edge_count(edges),.source_node(source),.exit_nodes(exits),
        .exit_block_masks(24'h040201),.busy(busy),.done(done),.error(error),
        .entry_valid(valid),.entry_ready(ready),.blocked_key(key),.segments(segments),
        .directions(directions),.selected_exit(exit_id),.status(status),.path_cost(cost));
    task fail;input [8*100-1:0] s;begin $display("TEST_FAIL graph bounds: %0s",s);$finish;end endtask
    task launch;begin @(negedge clk);start=1;@(negedge clk);start=0;end endtask
    task write_edge;input [4:0] idx,aa,bb;input [10:0] cost_in;
        begin @(negedge clk);we=1;index=idx;a=aa;b=bb;weight=cost_in;
            @(negedge clk);we=0;end endtask
    task expect_fault;
        begin launch();while(!done)begin @(negedge clk);if(valid)fail("invalid graph emitted a route");end
            if(!error||busy)fail("missing bounded error");faults=faults+1;@(negedge clk);end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        for(i=0;i<31;i=i+1)write_edge(i,i,i+1,2047);
        launch();
        for(k=0;k<256;k=k+1)begin
            while(!valid&&!error)@(negedge clk);
            if(error||key!=k)fail("maximum chain failed");
            expected_node=!(k&1) ? 29 : (!(k&2) ? 30 : 31);
            expected_exit=expected_node-28;
            if((k&7)==7)begin
                if(status!=1||exit_id||segments||directions)fail("all blocked chain");
            end else if(status||exit_id!=expected_exit||cost!=expected_node*2047||
                    segments!=((32'h1<<expected_node)-1)||directions)fail("16-bit maximum simple path or endpoint");
            ready=1;@(negedge clk);ready=0;
        end
        if(!done||busy)fail("chain completion");@(negedge clk);
        nodes=0;expect_fault();nodes=33;expect_fault();nodes=32;
        edges=0;expect_fault();edges=33;expect_fault();edges=31;
        nodes=31;source=31;exits={5'd30,5'd29,5'd28};expect_fault();source=0;
        exits={5'd31,5'd30,5'd29};expect_fault();nodes=32;
        exits={5'd31,5'd30,5'd30};expect_fault();exits={5'd31,5'd30,5'd29};
        write_edge(0,0,1,0);expect_fault();
        write_edge(0,0,0,2047);expect_fault();
        nodes=31;exits={5'd30,5'd29,5'd28};write_edge(0,0,31,2047);expect_fault();
        nodes=32;exits={5'd31,5'd30,5'd29};write_edge(0,0,1,2047);
        @(negedge clk);clear=1;@(negedge clk);clear=0;expect_fault();
        for(i=0;i<31;i=i+1)write_edge(i,i,i+1,2047);
        launch();repeat(5)@(negedge clk);we=1;@(negedge clk);we=0;
        while(!done)@(negedge clk);
        if(!error||busy||valid)fail("busy mutation accepted");faults=faults+1;
        launch();while(!valid&&!error)@(negedge clk);
        if(error||cost!=29*2047)fail("fault recovery");
        $display("TEST_PASS graph bounds: 32 nodes, 63457 cost, 256 keys, %0d malformed/mutation cases, restart",faults);$finish;
    end
    initial begin #50000000;fail("bounded timeout");end
endmodule
