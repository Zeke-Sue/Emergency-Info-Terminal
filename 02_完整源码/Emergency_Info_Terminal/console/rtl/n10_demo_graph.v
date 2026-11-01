`timescale 1ns/1ps

module n10_demo_graph(input wire [4:0] index,output reg [31:0] edge_word);
    always @* case(index)
        0:edge_word=32'h0101e020; 1:edge_word=32'h0201e041;
        2:edge_word=32'h0401e062; 3:edge_word=32'h0801e083;
        4:edge_word=32'h1001e0c5; 5:edge_word=32'h0101e0e6;
        6:edge_word=32'h0201e107; 7:edge_word=32'h0401e128;
        8:edge_word=32'h0801e16a; 9:edge_word=32'h1001e18b;
        10:edge_word=32'h0101e1ac;11:edge_word=32'h0201e1cd;
        12:edge_word=32'h0401e20f;13:edge_word=32'h0801e230;
        14:edge_word=32'h1001e251;15:edge_word=32'h0101e272;
        16:edge_word=32'h010190a0;17:edge_word=32'h020190c1;
        18:edge_word=32'h040190e2;19:edge_word=32'h08019103;
        20:edge_word=32'h10019124;21:edge_word=32'h01019145;
        22:edge_word=32'h02019166;23:edge_word=32'h04019187;
        24:edge_word=32'h080191a8;25:edge_word=32'h100191c9;
        26:edge_word=32'h010191ea;27:edge_word=32'h0201920b;
        28:edge_word=32'h0401922c;29:edge_word=32'h0801924d;
        30:edge_word=32'h1001926e;31:edge_word=32'h1000f234;
    endcase
endmodule
