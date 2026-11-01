`timescale 1ns/1ps

module console_hold_buffer #(parameter integer WIDTH=1)(
    input wire [WIDTH-1:0] d, output wire [WIDTH-1:0] q
);
    wire [WIDTH-1:0] middle;
    genvar bit_index;
    generate for(bit_index=0;bit_index<WIDTH;bit_index=bit_index+1)begin: bits
        AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) first(
            .a(d[bit_index]),.o(middle[bit_index]));
        AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) second(
            .a(middle[bit_index]),.o(q[bit_index]));
    end endgenerate
endmodule
