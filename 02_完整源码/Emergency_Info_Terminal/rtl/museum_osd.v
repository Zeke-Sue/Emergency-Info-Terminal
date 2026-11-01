`timescale 1ns/1ps

module museum_osd(
    input wire [10:0] x,y,
    input wire [23:0] rgb_in,
    input wire [3:0] page,error_code,
    input wire [2:0] selection,brightness,contrast,saturation,
    input wire [1:0] exhibit_index,period_select,
    input wire playing,zoom,mono,narration_ready,
    input wire [7:0] progress,
    input wire [7:0] subtitle_id,
    output wire [23:0] rgb_out
);

    function [15:0] label_char; input [7:0] label_id; input [5:0] column; begin
        label_char=16'h0020; case(label_id)
        0: case(column)
            0:label_char=16'h6570;
            1:label_char=16'h5B57;
            2:label_char=16'h6587;
            3:label_char=16'h535A;
            4:label_char=16'h5C55;
            5:label_char=16'h793A;
        endcase
        1: case(column)
            0:label_char=16'h6B63;
            1:label_char=16'h5728;
            2:label_char=16'h542F;
            3:label_char=16'h52A8;
        endcase
        2: case(column)
            0:label_char=16'h6B63;
            1:label_char=16'h5728;
            2:label_char=16'h52A0;
            3:label_char=16'h8F7D;
            4:label_char=16'h8D44;
            5:label_char=16'h6E90;
        endcase
        3: case(column)
            0:label_char=16'h6587;
            1:label_char=16'h535A;
            2:label_char=16'h4E3B;
            3:label_char=16'h83DC;
            4:label_char=16'h5355;
        endcase
        4: case(column)
            0:label_char=16'h81EA;
            1:label_char=16'h52A8;
            2:label_char=16'h5BFC;
            3:label_char=16'h89C8;
        endcase
        5: case(column)
            0:label_char=16'h5C55;
            1:label_char=16'h54C1;
            2:label_char=16'h6D4F;
            3:label_char=16'h89C8;
        endcase
        6: case(column)
            0:label_char=16'h7EC6;
            1:label_char=16'h8282;
            2:label_char=16'h89C2;
            3:label_char=16'h5BDF;
        endcase
        7: case(column)
            0:label_char=16'h56FE;
            1:label_char=16'h50CF;
            2:label_char=16'h589E;
            3:label_char=16'h5F3A;
        endcase
        8: case(column)
            0:label_char=16'h7CFB;
            1:label_char=16'h7EDF;
            2:label_char=16'h8BBE;
            3:label_char=16'h7F6E;
        endcase
        9: case(column)
            0:label_char=16'h8D44;
            1:label_char=16'h6E90;
            2:label_char=16'h8BFB;
            3:label_char=16'h53D6;
            4:label_char=16'h9519;
            5:label_char=16'h8BEF;
        endcase
        10: case(column)
            0:label_char=16'h81EA;
            1:label_char=16'h52A8;
            2:label_char=16'h5BFC;
            3:label_char=16'h89C8;
        endcase
        11: case(column)
            0:label_char=16'h5C55;
            1:label_char=16'h54C1;
            2:label_char=16'h6D4F;
            3:label_char=16'h89C8;
        endcase
        12: case(column)
            0:label_char=16'h7EC6;
            1:label_char=16'h8282;
            2:label_char=16'h89C2;
            3:label_char=16'h5BDF;
        endcase
        13: case(column)
            0:label_char=16'h56FE;
            1:label_char=16'h50CF;
            2:label_char=16'h589E;
            3:label_char=16'h5F3A;
        endcase
        14: case(column)
            0:label_char=16'h7CFB;
            1:label_char=16'h7EDF;
            2:label_char=16'h8BBE;
            3:label_char=16'h7F6E;
        endcase
        15: case(column)
            0:label_char=16'h4EAE;
            1:label_char=16'h5EA6;
        endcase
        16: case(column)
            0:label_char=16'h5BF9;
            1:label_char=16'h6BD4;
            2:label_char=16'h5EA6;
        endcase
        17: case(column)
            0:label_char=16'h9971;
            1:label_char=16'h548C;
            2:label_char=16'h5EA6;
        endcase
        18: case(column)
            0:label_char=16'h9ED1;
            1:label_char=16'h767D;
            2:label_char=16'h6EE4;
            3:label_char=16'h955C;
        endcase
        19: case(column)
            0:label_char=16'h8F6E;
            1:label_char=16'h64AD;
            2:label_char=16'h95F4;
            3:label_char=16'h9694;
        endcase
        20: case(column)
            0:label_char=16'h91CD;
            1:label_char=16'h65B0;
            2:label_char=16'h8BFB;
            3:label_char=16'h53D6;
            4:label_char=16'h5B58;
            5:label_char=16'h50A8;
            6:label_char=16'h5361;
        endcase
        21: case(column)
            0:label_char=16'h793A;
            1:label_char=16'h4F8B;
            2:label_char=16'h5C55;
            3:label_char=16'h54C1;
            4:label_char=16'h4E00;
        endcase
        22: case(column)
            0:label_char=16'h793A;
            1:label_char=16'h4F8B;
            2:label_char=16'h5C55;
            3:label_char=16'h54C1;
            4:label_char=16'h4E8C;
        endcase
        23: case(column)
            0:label_char=16'h793A;
            1:label_char=16'h4F8B;
            2:label_char=16'h5C55;
            3:label_char=16'h54C1;
            4:label_char=16'h4E09;
        endcase
        24: case(column)
            0:label_char=16'h793A;
            1:label_char=16'h4F8B;
            2:label_char=16'h5C55;
            3:label_char=16'h54C1;
            4:label_char=16'h56DB;
        endcase
        25: case(column)
            0:label_char=16'h5E74;
            1:label_char=16'h4EE3;
            2:label_char=16'hFF1A;
            3:label_char=16'h5F85;
            4:label_char=16'h914D;
            5:label_char=16'h7F6E;
        endcase
        26: case(column)
            0:label_char=16'h5730;
            1:label_char=16'h70B9;
            2:label_char=16'hFF1A;
            3:label_char=16'h5F85;
            4:label_char=16'h914D;
            5:label_char=16'h7F6E;
        endcase
        27: case(column)
            0:label_char=16'h64AD;
            1:label_char=16'h653E;
            2:label_char=16'h4E2D;
        endcase
        28: case(column)
            0:label_char=16'h5DF2;
            1:label_char=16'h6682;
            2:label_char=16'h505C;
        endcase
        29: case(column)
            0:label_char=16'h8BB2;
            1:label_char=16'h89E3;
            2:label_char=16'h5F85;
            3:label_char=16'h63A5;
            4:label_char=16'h5165;
        endcase
        30: case(column)
            0:label_char=16'h6682;
            1:label_char=16'h65E0;
            2:label_char=16'h540C;
            3:label_char=16'h6B65;
            4:label_char=16'h5B57;
            5:label_char=16'h5E55;
        endcase
        31: case(column)
            0:label_char=16'h5B57;
            1:label_char=16'h5E55;
            2:label_char=16'h63A5;
            3:label_char=16'h53E3;
            4:label_char=16'h6D4B;
            5:label_char=16'h8BD5;
            6:label_char=16'h4E00;
        endcase
        32: case(column)
            0:label_char=16'h5B57;
            1:label_char=16'h5E55;
            2:label_char=16'h63A5;
            3:label_char=16'h53E3;
            4:label_char=16'h6D4B;
            5:label_char=16'h8BD5;
            6:label_char=16'h4E8C;
        endcase
        33: case(column)
            0:label_char=16'h5B57;
            1:label_char=16'h5E55;
            2:label_char=16'h63A5;
            3:label_char=16'h53E3;
            4:label_char=16'h6D4B;
            5:label_char=16'h8BD5;
            6:label_char=16'h4E09;
        endcase
        34: case(column)
            0:label_char=16'h4E0A;
            1:label_char=16'h4E00;
            2:label_char=16'h9879;
            3:label_char=16'h0020;
            4:label_char=16'h0020;
            5:label_char=16'h4E0B;
            6:label_char=16'h4E00;
            7:label_char=16'h9879;
            8:label_char=16'h0020;
            9:label_char=16'h0020;
            10:label_char=16'h786E;
            11:label_char=16'h5B9A;
            12:label_char=16'h0020;
            13:label_char=16'h0020;
            14:label_char=16'h8FD4;
            15:label_char=16'h56DE;
        endcase
        35: case(column)
            0:label_char=16'h957F;
            1:label_char=16'h6309;
            2:label_char=16'h8FD4;
            3:label_char=16'h56DE;
            4:label_char=16'h952E;
            5:label_char=16'h56DE;
            6:label_char=16'h4E3B;
            7:label_char=16'h83DC;
            8:label_char=16'h5355;
        endcase
        36: case(column)
            0:label_char=16'h500D;
            1:label_char=16'h7387;
        endcase
        37: case(column)
            0:label_char=16'h79D2;
        endcase
        38: case(column)
            0:label_char=16'h5173;
            1:label_char=16'h95ED;
        endcase
        39: case(column)
            0:label_char=16'h5F00;
            1:label_char=16'h542F;
        endcase
        40: case(column)
            0:label_char=16'h6309;
            1:label_char=16'h786E;
            2:label_char=16'h5B9A;
            3:label_char=16'h952E;
            4:label_char=16'h91CD;
            5:label_char=16'h65B0;
            6:label_char=16'h52A0;
            7:label_char=16'h8F7D;
        endcase
        41: case(column)
            0:label_char=16'h9519;
            1:label_char=16'h8BEF;
            2:label_char=16'h7801;
            3:label_char=16'hFF1A;
        endcase
        42: case(column)
            0:label_char=16'h56FE;
            1:label_char=16'h7247;
            2:label_char=16'h8F6E;
            3:label_char=16'h64AD;
        endcase
        43: case(column)
            0:label_char=16'h53C2;
            1:label_char=16'h6570;
            2:label_char=16'h51CF;
            3:label_char=16'h0020;
            4:label_char=16'h0020;
            5:label_char=16'h53C2;
            6:label_char=16'h6570;
            7:label_char=16'h52A0;
            8:label_char=16'h0020;
            9:label_char=16'h0020;
            10:label_char=16'h5207;
            11:label_char=16'h6362;
            12:label_char=16'h53C2;
            13:label_char=16'h6570;
            14:label_char=16'h0020;
            15:label_char=16'h0020;
            16:label_char=16'h8FD4;
            17:label_char=16'h56DE;
        endcase
        44: case(column)
            0:label_char=16'h7F29;
            1:label_char=16'h5C0F;
            2:label_char=16'h0020;
            3:label_char=16'h0020;
            4:label_char=16'h653E;
            5:label_char=16'h5927;
            6:label_char=16'h0020;
            7:label_char=16'h0020;
            8:label_char=16'h5207;
            9:label_char=16'h6362;
            10:label_char=16'h500D;
            11:label_char=16'h7387;
            12:label_char=16'h0020;
            13:label_char=16'h0020;
            14:label_char=16'h8FD4;
            15:label_char=16'h56DE;
        endcase
        45: case(column)
            0:label_char=16'h4E0A;
            1:label_char=16'h4E00;
            2:label_char=16'h4EF6;
            3:label_char=16'h0020;
            4:label_char=16'h0020;
            5:label_char=16'h4E0B;
            6:label_char=16'h4E00;
            7:label_char=16'h4EF6;
            8:label_char=16'h0020;
            9:label_char=16'h0020;
            10:label_char=16'h64AD;
            11:label_char=16'h653E;
            12:label_char=16'h6682;
            13:label_char=16'h505C;
            14:label_char=16'h0020;
            15:label_char=16'h0020;
            16:label_char=16'h8FD4;
            17:label_char=16'h56DE;
        endcase
        46: case(column)
            0:label_char=16'h4E0A;
            1:label_char=16'h4E00;
            2:label_char=16'h4EF6;
            3:label_char=16'h0020;
            4:label_char=16'h0020;
            5:label_char=16'h4E0B;
            6:label_char=16'h4E00;
            7:label_char=16'h4EF6;
            8:label_char=16'h0020;
            9:label_char=16'h0020;
            10:label_char=16'h89C2;
            11:label_char=16'h5BDF;
            12:label_char=16'h7EC6;
            13:label_char=16'h8282;
            14:label_char=16'h0020;
            15:label_char=16'h0020;
            16:label_char=16'h8FD4;
            17:label_char=16'h56DE;
        endcase
        47: case(column)
            0:label_char=16'h9009;
            1:label_char=16'h62E9;
            2:label_char=16'h9879;
            3:label_char=16'h76EE;
            4:label_char=16'h0020;
            5:label_char=16'h0020;
            6:label_char=16'h786E;
            7:label_char=16'h5B9A;
            8:label_char=16'h4FEE;
            9:label_char=16'h6539;
            10:label_char=16'h0020;
            11:label_char=16'h0020;
            12:label_char=16'h8FD4;
            13:label_char=16'h56DE;
        endcase
        48: case(column)
            0:label_char=16'h5730;
            1:label_char=16'h9707;
            2:label_char=16'h9884;
            3:label_char=16'h8B66;
            4:label_char=16'h662F;
            5:label_char=16'h4EC0;
            6:label_char=16'h4E48;
        endcase
        49: case(column)
            0:label_char=16'h56DB;
            1:label_char=16'h8272;
            2:label_char=16'h9884;
            3:label_char=16'h8B66;
            4:label_char=16'h600E;
            5:label_char=16'h4E48;
            6:label_char=16'h8BA4;
        endcase
        50: case(column)
            0:label_char=16'h542C;
            1:label_char=16'h5230;
            2:label_char=16'h8B66;
            3:label_char=16'h62A5;
            4:label_char=16'h5C31;
            5:label_char=16'h5730;
            6:label_char=16'h907F;
            7:label_char=16'h9669;
        endcase
        51: case(column)
            0:label_char=16'h8DEF;
            1:label_char=16'h7EBF;
            2:label_char=16'h968F;
            3:label_char=16'h706B;
            4:label_char=16'h60C5;
            5:label_char=16'h53D8;
            6:label_char=16'h5316;
        endcase
        52: case(column)
            0:label_char=16'h6309;
            1:label_char=16'h73B0;
            2:label_char=16'h573A;
            3:label_char=16'h6307;
            4:label_char=16'h793A;
            5:label_char=16'h64A4;
            6:label_char=16'h79BB;
        endcase
        endcase end endfunction

    reg [15:0] character;
    reg [3:0] glyph_x,glyph_y;
    reg [7:0] label_id;
    reg [5:0] column;
    reg text_enable;
    reg [23:0] foreground,background;
    reg [2:0] row_index;
    reg [10:0] row_top;
    wire [15:0] glyph_pixels;
    wire [7:0] bounded_progress=progress>100 ? 8'd100 : progress;
    wire [16:0] bar_product=bounded_progress*512;
    wire [9:0] bar_width=bar_product/100;
    chinese_font_rom font(.codepoint(character),.row(glyph_y),.pixels(glyph_pixels));
    always @* begin
        background=rgb_in;foreground=24'hF4E8CE;
        character=16'h0020;glyph_x=0;glyph_y=0;label_id=0;column=0;text_enable=0;row_index=0;row_top=88;

        if(y>=248) begin row_index=4;row_top=248;end
        else if(y>=208) begin row_index=3;row_top=208;end
        else if(y>=168) begin row_index=2;row_top=168;end
        else if(y>=128) begin row_index=1;row_top=128;end
        if(x<640 && y<480) begin
            if(y<72) background=24'h162D38;
            if(y>=76 && y<312 && x>=24 && x<616 &&
                (page==0 || page==1 || page==2 || page==6 || page==7 || page==8)) background=24'h15232B;
            if(y>=320 && y<384) background=24'h162D38;
            if(y>=400 && y<448 && x>=24 && x<616) begin
                background=24'h182C36;
                if(x==24 || x==615 || y==400 || y==447) background=24'hB69B63;
            end
            if(y>=464 && y<472 && x>=64 && x<576) begin
                background=24'h394953;
                if(narration_ready && x<64+bar_width) background=24'hD9B969;
            end

            if(x>=24 && x<376 && y>=16 && y<48) begin
                label_id=page<=8 ? page+1'b1 : 8'd3;
                column=(x-24)>>5;glyph_x=(x-24)>>1;glyph_y=(y-16)>>1;text_enable=1;
            end else if(x>=400 && x<624 && y>=24 && y<40) begin
                label_id=(page==3) ? (playing ? 27 : 28) : 0;
                column=(x-400)>>4;glyph_x=x-400;glyph_y=y-24;text_enable=1;
            end else if(page==2 && x>=40 && x<600 && y>=88 && y<288) begin

                if(row_index==selection) background=24'h745A2D;
                if(y>=row_top+12 && y<row_top+28) begin
                    label_id=10+row_index;column=(x-40)>>4;
                    glyph_x=x-40;glyph_y=y-row_top-12;text_enable=1;
                end
            end else if(page==6 && x>=40 && x<600 && y>=88 && y<248) begin

                if(row_index==selection) background=24'h745A2D;
                if(y>=row_top+12 && y<row_top+28) begin
                    label_id=15+row_index;column=(x-40)>>4;
                    glyph_x=x-40;glyph_y=y-row_top-12;text_enable=1;
                end
            end else if(page==7 && x>=40 && x<600 && y>=88 && y<168) begin

                if(row_index==selection) background=24'h745A2D;
                if(y>=row_top+12 && y<row_top+28) begin
                    label_id=19+row_index;column=(x-40)>>4;
                    glyph_x=x-40;glyph_y=y-row_top-12;text_enable=1;
                end
            end else if(page==5 && x>=40 && x<200 && y>=100 && y<116) begin
                label_id=36;column=(x-40)>>4;glyph_x=x-40;glyph_y=y-100;text_enable=1;
            end else if(page==8 && x>=40 && x<600 && y>=100 && y<116) begin
                label_id=41;column=(x-40)>>4;glyph_x=x-40;glyph_y=y-100;text_enable=1;
            end else if(page==8 && x>=40 && x<600 && y>=140 && y<156) begin
                label_id=40;column=(x-40)>>4;glyph_x=x-40;glyph_y=y-140;text_enable=1;
            end else if(x>=24 && x<400 && y>=328 && y<344) begin
                label_id=21+exhibit_index;column=(x-24)>>4;glyph_x=x-24;glyph_y=y-328;text_enable=1;
            end else if(x>=24 && x<288 && y>=352 && y<368) begin
                label_id=25;column=(x-24)>>4;glyph_x=x-24;glyph_y=y-352;text_enable=1;
            end else if(x>=304 && x<624 && y>=352 && y<368) begin
                label_id=26;column=(x-304)>>4;glyph_x=x-304;glyph_y=y-352;text_enable=1;
            end else if(x>=400 && x<624 && y>=328 && y<344) begin
                label_id=narration_ready ? 42 : 29;
                column=(x-400)>>4;glyph_x=x-400;glyph_y=y-328;text_enable=1;
            end else if(x>=40 && x<600 && y>=408 && y<424) begin
                label_id=(!narration_ready || subtitle_id==0 || subtitle_id>3) ? 30 : 30+subtitle_id;
                column=(x-40)>>4;glyph_x=x-40;glyph_y=y-408;text_enable=1;
            end else if(x>=40 && x<600 && y>=428 && y<444) begin
                case(page)
                    3:label_id=45;
                    4:label_id=46;
                    5:label_id=44;
                    6:label_id=43;
                    7:label_id=47;
                    default:label_id=34;
                endcase
                column=(x-40)>>4;glyph_x=x-40;glyph_y=y-428;text_enable=1;
            end
        end
        character=label_char(label_id,column);

        if(text_enable && page==6 && y>=100 && y<248 && column==16) begin
            case(row_index)
                0:character=16'h0030+brightness;
                1:character=16'h0030+contrast;
                2:character=16'h0030+saturation;
                3:character=16'h0030+mono;
            endcase
        end
        if(text_enable && page==5 && y>=100 && y<116 && column==4)
            character=zoom ? 16'h0032 : 16'h0031;
        if(text_enable && page==7 && y>=100 && y<116 && column==16)
            character=period_select==3 ? 16'h0031 : period_select==2 ? 16'h0035 : period_select==1 ? 16'h0032 : 16'h0031;
        if(text_enable && page==7 && y>=100 && y<116 && column==17)
            character=period_select==3 ? 16'h0030 : 16'h0020;
        if(text_enable && page==8 && y>=100 && y<116 && column==5)
            character=error_code<10 ? 16'h0030+error_code : 16'h0041+error_code-10;
    end
    assign rgb_out=text_enable && glyph_pixels[15-glyph_x] ? foreground : background;
endmodule

