`timescale 1ns/1ps

module resample_pixel(
    input wire clk,
    input wire area_mode,
    input wire [7:0] fraction_x,
    input wire [7:0] fraction_y,
    input wire [23:0] p00,p10,p01,p11,
    output reg [23:0] pixel_out
);
    integer c;
    reg [7:0] a00 [0:2];reg [7:0] a10 [0:2];reg [7:0] a01 [0:2];reg [7:0] a11 [0:2];
    reg [16:0] top [0:2],bottom [0:2];
    reg [25:0] result [0:2];
    wire [9:0] average_r={2'b0,p00[23:16]}+{2'b0,p10[23:16]}+
                         {2'b0,p01[23:16]}+{2'b0,p11[23:16]}+10'd2;
    wire [9:0] average_g={2'b0,p00[15:8]}+{2'b0,p10[15:8]}+
                         {2'b0,p01[15:8]}+{2'b0,p11[15:8]}+10'd2;
    wire [9:0] average_b={2'b0,p00[7:0]}+{2'b0,p10[7:0]}+
                         {2'b0,p01[7:0]}+{2'b0,p11[7:0]}+10'd2;
    always @* begin
        a00[0]=p00[23:16];a00[1]=p00[15:8];a00[2]=p00[7:0];
        a10[0]=p10[23:16];a10[1]=p10[15:8];a10[2]=p10[7:0];
        a01[0]=p01[23:16];a01[1]=p01[15:8];a01[2]=p01[7:0];
        a11[0]=p11[23:16];a11[1]=p11[15:8];a11[2]=p11[7:0];
        for(c=0;c<3;c=c+1) begin
            top[c]=a00[c]*(256-fraction_x)+a10[c]*fraction_x;
            bottom[c]=a01[c]*(256-fraction_x)+a11[c]*fraction_x;
            result[c]=top[c]*(256-fraction_y)+bottom[c]*fraction_y;
        end
    end
    always @(posedge clk) begin
        if(area_mode) pixel_out<={average_r[9:2],average_g[9:2],average_b[9:2]};
        else pixel_out<={result[0][23:16],result[1][23:16],result[2][23:16]};
    end
endmodule
