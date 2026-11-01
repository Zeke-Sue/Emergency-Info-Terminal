`timescale 1ns/1ps

module physical_hold_buffer #(parameter integer WIDTH=1)(
    input wire [WIDTH-1:0] d,output wire [WIDTH-1:0] q
);
    wire [WIDTH-1:0] middle;
    genvar n;
    generate for(n=0;n<WIDTH;n=n+1)begin: bits
        AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) first(.a(d[n]),.o(middle[n]));
        AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) second(.a(middle[n]),.o(q[n]));
    end endgenerate
endmodule
