`timescale 1ns/1ps
module tb_clean_presentation;
 reg clk=0,rst=1,link=0;always #5 clk=~clk;
 reg [10:0] x=40,y=80;reg [103:0] rows=0;wire [23:0] rgb;
 remote_status_overlay #(.EXTENSIONS(1),.CLEAN_PRESENTATION(1)) dut(
 .clk(clk),.rst(rst),.link_ready(link),.health_enable(1'b1),.health_fresh(1'b1),
 .health(48'd0),.x(x),.y(y),.enable(1'b1),.remote_confirmation(8'd0),
 .remote_rows(rows),.rgb_in(24'h123456),.rgb_out(rgb));
 wire [23:0] card_rgb;
 console_status_card card(.x(x),.y(y),.status_valid(1'b1),
 .status({8'h80,2'd2,2'd0,3'd1,1'b1,4'd0,1'b0,3'd5,72'd0}),
 .rgb_in(rgb),.rgb_out(card_rgb));
 task pixel;input integer py;begin @(negedge clk);y=py;repeat(4)@(negedge clk);end endtask
 initial begin
 repeat(4)@(negedge clk);rst=0;
 rows[23:16]=8'hb4;rows[103:96]=8'hb4;
 pixel(80);if(rgb!=24'h123456)$fatal(1,"tone banner obscures poster");
 pixel(140);if(rgb!=24'h123456)$fatal(1,"frequency banner obscures poster");
 pixel(344);if(rgb!=24'h123456)$fatal(1,"waveform caption obscures poster");
 pixel(12);if(rgb!=24'h123456)$fatal(1,"B LINK WAIT banner obscures poster");
 link=1;pixel(12);if(rgb!=24'h123456)$fatal(1,"B LINK READY banner obscures poster");
 link=0;pixel(12);if(rgb!=24'h123456)$fatal(1,"B LINK LOST banner obscures poster");
 x=440;pixel(12);if(card_rgb==rgb)$fatal(1,"upper-right B control card hidden");
 x=40;
 rows[39:32]=8'h84;pixel(292);if(rgb==24'h123456)$fatal(1,"media error hidden");
 rows[31:24]=8'h93;pixel(112);if(rgb==24'h123456)$fatal(1,"confirmation hidden");
 $display("TEST_PASS clean poster hides left WAIT/READY/LOST and diagnostics; right B card, faults and confirmation retained");$finish;
 end
endmodule
