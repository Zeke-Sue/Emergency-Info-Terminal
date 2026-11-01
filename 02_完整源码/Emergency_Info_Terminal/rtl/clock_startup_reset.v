`timescale 1ns/1ps

module clock_startup_reset #(parameter integer SETTLE_BITS=20)(
    input wire clk,async_reset,
    output wire reset_out
);
    reg [SETTLE_BITS-1:0] count;
    reg settled;
    always @(posedge clk or posedge async_reset)begin
        if(async_reset)begin count<=0;settled<=0;end
        else if(!settled)begin
            if(&count)settled<=1;
            else count<=count+1'b1;
        end
    end
    reset_release_falling release_sync(.clk(clk),
        .async_reset(async_reset||!settled),.reset_out(reset_out));
endmodule
