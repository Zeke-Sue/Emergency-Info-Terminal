`timescale 1ns/1ps

module console_wav_admission_pipeline #(
    parameter integer MAX_AUDIO_FILES=10,
    parameter integer CLK_HZ=50000000,
    parameter integer DEPLOYMENT_PROFILES=0,
    parameter integer STRICT_CHAIN=0,
    parameter integer FIXED_PLAYLIST=0,
    parameter integer ENABLE_IMA=1,
    parameter integer STREAM_BYTES_PER_SECOND=1000000
)(
    input wire clk,input wire rst,input wire start_ready,input wire sd_ready,
    input wire reload,input wire trajectory_error,input wire [7:0] purpose,
    output wire sector_req,output wire [31:0] sector_lba,
    input wire [7:0] sector_data,input wire sector_valid,input wire sector_end,
    output reg result_valid,output reg admitted,output reg [3:0] reason,
    output reg [31:0] admitted_length,output reg [31:0] admitted_crc32,
    output reg [7:0] admitted_purpose,output reg [15:0] admitted_version,
    output reg [95:0] certificate,output reg certificate_valid,
    output reg [3:0] result_index,output reg [4:0] completed_count,
    output reg [15:0] certificate_valid_bitmap,
    output reg [15:0] admitted_bitmap,
    output wire mounted,output wire [4:0] wav_count,
    output reg busy,output reg [3:0] error_code,
    output wire spectrum_valid,output wire [5:0] spectrum_bin,
    output wire [15:0] spectrum_magnitude,output wire transform_done,
    output wire [23:0] peak_frequency_q8,
    output wire analysis_start,analysis_sample_valid,
    output wire [3:0] analysis_file_index,
    output wire [31:0] trajectory_bad_windows,trajectory_first_bad_sample,
    output wire [4:0] trajectory_missing_voices
);
    localparam S_MOUNT=0,S_OPEN=1,S_WAIT=2,S_STREAM=3,
        S_WAIT_CHECK=4,S_ADVANCE=5,S_DONE=6;
    reg [2:0] state;
    reg open_req;
    reg [3:0] current_file;
    reg checker_done;
    reg parser_done;
    reg fat_error_handled;
    reg [31:0] byte_phase;
    reg byte_pulse;
    wire [4:0] files_to_check=wav_count>MAX_AUDIO_FILES ?
        MAX_AUDIO_FILES : wav_count;

    wire [7:0] current_purpose=(DEPLOYMENT_PROFILES ? 8'h21 : purpose)+current_file;
    wire [1:0] profile=current_purpose==8'h2b ? 2'd1 :
        (current_purpose==8'h2c ? 2'd2 : 2'd0);

    wire open_done,open_not_found,file_valid,file_ready,file_end;
    wire [31:0] file_size;wire [7:0] file_data;wire [3:0] fat_error;
    wire [5:0] catalog_count;wire [4:0] bmp_count;
    wire config_found;wire [7:0] malformed;wire catalog_overflow;
    fat32_file_reader #(.CACHE_BMP(0),.CACHE_WAV(1),.STRICT_CHAIN(STRICT_CHAIN),.FIXED_PLAYLIST(FIXED_PLAYLIST),.HASH_NAMES(!FIXED_PLAYLIST),
        .MAX_WAV_FILES(16),.FIXED_WAV_FILES(MAX_AUDIO_FILES),.PHYSICAL_HOLD_BUFFERS(1)) files(
        .clk(clk),.rst(rst|reload),
        .start_ready(start_ready),.sd_ready(sd_ready),.sector_req(sector_req),
        .sector_lba(sector_lba),.sector_data(sector_data),
        .sector_valid(sector_valid),.sector_end(sector_end),.open_req(open_req),
        .abort_file(1'b0),
        .open_type(2'd2),.file_index({2'd0,current_file}),.open_done(open_done),
        .open_not_found(open_not_found),.file_size(file_size),.file_data(file_data),
        .file_valid(file_valid),.file_ready(file_ready),.file_end(file_end),
        .mounted(mounted),.catalog_file_count(catalog_count),
        .bmp_file_count(bmp_count),.wav_file_count(wav_count),
        .config_found(config_found),.catalog_malformed_count(malformed),
        .catalog_overflow(catalog_overflow),.error_code(fat_error));

    wire parser_ready,data_start,sample_valid,data_finish,parse_done,parse_valid;
    wire parser_sample_valid;
    wire [31:0] container_length,container_crc;
    wire stft_busy,stft_overrun,full_bin_valid,trajectory_failed;
    wire signed [15:0] sample;wire [3:0] parse_reason;
    wire [31:0] data_length,sample_count;

    assign file_ready=state==S_STREAM&&parser_ready&&byte_pulse&&!stft_busy;
    assign sample_valid=parser_sample_valid&&!stft_busy;
    wav_stream_parser #(.SAMPLE_BACKPRESSURE(1),.ENABLE_IMA(ENABLE_IMA)) parser(.clk(clk),.rst(rst|reload),.file_start(open_done),
        .byte_valid(file_valid&&file_ready),.byte_data(file_data),
        .byte_ready(parser_ready),.file_end(file_end&&state==S_STREAM),
        .sample_ready(!stft_busy),.data_start(data_start),.sample_valid(parser_sample_valid),.sample(sample),
        .data_finish(data_finish),.parse_done(parse_done),.file_valid(parse_valid),
        .error_reason(parse_reason),.data_length(data_length),
        .sample_count(sample_count),.container_length(container_length),.container_crc32(container_crc));

    wire [8:0] full_bin_index;wire [15:0] full_bin_magnitude;
    wire [31:0] trajectory_windows;
    assign analysis_start=data_start;
    assign analysis_sample_valid=sample_valid;
    assign analysis_file_index=current_file;
    stft_512_fft spectrum(.clk(clk),.rst(rst|reload|data_start),
        .sample_tick(sample_valid),.sample_in(sample),
        .spectrum_valid(spectrum_valid),.spectrum_bin(spectrum_bin),
        .spectrum_magnitude(spectrum_magnitude),.transform_done(transform_done),
        .peak_frequency_q8(peak_frequency_q8),.busy(stft_busy),
        .full_bin_valid(full_bin_valid),.full_bin_index(full_bin_index),
        .full_bin_magnitude(full_bin_magnitude),.overrun(stft_overrun));
    alarm_trajectory_checker trajectories(.clk(clk),.rst(rst|reload),
        .start(data_start),.profile(profile),.bin_valid(full_bin_valid),
        .bin_index(full_bin_index),.magnitude(full_bin_magnitude),
        .window_done(transform_done),.failed(trajectory_failed),
        .windows_checked(trajectory_windows),.bad_windows(trajectory_bad_windows),
        .first_bad_sample(trajectory_first_bad_sample),
        .missing_voices(trajectory_missing_voices),.bad_window());
    reg [31:0] spectral_windows,expected_windows;
    reg spectral_error,finish_pending,checker_finish;
    reg [16:0] cycle_samples;
    reg [31:0] analysis_watchdog;

    wire checker_result,checker_admitted;wire [3:0] checker_reason;
    wire [31:0] checker_length,checker_crc;
    wire [7:0] checker_purpose;wire [15:0] checker_version;
    wire [31:0] checked_samples,clipped,longest_silence,crossings;
    wav_admission_checker checker(.clk(clk),.rst(rst|reload),.start(data_start),
        .sample_valid(sample_valid),.sample(sample),
        .trajectory_error(trajectory_error|spectral_error|stft_overrun|
            (checker_finish&&profile!=0&&(trajectory_failed||sample_count<285120||
                (cycle_samples>960&&cycle_samples<95040)))),.finish(checker_finish),
        .purpose(current_purpose),.result_valid(checker_result),
        .admitted(checker_admitted),.reason(checker_reason),
        .file_length(checker_length),.file_crc32(checker_crc),
        .certificate_purpose(checker_purpose),
        .certificate_version(checker_version),.sample_count_out(checked_samples),
        .clipped_count_out(clipped),.longest_silence_out(longest_silence),
        .zero_crossings_out(crossings));

    task record_checker_result;
        begin
            result_valid<=1;result_index<=current_file;
            admitted<=checker_admitted;reason<=checker_reason;
            admitted_length<=container_length;admitted_crc32<=container_crc;
            admitted_purpose<=checker_purpose;admitted_version<=16'h0500;
            certificate_valid<=1;certificate_valid_bitmap[current_file]<=1;
            admitted_bitmap[current_file]<=checker_admitted;
            certificate<={3'd0,16'h0500,checker_reason,
                checker_admitted,container_crc,container_length,checker_purpose};
        end
    endtask

    task record_parser_failure;
        begin
            result_valid<=1;result_index<=current_file;admitted<=0;
            reason<={1'b1,parse_reason[2:0]};admitted_length<=0;
            admitted_crc32<=0;admitted_purpose<=current_purpose;
            admitted_version<=16'h0500;certificate_valid<=1;
            certificate_valid_bitmap[current_file]<=1;
            admitted_bitmap[current_file]<=0;
            certificate<={3'd0,16'h0500,{1'b1,parse_reason[2:0]},
                1'b0,32'd0,32'd0,current_purpose};
        end
    endtask

    always @(posedge clk or posedge rst)begin
        if(rst)begin
            byte_phase<=0;byte_pulse<=0;
        end else if(reload)begin
            byte_phase<=0;byte_pulse<=0;
        end else begin
            byte_pulse<=0;
            if(byte_phase+STREAM_BYTES_PER_SECOND>=CLK_HZ)begin
                byte_phase<=byte_phase+STREAM_BYTES_PER_SECOND-CLK_HZ;
                byte_pulse<=1;
            end else byte_phase<=byte_phase+STREAM_BYTES_PER_SECOND;
        end
    end

    always @(posedge clk or posedge rst)begin
        if(rst)begin
            spectral_windows<=0;expected_windows<=0;spectral_error<=0;
            finish_pending<=0;checker_finish<=0;
            cycle_samples<=0;analysis_watchdog<=0;
        end else if(reload)begin
            spectral_windows<=0;expected_windows<=0;spectral_error<=0;
            finish_pending<=0;checker_finish<=0;
            cycle_samples<=0;analysis_watchdog<=0;
        end else begin
            checker_finish<=0;
            if(data_start)begin
                spectral_windows<=0;expected_windows<=0;spectral_error<=0;
                finish_pending<=0;
                cycle_samples<=0;analysis_watchdog<=0;
            end else begin
                if(sample_valid)cycle_samples<=cycle_samples==95999 ? 0 : cycle_samples+1'b1;
                if(finish_pending)analysis_watchdog<=analysis_watchdog+1'b1;
                else analysis_watchdog<=0;
                if(transform_done)begin
                    spectral_windows<=spectral_windows+1'b1;
                    if(!((current_purpose>=8'h21&&current_purpose<=8'h2a)||
                            (current_purpose>=8'h2d&&current_purpose<=8'h2f)) &&
                            (peak_frequency_q8<(24'd80<<8)||
                             peak_frequency_q8>(24'd12000<<8)))
                        spectral_error<=1;
                end
                if(data_finish)begin
                    finish_pending<=1;
                    expected_windows<=sample_count<512 ? 0 :
                        1+((sample_count-512)>>8);
                end else if(finish_pending&&
                        (expected_windows==0||
                         spectral_windows+(transform_done ? 1'b1 : 1'b0)>=expected_windows))begin
                    finish_pending<=0;checker_finish<=1;
                end else if(finish_pending&&analysis_watchdog==CLK_HZ/10)begin

                    finish_pending<=0;spectral_error<=1;checker_finish<=1;
                end
            end
        end
    end

    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=S_MOUNT;open_req<=0;current_file<=0;
            fat_error_handled<=0;
            checker_done<=0;parser_done<=0;result_valid<=0;result_index<=0;
            admitted<=0;reason<=0;admitted_length<=0;admitted_crc32<=0;
            admitted_purpose<=0;admitted_version<=0;certificate<=0;
            certificate_valid<=0;completed_count<=0;
            certificate_valid_bitmap<=0;admitted_bitmap<=0;
            busy<=1;error_code<=0;
        end else if(reload)begin
            state<=S_MOUNT;open_req<=0;current_file<=0;
            fat_error_handled<=0;
            checker_done<=0;parser_done<=0;result_valid<=0;result_index<=0;
            admitted<=0;reason<=0;certificate_valid<=0;completed_count<=0;
            certificate_valid_bitmap<=0;admitted_bitmap<=0;
            busy<=1;error_code<=0;
        end else begin
            result_valid<=0;
            if(fat_error==0)fat_error_handled<=0;
            if(fat_error!=0&&!fat_error_handled)begin
                error_code<=fat_error;open_req<=0;fat_error_handled<=1;
                if(mounted&&(state==S_WAIT||state==S_STREAM||state==S_WAIT_CHECK))begin
                    result_valid<=1;result_index<=current_file;admitted<=0;reason<=15;
                    admitted_length<=0;admitted_crc32<=0;admitted_purpose<=current_purpose;
                    admitted_version<=16'h0500;certificate_valid<=1;
                    certificate_valid_bitmap[current_file]<=1;admitted_bitmap[current_file]<=0;
                    certificate<={3'd0,16'h0500,4'hf,1'b0,32'd0,32'd0,current_purpose};
                    state<=S_ADVANCE;
                end else begin busy<=0;state<=S_DONE;end
            end else case(state)
                S_MOUNT:if(mounted)begin
                    if(files_to_check!=0)begin
                        current_file<=0;busy<=1;state<=S_OPEN;
                    end else begin error_code<=3;busy<=0;state<=S_DONE;end
                end
                S_OPEN:begin
                    checker_done<=0;parser_done<=0;open_req<=1;state<=S_WAIT;
                end
                S_WAIT:begin
                    open_req<=0;
                    if(open_not_found)begin error_code<=3;busy<=0;state<=S_DONE;end
                    else if(open_done)state<=S_STREAM;
                end
                S_STREAM:begin
                    if(checker_result)begin
                        checker_done<=1;
                    end
                    if(parse_done)begin
                        parser_done<=1;
                        if(!parse_valid||container_length!=file_size)begin
                            record_parser_failure;state<=S_ADVANCE;
                        end else if(checker_done||checker_result)begin
                            record_checker_result;state<=S_ADVANCE;
                        end
                        else state<=S_WAIT_CHECK;
                    end
                end
                S_WAIT_CHECK:begin
                    if(checker_result)begin
                        record_checker_result;checker_done<=1;state<=S_ADVANCE;
                    end
                end
                S_ADVANCE:begin
                    completed_count<=completed_count+1'b1;
                    if(completed_count+1'b1>=files_to_check)begin
                        busy<=0;state<=S_DONE;
                    end else begin
                        current_file<=current_file+1'b1;state<=S_OPEN;
                    end
                end
                S_DONE:begin busy<=0;open_req<=0;end
                default:begin state<=S_DONE;busy<=0;error_code<=15;end
            endcase
        end
    end
endmodule
