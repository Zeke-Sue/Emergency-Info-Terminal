// 预设楼层图：0至2为出口封锁位，3至7为通道封锁位。
`timescale 1ns/1ps

module live_floor_graph(input wire [4:0] index,output reg [31:0] edge_word);
 always @* case(index)
  0:edge_word=32'h0801e020;
  1:edge_word=32'h0801e041;
  2:edge_word=32'h0801e062;
  3:edge_word=32'h0801e083;
  4:edge_word=32'h0801e0c5;
  5:edge_word=32'h0801e0e6;
  6:edge_word=32'h0801e107;
  7:edge_word=32'h0801e128;
  8:edge_word=32'h1001e16a;
  9:edge_word=32'h1001e18b;
  10:edge_word=32'h1001e1ac;
  11:edge_word=32'h1001e1cd;
  12:edge_word=32'h1001e20f;
  13:edge_word=32'h1001e230;
  14:edge_word=32'h1001e251;
  15:edge_word=32'h1001e272;
  16:edge_word=32'h010190a0;
  17:edge_word=32'h010190c1;
  18:edge_word=32'h020190e2;
  19:edge_word=32'h04019103;
  20:edge_word=32'h04019124;
  21:edge_word=32'h01019145;
  22:edge_word=32'h01019166;
  23:edge_word=32'h02019187;
  24:edge_word=32'h040191a8;
  25:edge_word=32'h040191c9;
  26:edge_word=32'h010191ea;
  27:edge_word=32'h0101920b;
  28:edge_word=32'h0201922c;
  29:edge_word=32'h0401924d;
  30:edge_word=32'h0401926e;
  31:edge_word=32'h0000f234;
 endcase
endmodule
