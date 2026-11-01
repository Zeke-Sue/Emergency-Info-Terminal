`timescale 1ns/1ps
module tb_confirmation_overlay;
    reg [10:0] x=0,y=0;reg [7:0] status=0;reg enable=1;
    wire [23:0] rgb;integer n,pixels;
    local_status_overlay dut(.x(x),.y(y),.enable(enable),.fire_visible(1'b0),
        .remote_evacuation_selected(1'b0),.remote_confirmation(status),
        .status(16'd0),.quality_status(16'd0),.rgb_in(24'h123456),.rgb_out(rgb));
    task fail;input [799:0] why;begin $display("TEST_FAIL confirmation OSD %0s",why);$finish;end endtask
    initial begin
        status={1'b1,1'b0,5'd10,1'b0};y=128;
        for(n=0;n<320;n=n+1)begin
            x=32+n;#1;if(rgb!==(n<160 ? 24'h45df82 : 24'h303b46))fail("halfway bar width");
        end
        x=352;#1;if(rgb!=24'h123456)fail("bar clipping");
        y=108;pixels=0;
        for(n=0;n<576*14;n=n+1)begin
            x=32+n%576;y=108+n/576;#1;if(rgb==24'hffffff)pixels=pixels+1;
        end
        if(pixels<200)fail("missing confirmation text");
        enable=0;#1;if(rgb!=24'h123456)fail("disabled overlay");
        enable=1;status=0;#1;if(rgb!=24'h123456)fail("idle overlay");
        $display("TEST_PASS confirmation text and exact 20-step bounded progress bar");$finish;
    end
endmodule
