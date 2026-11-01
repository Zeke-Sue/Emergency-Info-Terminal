`timescale 1ns/1ps

module dual_source_blend(
    input wire [23:0] old_rgb,new_rgb,
    input wire [6:0] progress,
    input wire crossfade,select_new,enable,
    output wire [23:0] rgb
);
    function [7:0] blend;
        input [7:0] a,b;
        input [6:0] p;
        reg signed [8:0] delta;
        reg signed [16:0] product;
        reg signed [17:0] sum;
        begin
            delta=$signed({1'b0,b})-$signed({1'b0,a});
            product=delta*$signed({1'b0,p});
            sum=$signed({1'b0,a,6'b0})+product+18'sd32;
            blend=sum>>>6;
        end
    endfunction
    assign rgb=!enable ? old_rgb : crossfade ?
        {blend(old_rgb[23:16],new_rgb[23:16],progress),
         blend(old_rgb[15:8],new_rgb[15:8],progress),
         blend(old_rgb[7:0],new_rgb[7:0],progress)} :
        (select_new ? new_rgb : old_rgb);
endmodule
