`timescale 1ns/1ps

module console_dashboard_renderer(
    input wire [10:0] x,input wire [10:0] y,
    input wire link_alive,input wire ack_pending,input wire error_latched,
    input wire permission_denied,input wire remote_alarm,
    input wire [1:0] role,input wire [1:0] action,
    input wire [2:0] selected_level,input wire [2:0] selected_region,
    input wire [2:0] remote_level,input wire [3:0] remote_active_count,
    input wire [7:0] remote_blocked_set,input wire [23:0] pixel_latency_us,
    input wire [15:0] telemetry_max_line,
    input wire [15:0] telemetry_video_underflows,
    input wire [15:0] telemetry_uart_errors,
    input wire [15:0] log_records,input wire [15:0] log_dropped,
    input wire [7:0] log_digest,
    input wire admission_busy,input wire [4:0] admission_completed,
    input wire [4:0] admission_total,input wire [15:0] admission_pass_bitmap,
    input wire [3:0] admission_error,input wire [3:0] admission_reason,
    output reg [23:0] rgb
);
    reg [7:0] character;
    reg [34:0] glyph;
    reg [127:0] text;
    reg [4:0] glyph_row;
    reg [5:0] column;
    reg [2:0] glyph_x,glyph_y;
    reg text_enable;
    reg [23:0] foreground;
    reg [3:0] digit;
    reg [2:0] alarm_level_safe;

    function [7:0] hex_char;
        input [3:0] value;
        begin hex_char=value<10 ? 8'h30+value : 8'h41+value-10; end
    endfunction
    function [127:0] label_text;
        input [4:0] id;
        begin case(id)
            0:label_text="DUTY CONSOLE    ";
            1:label_text="ONLINE          ";
            2:label_text="OFFLINE         ";
            3:label_text="ALARM ACTIVE    ";
            4:label_text="SYSTEM STANDBY  ";
            5:label_text="LEVEL           ";
            6:label_text="REGION          ";
            7:label_text="ROLE            ";
            8:label_text="ACTION          ";
            9:label_text="EVENTS          ";
            10:label_text="BLOCKED         ";
            11:label_text="PIXEL LATENCY US";
            12:label_text="MAX LINE CYCLES ";
            13:label_text="VIDEO UNDERFLOW ";
            14:label_text="UART ERRORS     ";
            15:label_text="ACK PENDING     ";
            16:label_text="READY           ";
            17:label_text="PERMISSION DENY ";
            18:label_text="LOG REC/DROP/CRC";
            19:label_text="WAV DONE/TOTAL  ";
            default:label_text="                ";
        endcase end
    endfunction
    function [34:0] font5x7;
        input [7:0] c;
        begin case(c)
            "0":font5x7={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
            "1":font5x7={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            "2":font5x7={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
            "3":font5x7={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
            "4":font5x7={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
            "5":font5x7={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
            "6":font5x7={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
            "7":font5x7={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
            "8":font5x7={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
            "9":font5x7={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
            "A":font5x7={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            "B":font5x7={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
            "C":font5x7={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
            "D":font5x7={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
            "E":font5x7={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
            "F":font5x7={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
            "G":font5x7={5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01111};
            "H":font5x7={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            "I":font5x7={5'b01110,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            "J":font5x7={5'b00001,5'b00001,5'b00001,5'b00001,5'b10001,5'b10001,5'b01110};
            "K":font5x7={5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
            "L":font5x7={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
            "M":font5x7={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
            "N":font5x7={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
            "O":font5x7={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            "P":font5x7={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
            "Q":font5x7={5'b01110,5'b10001,5'b10001,5'b10001,5'b10101,5'b10010,5'b01101};
            "R":font5x7={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
            "S":font5x7={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
            "T":font5x7={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
            "U":font5x7={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            "V":font5x7={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
            "W":font5x7={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
            "X":font5x7={5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
            "Y":font5x7={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
            "Z":font5x7={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b10000,5'b11111};
            default:font5x7=0;
        endcase end
    endfunction

    task select_label;
        input [4:0] id;input [10:0] left;input [10:0] top;
        begin
            column=(x-left)>>3;glyph_x=x-left-(column<<3);glyph_y=y-top;
            text=label_text(id);character=text>>((15-column)*8);
            text_enable=column<16&&glyph_x<5&&glyph_y<7;
        end
    endtask
    task select_hex;
        input [31:0] value;input [3:0] digits;input [10:0] left;input [10:0] top;
        begin
            column=(x-left)>>3;glyph_x=x-left-(column<<3);glyph_y=y-top;
            digit=(value>>((digits-1-column)*4));character=hex_char(digit);
            text_enable=column<digits&&glyph_x<5&&glyph_y<7;
        end
    endtask

    always @* begin
        alarm_level_safe=remote_level==0 ? selected_level : remote_level;
        rgb=24'h0b1117;foreground=24'hd8e2ea;text_enable=0;
        character=8'h20;glyph=0;glyph_row=0;text=0;column=0;
        glyph_x=0;glyph_y=0;digit=0;
        if(y<72)rgb=24'h15212b;
        if(y==71)rgb=24'h2c3d49;
        if(x>=24&&x<308&&y>=92&&y<270)rgb=24'h131c24;
        if(x>=324&&x<616&&y>=92&&y<270)rgb=24'h131c24;
        if(x>=24&&x<616&&y>=286&&y<452)rgb=24'h131c24;
        if(x>=344&&x<600&&y>=290&&y<302)rgb=24'h24333d;
        if(x>=344&&x<344+({6'd0,admission_completed}<<4)&&y>=290&&y<302)
            rgb=admission_error!=0 ? 24'he65a61 :
                (admission_busy ? 24'h72b7ff : 24'h55d6a6);
        if(error_latched&&y>=68&&y<72)rgb=24'he5484d;
        if(x>=498&&x<616&&y>=20&&y<52)
            rgb=link_alive ? 24'h137a56 : 24'h9c3440;
        if(x>=40&&x<292&&y>=112&&y<156)
            rgb=remote_alarm ?
                (alarm_level_safe==1 ? 24'hb6202b : alarm_level_safe==2 ?
                 24'hc95c18 : alarm_level_safe==3 ? 24'hb99a15 : 24'h16689a) :
                24'h1c3948;
        if(x>=340&&x<600&&y>=112&&y<156)
            rgb=permission_denied ? 24'h8d323d :
                (ack_pending ? 24'h8d6c21 : 24'h215845);

        if(x>=32&&x<224&&y>=30&&y<37)select_label(0,32,30);
        else if(x>=510&&x<606&&y>=32&&y<39)begin
            foreground=24'hffffff;select_label(link_alive ? 1 : 2,510,32);
        end else if(x>=54&&x<182&&y>=130&&y<137)begin
            foreground=24'hffffff;select_label(remote_alarm ? 3 : 4,54,130);
        end else if(x>=342&&x<590&&y>=130&&y<137)begin
            foreground=24'hffffff;
            select_label(permission_denied ? 17 : (ack_pending ? 15 : 16),342,130);
        end else if(x>=44&&x<116&&y>=184&&y<191)select_label(5,44,184);
        else if(x>=156&&x<164&&y>=184&&y<191)begin
            foreground=24'h55d6a6;select_hex({29'd0,selected_level},1,156,184);
        end else if(x>=44&&x<116&&y>=216&&y<223)select_label(6,44,216);
        else if(x>=156&&x<164&&y>=216&&y<223)begin
            foreground=24'h55d6a6;select_hex({29'd0,selected_region},1,156,216);
        end else if(x>=344&&x<416&&y>=184&&y<191)select_label(7,344,184);
        else if(x>=456&&x<464&&y>=184&&y<191)begin
            foreground=24'h55d6a6;select_hex({30'd0,role},1,456,184);
        end else if(x>=344&&x<416&&y>=216&&y<223)select_label(8,344,216);
        else if(x>=456&&x<464&&y>=216&&y<223)begin
            foreground=24'h55d6a6;select_hex({30'd0,action},1,456,216);
        end else if(x>=44&&x<116&&y>=246&&y<253)select_label(9,44,246);
        else if(x>=156&&x<164&&y>=246&&y<253)begin
            foreground=24'h72b7ff;select_hex({28'd0,remote_active_count},1,156,246);
        end else if(x>=344&&x<416&&y>=246&&y<253)select_label(10,344,246);
        else if(x>=456&&x<472&&y>=246&&y<253)begin
            foreground=24'hffb861;select_hex({24'd0,remote_blocked_set},2,456,246);
        end else if(x>=44&&x<172&&y>=294&&y<301)select_label(19,44,294);
        else if(x>=184&&x<192&&y>=294&&y<301)begin
            foreground=admission_error==0 ? 24'h55d6a6 : 24'he65a61;
            select_hex({27'd0,admission_completed},1,184,294);
        end else if(x>=200&&x<208&&y>=294&&y<301)begin
            foreground=24'hd8e2ea;select_hex({27'd0,admission_total},1,200,294);
        end else if(x>=232&&x<264&&y>=294&&y<301)begin
            foreground=admission_reason==0 ? 24'h55d6a6 : 24'hffb861;
            select_hex({16'd0,admission_pass_bitmap},4,232,294);
        end else if(x>=44&&x<172&&y>=314&&y<321)select_label(11,44,314);
        else if(x>=464&&x<512&&y>=314&&y<321)begin
            foreground=24'h72b7ff;select_hex({8'd0,pixel_latency_us},6,464,314);
        end else if(x>=44&&x<172&&y>=346&&y<353)select_label(12,44,346);
        else if(x>=480&&x<512&&y>=346&&y<353)begin
            foreground=24'h72b7ff;select_hex({16'd0,telemetry_max_line},4,480,346);
        end else if(x>=44&&x<172&&y>=378&&y<385)select_label(13,44,378);
        else if(x>=480&&x<512&&y>=378&&y<385)begin
            foreground=telemetry_video_underflows==0 ? 24'h55d6a6 : 24'he65a61;
            select_hex({16'd0,telemetry_video_underflows},4,480,378);
        end else if(x>=44&&x<172&&y>=410&&y<417)select_label(14,44,410);
        else if(x>=480&&x<512&&y>=410&&y<417)begin
            foreground=telemetry_uart_errors==0 ? 24'h55d6a6 : 24'he65a61;
            select_hex({16'd0,telemetry_uart_errors},4,480,410);
        end
        else if(x>=44&&x<172&&y>=434&&y<441)select_label(18,44,434);
        else if(x>=456&&x<488&&y>=434&&y<441)begin
            foreground=24'h72b7ff;select_hex({16'd0,log_records},4,456,434);
        end else if(x>=504&&x<520&&y>=434&&y<441)begin
            foreground=log_dropped==0 ? 24'h55d6a6 : 24'he65a61;
            select_hex({16'd0,log_dropped},2,504,434);
        end else if(x>=536&&x<552&&y>=434&&y<441)begin
            foreground=24'hffb861;select_hex({24'd0,log_digest},2,536,434);
        end
        glyph=font5x7(character);
        glyph_row=glyph>>(30-glyph_y*5);
        if(text_enable&&glyph_row[4-glyph_x])rgb=foreground;
    end
endmodule
