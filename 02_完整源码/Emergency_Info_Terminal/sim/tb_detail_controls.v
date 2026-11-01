`timescale 1ns/1ps
module tb_detail_controls;
    reg clk=0,rst=1,frame=0;
    always #5 clk=~clk;
    reg k1=0,k1long=0,k2=0,k3=0,k3long=0;
    wire previous,next,auto_event,period;
    wire [1:0] zoom;
    wire [2:0] pan_x,pan_y;
    daily_control #(.V5_CONTROLS(1)) dut(.clk(clk),.rst(rst),.frame_tick(frame),
        .follow_switch(1'b0),
        .maintenance_enable(1'b0),.grayscale_switch(1'b0),.night_switch(1'b0),
        .key1_short(k1),.key1_long(k1long),.key2_short(k2),
        .key3_short(k3),.key3_long(k3long),.key4_short(1'b0),.key4_long(1'b0),
        .period_select(2'd0),.zoom_scale(zoom),.pan_x_level(pan_x),.pan_y_level(pan_y),
        .previous_event(previous),.next_event(next),.auto_event(auto_event),.period_event(period));
    task commit_frame;
        begin frame=1;@(negedge clk);frame=0;@(negedge clk);end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        k1long=1;@(negedge clk);k1long=0;commit_frame();
        if(zoom!=1)$fatal(1,"2x not selected");
        k1=1;k3=1;#1;
        if(previous||auto_event)$fatal(1,"pan also navigated slideshow");
        @(negedge clk);k1=0;k3=0;commit_frame();
        if(pan_x!=1||pan_y!=1)$fatal(1,"left/up pan failed");
        k2=1;k3long=1;#1;
        if(next||period)$fatal(1,"pan also changed slide/period");
        @(negedge clk);k2=0;k3long=0;commit_frame();
        if(pan_x!=2||pan_y!=2)$fatal(1,"right/down pan failed");
        k1long=1;@(negedge clk);k1long=0;commit_frame();
        if(zoom!=2)$fatal(1,"4x not selected");
        k1long=1;@(negedge clk);k1long=0;commit_frame();
        k1=1;#1;if(!previous)$fatal(1,"Fit navigation not restored");
        $display("TEST_PASS tb_detail_controls detail pan without duplicate navigation");$finish;
    end
    initial begin #20000;$fatal(1,"detail controls timeout");end
endmodule
