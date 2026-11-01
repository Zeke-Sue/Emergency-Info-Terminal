`timescale 1ns/1ps

module seven_layer_compositor(
    input wire clk,
    input wire [23:0] base_rgb,
    input wire route_valid,
    input wire [23:0] route_rgb,
    input wire [2:0] route_alpha,
    input wire [31:0] sprite0_argb,
    input wire [31:0] sprite1_argb,
    input wire alarm_valid,
    input wire [23:0] alarm_rgb,
    input wire [2:0] alarm_alpha,
    input wire countdown_valid,
    input wire [23:0] countdown_rgb,
    input wire [1:0] text_coverage,
    input wire [23:0] text_rgb,
    input wire osd_valid,
    input wire [23:0] osd_rgb,
    input wire [2:0] osd_alpha,
    output reg [23:0] rgb_out
);
    function [7:0] blend3;
        input [7:0] dst,src;input [2:0] alpha;
        reg [11:0] sum;
        begin

            if(alpha==7) blend3=src;
            else begin sum=src*alpha+dst*(8-alpha)+4;blend3=sum[10:3];end
        end
    endfunction
    function [7:0] blend8;
        input [7:0] dst,src,alpha;
        reg [16:0] sum;
        begin sum=src*alpha+dst*(255-alpha)+128;blend8=(sum+(sum>>8))>>8;end
    endfunction
    wire [23:0] route_mix=route_valid ?
        {blend3(base_rgb[23:16],route_rgb[23:16],route_alpha),
         blend3(base_rgb[15:8],route_rgb[15:8],route_alpha),
         blend3(base_rgb[7:0],route_rgb[7:0],route_alpha)} : base_rgb;
    reg [23:0] sprite0_mix;
    reg [31:0] sprite1_q;
    reg alarm_valid_q,countdown_valid_q,osd_valid_q;
    reg [23:0] alarm_rgb_q,countdown_rgb_q,osd_rgb_q,text_rgb_q;
    reg [2:0] alarm_alpha_q,osd_alpha_q;
    reg [1:0] text_coverage_q;
    wire [23:0] sprite1_mix={
        blend8(sprite0_mix[23:16],sprite1_q[23:16],sprite1_q[31:24]),
        blend8(sprite0_mix[15:8],sprite1_q[15:8],sprite1_q[31:24]),
        blend8(sprite0_mix[7:0],sprite1_q[7:0],sprite1_q[31:24])};
    reg [23:0] final_mix;
    always @(posedge clk) begin
        sprite0_mix<={
            blend8(route_mix[23:16],sprite0_argb[23:16],sprite0_argb[31:24]),
            blend8(route_mix[15:8],sprite0_argb[15:8],sprite0_argb[31:24]),
            blend8(route_mix[7:0],sprite0_argb[7:0],sprite0_argb[31:24])};
        sprite1_q<=sprite1_argb;
        alarm_valid_q<=alarm_valid;alarm_rgb_q<=alarm_rgb;alarm_alpha_q<=alarm_alpha;
        countdown_valid_q<=countdown_valid;countdown_rgb_q<=countdown_rgb;
        text_coverage_q<=text_coverage;text_rgb_q<=text_rgb;
        osd_valid_q<=osd_valid;osd_rgb_q<=osd_rgb;osd_alpha_q<=osd_alpha;
        final_mix=sprite1_mix;
        if(alarm_valid_q) final_mix={blend3(final_mix[23:16],alarm_rgb_q[23:16],alarm_alpha_q),
            blend3(final_mix[15:8],alarm_rgb_q[15:8],alarm_alpha_q),
            blend3(final_mix[7:0],alarm_rgb_q[7:0],alarm_alpha_q)};
        if(countdown_valid_q) final_mix=countdown_rgb_q;
        if(text_coverage_q!=0) final_mix={
            blend3(final_mix[23:16],text_rgb_q[23:16],{1'b0,text_coverage_q}<<1),
            blend3(final_mix[15:8],text_rgb_q[15:8],{1'b0,text_coverage_q}<<1),
            blend3(final_mix[7:0],text_rgb_q[7:0],{1'b0,text_coverage_q}<<1)};
        if(osd_valid_q) final_mix={blend3(final_mix[23:16],osd_rgb_q[23:16],osd_alpha_q),
            blend3(final_mix[15:8],osd_rgb_q[15:8],osd_alpha_q),
            blend3(final_mix[7:0],osd_rgb_q[7:0],osd_alpha_q)};
        rgb_out<=final_mix;
    end
endmodule
