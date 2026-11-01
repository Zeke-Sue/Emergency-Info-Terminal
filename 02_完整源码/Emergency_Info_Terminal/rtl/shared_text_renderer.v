`timescale 1ns/1ps

module shared_text_renderer(
    input wire [15:0] codepoint,
    input wire [3:0] glyph_x,
    input wire [3:0] glyph_y,
    output wire [1:0] coverage
);
    wire [15:0] row_bits;
    emergency_font_rom current(.codepoint(codepoint),.row(glyph_y),.pixels(row_bits));
    wire centre=row_bits[15-glyph_x];
    wire left=glyph_x==0 ? 0 : row_bits[16-glyph_x];
    wire right=glyph_x==15 ? 0 : row_bits[14-glyph_x];
    wire fringe=left||right;
    assign coverage=centre ? 2'd3 : fringe ? 2'd1 : 2'd0;
endmodule
