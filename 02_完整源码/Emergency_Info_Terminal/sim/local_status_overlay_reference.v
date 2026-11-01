`timescale 1ns/1ps

module local_status_overlay_reference(
    input wire [10:0] x,y,
    input wire enable,fire_visible,
    input wire media_fault,
    input wire remote_evacuation_selected,
    input wire [7:0] remote_confirmation,
    input wire [15:0] status,
    input wire [15:0] quality_status,
    input wire [23:0] rgb_in,
    output reg [23:0] rgb_out
);

    reg [287:0] message;
    reg [7:0] letter;
    reg [34:0] glyph;
    reg [10:0] tx,ty;
    reg panel,ink;
    always @* begin
        case(letter)
            "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
            "B":glyph=35'b11110_10001_10001_11110_10001_10001_11110;
            "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
            "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
            "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
            "F":glyph=35'b11111_10000_10000_11110_10000_10000_10000;
            "G":glyph=35'b01111_10000_10000_10111_10001_10001_01111;
            "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
            "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
            "J":glyph=35'b00111_00010_00010_00010_10010_10010_01100;
            "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
            "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
            "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
            "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
            "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
            "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
            "Q":glyph=35'b01110_10001_10001_10001_10101_10010_01101;
            "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
            "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
            "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
            "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
            "V":glyph=35'b10001_10001_10001_10001_10001_01010_00100;
            "W":glyph=35'b10001_10001_10001_10101_10101_11011_10001;
            "X":glyph=35'b10001_10001_01010_00100_01010_10001_10001;
            "Y":glyph=35'b10001_10001_01010_00100_00100_00100_00100;
            "Z":glyph=35'b11111_00001_00010_00100_01000_10000_11111;
            default:glyph=0;
        endcase
    end
    always @* begin
        panel=0;message="                                    ";tx=0;ty=0;
        if(enable&&x>=32&&x<608)begin
            tx=x-32;
            if(fire_visible&&y>=56&&y<72)begin
                panel=1;ty=y-56;
                if(status[3])message="SIM FIRE  EVACUATION AUTHORIZED     ";
                else if(status[2])message="SIM FIRE  CONFIRMED  AWAIT COMMAND  ";
                else message="SIM FIRE  PENDING CONFIRMATION      ";
            end else if(media_fault&&y>=288&&y<304)begin
                panel=1;ty=y-288;message="MEDIA LIST MISMATCH  WAV DISABLED   ";
            end else if(quality_status[15]&&quality_status[0]&&
                    quality_status[14:11]>=12&&quality_status[14:11]<=14&&y>=320&&y<336)begin
                panel=1;ty=y-320;message="DETAIL VIEW LOADING                 ";
            end else if(quality_status[15]&&quality_status[14:11]>=11&&y>=304&&y<320)begin
                panel=1;ty=y-304;
                case(quality_status[14:11])
                    11:message=quality_status[10] ? "GRAYSCALE  ON                       " : "GRAYSCALE  OFF                      ";
                    12:message=quality_status[9:8]==2 ? "ZOOM  FOUR TIMES                    " :
                        quality_status[9:8]==1 ? "ZOOM  TWO TIMES                     " : "ZOOM  FIT                           ";
                    13:message=quality_status[7:5]==2 ? "PAN X  CENTER                       " :
                        quality_status[7:5]<2 ? "PAN X  LEFT                         " : "PAN X  RIGHT                        ";
                    14:message=quality_status[4:2]==2 ? "PAN Y  CENTER                       " :
                        quality_status[4:2]<2 ? "PAN Y  UP                           " : "PAN Y  DOWN                         ";
                    15:message=quality_status[1] ? "AUTO CONTRAST  ON                   " : "AUTO CONTRAST  OFF                  ";
                endcase
            end else if((remote_confirmation[7]||remote_confirmation[6]||remote_confirmation[0])&&y>=108&&y<124)begin
                panel=1;ty=y-108;
                if(remote_confirmation[7])message="B COMMAND  CONFIRMATION ARMED       ";
                else if(remote_confirmation[6])message="B COMMAND  CONFIRMATION EXPIRED     ";
                else message="B COMMAND  AWAITING DISPLAY ACK     ";
            end else if(remote_evacuation_selected&&y>=108&&y<124)begin
                panel=1;ty=y-108;message="B SELECTION  AUTHORIZE EVACUATION   ";
            end else if(status[4]&&y>=336&&y<416)begin
                panel=1;ty=(y-336)%16;
                case((y-336)/16)
                    0:case(status[7:6])
                        0:message="LOCAL ROLE  LOCKED                  ";
                        1:message="LOCAL ROLE  DUTY OFFICER            ";
                        2:message="LOCAL ROLE  COMMANDER               ";
                        3:message="LOCAL ROLE  MAINTAINER              ";
                    endcase
                    1:case(status[9:8])
                        0:message="SELECT ROLE                         ";
                        1:message="ACTION  CONFIRM FIRE                ";
                        2:message="ACTION  AUTHORIZE EVACUATION        ";
                        3:message="ACTION  RESET LOCAL FIRE            ";
                    endcase
                    2:message=status[0] ? "SIM CONTACT  CLOSED                 " :
                        "SIM CONTACT  OPEN                   ";
                    3:begin
                        if(status[5])message="CONFIRMATION ARMED                  ";
                        else case(status[13:10])
                            0:message="RUNNING COPY  NOT PERSISTED         ";
                            1:message="DENIED  COMMANDER REQUIRED          ";
                            2:message="DENIED  NO LOCAL FIRE               ";
                            3:message="DENIED  CONTACT CLOSED              ";
                            4:message="CONFIRMATION EXPIRED                ";
                            5:message="DENIED  FIRE NOT CONFIRMED          ";
                            default:message="OPERATION REJECTED                  ";
                        endcase
                    end
                    4:message=status[14] ? "NIGHT PRESET                        " :
                        (status[15] ? "DAY PRESET  FOLLOW NARRATION        " :
                        "DAY PRESET  TIMED OR MANUAL         ");
                endcase
            end
        end
        letter=message>>((35-tx[9:4])*8);
        ink=panel&&tx[3:0]<10&&ty<14&&glyph[(6-ty[3:1])*5+4-tx[3:1]];
        rgb_out=rgb_in;
        if(panel)rgb_out=ink ? 24'hffffff : 24'h181818;
        if(enable&&remote_confirmation[7]&&x>=32&&x<352&&y>=126&&y<132)
            rgb_out=((x-32)>>4)<remote_confirmation[5:1] ? 24'h45df82 : 24'h303b46;
    end
endmodule
