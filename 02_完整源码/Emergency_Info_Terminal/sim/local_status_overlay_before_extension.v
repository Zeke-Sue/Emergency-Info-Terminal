`timescale 1ns/1ps

module local_status_overlay_before_extension #(parameter integer REGISTERED=0,MODERN_UI=0,SIMPLE_DEMO=0)(
    input wire clk,
    input wire [10:0] x,y,
    input wire enable,fire_visible,
    input wire [15:0] panel_status,
    input wire media_fault,
    input wire [1:0] waveform_status,
    input wire remote_evacuation_selected,
    input wire [7:0] remote_confirmation,
    input wire [15:0] status,
    input wire [15:0] quality_status,
    input wire [23:0] rgb_in,
    output reg [23:0] rgb_out
);

    reg [5:0] message;
    wire [7:0] letter;
    reg [34:0] glyph;
    reg [10:0] tx,ty;
    reg panel,ink;
    wire progress_panel=enable&&remote_confirmation[7]&&x>=32&&x<352&&y>=126&&y<132;
    wire progress_fill=((x-32)>>4)<remote_confirmation[5:1];
    wire render_panel,render_progress,render_fill;
    wire [10:0] render_tx,render_ty;
    wire [23:0] render_rgb;
    generate if(REGISTERED)begin: synchronous_text
        reg panel_q,progress_q,fill_q;
        reg [10:0] tx_q,ty_q;
        reg [23:0] rgb_q;
        always @(posedge clk)begin
            panel_q<=panel;progress_q<=progress_panel;fill_q<=progress_fill;
            tx_q<=tx;ty_q<=ty;rgb_q<=rgb_in;
        end
        assign render_panel=panel_q;
        assign render_progress=progress_q;
        assign render_fill=fill_q;
        assign render_tx=tx_q;
        assign render_ty=ty_q;
        assign render_rgb=rgb_q;
`ifdef __ICARUS__
        reg [7:0] memory[0:4095];
        reg [7:0] letter_q;
        initial $readmemh("../../rtl/status_text.mem",memory);
        always @(posedge clk)letter_q<=memory[{message,tx[9:4]}];
        assign letter=letter_q;
`else
        EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.DATA_WIDTH_B(8),
            .ADDR_WIDTH_A(12),.ADDR_WIDTH_B(12),.DATA_DEPTH_A(4096),.DATA_DEPTH_B(4096),
            .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
            .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
            .INIT_FILE("../rtl/status_text.mif"),.IMPLEMENT("32K")) rom(
            .dia(8'd0),.addra({message,tx[9:4]}),.cea(1'b1),.ocea(1'b1),.clka(clk),
            .wea(1'b0),.rsta(1'b0),.bea(1'b1),
            .dib(8'd0),.addrb(12'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),
            .web(1'b0),.rstb(1'b0),.beb(1'b1),.doa(letter),.dob());
`endif
    end else begin: asynchronous_text
        reg [7:0] memory[0:4095];
        initial $readmemh("../../rtl/status_text.mem",memory);
        assign letter=memory[{message,tx[9:4]}];
        assign render_panel=panel;
        assign render_progress=progress_panel;
        assign render_fill=progress_fill;
        assign render_tx=tx;
        assign render_ty=ty;
        assign render_rgb=rgb_in;
    end endgenerate
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
        panel=0;message=6'd0;tx=0;ty=0;
        if(enable&&x>=32&&x<608)begin
            tx=x-32;
            if(SIMPLE_DEMO&&panel_status[15]&&x>=112&&x<528&&y>=40&&y<56)begin
                panel=1;tx=x-112;ty=y-40;message=panel_status[13:10]==0 ? 6'd47 : 6'd45+panel_status[13:10];
            end else if(SIMPLE_DEMO&&panel_status[15]&&x<160&&y>=56&&y<72)begin
                panel=1;ty=y-56;message=6'd59+panel_status[9:7];
            end else if(SIMPLE_DEMO&&panel_status[15]&&x<416&&y>=76&&y<92)begin
                panel=1;ty=y-76;message=!panel_status[14] ? 6'd56 : panel_status[6] ? 6'd53 : 6'd52;
            end else if(SIMPLE_DEMO&&panel_status[15]&&!panel_status[14]&&y>=304&&y<336)begin
                panel=1;ty=(y-304)%16;message=y<320 ? 6'd57 : 6'd58;
            end else if(fire_visible&&y>=56&&y<72)begin
                panel=1;ty=y-56;
                if(status[3])message=6'd1;
                else if(status[2])message=6'd2;
                else message=6'd3;
            end else if(media_fault&&y>=288&&y<304)begin
                panel=1;ty=y-288;message=6'd4;
            end else if(quality_status[15]&&quality_status[0]&&
                    quality_status[14:11]>=12&&quality_status[14:11]<=14&&y>=320&&y<336)begin
                panel=1;ty=y-320;message=6'd5;
            end else if(quality_status[15]&&quality_status[14:11]>=11&&y>=304&&y<320)begin
                panel=1;ty=y-304;
                case(quality_status[14:11])
                    11:message=quality_status[10] ? 6'd6 : 6'd7;
                    12:message=quality_status[9:8]==2 ? 6'd8 :
                        quality_status[9:8]==1 ? 6'd9 : 6'd10;
                    13:message=quality_status[7:5]==2 ? 6'd11 :
                        quality_status[7:5]<2 ? 6'd12 : 6'd13;
                    14:message=quality_status[4:2]==2 ? 6'd14 :
                        quality_status[4:2]<2 ? 6'd15 : 6'd16;
                    15:message=quality_status[1] ? 6'd17 : 6'd18;
                endcase
            end else if((remote_confirmation[7]||remote_confirmation[6]||remote_confirmation[0])&&y>=108&&y<124)begin
                panel=1;ty=y-108;
                if(remote_confirmation[7])message=6'd19;
                else if(remote_confirmation[6])message=6'd20;
                else message=6'd21;
            end else if(remote_evacuation_selected&&y>=108&&y<124)begin
                panel=1;ty=y-108;message=6'd22;
            end else if(waveform_status[0]&&!status[4]&&y>=340&&y<356)begin
                panel=1;ty=y-340;message=waveform_status[1] ? (SIMPLE_DEMO ? 6'd52 : 6'd45) : 6'd44;
            end else if(status[4]&&y>=336&&y<416)begin
                panel=1;ty=(y-336)%16;
                case((y-336)/16)
                    0:case(status[7:6])
                        0:message=6'd23;
                        1:message=6'd24;
                        2:message=6'd25;
                        3:message=6'd26;
                    endcase
                    1:case(status[9:8])
                        0:message=6'd27;
                        1:message=6'd28;
                        2:message=6'd29;
                        3:message=6'd30;
                    endcase
                    2:message=status[0] ? 6'd31 :
                        6'd32;
                    3:begin
                        if(status[5])message=6'd33;
                        else case(status[13:10])
                            0:message=6'd34;
                            1:message=6'd35;
                            2:message=6'd36;
                            3:message=6'd37;
                            4:message=6'd38;
                            5:message=6'd39;
                            default:message=6'd40;
                        endcase
                    end
                    4:message=status[14] ? 6'd41 :
                        (status[15] ? 6'd42 :
                        6'd43);
                endcase
            end
        end
    end
    always @* begin
        ink=render_panel&&render_tx[3:0]<10&&render_ty<14&&
            glyph[(6-render_ty[3:1])*5+4-render_tx[3:1]];
        rgb_out=render_rgb;
        if(render_panel)begin
            rgb_out=ink ? (MODERN_UI ? 24'he9f1f8 : 24'hffffff) :
                (MODERN_UI ? 24'h203b52 : 24'h181818);
            if(MODERN_UI&&(render_ty>=14))rgb_out=24'h31495f;
        end
        if(render_progress)rgb_out=render_fill ? 24'h45df82 : 24'h303b46;
    end
endmodule
