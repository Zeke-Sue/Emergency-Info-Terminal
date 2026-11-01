`timescale 1ns/1ps
module tb_p2_datapath;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg [2:0] mode=0;reg [6:0] progress=0;reg [10:0] x=0,y=0;
    wire select_new;wire [7:0] alpha;wire [10:0] ox,oy,nx,ny;wire dual;
    transition_coordinate_generator #(.WIDTH(64),.HEIGHT(48)) trans(.mode(mode),.progress(progress),.x(x),.y(y),
        .select_new(select_new),.new_alpha(alpha),.old_x(ox),.old_y(oy),.new_x(nx),.new_y(ny),.dual_source(dual));
    reg [1:0] scale=0;reg [10:0] pan_x=32,pan_y=24;wire [10:0] sx,sy,rx,ry;wire source_valid;
    shared_coordinate_mapper #(.WIDTH(64),.HEIGHT(48)) mapper(.x(x),.y(y),.scale(scale),.pan_x(pan_x),.pan_y(pan_y),
        .source_width(11'd64),.source_height(11'd48),.source_x(sx),.source_y(sy),.source_valid(source_valid),.route_x(rx),.route_y(ry));
    reg [31:0] sprite0=0,sprite1=0;wire [23:0] composite;
    seven_layer_compositor comp(.clk(clk),.base_rgb(24'h204060),.route_valid(1'b0),.route_rgb(24'd0),.route_alpha(3'd0),
        .sprite0_argb(sprite0),.sprite1_argb(sprite1),.alarm_valid(1'b0),.alarm_rgb(24'd0),.alarm_alpha(3'd0),
        .countdown_valid(1'b0),.countdown_rgb(24'd0),.text_coverage(2'd0),.text_rgb(24'd0),
        .osd_valid(1'b0),.osd_rgb(24'd0),.osd_alpha(3'd0),.rgb_out(composite));
    reg area=0;reg [7:0] fx=128,fy=128;reg [23:0] p00=0,p10=24'h400000,p01=24'h004000,p11=24'h000040;wire [23:0] sampled;
    resample_pixel resample(.clk(clk),.area_mode(area),.fraction_x(fx),.fraction_y(fy),.p00(p00),.p10(p10),.p01(p01),.p11(p11),.pixel_out(sampled));
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_p2_datapath: %0s",reason);$finish;end endtask
    integer m;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(m=0;m<7;m=m+1)begin mode=m;progress=0;x=40;y=20;#1;if(select_new||alpha!=0)fail("transition first frame");progress=64;#1;if(!select_new||alpha!=255)fail("transition last frame");end
        mode=1;progress=32;x=10;#1;if(!select_new)fail("wipe revealed half");x=50;#1;if(select_new)fail("wipe hidden half");
        mode=5;x=42;#1;if(!select_new)fail("blinds repeated open strip");x=50;#1;if(select_new)fail("blinds closed strip");
        mode=6;x=32;y=24;#1;if(!select_new)fail("circle centre");x=0;y=0;#1;if(select_new)fail("circle corner outside radius");
        x=32;y=24;scale=1;#1;if(sx!=32||sy!=24||rx!=sx||ry!=sy)fail("2x centre mapping");
        x=0;y=0;scale=2;#1;if(sx!=24||sy!=18)fail("4x mapping");
        sprite0={8'd128,24'hff0000};sprite1=0;repeat(2)@(posedge clk);#1;
        if(composite[23:16]<8'h8f||composite[23:16]>8'h90||composite[15:8]!=8'h20||composite[7:0]!=8'h30)fail("ARGB blend error");
        @(posedge clk);#1;if(sampled!=24'h101010)fail("bilinear centre");
        area=1;@(posedge clk);#1;if(sampled!=24'h101010)fail("area average");
        $display("TEST_PASS tb_p2_datapath seven transition masks, shared mapper, ARGB and resampler");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
