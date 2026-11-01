`timescale 1ns/1ps
module v41_telemetry_monitor(
    input wire clk,input wire rst,input wire clear_stats,
    input wire line_start,input wire line_end,input wire sdram_busy,
    input wire video_underflow,input wire audio_underflow,
    input wire uart_crc_error,input wire uart_frame_error,
    input wire cache_error,input wire tf_error,
    output reg [15:0] last_line_cycles,output reg [15:0] max_line_cycles,
    output reg [31:0] video_underflow_count,output reg [31:0] audio_underflow_count,
    output reg [31:0] uart_crc_error_count,output reg [31:0] uart_frame_error_count,
    output reg [31:0] cache_error_count,output reg [31:0] tf_error_count
);
    reg line_active;reg [15:0] line_cycles;
    reg video_underflow_q,audio_underflow_q,cache_error_q,tf_error_q;
    always @(posedge clk or posedge rst)begin
        if(rst||clear_stats)begin
            line_active<=0;line_cycles<=0;last_line_cycles<=0;max_line_cycles<=0;
            video_underflow_count<=0;audio_underflow_count<=0;
            uart_crc_error_count<=0;uart_frame_error_count<=0;
            cache_error_count<=0;tf_error_count<=0;
            video_underflow_q<=0;audio_underflow_q<=0;
            cache_error_q<=0;tf_error_q<=0;
        end else begin
            video_underflow_q<=video_underflow;audio_underflow_q<=audio_underflow;
            cache_error_q<=cache_error;tf_error_q<=tf_error;
            if(line_start)begin line_active<=1;line_cycles<=0;end
            else if(line_active&&sdram_busy&&line_cycles!=16'hffff)line_cycles<=line_cycles+1'b1;
            if(line_end&&line_active)begin
                line_active<=0;last_line_cycles<=line_cycles;
                if(line_cycles>max_line_cycles)max_line_cycles<=line_cycles;
            end
            if(video_underflow&&!video_underflow_q)
                video_underflow_count<=video_underflow_count+1'b1;
            if(audio_underflow&&!audio_underflow_q)
                audio_underflow_count<=audio_underflow_count+1'b1;
            if(uart_crc_error)uart_crc_error_count<=uart_crc_error_count+1'b1;
            if(uart_frame_error)uart_frame_error_count<=uart_frame_error_count+1'b1;
            if(cache_error&&!cache_error_q)cache_error_count<=cache_error_count+1'b1;
            if(tf_error&&!tf_error_q)tf_error_count<=tf_error_count+1'b1;
        end
    end
endmodule
