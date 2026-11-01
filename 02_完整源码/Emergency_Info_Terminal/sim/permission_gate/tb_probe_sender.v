`timescale 1ns/1ps
module tb_probe_sender;
 reg clk=0,rst=1,go=0,ready=0;reg [31:0] parameters=32'ha6123401;
 wire valid,last;wire [7:0] kind;wire [95:0] payload;wire [15:0] batch;
 always #10 clk=~clk;
 probe_sender dut(.clk(clk),.rst(rst),.go(go),.ready(ready),.parameters(parameters),.valid(valid),.kind(kind),.payload(payload),.batch(batch),.last(last));
 integer n=0;
 task record_check;input [7:0] typ;input [95:0] expected;input terminal;begin
  wait(valid);repeat(3)@(negedge clk);
  $display("SENDER kind=%h payload=%h expected=%h",kind,payload,expected);
  if(kind!==typ||payload!==expected||last!==terminal)$fatal(1,"Post-synthesis control payload lost");
  ready=1;@(negedge clk);ready=0;
 end endtask
 task snapshot;input [31:0] p;begin
  @(negedge clk);parameters=p;go=1;@(negedge clk);go=0;
  record_check(8'h0c,{64'd0,p},0);
  record_check(8'h0d,96'h0123456789abcdef,0);
  record_check(8'h0b,96'h5a,1);
  repeat(5)@(negedge clk);
 end endtask
 initial begin
  repeat(20)@(negedge clk);rst=0;repeat(5)@(negedge clk);
  snapshot(32'ha6123401);snapshot(32'ha6156700);
  $display("TEST_PASS synthesized sender exact parameters/event/blocked grant+revoke");$finish;
 end
 initial begin #100000;$fatal(1,"Timeout");end
endmodule
