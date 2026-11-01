`timescale 1ns/1ps
module tb_v5_daily_control;
    reg clk=0,rst=1,frame=0,night=0,maintenance=0,k3long=0,k4long=0,k4short=0;
    reg [1:0] period=0;
    reg k1=0,k2=0,k3=0;
    always #5 clk=~clk;
    wire follow,period_event,mono,osd,reload;
    wire [2:0] bright,contrast,saturation,volume;
    wire [1:0] gamma,temp;
    wire [1:0] zoom;wire [2:0] panx,pany;wire automatic_contrast;
    daily_control #(.V5_CONTROLS(1)) dut(.clk(clk),.rst(rst),.frame_tick(frame),
        .follow_switch(1'b0),
        .maintenance_enable(maintenance),.grayscale_switch(1'b1),.night_switch(night),
        .key1_short(k1),.key1_long(1'b0),.key2_short(k2),.key3_short(k3),
        .key3_long(k3long),.key4_long(k4long),.key4_short(k4short),.period_select(period),
        .follow_narration(follow),.period_event(period_event),.grayscale_enable(mono),
        .osd_visible(osd),.reload_event(reload),.brightness_level(bright),.contrast_level(contrast),
        .saturation_level(saturation),.gamma_mode(gamma),.temperature_mode(temp),.volume_level(volume),
        .zoom_scale(zoom),.pan_x_level(panx),.pan_y_level(pany),.auto_contrast_enable(automatic_contrast));
    task fail;input [799:0] msg;begin $display("TEST_FAIL V5 controls: %0s",msg);$finish;end endtask
    task frame_tick;begin frame=1;@(negedge clk);frame=0;@(negedge clk);end endtask
    always @(posedge clk)if(!rst&&period_event)period<=period+1'b1;
    task cycle;begin k3long=1;@(negedge clk);k3long=0;@(negedge clk);end endtask
    task key;input integer id;begin
        case(id)1:k1=1;2:k2=1;3:k3=1;endcase
        @(negedge clk);k1=0;k2=0;k3=0;@(negedge clk);
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;night=1;repeat(4)@(negedge clk);
        if(bright!=2||mono)fail("night committed mid-frame or SW4 leaked into grayscale");
        frame_tick();if(bright!=1||saturation!=1||gamma!=2||temp!=0||volume!=4)fail("night preset");
        night=0;frame_tick();if(bright!=2||saturation!=2||gamma!=1||temp!=1||volume!=7)fail("day restore");
        repeat(3)cycle();if(period!=3||follow)fail("timed period selection");
        cycle();if(!follow||period!=3)fail("follow mode unreachable");
        cycle();if(follow||period!=0)fail("follow to first timed period");
        maintenance=1;k4long=1;@(negedge clk);k4long=0;@(negedge clk);
        if(!osd||reload)fail("protected maintenance");
        repeat(11)key(3);key(2);if(mono)fail("grayscale committed mid-frame");
        frame_tick();if(!mono)fail("grayscale menu lost after SW4 remap");
        key(3);repeat(3)key(2);frame_tick();if(zoom!=2)fail("four-times zoom unavailable");
        key(3);repeat(6)key(2);frame_tick();if(panx!=4)fail("pan X upper clamp");
        repeat(6)key(1);frame_tick();if(panx!=0)fail("pan X lower clamp");
        key(3);repeat(6)key(2);frame_tick();if(pany!=4)fail("pan Y upper clamp");
        repeat(6)key(1);frame_tick();if(pany!=0)fail("pan Y lower clamp");
        key(3);key(2);frame_tick();if(!automatic_contrast)fail("auto contrast menu");
        k4short=1;@(negedge clk);k4short=0;@(negedge clk);if(osd)fail("KEY4 back");
        $display("TEST_PASS V5 controls: frame-atomic day/night, SW4 separation, timed/follow cycle, maintenance/back, retained grayscale/4x zoom/XY pan/auto contrast");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
