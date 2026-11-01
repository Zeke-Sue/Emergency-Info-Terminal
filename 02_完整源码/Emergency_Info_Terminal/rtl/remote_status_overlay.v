`timescale 1ns/1ps

module remote_status_overlay #(parameter integer EXTENSIONS=0,CLEAN_PRESENTATION=0)(input wire clk,input wire rst,
 input wire link_ready,health_enable,health_fresh,input wire [47:0] health,
 input wire [10:0] x,y,
 input wire enable,input wire [7:0] remote_confirmation,input wire [103:0] remote_rows,
 input wire [23:0] rgb_in,output reg [23:0] rgb_out);
 reg seen_link;
 always @(posedge clk or posedge rst)if(rst)seen_link<=0;else if(link_ready)seen_link<=1;
 reg [10:0] tx,ty;reg panel;reg [5:0] message;reg link_line,health_line;
        reg [3:0] row;reg hit;reg [7:0] descriptor;
        always @* begin
            row=0;hit=1;ty=0;tx=x-32;link_line=0;health_line=0;
            if(y>=40&&y<56)begin row=0;ty=y-40;tx=x-112;end
            else if(y>=56&&y<72)begin row=1;ty=y-56;end
            else if(y>=76&&y<92)begin row=2;ty=y-76;end
            else if(y>=108&&y<124)begin row=3;ty=y-108;end
            else if(y>=288&&y<304)begin row=4;ty=y-288;end
            else if(y>=304&&y<320)begin row=5;ty=y-304;end
            else if(y>=320&&y<336)begin row=6;ty=y-320;end
            else if(y>=340&&y<356&&remote_rows[103])begin row=12;ty=y-340;end
            else if(y>=336&&y<416)begin row=7+((y-336)>>4);ty={7'd0,y[3:0]};end
            else hit=0;
            descriptor=remote_rows[row*8 +: 8];message=descriptor[5:0];
            panel=enable&&hit&&descriptor[7]&&x>=32&&x<608;
            if(row==0)panel=panel&&x>=112&&x<528;
            if(row==1&&descriptor[6])panel=panel&&x<160;
            if(row==2&&descriptor[6])panel=panel&&x<416;

            if(CLEAN_PRESENTATION&&((row<=2&&message>=45)||(row==12)||
                (row==4&&message!=4)||(row==5&&(message==57))||
                (row==6&&message==58)))panel=0;
            if(EXTENSIONS&&!CLEAN_PRESENTATION&&y>=8&&y<24)begin

                link_line=1;message=45;tx=x-32;ty=y-8;panel=enable&&x>=32&&x<240;
            end else if(EXTENSIONS&&!CLEAN_PRESENTATION&&health_enable&&y>=136&&y<152)begin
                health_line=1;message=54;tx=x-32;ty=y-136;panel=enable&&x>=32&&x<528&&!CLEAN_PRESENTATION;
            end
        end

 wire [7:0] rom_letter,font_row;reg [7:0] letter;
 reg [10:0] tx_q,ty_q,tx_qq,ty_qq;reg [23:0] rgb_q;
 reg link_q,health_q;
 wire [39:0] link_word=link_ready ? "READY" : seen_link ? "LOST " : "WAIT ";
 wire [7:0] health_status=health_fresh ? health[7:0] : 8'd5;
 wire [39:0] status_word=health_status==1 ? "PASS " : health_status==2 ? "FAIL " :
     health_status==3 ? "QUIET" : health_status==4 ? "CLIP " : health_status==5 ? "LOST " : "WAIT ";
 always @* begin
  letter=rom_letter;
  if(EXTENSIONS&&link_q&&tx_q[9:4]>=7&&tx_q[9:4]<12)
    letter=link_word[(11-tx_q[9:4])*8+:8];
  if(EXTENSIONS&&!CLEAN_PRESENTATION&&health_q)begin
   case(tx_q[9:4])
    4:letter=health_fresh ? 8'h30+health[47:44] : "-";
    5:letter=health_fresh ? 8'h30+health[43:40] : "-";
    6:letter=health_fresh ? 8'h30+health[39:36] : "-";
    7:letter=health_fresh ? 8'h30+health[35:32] : "-";
    13:letter=health_fresh ? 8'h30+health[31:28] : "-";
    14:letter=health_fresh ? 8'h30+health[27:24] : "-";
    15:letter=health_fresh ? 8'h30+health[23:20] : "-";
    16:letter=health_fresh ? 8'h30+health[19:16] : "-";
    21,22,23,24,25:letter=status_word[(25-tx_q[9:4])*8+:8];
    29:letter=health_fresh ? 8'h30+health[15:12] : "-";
    30:letter=health_fresh ? 8'h30+health[11:8] : "-";
   endcase
  end
 end
 reg panel_q,panel_qq,progress_q,progress_qq,fill_q,fill_qq;
 always @(posedge clk)begin
  link_q<=link_line;health_q<=health_line;
  panel_q<=panel;panel_qq<=panel_q;tx_q<=tx;ty_q<=ty;tx_qq<=tx_q;ty_qq<=ty_q;
  progress_q<=enable&&remote_confirmation[7]&&x>=32&&x<352&&y>=126&&y<132;
  progress_qq<=progress_q;fill_q<=((x-32)>>4)<remote_confirmation[5:1];fill_qq<=fill_q;
  rgb_q<=rgb_in;
 end
`ifdef __ICARUS__
 reg [7:0] text_memory[0:4095],font_memory[0:511];reg [7:0] letter_q,font_q;
 initial begin $readmemh("../../rtl/status_text.mem",text_memory);$readmemh("../../rtl/status_glyph_rows.mem",font_memory);end
 always @(posedge clk)begin letter_q<=text_memory[{message,tx[9:4]}];font_q<=font_memory[{letter[5:0],ty_q[3:1]}];end
 assign rom_letter=letter_q;assign font_row=font_q;
`else
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.DATA_WIDTH_B(8),.ADDR_WIDTH_A(12),.ADDR_WIDTH_B(12),
  .DATA_DEPTH_A(4096),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
  .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.INIT_FILE("../rtl/status_text.mif"),.IMPLEMENT("32K")) text_rom(
  .dia(8'd0),.addra({message,tx[9:4]}),.cea(1'b1),.ocea(1'b1),.clka(clk),.wea(1'b0),.rsta(1'b0),.bea(1'b1),
  .dib(8'd0),.addrb(12'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),.web(1'b0),.rstb(1'b0),.beb(1'b1),.doa(rom_letter),.dob());
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.DATA_WIDTH_B(8),.ADDR_WIDTH_A(9),.ADDR_WIDTH_B(9),
  .DATA_DEPTH_A(512),.DATA_DEPTH_B(512),.MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
  .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.INIT_FILE("../rtl/status_glyph_rows.mif"),.IMPLEMENT("9K")) font_rom(
  .dia(8'd0),.addra({letter[5:0],ty_q[3:1]}),.cea(1'b1),.ocea(1'b1),.clka(clk),.wea(1'b0),.rsta(1'b0),.bea(1'b1),
  .dib(8'd0),.addrb(9'd0),.ceb(1'b0),.oceb(1'b0),.clkb(clk),.web(1'b0),.rstb(1'b0),.beb(1'b1),.doa(font_row),.dob());
`endif
 wire ink=tx_qq[3:0]<10&&ty_qq<14&&font_row[4-tx_qq[3:1]];
 always @* begin
  rgb_out=rgb_q;
  if(panel_qq)begin rgb_out=ink ? 24'he9f1f8 : 24'h203b52;if(ty_qq>=14)rgb_out=24'h31495f;end
  if(progress_qq)rgb_out=fill_qq ? 24'h45df82 : 24'h303b46;
 end
endmodule
