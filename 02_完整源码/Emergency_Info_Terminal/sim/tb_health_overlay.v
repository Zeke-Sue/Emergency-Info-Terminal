`timescale 1ns/1ps
module tb_health_overlay;
 reg clk=0,rst=1,link=0,fresh=1;always #5 clk=~clk;
 reg [10:0] x=0,y=0;wire [23:0] rgb;
 reg [47:0] health={16'h1500,16'h1499,8'h19,8'd1};
 remote_status_overlay #(.EXTENSIONS(1)) dut(.clk(clk),.rst(rst),.link_ready(link),
 .health_enable(1'b1),.health_fresh(fresh),.health(health),.x(x),.y(y),.enable(1'b1),
 .remote_confirmation(8'd0),.remote_rows(104'd0),.rgb_in(24'h123456),.rgb_out(rgb));
 reg [7:0] font[0:511];reg [8*31-1:0] expected;
 integer c,r,p;reg [7:0] ch;reg [23:0] want;
 task check_line;input integer ypos,count;begin
  for(c=0;c<count;c=c+1)begin
   ch=expected[(30-c)*8+:8];
   for(r=0;r<7;r=r+1)for(p=0;p<5;p=p+1)begin
    @(negedge clk);x=32+16*c+2*p;y=ypos+2*r;repeat(3)@(negedge clk);
    want=font[{ch[5:0],3'd0}+r][4-p] ? 24'he9f1f8 : 24'h203b52;
    if(rgb!==want)$fatal(1,"dynamic text glyph mismatch col=%d char=%h row=%d pixel=%d got=%h",c,ch,r,p,rgb);
   end
  end
 end endtask
 initial begin
 $readmemh("../../rtl/status_glyph_rows.mem",font);
 repeat(4)@(negedge clk);rst=0;
 expected="B LINK WAIT                    ";check_line(8,12);
 link=1;expected="B LINK READY                   ";check_line(8,12);
 link=0;expected="B LINK LOST                    ";check_line(8,12);
 expected="EXP 1500 GOT 1499 HZ PASS  LV19";check_line(136,31);
 fresh=0;expected="EXP ---- GOT ---- HZ LOST  LV--";check_line(136,31);
 health[7:0]=3;fresh=1;expected="EXP 1500 GOT 1499 HZ QUIET LV19";check_line(136,31);
 $display("TEST_PASS health/link overlay all glyph pixels, BCD alignment, silence and local lost/recovered link indication");$finish;
 end
 initial begin #1000000;$fatal(1,"health overlay timeout");end
endmodule
