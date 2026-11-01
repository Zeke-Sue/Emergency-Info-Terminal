`timescale 1ns/1ps

module shared_coordinate_mapper #(
    parameter integer WIDTH=640,
    parameter integer HEIGHT=480
)(
    input wire [10:0] x,
    input wire [10:0] y,
    input wire [1:0] scale,
    input wire [10:0] pan_x,
    input wire [10:0] pan_y,
    input wire [10:0] source_width,
    input wire [10:0] source_height,
    output reg [10:0] source_x,
    output reg [10:0] source_y,
    output reg source_valid,
    output wire [10:0] route_x,
    output wire [10:0] route_y
);
    reg signed [12:0] mapped_x,mapped_y;
    reg [10:0] half_w,half_h;
    always @* begin
        half_w=(WIDTH>>1)>>scale;
        half_h=(HEIGHT>>1)>>scale;
        mapped_x=$signed({2'b0,pan_x})-$signed({2'b0,half_w})+$signed({2'b0,(x>>scale)});
        mapped_y=$signed({2'b0,pan_y})-$signed({2'b0,half_h})+$signed({2'b0,(y>>scale)});
        source_valid=1;
        if(mapped_x<0) begin source_x=0;source_valid=0;end
        else if(mapped_x>=$signed({2'b0,source_width})) begin source_x=source_width-1'b1;source_valid=0;end
        else source_x=mapped_x[10:0];
        if(mapped_y<0) begin source_y=0;source_valid=0;end
        else if(mapped_y>=$signed({2'b0,source_height})) begin source_y=source_height-1'b1;source_valid=0;end
        else source_y=mapped_y[10:0];
    end
    assign route_x=source_x;
    assign route_y=source_y;
endmodule
