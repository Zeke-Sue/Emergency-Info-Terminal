`timescale 1ns/1ps
module tb_p2_overlay;
    reg clk=0;always #5 clk=~clk;
    reg [10:0] x=0,y=0;reg [1:0] view=0;reg [19:0] hist=0;
    reg [7:0] water=0;reg [23:0] peak=0;reg [7:0] subtitle=0;
    wire [5:0] hist_column,water_bin;wire [6:0] water_age;
    wire [23:0] analysis_rgb,subtitle_rgb;
    p2_analysis_overlay dut(.x(x),.y(y),.view(view),.histogram_value(hist),
        .waterfall_value(water),.peak_frequency_q8(peak),.rgb_in(24'h204060),
        .histogram_column(hist_column),.waterfall_age(water_age),
        .waterfall_bin(water_bin),.rgb_out(analysis_rgb));
    subtitle_overlay_renderer text(.clk(clk),.x(x),.y(y),.subtitle_id(subtitle),
        .rgb_in(analysis_rgb),.rgb_out(subtitle_rgb));
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_p2_overlay: %0s",reason);$finish;end endtask
    initial begin
        view=1;x=20;y=120;hist=20'd4096;#1;
        if(hist_column!=5||analysis_rgb!=24'h40e0ff)fail("histogram bar/query");
        x=640-128+7;y=126;view=2;water=8'hc0;peak=0;#1;
        if(water_age!=7||water_bin!=0||analysis_rgb==24'h204060)fail("waterfall map/query");
        x=640-128;y=66;peak=24'd737280;#1;
        if(water_bin!=30||analysis_rgb!=24'hffffff)fail("approximate peak marker");
        view=0;subtitle=1;x=16;y=480-48;@(posedge clk);#1;
        if(subtitle_rgb==24'h204060)fail("subtitle backing layer");
        subtitle=0;@(posedge clk);#1;if(subtitle_rgb!=24'h204060)fail("subtitle disable");
        $display("TEST_PASS tb_p2_overlay histogram/waterfall queries, colour map and subtitle layer");$finish;
    end
endmodule
