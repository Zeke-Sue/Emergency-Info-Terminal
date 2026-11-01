`timescale 1ns/1ps
module demo_sprite_rom #(parameter integer SPRITE_ID=0)(
    input wire clk,input wire [12:0] address,output wire [31:0] argb,
    output wire [35:0] premultiplied,output wire [4:0] inverse_alpha
);
    wire [3:0] index;
    packed_nibble_rom #(
        .MEM_FILE(SPRITE_ID==0 ? "../../rtl/demo_sprite0.packed.mem" : "../../rtl/demo_sprite1.packed.mem"),
        .INIT_FILE(SPRITE_ID==0 ? "../rtl/demo_sprite0.packed.mif" : "../rtl/demo_sprite1.packed.mif"))
        rom(.clk(clk),.address(address),.nibble(index));
    demo_sprite_palette palette(.sprite(SPRITE_ID!=0),.index(index),.argb(argb),
        .premultiplied(premultiplied),.inverse_alpha(inverse_alpha));
endmodule
