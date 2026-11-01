`timescale 1ns/1ps

module key_events #(
    parameter integer CLK_HZ = 25000000,
    parameter integer DEBOUNCE_CYCLES = CLK_HZ / 50,
    parameter integer LONG_CYCLES = CLK_HZ
)(
    input wire clk, rst, key_n,
    output reg press, short_release, long_press,
    output wire held
);
    reg [1:0] sync;
    reg stable_n, long_sent;
    reg [31:0] debounce_count, hold_count;
    assign held = !stable_n;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync <= 2'b11; stable_n <= 1'b1;
            debounce_count <= 0; hold_count <= 0; long_sent <= 0;
            press <= 0; short_release <= 0; long_press <= 0;
        end else begin
            sync <= {sync[0], key_n};
            press <= 0; short_release <= 0; long_press <= 0;
            if (sync[1] == stable_n) debounce_count <= 0;
            else if (debounce_count == DEBOUNCE_CYCLES-1) begin
                debounce_count <= 0;
                stable_n <= sync[1];
                if (!sync[1]) begin
                    press <= 1; hold_count <= 0; long_sent <= 0;
                end else if (!long_sent) short_release <= 1;
            end else debounce_count <= debounce_count + 1'b1;
            if (!stable_n && !long_sent) begin
                if (hold_count == LONG_CYCLES-1) begin
                    long_press <= 1; long_sent <= 1;
                end else hold_count <= hold_count + 1'b1;
            end
        end
    end
endmodule
