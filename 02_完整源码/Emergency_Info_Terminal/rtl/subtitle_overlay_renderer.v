`timescale 1ns/1ps

module subtitle_overlay_renderer #(
    parameter integer WIDTH=640,
    parameter integer HEIGHT=480
)(
    input wire clk,
    input wire [10:0] x,
    input wire [10:0] y,
    input wire [7:0] subtitle_id,
    input wire [23:0] rgb_in,
    output wire [23:0] rgb_out
);
    localparam integer PANEL_Y=HEIGHT>48 ? HEIGHT-48 : 0;
    wire panel=subtitle_id!=0 && subtitle_id<=16 &&
        x>=16 && x<WIDTH-16 && y>=PANEL_Y && y<PANEL_Y+32;
    wire [10:0] local_x=x-16;
    wire [10:0] local_y=y-PANEL_Y;
    wire glyph_enable=panel && local_x<128 && local_y>=8 && local_y<24;
    wire [3:0] subtitle_slot=subtitle_id==0 ? 4'd0 : subtitle_id-1'b1;
    wire [4:0] glyph_row=local_y[4:0]-5'd8;
    wire glyph_pixel;
    subtitle_bitmap_rom bitmap(.clk(clk),.subtitle_slot(subtitle_slot),
        .row(glyph_row[3:0]),.pixel_x(local_x[6:0]),.pixel(glyph_pixel));

    reg panel_q,glyph_enable_q;
    reg [23:0] rgb_q;
    always @(posedge clk) begin
        panel_q<=panel;glyph_enable_q<=glyph_enable;rgb_q<=rgb_in;
    end
    wire [23:0] panel_rgb={1'b0,rgb_q[23:17],1'b0,rgb_q[15:9],1'b0,rgb_q[7:1]};
    assign rgb_out=!panel_q ? rgb_q :
        (glyph_enable_q && glyph_pixel ? 24'hffffff : panel_rgb);
endmodule
