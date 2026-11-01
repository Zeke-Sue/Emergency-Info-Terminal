`timescale 1ns/1ps
module tb_status_text_equivalence;
    reg clk=0;
    always #5 clk=~clk;
    reg [10:0] x=0,y=0;
    reg enable=0,fire_visible=0,media_fault=0,remote_evacuation_selected=0;
    reg [7:0] remote_confirmation=0;
    reg [15:0] status=0,quality_status=0;
    reg [23:0] rgb_in=0;
    wire [23:0] original,combinational,pipelined;
    local_status_overlay_reference reference(.x(x),.y(y),.enable(enable),
        .fire_visible(fire_visible),.media_fault(media_fault),
        .remote_evacuation_selected(remote_evacuation_selected),
        .remote_confirmation(remote_confirmation),.status(status),
        .quality_status(quality_status),.rgb_in(rgb_in),.rgb_out(original));
    local_status_overlay asynchronous(.clk(clk),.x(x),.y(y),.enable(enable),
        .fire_visible(fire_visible),.media_fault(media_fault),
        .remote_evacuation_selected(remote_evacuation_selected),
        .remote_confirmation(remote_confirmation),.status(status),
        .quality_status(quality_status),.rgb_in(rgb_in),.rgb_out(combinational));
    local_status_overlay #(.REGISTERED(1)) synchronous(.clk(clk),.x(x),.y(y),.enable(enable),
        .fire_visible(fire_visible),.media_fault(media_fault),
        .remote_evacuation_selected(remote_evacuation_selected),
        .remote_confirmation(remote_confirmation),.status(status),
        .quality_status(quality_status),.rgb_in(rgb_in),.rgb_out(pipelined));
    integer trial,seed=32'h17325644;
    reg [23:0] expected;
    reg [63:0] seen=0;
    task compare;begin
        #1;
        expected=original;
        if(combinational!==expected)$fatal(1,"async status pixel mismatch x=%d y=%d",x,y);
        seen[asynchronous.message]=1;
        @(posedge clk);#1;
        if(pipelined!==expected)$fatal(1,"ROM status pipeline mismatch x=%d y=%d",x,y);
    end endtask
    initial begin
        for(trial=0;trial<600000;trial=trial+1)begin
            @(negedge clk);
            x=($random(seed)&32'h7fffffff)%660;
            y=($random(seed)&32'h7fffffff)%490;
            enable=trial%17!=0;
            fire_visible=$random(seed);media_fault=$random(seed);
            remote_evacuation_selected=$random(seed);remote_confirmation=$random(seed);
            status=$random(seed);quality_status=$random(seed);rgb_in=$random(seed);
            compare;
        end
        if(seen[43:0]!==44'hfffffffffff)$fatal(1,"status messages not all exercised: %h",seen);
        $display("TEST_PASS status ROM exact pixels and one-cycle alignment, 44 messages, 600000 randomized pixels");
        $finish;
    end
    initial begin #10000000;$fatal(1,"status ROM timeout");end
endmodule
