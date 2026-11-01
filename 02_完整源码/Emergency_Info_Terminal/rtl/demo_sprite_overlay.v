`timescale 1ns/1ps

module demo_sprite_overlay #(parameter integer WIDTH=640,HEIGHT=480,HALF_ALPHA=0)(
    input wire clk,rst,frame_tick,enable,
    input wire [10:0] x,y,
    input wire [23:0] rgb_in,
    output wire [23:0] rgb_out
);
    reg [5:0] phase;
    reg enabled_frame;
    wire [4:0] bounce=phase[5] ? 5'd31-phase[4:0] : phase[4:0];
    always @(posedge clk or posedge rst)
        if(rst)begin phase<=0;enabled_frame<=0;end
        else if(frame_tick)begin phase<=phase+1'b1;enabled_frame<=enable;end
    wire [10:0] left0=WIDTH>=360 ? WIDTH-176 : 0;
    wire [10:0] top0=11'd112+{7'd0,bounce[4:1]};
    wire [10:0] left1=11'd16+{7'd0,bounce[4:1]};
    wire [10:0] top1=HEIGHT>=320 ? HEIGHT-224 : 0;
    wire inside0=enabled_frame&&WIDTH>=360&&HEIGHT>=320&&
        x>=left0&&x<left0+160&&y>=top0&&y<top0+160;
    wire inside1=enabled_frame&&WIDTH>=360&&HEIGHT>=320&&
        x>=left1&&x<left1+160&&y>=top1&&y<top1+160;
    wire [10:0] dx0=x-left0,dy0=y-top0,dx1=x-left1,dy1=y-top1;
    wire [12:0] addr0=inside0 ? dy0[7:1]*13'd80+dx0[7:1] : 13'd0;
    wire [12:0] addr1=inside1 ? dy1[7:1]*13'd80+dx1[7:1] : 13'd0;
    wire [35:0] premult0,premult1;
    wire [31:0] argb0,argb1;
    wire [4:0] inverse0,inverse1;
    reg hit0,hit1;
    always @(posedge clk or posedge rst)
        if(rst)begin hit0<=0;hit1<=0;end
        else begin hit0<=inside0;hit1<=inside1;end
    demo_sprite_rom #(.SPRITE_ID(0)) sprite0(.clk(clk),.address(addr0),.argb(argb0),
        .premultiplied(premult0),.inverse_alpha(inverse0));
    demo_sprite_rom #(.SPRITE_ID(1)) sprite1(.clk(clk),.address(addr1),.argb(argb1),
        .premultiplied(premult1),.inverse_alpha(inverse1));
    wire [35:0] foreground=hit1 ? premult1 : hit0 ? premult0 : 36'd0;
    wire [4:0] inverse_alpha=hit1 ? inverse1 : hit0 ? inverse0 : 5'd16;
    function [7:0] blend;
        input [7:0] base;
        input [11:0] front_premultiplied;
        input [4:0] inverse_weight;
        reg [12:0] sum;
        begin
            sum=base*inverse_weight+front_premultiplied+13'd8;
            blend=sum[11:4];
        end
    endfunction
    wire [31:0] color=hit1 ? argb1 : hit0 ? argb0 : 32'd0;
    function [7:0] half_blend;
        input [7:0] base,front;
        input [3:0] alpha;
        reg [8:0] sum;
        begin
            sum={1'b0,base}+{1'b0,front}+1'b1;
            half_blend=alpha<=4 ? base : alpha>=12 ? front : sum[8:1];
        end
    endfunction
    assign rgb_out=HALF_ALPHA ? {
        half_blend(rgb_in[23:16],color[23:16],color[31:28]),
        half_blend(rgb_in[15:8],color[15:8],color[31:28]),
        half_blend(rgb_in[7:0],color[7:0],color[31:28])} :
                   {blend(rgb_in[23:16],foreground[35:24],inverse_alpha),
                    blend(rgb_in[15:8],foreground[23:12],inverse_alpha),
                    blend(rgb_in[7:0],foreground[11:0],inverse_alpha)};
endmodule
