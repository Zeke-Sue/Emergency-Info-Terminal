`timescale 1ns/1ps

module AL_MAP_LUT1 #(
    parameter [1:0] INIT=2'b00,
    parameter EQN="0"
)(
    output wire o,
    input wire a
);
    assign o=INIT[a];
endmodule
