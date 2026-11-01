`timescale 1ns/1ps

module alarm_disaster_ticker #(parameter integer SHOW_LOCATION=0)(
    input wire clk,rst,frame_tick,
    input wire enable,evacuation,drill,
    input wire [2:0] kind,
    input wire [10:0] x,y,
    input wire [23:0] rgb_in,
    output wire [23:0] rgb_out
);
    reg active,evac_q,drill_q,half_frame;
    reg [2:0] kind_q;
    reg [6:0] scroll;
    always @(posedge clk or posedge rst)
        if(rst)begin
            active<=0;evac_q<=0;drill_q<=0;kind_q<=0;half_frame<=0;scroll<=0;
        end else if(frame_tick)begin
            active<=enable;evac_q<=evacuation;drill_q<=drill;kind_q<=kind;
            if(!enable||!active||kind!=kind_q||evacuation!=evac_q||drill!=drill_q)begin
                scroll<=0;half_frame<=0;
            end else begin
                half_frame<=!half_frame;
                if(half_frame)scroll<=scroll+1'b1;
            end
        end
    wire [6:0] tx=x[6:0]+scroll;
    wire [10:0] ty=y-4;
    wire location=SHOW_LOCATION&&active&&(kind_q==1||kind_q==3)&&
        x>=248&&x<392&&y>=316&&y<332;
    wire [10:0] lx=x-248,ly=y-316;
    reg [4:0] glyph;
    always @* begin
        glyph=31;
        case(tx[6:4])
            0:glyph=kind_q==0 ? 0 : (kind_q==1||kind_q==3 ? 2 : 8);
            1:glyph=kind_q==0 ? 1 : (kind_q==1||kind_q==3 ? 3 : 9);
            2:glyph=evac_q||kind_q==3 ? 6 : (kind_q==2 ? 10 : 4);
            3:glyph=evac_q||kind_q==3 ? 7 : (kind_q==2 ? 11 : 5);
            default:glyph=31;
        endcase
        if(location)glyph=5'd12+lx[7:4];
    end
    wire ink;
    disaster_font font(.glyph(glyph),.x(location ? lx[3:0] : tx[3:0]),.y(location ? ly[3:0] : ty[3:0]),.ink(ink));
    wire band=active&&y<24;
    assign rgb_out=location ? (ink ? 24'hfff4cc : 24'hb51f29) : band ? ((y>=4&&y<20&&ink) ? 24'hfff4cc :
        (y>=22 ? 24'hffd166 : 24'hb51f29)) : rgb_in;
endmodule
