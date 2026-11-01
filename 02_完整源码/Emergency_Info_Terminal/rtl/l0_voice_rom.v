`timescale 1ns/1ps

module l0_voice_rom(input wire clk,input wire [15:0] address,output reg [3:0] nibble);
    reg [2:0] bank_q;
    wire [3:0] q0,q1,q2,q3,q4,q5;
    always @(posedge clk)bank_q<=address[15:13];
    always @* case(bank_q)
        0:nibble=q0;1:nibble=q1;2:nibble=q2;3:nibble=q3;4:nibble=q4;5:nibble=q5;
        default:nibble=0;
    endcase
    packed_nibble_rom #(.MEM_FILE("../../rtl/l0_voice_bank0.packed.mem"),.INIT_FILE("../rtl/l0_voice_bank0.packed.mif")) r0(.clk(clk),.address(address[12:0]),.nibble(q0));
    packed_nibble_rom #(.MEM_FILE("../../rtl/l0_voice_bank1.packed.mem"),.INIT_FILE("../rtl/l0_voice_bank1.packed.mif")) r1(.clk(clk),.address(address[12:0]),.nibble(q1));
    packed_nibble_rom #(.MEM_FILE("../../rtl/l0_voice_bank2.packed.mem"),.INIT_FILE("../rtl/l0_voice_bank2.packed.mif")) r2(.clk(clk),.address(address[12:0]),.nibble(q2));
    packed_nibble_rom #(.MEM_FILE("../../rtl/l0_voice_bank3.packed.mem"),.INIT_FILE("../rtl/l0_voice_bank3.packed.mif")) r3(.clk(clk),.address(address[12:0]),.nibble(q3));
    packed_nibble_rom #(.MEM_FILE("../../rtl/l0_voice_bank4.packed.mem"),.INIT_FILE("../rtl/l0_voice_bank4.packed.mif")) r4(.clk(clk),.address(address[12:0]),.nibble(q4));
    packed_nibble_rom #(.MEM_FILE("../../rtl/l0_voice_bank5.packed.mem"),.INIT_FILE("../rtl/l0_voice_bank5.packed.mif")) r5(.clk(clk),.address(address[12:0]),.nibble(q5));
endmodule
