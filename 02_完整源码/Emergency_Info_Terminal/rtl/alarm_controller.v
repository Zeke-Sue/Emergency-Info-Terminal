`timescale 1ns/1ps

module alarm_controller #(
    parameter integer FPS=60
)(
    input wire clk,
    input wire rst,
    input wire frame_tick,
    input wire first_active_pixel,
    input wire audio_sample_tick,
    input wire us_tick,
    input wire [47:0] microseconds,
    input wire trigger_pulse,
    input wire [47:0] trigger_timestamp,
    input wire primary_valid,
    input wire cancel_notice,
    input wire full_urgent,
    input wire [2:0] primary_level,
    input wire primary_drill,
    input wire primary_time_trusted,
    input wire [15:0] primary_remaining_seconds,
    output reg alarm_active,
    output reg [2:0] alarm_level,
    output reg alarm_drill,
    output reg countdown_trusted,
    output reg [15:0] countdown_seconds,
    output reg flash_on,
    output wire buzzer_on,
    output reg latency_valid,
    output reg [23:0] pixel_latency_us,
    output reg [23:0] audio_latency_us
);
    reg [31:0] second_div;
    reg [6:0] flash_frame;
    reg capture_armed,pixel_captured,audio_captured;
    reg [47:0] capture_start;
    assign buzzer_on=alarm_active && flash_on;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            alarm_active<=0;alarm_level<=4;alarm_drill<=0;countdown_trusted<=0;
            countdown_seconds<=0;flash_on<=0;flash_frame<=0;second_div<=0;
            capture_armed<=0;pixel_captured<=0;audio_captured<=0;capture_start<=0;
            latency_valid<=0;pixel_latency_us<=0;audio_latency_us<=0;
        end else begin
            latency_valid<=0;
            if(trigger_pulse) begin capture_armed<=1;pixel_captured<=0;audio_captured<=0;capture_start<=trigger_timestamp;end
            if(frame_tick) begin
                alarm_active<=primary_valid || cancel_notice || full_urgent;
                if(primary_valid) begin
                    alarm_level<=primary_level;alarm_drill<=primary_drill;
                    countdown_trusted<=primary_time_trusted;
                    if(!alarm_active) countdown_seconds<=primary_remaining_seconds;
                end
                if(!(primary_valid || cancel_notice || full_urgent)) begin
                    flash_frame<=0;flash_on<=0;second_div<=0;
                end else begin
                    flash_frame<=flash_frame==79 ? 0 : flash_frame+1'b1;
                    flash_on<=countdown_seconds==0 || flash_frame<16;
                end
            end
            if(us_tick && alarm_active && countdown_seconds!=0) begin
                if(second_div==999999) begin second_div<=0;countdown_seconds<=countdown_seconds-1'b1;end
                else second_div<=second_div+1'b1;
            end
            if(capture_armed && alarm_active && first_active_pixel && !pixel_captured) begin
                pixel_latency_us<=microseconds-capture_start;pixel_captured<=1;
            end
            if(capture_armed && alarm_active && audio_sample_tick && !audio_captured) begin
                audio_latency_us<=microseconds-capture_start;audio_captured<=1;
            end
            if(capture_armed && (pixel_captured || (alarm_active && first_active_pixel)) &&
               (audio_captured || (alarm_active && audio_sample_tick))) begin
                latency_valid<=1;capture_armed<=0;
            end
        end
    end
endmodule
