`timescale 1ns/1ps
module tb_probe_parser;
 reg clk=0,rst=1,mv=0;reg [7:0] mt=8'h0c;reg [95:0] mp=96'ha6123401;
 wire mr,bv;wire [7:0] bd;wire valid,last,ce,fe;wire [7:0] kind;wire [95:0] payload;wire [15:0] batch;
 always #20 clk=~clk;
 v41_record_framer tx(.clk(clk),.rst(rst),.msg_valid(mv),.msg_ready(mr),.msg_type(mt),.msg_batch(16'h1234),
 .msg_payload(mp),.msg_last(1'b0),.byte_valid(bv),.byte_ready(1'b1),.byte_data(bd));
 probe_parser dut(.clk(clk),.rst(rst),.byte_valid(bv),.byte_data(bd),.valid(valid),.kind(kind),.payload(payload),.batch(batch),.last(last),.crc_error(ce),.frame_error(fe));
 task check;input [7:0] typ;input [95:0] data;begin
  wait(mr);@(negedge clk);mt=typ;mp=data;mv=1;@(negedge clk);mv=0;
  wait(valid);@(negedge clk);
  $display("PARSER kind=%h payload=%h expected=%h",kind,payload,data);
  if(kind!==typ||payload!==data||batch!==16'h1234||ce||fe)$fatal(1,"Post-synthesis parser mismatch");
  if(last!==(typ==8'h0b))$fatal(1,"Wrong batch end marker");
  repeat(3)@(negedge clk);
 end endtask
 initial begin
  repeat(20)@(negedge clk);rst=0;
  check(8'h0c,96'ha6123401);check(8'h0d,96'h0123456789abcdef);check(8'h0b,96'h5a);
  $display("TEST_PASS synthesized A parser exact control payloads");$finish;
 end
 initial begin #100000;$fatal(1,"Timeout");end
endmodule
