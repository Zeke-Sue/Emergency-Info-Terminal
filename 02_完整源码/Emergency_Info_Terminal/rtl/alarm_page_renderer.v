`timescale 1ns/1ps

module alarm_page_renderer #(
    parameter integer WIDTH=640,
    parameter integer HEIGHT=480,
    parameter integer MODERN_UI=0
)(
    input wire clk,
    input wire rst,
    input wire [10:0] x,
    input wire [10:0] y,
    input wire [23:0] rgb_in,
    input wire alarm_active,
    input wire [2:0] alarm_level,
    input wire alarm_drill,
    input wire cancel_notice,
    input wire flash_on,
    input wire countdown_trusted,
    input wire [15:0] countdown_seconds,
    input wire latency_valid,
    input wire [23:0] pixel_latency_us,
    input wire [23:0] audio_latency_us,
    output reg [23:0] rgb_out
);
    reg [23:0] level_color;
    reg [1:0] digit_index;
    reg [3:0] digit_value;
    reg [6:0] local_x;
    reg [7:0] local_y;
    reg [3:0] hundreds_digit,tens_digit,ones_digit;
    reg [6:0] segments;
    reg digit_pixel;
    reg [9:0] bcd_source,bcd_cached;
    reg [11:0] bcd_work;
    reg [3:0] bcd_count;
    reg bcd_busy;
    wire [9:0] bounded_count=countdown_seconds>999 ? 10'd999 : countdown_seconds[9:0];
    wire [3:0] bcd_hundreds=bcd_work[11:8]>=5 ? bcd_work[11:8]+3 : bcd_work[11:8];
    wire [3:0] bcd_tens=bcd_work[7:4]>=5 ? bcd_work[7:4]+3 : bcd_work[7:4];
    wire [3:0] bcd_ones=bcd_work[3:0]>=5 ? bcd_work[3:0]+3 : bcd_work[3:0];
    wire [11:0] bcd_next={bcd_hundreds[2:0],bcd_tens,bcd_ones,bcd_source[9]};
    localparam MODERN_LAYOUT=MODERN_UI&&WIDTH>=640&&HEIGHT>=480;
    wire [10:0] title_x=x-(cancel_notice ? 256 : 224),title_y=y-244;
    wire title_region=y>=244&&y<308&&
        (cancel_notice ? x>=256&&x<384 : x>=224&&x<416);
    wire drill_region=alarm_drill&&!cancel_notice&&x>=24&&x<88&&y>=24&&y<56;
    wire [10:0] drill_x=x-24,drill_y=y-24;
    wire [2:0] title_glyph=drill_region ? 3'd5+drill_x[5] :
        (cancel_notice ? 3'd3+title_x[7:6] : {1'b0,title_x[7:6]});
    wire title_ink;
    generate if(MODERN_LAYOUT)begin: modern_title
        alarm_title_font font(.glyph(title_glyph),
            .x(drill_region ? drill_x[4:0] : title_x[5:1]),
            .y(drill_region ? drill_y[4:0] : title_y[5:1]),.ink(title_ink));
    end else begin: no_title
        assign title_ink=1'b0;
    end endgenerate
    wire [10:0] icon_dx=x>=320 ? x-320 : 320-x;
    wire [10:0] icon_dy=y-72;
    wire triangle=y>=72&&y<216&&(icon_dx<<1)<=icon_dy;
    wire triangle_inner=y>=88&&y<204&&(icon_dx<<1)<=icon_dy-16;
    wire exclamation=x>=314&&x<326&&((y>=128&&y<176)||(y>=186&&y<198));
    wire check_mark=(x>=272&&x<314&&y>=150&&y<198&&
        x+150<=y+278&&y+272<=x+156)||
        (x>=308&&x<370&&y>=128&&y<202&&x+y>=498&&x+y<=510);
    function [6:0] segment_bits;
        input [3:0] digit;
        begin case(digit)
            0:segment_bits=7'b1111110;1:segment_bits=7'b0110000;
            2:segment_bits=7'b1101101;3:segment_bits=7'b1111001;
            4:segment_bits=7'b0110011;5:segment_bits=7'b1011011;
            6:segment_bits=7'b1011111;7:segment_bits=7'b1110000;
            8:segment_bits=7'b1111111;9:segment_bits=7'b1111011;
            default:segment_bits=0;endcase
        end
    endfunction
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            hundreds_digit<=0;tens_digit<=0;ones_digit<=0;
            bcd_source<=0;bcd_cached<=10'h3ff;bcd_work<=0;
            bcd_count<=0;bcd_busy<=0;
        end else if(!bcd_busy && bounded_count!=bcd_cached)begin
            bcd_cached<=bounded_count;bcd_source<=bounded_count;
            bcd_work<=0;bcd_count<=0;bcd_busy<=1;
        end else if(bcd_busy)begin
            bcd_work<=bcd_next;
            bcd_source<={bcd_source[8:0],1'b0};
            if(bcd_count==9)begin
                hundreds_digit<=bcd_next[11:8];
                tens_digit<=bcd_next[7:4];
                ones_digit<=bcd_next[3:0];
                bcd_busy<=0;
            end else bcd_count<=bcd_count+1'b1;
        end
    end
    always @* begin
        case(alarm_level)

            1:level_color=24'hdc2828;
            2:level_color=24'hf09614;
            3:level_color=24'hfae600;
            default:level_color=24'h3764ff;
        endcase
        if(cancel_notice) level_color=24'h52606d;
        digit_pixel=0;segments=0;digit_value=0;digit_index=0;local_x=0;local_y=0;
        if(MODERN_LAYOUT)begin
            if(x>=WIDTH-88&&x<WIDTH-25&&y>=28&&y<64)begin
                if(x<WIDTH-67)begin digit_index=0;local_x=(x-WIDTH+88)<<2;end
                else if(x<WIDTH-46)begin digit_index=1;local_x=(x-WIDTH+67)<<2;end
                else begin digit_index=2;local_x=(x-WIDTH+46)<<2;end
                local_y=(y-28)<<2;
            end
        end else if(x>=WIDTH/2-126 && x<WIDTH/2+126 && y>=HEIGHT/2-92 && y<HEIGHT/2+52) begin
            if(x<WIDTH/2-42) begin
                digit_index=0;local_x=x-(WIDTH/2-126);
            end else if(x<WIDTH/2+42) begin
                digit_index=1;local_x=x-(WIDTH/2-42);
            end else begin
                digit_index=2;local_x=x-(WIDTH/2+42);
            end
            local_y=y-(HEIGHT/2-92);
        end
        if((MODERN_LAYOUT&&x>=WIDTH-88&&x<WIDTH-25&&y>=28&&y<64)||
            (!MODERN_LAYOUT&&x>=WIDTH/2-126&&x<WIDTH/2+126&&y>=HEIGHT/2-92&&y<HEIGHT/2+52))begin
            case(digit_index)
                0:digit_value=hundreds_digit;
                1:digit_value=tens_digit;
                default:digit_value=ones_digit;
            endcase
            segments=segment_bits(digit_value[3:0]);
            digit_pixel=(segments[6] && local_y<12 && local_x>=12 && local_x<72) ||
                (segments[5] && local_x>=68 && local_y>=8 && local_y<70) ||
                (segments[4] && local_x>=68 && local_y>=70 && local_y<136) ||
                (segments[3] && local_y>=132 && local_x>=12 && local_x<72) ||
                (segments[2] && local_x<12 && local_y>=70 && local_y<136) ||
                (segments[1] && local_x<12 && local_y>=8 && local_y<70) ||
                (segments[0] && local_y>=64 && local_y<76 && local_x>=12 && local_x<72);
        end
        rgb_out=rgb_in;
        if(alarm_active) begin
          if(MODERN_LAYOUT)begin
            rgb_out=cancel_notice ? 24'h101d2b : 24'hdc2828;
            if(y<12)rgb_out=level_color;
            if(x>=144&&x<496&&y>=56&&y<328)rgb_out=cancel_notice ? 24'h1b2b3c : 24'hc51f2b;
            if((x<6||x>=WIDTH-6||y<6||y>=HEIGHT-6)&&flash_on)rgb_out=level_color;
            if(!cancel_notice&&((triangle&&!triangle_inner)||exclamation))rgb_out=24'hffd166;
            if(cancel_notice&&check_mark)rgb_out=24'h66dfb0;
            if((title_region||drill_region)&&title_ink)rgb_out=cancel_notice ? 24'h66dfb0 : 24'hf4f7fb;
            if(digit_pixel&&countdown_trusted&&!cancel_notice)rgb_out=24'hf4f7fb;
          end else begin
            rgb_out={level_color[23:18],2'b0,level_color[15:10],2'b0,level_color[7:2],2'b0};
            if((x<24 || x>=WIDTH-24 || y<24 || y>=HEIGHT-24) && flash_on) rgb_out=level_color;
            if(digit_pixel && countdown_trusted && !cancel_notice) rgb_out=24'hffffff;
            if(alarm_drill && ((x+y)&11'h020)!=0 && y>HEIGHT-64) rgb_out=24'hffffff;
            if(latency_valid && x>=WIDTH-190 && y>=HEIGHT-42) begin
                rgb_out=24'h101820;
                if(y>=HEIGHT-34 && y<HEIGHT-28 && x-WIDTH+184<(pixel_latency_us>>8)) rgb_out=24'h50e0ff;
                if(y>=HEIGHT-22 && y<HEIGHT-16 && x-WIDTH+184<(audio_latency_us>>8)) rgb_out=24'h80ff80;
            end
          end
        end
    end
endmodule
