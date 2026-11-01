`timescale 1ns/1ps

module n10_demo_map_renderer(
    input wire [10:0] x,y,input wire enable,
    input wire [5:0] segment_id,input wire route_valid,
    input wire [1:0] status,input wire [2:0] selected_exit,
    input wire [23:0] rgb_in,output reg [23:0] rgb_out,output wire foreground
);
    reg [7:0] letter;
    reg [10:0] tx,ty;
    reg text_valid,exit_tile,source_tile;
    reg [2:0] tile_number;
    reg [159:0] message;
    reg [34:0] glyph;
    reg ink;
    assign foreground=enable&&(exit_tile||source_tile||ink);

    always @* begin
        case(letter)
            "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
            "B":glyph=35'b11110_10001_10001_11110_10001_10001_11110;
            "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
            "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
            "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
            "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
            "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
            "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
            "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
            "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
            "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
            "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
            "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
            "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
            "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
            "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
            "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
            "W":glyph=35'b10001_10001_10001_10101_10101_11011_10001;
            "X":glyph=35'b10001_10001_01010_00100_01010_10001_10001;
            "Y":glyph=35'b10001_10001_01010_00100_00100_00100_00100;
            "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
            "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
            "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
            default:glyph=0;
        endcase
    end
    always @* begin
        tx=0;ty=0;text_valid=0;letter=0;tile_number=0;
        exit_tile=0;source_tile=x>=312&&x<328&&y>=432&&y<448;
        if(x>=68&&x<92&&y>=68&&y<92)begin
            exit_tile=1;tile_number=1;tx=x-74;ty=y-73;
        end else if(x>=548&&x<572&&y>=68&&y<92)begin
            exit_tile=1;tile_number=2;tx=x-554;ty=y-73;
        end else if(x>=548&&x<572&&y>=368&&y<392)begin
            exit_tile=1;tile_number=3;tx=x-554;ty=y-373;
        end
        message="                    ";
        if(exit_tile)begin letter="0"+tile_number;text_valid=tx<10&&ty<14;end
        else if(y>=32&&y<46&&x>=48&&x<176)begin
            tx=x-48;ty=y-32;message="DEMO MAP            ";text_valid=1;
            letter=message>>((19-tx[8:4])*8);
        end else if(y>=32&&y<46&&x>=272&&x<592)begin
            tx=x-272;ty=y-32;text_valid=1;
            if(!route_valid||status==3)message="WAIT TABLE          ";
            else if(status==1)message="ALL EXITS BLOCKED   ";
            else if(status==2)message="NO REACHABLE EXIT   ";
            else begin
                message="EXIT                ";message[119:112]="0"+selected_exit;
            end
            letter=message>>((19-tx[8:4])*8);
        end else if(y>=434&&y<448&&x>=344&&x<536)begin
            tx=x-344;ty=y-434;message="YOU ARE HERE        ";text_valid=1;
            letter=message>>((19-tx[8:4])*8);
        end
    end
    always @* begin
        ink=text_valid&&tx[3:0]<10&&ty<14&&glyph[(6-ty[3:1])*5+4-tx[3:1]];
        rgb_out=rgb_in;
        if(enable&&x>=32&&x<608&&y>=28&&y<452)begin
            rgb_out=24'h182020;
            if(segment_id!=0)rgb_out=24'h526464;
            if(exit_tile)rgb_out=24'hd8e8e0;
            if(source_tile)rgb_out=24'h40d8ff;
            if(ink)rgb_out=exit_tile ? 24'h102020 : 24'hffffff;
        end
    end
endmodule
