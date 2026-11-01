`timescale 1ns/1ps

module reset_release_falling(
    input wire clk,async_reset,
    output wire reset_out
);
    reg [2:0] stages;
    always @(negedge clk or posedge async_reset)
        if(async_reset)stages<=3'b111;
        else stages<={stages[1:0],1'b0};
    assign reset_out=stages[2];
endmodule
