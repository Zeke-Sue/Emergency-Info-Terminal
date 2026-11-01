`timescale 1ns/1ps

module console_status_card #(parameter integer COMPACT=0)(
    input wire [10:0] x,y,input wire status_valid,input wire [95:0] status,
    input wire [23:0] rgb_in,output reg [23:0] rgb_out
);
    wire [7:0] px=x-432,py=y-8;
    wire panel=status_valid&&x>=432&&x<632&&y>=8&&y<(COMPACT ? 30 : 112)&&
        !((px<4||px>=196)&&(py<4||py>=100));
    wire [7:0] flags=status[95:88];
    wire [1:0] role=status[87:86],action=status[85:84];
    wire armed=status[75];
    reg [119:0] text_line;
    reg [7:0] letter;
    reg [34:0] glyph;
    reg [7:0] tx,ty;
    reg text_region,ink;
    reg [23:0] ink_color;
    wire [23:0] state_color=!flags[7]||flags[4] ? 24'hff8e8e :
        armed||flags[6] ? 24'hffd280 : 24'h66dfc2;
    always @* begin
        text_line="               ";tx=px-8;ty=0;text_region=0;ink_color=24'he9f1f8;
        if(py>=8&&py<22)begin
            text_line="B CONTROL      ";ty=py-8;text_region=1;
        end else if(py>=34&&py<48)begin
            case(role)
                0:text_line="ROLE LOCK LVL 0";
                1:text_line="ROLE DUTY LVL 0";
                2:text_line="ROLE CMD  LVL 0";
                3:text_line="ROLE TECH LVL 0";
            endcase
            text_line[7:0]="0"+status[83:81];ty=py-34;text_region=1;
            if(tx<60||tx>=120&&tx<168)ink_color=24'h92abc0;
        end else if(py>=56&&py<70)begin
            case(action)
                0:text_line=status[80] ? "ACT EVAC  ZON 0" : "ACT SEND  ZON 0";
                1:text_line="ACT BLOCK ZON 0";
                2:text_line="ACT OPEN  ZON 0";
                3:text_line="ACT CLEAR ZON 0";
            endcase
            text_line[7:0]="0"+status[74:72];ty=py-56;text_region=1;
            if(tx<48||tx>=120&&tx<168)ink_color=24'h92abc0;
        end else if(py>=82&&py<96)begin
            text_line=!flags[7] ? "LINK LOST      " : flags[4] ? "DENIED         " :
                armed ? "HOLD KEY4      " : flags[6] ? "WAIT ACK       " :
                flags[5] ? "CHECK COMMAND  " : "LINK READY     ";
            ty=py-82;text_region=1;ink_color=state_color;
        end
        if(COMPACT)begin
            ty=py-4;tx=px-8;text_region=py>=4&&py<18;
            case(action)
              0:text_line="ZONE 0  APPLY  ";
              1:text_line="ZONE 0  BLOCK  ";
              2:text_line="ZONE 0  OPEN   ";
              3:text_line="CLEAR FIRE     ";
            endcase
            if(action!=3)text_line[79:72]="0"+status[74:72];
            if(armed)text_line[55:0]="HOLD K4";
            else if(flags[6])text_line[55:0]="WAIT   ";
            else if(flags[4])text_line[55:0]="DENIED ";
        end

        letter=text_line>>((14-tx/12)*8);
    end
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
            "0":glyph=35'b01110_10001_10011_10101_11001_10001_01110;
            "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
            "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
            "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
            "4":glyph=35'b00010_00110_01010_10010_11111_00010_00010;
            "5":glyph=35'b11111_10000_10000_11110_00001_00001_11110;
            "6":glyph=35'b01110_10000_10000_11110_10001_10001_01110;
            "7":glyph=35'b11111_00001_00010_00100_01000_01000_01000;
            "8":glyph=35'b01110_10001_10001_01110_10001_10001_01110;
            "9":glyph=35'b01110_10001_10001_01111_00001_00001_01110;
            default:glyph=0;
        endcase
    end
    always @* begin
        rgb_out=rgb_in;ink=0;
        if(panel)begin
            rgb_out=24'h142538;
            if(px<1||px>=199||py<1||py>=103)rgb_out=24'h3a536b;
            if(py>=2&&py<28)rgb_out=24'h203b52;
            if(py==28||py==76)rgb_out=24'h31495f;
            if(px>=180&&px<188&&py>=10&&py<18)rgb_out=state_color;
            ink=text_region&&px>=8&&px<188&&(tx%12)<10&&ty<14&&
                glyph[(6-ty[3:1])*5+4-((tx%12)>>1)];
            if(ink)rgb_out=ink_color;
        end
    end
endmodule
