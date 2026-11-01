`timescale 1ns/1ps

module wav_admission_checker #(
    parameter integer SILENCE_LEVEL=256,
    parameter integer CLIP_LEVEL=32000,
    parameter integer MIN_NON_SILENT=16,
    parameter integer MAX_CLIPPED=2,
    parameter integer MAX_SILENT_RUN=9600,
    parameter integer MIN_ZERO_CROSS=4,
    parameter integer MAX_ZERO_CROSS=4096,
    parameter integer WINDOW_SAMPLES=4800,
    parameter integer WINDOW_RMS_SQ=10737,
    parameter integer WHOLE_RMS_SQ=107374,
    parameter integer MIN_PEAK=3277,
    parameter integer MAX_PEAK=29204,
    parameter integer FULL_SCALE_LEVEL=32760,
    parameter integer MAX_FULL_SCALE_RUN=2,
    parameter integer USE_PURPOSE_PROFILES=1,
    parameter [15:0] CHECKER_VERSION=16'h0402
)(
    input wire clk,input wire rst,input wire start,
    input wire sample_valid,input wire signed [15:0] sample,
    input wire trajectory_error,input wire finish,
    input wire [7:0] purpose,
    output reg result_valid,output reg admitted,output reg [3:0] reason,
    output reg [31:0] file_length,output reg [31:0] file_crc32,
    output reg [7:0] certificate_purpose,
    output wire [15:0] certificate_version,
    output reg [31:0] sample_count_out,output reg [31:0] clipped_count_out,
    output reg [31:0] longest_silence_out,output reg [31:0] zero_crossings_out
);
    reg [31:0] sample_count,non_silent_count,clipped_count,silent_run,max_silent_run;
    reg [31:0] zero_crossings;reg previous_negative,have_previous;
    reg trajectory_failed;reg [31:0] crc;
    wire [15:0] magnitude=sample[15] ? (~sample+1'b1) : sample;
    wire [31:0] magnitude_sq=magnitude*magnitude;
    reg [63:0] total_energy,window_energy;
    reg [31:0] window_count,low_rms_run,max_low_rms_run;
    reg [15:0] peak_magnitude,full_scale_run,max_full_scale_run;
    reg peak_violation;
    wire narration_profile=USE_PURPOSE_PROFILES &&
        ((certificate_purpose>=8'h21 && certificate_purpose<=8'h2a)||
         (certificate_purpose>=8'h2d && certificate_purpose<=8'h2f));
    wire spectral_profile=USE_PURPOSE_PROFILES &&
        (certificate_purpose==8'h2b || certificate_purpose==8'h2c);
    wire [63:0] whole_energy_floor={{32{1'b0}},sample_count}*WHOLE_RMS_SQ;
    wire [63:0] window_energy_floor=WINDOW_RMS_SQ*WINDOW_SAMPLES;
    assign certificate_version=CHECKER_VERSION;
    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer k;reg [31:0] work;
        begin
            work=current^value;
            for(k=0;k<8;k=k+1)work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            sample_count<=0;non_silent_count<=0;clipped_count<=0;silent_run<=0;
            max_silent_run<=0;zero_crossings<=0;previous_negative<=0;have_previous<=0;
            trajectory_failed<=0;crc<=32'hffffffff;result_valid<=0;admitted<=0;
            total_energy<=0;window_energy<=0;window_count<=0;low_rms_run<=0;
            max_low_rms_run<=0;peak_magnitude<=0;full_scale_run<=0;
            max_full_scale_run<=0;peak_violation<=0;
            reason<=0;file_length<=0;file_crc32<=0;certificate_purpose<=0;
            sample_count_out<=0;clipped_count_out<=0;longest_silence_out<=0;
            zero_crossings_out<=0;
        end else begin
            result_valid<=0;
            if(start)begin
                sample_count<=0;non_silent_count<=0;clipped_count<=0;silent_run<=0;
                max_silent_run<=0;zero_crossings<=0;have_previous<=0;
                trajectory_failed<=0;crc<=32'hffffffff;admitted<=0;reason<=0;
                total_energy<=0;window_energy<=0;window_count<=0;low_rms_run<=0;
                max_low_rms_run<=0;peak_magnitude<=0;full_scale_run<=0;
                max_full_scale_run<=0;peak_violation<=0;
                certificate_purpose<=purpose;
            end else begin
                if(trajectory_error)trajectory_failed<=1;
                if(sample_valid)begin
                    sample_count<=sample_count+1'b1;
                    total_energy<=total_energy+magnitude_sq;
                    crc<=crc32_byte(crc32_byte(crc,sample[7:0]),sample[15:8]);
                    if(magnitude>peak_magnitude)peak_magnitude<=magnitude;
                    if(magnitude>MAX_PEAK)peak_violation<=1;
                    if(magnitude>=FULL_SCALE_LEVEL)begin
                        full_scale_run<=full_scale_run+1'b1;
                        if(full_scale_run+1'b1>max_full_scale_run)
                            max_full_scale_run<=full_scale_run+1'b1;
                    end else full_scale_run<=0;
                    if(window_count==WINDOW_SAMPLES-1)begin
                        window_count<=0;window_energy<=0;
                        if(window_energy+magnitude_sq<window_energy_floor)begin
                            low_rms_run<=low_rms_run+WINDOW_SAMPLES;
                            if(low_rms_run+WINDOW_SAMPLES>max_low_rms_run)
                                max_low_rms_run<=low_rms_run+WINDOW_SAMPLES;
                        end else low_rms_run<=0;
                    end else begin
                        window_count<=window_count+1'b1;
                        window_energy<=window_energy+magnitude_sq;
                    end
                    if(magnitude>=SILENCE_LEVEL)begin non_silent_count<=non_silent_count+1'b1;silent_run<=0;end
                    else begin
                        silent_run<=silent_run+1'b1;
                        if(silent_run+1'b1>max_silent_run)max_silent_run<=silent_run+1'b1;
                    end
                    if(magnitude>=CLIP_LEVEL)clipped_count<=clipped_count+1'b1;
                    if(have_previous&&(sample[15]!=previous_negative)&&sample!=0)
                        zero_crossings<=zero_crossings+1'b1;
                    previous_negative<=sample[15];have_previous<=1;
                end
                if(finish)begin
                    result_valid<=1;file_length<=sample_count<<1;file_crc32<=~crc;
                    sample_count_out<=sample_count;clipped_count_out<=clipped_count;
                    longest_silence_out<=max_silent_run;zero_crossings_out<=zero_crossings;
                    admitted<=0;

                    if(clipped_count>MAX_CLIPPED||peak_violation||
                            max_full_scale_run>MAX_FULL_SCALE_RUN)reason<=2;
                    else if(sample_count==0||non_silent_count<MIN_NON_SILENT||
                            total_energy<whole_energy_floor)reason<=1;
                    else if(!narration_profile && max_low_rms_run>MAX_SILENT_RUN)reason<=3;
                    else if(peak_magnitude<MIN_PEAK)reason<=5;
                    else if(trajectory_failed||trajectory_error||(!narration_profile && !spectral_profile &&
                            (zero_crossings<MIN_ZERO_CROSS||
                             zero_crossings>MAX_ZERO_CROSS)))reason<=4;
                    else begin admitted<=1;reason<=0;end
                end
            end
        end
    end
endmodule
