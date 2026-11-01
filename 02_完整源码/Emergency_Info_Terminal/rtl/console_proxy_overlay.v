`timescale 1ns/1ps
module console_proxy_overlay #(parameter integer MODERN_UI=0)(
    input wire [10:0] x,y,input wire status_valid,input wire [95:0] status,
    input wire [23:0] rgb_in,output wire [23:0] rgb_out
);
    generate if(MODERN_UI)begin: card
        console_status_card ui(.x(x),.y(y),.status_valid(status_valid),.status(status),.rgb_in(rgb_in),.rgb_out(rgb_out));
    end else begin: legacy
        console_proxy_legacy ui(.x(x),.y(y),.status_valid(status_valid),.status(status),.rgb_in(rgb_in),.rgb_out(rgb_out));
    end endgenerate
endmodule
`timescale 1ns/1ps

module console_proxy_legacy(
    input wire [10:0] x,input wire [10:0] y,
    input wire status_valid,input wire [95:0] status,
    input wire [23:0] rgb_in,output reg [23:0] rgb_out
);
    wire [7:0] flags=status[95:88];
    wire [1:0] role=status[87:86];
    wire [1:0] action=status[85:84];
    wire [2:0] level=status[83:81];
    wire [2:0] region=status[74:72];
    wire [15:0] admitted=status[47:32];
    wire analysis_present=status[70:67]!=4'hf;
    wire panel=status_valid&&x>=11'd432&&x<11'd632&&y>=11'd8&&y<11'd104;
    wire [7:0] px=x-11'd432;
    wire [6:0] py=y-11'd8;
    reg [3:0] digit;
    reg [6:0] segments;
    reg [5:0] dx;
    reg [5:0] dy;
    reg digit_pixel,label_pixel;
    reg [23:0] accent;
    wire [7:0] cell_offset=px-8'd8;
    wire [2:0] flag_column=cell_offset[6:4];
    wire [3:0] admission_column=cell_offset[6:3];

    function [6:0] seven_segments;
        input [3:0] value;
        begin
            case(value)
                0:seven_segments=7'b1111110;1:seven_segments=7'b0110000;
                2:seven_segments=7'b1101101;3:seven_segments=7'b1111001;
                4:seven_segments=7'b0110011;5:seven_segments=7'b1011011;
                6:seven_segments=7'b1011111;7:seven_segments=7'b1110000;
                8:seven_segments=7'b1111111;9:seven_segments=7'b1111011;
                10:seven_segments=7'b1110111;11:seven_segments=7'b0011111;
                12:seven_segments=7'b1001110;13:seven_segments=7'b0111101;
                14:seven_segments=7'b1001111;default:seven_segments=7'b1000111;
            endcase
        end
    endfunction
    always @* begin
        rgb_out=rgb_in;digit=0;segments=0;dx=0;dy=0;
        digit_pixel=0;label_pixel=0;accent=24'h35d0c8;
        if(panel)begin
            rgb_out=24'h101820;
            if(px<2||px>=198||py<2||py>=94)rgb_out=24'h35d0c8;

            if(((px>=8&&px<=10)&&(py>=8&&py<=25))||
               ((px>=8&&px<=20)&&(py>=8&&py<=10))||
               ((px>=8&&px<=20)&&(py>=16&&py<=18))||
               ((px>=8&&px<=20)&&(py>=23&&py<=25))||
               ((px>=19&&px<=21)&&((py>=10&&py<=16)||(py>=18&&py<=23))))
                rgb_out=24'hffffff;

            if(px>=36&&px<196&&py>=8&&py<62)begin
                dy=py-8;
                if(px<76)begin
                    dx=px-36;digit={2'd0,role};accent=24'h35d0c8;
                    label_pixel=(dx<=2)||(dy<=2)||(dy>=8&&dy<=10)||
                        ((dx>=12&&dx<=14)&&(dy<=9))||
                        (dy>=6'd9&&dx>=dy-6'd7&&dx<=dy-6'd5);
                end else if(px<116)begin
                    dx=px-76;digit={2'd0,action};accent=24'hffcc55;
                    label_pixel=(dy<=2&&dx>=4&&dx<=10)||
                        (dx<=2&&dy>=4)||(dx>=12&&dx<=14&&dy>=4)||
                        (dy>=8&&dy<=10);
                end else if(px<156)begin
                    dx=px-116;digit={1'd0,level};accent=24'hff6b62;
                    label_pixel=(dx<=2)||(dy>=12&&dy<=14);
                end else begin
                    dx=px-156;digit={1'd0,region};accent=24'h8fd14f;
                    label_pixel=(dy<=2)||(dy>=12&&dy<=14)||
                        (dx<=2)||((dx>=12&&dx<=14)&&(dy>=7))||
                        ((dy>=7&&dy<=9)&&(dx>=7));
                end

                label_pixel=label_pixel&&dx<15&&dy<15;
                segments=seven_segments(digit);
                if(dy>=22)begin
                    dy=dy-22;
                    digit_pixel=(segments[6]&&dy<=2&&dx>=3&&dx<=11)||
                        (segments[5]&&dx>=12&&dx<=14&&dy>=3&&dy<=12)||
                        (segments[4]&&dx>=12&&dx<=14&&dy>=14&&dy<=23)||
                        (segments[3]&&dy>=24&&dy<=26&&dx>=3&&dx<=11)||
                        (segments[2]&&dx<=2&&dy>=14&&dy<=23)||
                        (segments[1]&&dx<=2&&dy>=3&&dy<=12)||
                        (segments[0]&&dy>=12&&dy<=14&&dx>=3&&dx<=11);
                end
                if(label_pixel||digit_pixel)rgb_out=accent;
            end

            if(py>=70&&py<80&&px>=8&&px<136&&
                    (analysis_present||(flag_column!=5&&flag_column!=6)))begin
                    if(flags[~flag_column])begin
                        case(flag_column)
                            0,7:rgb_out=24'h45df82;
                            1,5:rgb_out=24'hffd45e;
                            default:rgb_out=24'hff5c68;
                        endcase
                    end else rgb_out=24'h303b46;
            end

            if(analysis_present&&py>=85&&py<91&&px>=8&&px<136)
                rgb_out=admitted[~admission_column] ? 24'h45df82 : 24'h303b46;
        end
    end
endmodule
