`timescale 1ns/1ps

module global_timebase #(
    parameter integer CLK_HZ = 25000000,
    parameter integer SAMPLE_HZ = 48000
)(
    input wire clk,
    input wire rst,
    output reg us_tick,
    output reg sample_tick,
    output reg [47:0] microseconds,
    output reg [47:0] sample_count
);
    reg [31:0] us_accumulator;
    reg [31:0] sample_accumulator;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            us_accumulator <= 0;
            sample_accumulator <= 0;
            microseconds <= 0;
            sample_count <= 0;
            us_tick <= 0;
            sample_tick <= 0;
        end else begin
            us_tick <= 0;
            sample_tick <= 0;
            if (us_accumulator >= CLK_HZ-1000000) begin
                us_accumulator <= us_accumulator-(CLK_HZ-1000000);
                microseconds <= microseconds+1'b1;
                us_tick <= 1;
            end else us_accumulator <= us_accumulator+1000000;
            if (sample_accumulator >= CLK_HZ-SAMPLE_HZ) begin
                sample_accumulator <= sample_accumulator-(CLK_HZ-SAMPLE_HZ);
                sample_count <= sample_count+1'b1;
                sample_tick <= 1;
            end else sample_accumulator <= sample_accumulator+SAMPLE_HZ;
        end
    end
endmodule
