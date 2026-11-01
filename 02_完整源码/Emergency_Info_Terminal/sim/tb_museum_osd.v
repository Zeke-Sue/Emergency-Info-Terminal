`timescale 1ns/1ps
module tb_museum_osd;
 reg [10:0] x=0,y=0;
 reg [3:0] page=2,error_code=5;
 reg [2:0] selection=1;
 reg [7:0] progress=50,subtitle=0;
 reg narration=0;
 wire [23:0] rgb;
 museum_osd dut(.x(x),.y(y),.rgb_in(24'h305060),.page(page),.error_code(error_code),
 .selection(selection),.brightness(3'd4),.contrast(3'd3),.saturation(3'd2),
 .exhibit_index(2'd0),.period_select(2'd2),.playing(1'b1),.zoom(1'b1),.mono(1'b0),
 .narration_ready(narration),.progress(progress),.subtitle_id(subtitle),.rgb_out(rgb));
 task fail;input [511:0] why;begin $display("TEST_FAIL tb_museum_osd %0s x=%0d y=%0d rgb=%h",why,x,y,rgb);$finish;end endtask
 task pixel;input integer xx,yy;input [23:0] expected;begin x=xx;y=yy;#2;if(rgb!==expected)fail("pixel geometry/color");end endtask
 integer xx,yy,f,j,lit;
 reg [255:0] glyph;
 initial begin
 pixel(600,88,24'h15232b);pixel(599,128,24'h745a2d);pixel(39,128,24'h15232b);
 pixel(24,400,24'hb69b63);pixel(615,447,24'hb69b63);pixel(23,400,24'h305060);
 pixel(64,464,24'h394953);narration=1;pixel(64,464,24'hd9b969);
 pixel(319,464,24'hd9b969);pixel(320,464,24'h394953);pixel(576,464,24'h305060);
 progress=0;pixel(64,464,24'h394953);progress=255;pixel(575,471,24'hd9b969);pixel(575,472,24'h305060);

 glyph=256'h0300010001807FFE083008200C200460064002C0018003C00E70781E00000000;
 for(yy=0;yy<32;yy=yy+1)for(xx=0;xx<32;xx=xx+1)
  pixel(24+xx,16+yy,glyph[255-(yy/2)*16-xx/2] ? 24'hf4e8ce : 24'h162d38);
 page=3;pixel(300,200,24'h305060);pixel(640,24,24'h305060);pixel(24,480,24'h305060);
 subtitle=1;x=40;y=408;#2;if(dut.label_id!=31)fail("subtitle mapping");
 subtitle=250;#2;if(dut.label_id!=30)fail("unknown subtitle fallback");
 narration=0;subtitle=1;#2;if(dut.label_id!=30)fail("unavailable narration fallback");
 page=8;x=120;y=100;#2;if(dut.character!=16'h0035)fail("error digit");

 for(j=0;j<4;j=j+1)begin
  case(j)0:begin page=2;f=$fopen("museum_main.ppm","w");end
   1:begin page=6;f=$fopen("museum_enhance.ppm","w");end
   2:begin page=3;f=$fopen("museum_guide.ppm","w");end
   3:begin page=8;f=$fopen("museum_error.ppm","w");end endcase
  if(!f)fail("open preview");$fwrite(f,"P3\n640 480\n255\n");lit=0;
  for(yy=0;yy<480;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+1)begin
    x=xx;y=yy;#1;
    if(^rgb===1'bx)fail("unknown output");
    if(rgb==24'hf4e8ce)lit=lit+1;
    $fwrite(f,"%0d %0d %0d ",rgb[23:16],rgb[15:8],rgb[7:0]);
   end
   $fwrite(f,"\n");
  end
  if(lit<100)fail("missing glyphs");$fclose(f);
 end
 $display("TEST_PASS tb_museum_osd exact title bitmap/scale, highlight, clipping, progress endpoints, subtitles, errors and four 640x480 previews");$finish;
 end
endmodule
