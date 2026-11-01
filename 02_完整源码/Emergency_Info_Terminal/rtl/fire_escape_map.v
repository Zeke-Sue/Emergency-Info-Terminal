`timescale 1ns/1ps

module fire_escape_map(input wire [10:0] x,y,input wire enable,flash_on,drill,
    input wire [23:0] rgb_in,output reg [23:0] rgb_out);
    wire floor=x>=24&&x<616&&y>=140&&y<420;
    wire border=floor&&(x<28||x>=612||y<144||y>=416);
    wire room_a=x>=60&&x<272&&y>=166&&y<286;
    wire room_b=x>=60&&x<272&&y>=378&&y<400;
    wire room_c=x>=352&&x<488&&y>=262&&y<400;
    wire room_d=x>=572&&x<596&&y>=262&&y<400;
    wire route=(x>=124&&x<326&&y>=327&&y<338)||
        (x>=315&&x<326&&y>=215&&y<338)||
        (x>=315&&x<546&&y>=215&&y<226)||
        (x>=535&&x<546&&y>=172&&y<226);
    wire arrow=((x>=184&&x<196)&&(y>=320&&y<345)&&
            (y>=332 ? y-332 : 332-y)<=195-x)||
        ((x>=308&&x<333)&&(y>=270&&y<282)&&
            (x>=320 ? x-320 : 320-x)<=y-270)||
        ((x>=416&&x<428)&&(y>=208&&y<233)&&
            (y>=220 ? y-220 : 220-y)<=427-x)||
        ((x>=528&&x<553)&&(y>=188&&y<200)&&
            (x>=540 ? x-540 : 540-x)<=y-188);
    wire here=x>=112&&x<137&&y>=320&&y<345&&
        (x>=124 ? x-124 : 124-x)+(y>=332 ? y-332 : 332-y)<=12;
    wire exit_box=x>=500&&x<584&&y>=148&&y<184;
    wire warning=x>=16&&x<192&&y>=32&&y<104;
    wire exclamation=x>=38&&x<46&&((y>=48&&y<76)||(y>=82&&y<90));
    reg text;reg [10:0] tx,ty;reg [4:0] glyph;reg [23:0] ink_color;
    wire ink;
    fire_map_font font(.glyph(glyph),.x(tx[3:0]),.y(ty[3:0]),.ink(ink));
    always @* begin
        text=0;tx=0;ty=0;glyph=31;ink_color=24'hf4f7fb;

        if(x>=216&&x<376&&y>=52&&y<84)begin
            text=1;tx=(x-216)>>1;ty=(y-52)>>1;glyph=tx[6:4];
        end else if(x>=76&&x<140&&y>=48&&y<80)begin
            text=1;tx=(x-76)>>1;ty=(y-48)>>1;glyph=tx[4] ? 14 : 13;
        end else if(x>=508&&x<572&&y>=158&&y<174)begin
            text=1;tx=x-508;ty=y-158;glyph=9+tx[5:4];
        end else if(x>=80&&x<144&&y>=354&&y<370)begin
            text=1;tx=x-80;ty=y-354;glyph=5+tx[5:4];ink_color=24'h793900;
        end else if(x>=240&&x<400&&y>=434&&y<450)begin
            text=1;tx=x-240;ty=y-434;
            case(tx[7:4])
                0:glyph=2;1:glyph=3;2:glyph=4;
                5:glyph=drill ? 15 : 17;6:glyph=drill ? 16 : 18;
                default:glyph=31;
            endcase
            ink_color=24'haec4d4;
        end
        rgb_out=rgb_in;
        if(enable)begin
            rgb_out=24'h102638;
            if(floor)rgb_out=24'he4edf0;
            if(border)rgb_out=24'h5b7485;
            if(room_a||room_b||room_c||room_d)rgb_out=24'h9eb4c0;
            if(route)rgb_out=24'h087f64;
            if(arrow)rgb_out=24'h00b88b;
            if(here)rgb_out=24'hffad32;
            if(exit_box)rgb_out=24'h087f64;
            if(warning)rgb_out=flash_on ? 24'hb51f29 : 24'h74222c;
            if(exclamation)rgb_out=24'hffd166;
            if(text&&ink)rgb_out=ink_color;
        end
    end
endmodule
