`timescale 1ns/1ps
module idle_return_control #(
    parameter integer CLK_HZ=25000000,
    parameter integer TIMEOUT_SECONDS=60
)(
    input wire clk, rst, enable, activity, key_held,
    output reg timeout_event
);
    reg [31:0] divider, seconds;
    reg expired;
    always @(posedge clk or posedge rst) begin
        if(rst) begin divider<=0;seconds<=0;expired<=0;timeout_event<=0;end
        else begin
            timeout_event<=0;
            if(!enable || activity || key_held) begin
                divider<=0;seconds<=0;expired<=0;
            end else if(!expired) begin
                if(divider==CLK_HZ-1) begin
                    divider<=0;
                    if(seconds==TIMEOUT_SECONDS-1) begin
                        timeout_event<=1;expired<=1;
                    end else seconds<=seconds+1'b1;
                end else divider<=divider+1'b1;
            end
        end
    end
endmodule
