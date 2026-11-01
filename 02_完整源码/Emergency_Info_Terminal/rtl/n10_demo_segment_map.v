`timescale 1ns/1ps

module n10_demo_segment_map(
    input wire [10:0] x,y,input wire [7:0] blocked_set,
    output reg [5:0] segment_id,output reg [7:0] segment_phase,
    output reg [1:0] segment_distance,
    output reg blocked_exit_pixel
);
    reg row_hit,column_hit;
    reg [1:0] row,hcolumn,vrow;
    reg [2:0] column;
    reg [10:0] xbase,ybase;
    function cross_pixel;
        input [10:0] px,py,cx,cy;
        reg [10:0] lx,ly;
        begin
            lx=px-(cx-16);ly=py-(cy-16);
            cross_pixel=lx<32&&ly<32&&
                ((lx+2>=ly&&ly+2>=lx)||(lx+ly>=29&&lx+ly<=33));
        end
    endfunction
    always @* begin
        row_hit=1;row=0;
        if(y>=78&&y<=82)row=0;
        else if(y>=178&&y<=182)row=1;
        else if(y>=278&&y<=282)row=2;
        else if(y>=378&&y<=382)row=3;
        else row_hit=0;
        column_hit=1;column=0;
        if(x>=78&&x<=82)column=0;
        else if(x>=198&&x<=202)column=1;
        else if(x>=318&&x<=322)column=2;
        else if(x>=438&&x<=442)column=3;
        else if(x>=558&&x<=562)column=4;
        else column_hit=0;
        if(x<200)begin hcolumn=0;xbase=80;end
        else if(x<320)begin hcolumn=1;xbase=200;end
        else if(x<440)begin hcolumn=2;xbase=320;end
        else begin hcolumn=3;xbase=440;end
        if(y<180)begin vrow=0;ybase=80;end
        else if(y<280)begin vrow=1;ybase=180;end
        else begin vrow=2;ybase=280;end
        segment_id=0;segment_phase=0;segment_distance=0;
        if(row_hit&&x>=80&&x<560)begin
            segment_id={row,hcolumn}+1'b1;segment_phase=x-xbase;
            case(row)
                0:segment_distance=y>=80 ? y-80 : 80-y;
                1:segment_distance=y>=180 ? y-180 : 180-y;
                2:segment_distance=y>=280 ? y-280 : 280-y;
                3:segment_distance=y>=380 ? y-380 : 380-y;
            endcase
        end else if(column_hit&&y>=80&&y<380)begin
            segment_id=17+{vrow,2'b00}+vrow+column;segment_phase=y-ybase;
            case(column)
                0:segment_distance=x>=80 ? x-80 : 80-x;
                1:segment_distance=x>=200 ? x-200 : 200-x;
                2:segment_distance=x>=320 ? x-320 : 320-x;
                3:segment_distance=x>=440 ? x-440 : 440-x;
                4:segment_distance=x>=560 ? x-560 : 560-x;
            endcase
        end else if(x>=318&&x<=322&&y>=380&&y<=440)begin
            segment_id=32;segment_phase=440-y;
            segment_distance=x>=320 ? x-320 : 320-x;
        end
        blocked_exit_pixel=(blocked_set[0]&&cross_pixel(x,y,11'd80,11'd80))||
            (blocked_set[1]&&cross_pixel(x,y,11'd560,11'd80))||
            (blocked_set[2]&&cross_pixel(x,y,11'd560,11'd380));
    end
endmodule
