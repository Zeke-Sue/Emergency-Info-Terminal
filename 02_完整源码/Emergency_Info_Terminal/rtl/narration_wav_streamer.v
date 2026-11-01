`timescale 1ns/1ps

module narration_wav_streamer #(
    parameter integer ENABLE_FILE_ERROR=0,
    parameter integer ENABLE_RESUME=0,
    parameter integer ENABLE_IO_PROGRESS=0,
    parameter integer ENABLE_IMA=1,
    parameter integer CANONICAL_PCM=0,

    parameter integer DIRECT_PLAY=0,
    parameter integer ENABLE_STOP=0,ENABLE_WINDOW=0,
    parameter integer TIMEOUT_CYCLES=100000000
)(
    input wire clk,input wire rst,input wire play_request,
    input wire stop_request,
    output wire file_abort,
    input wire [3:0] requested_index,input wire external_allowed,
    input wire [31:0] requested_start_sample,
    input wire [31:0] requested_sample_limit,
    input wire loop_enable,
    input wire [3:0] file_error,
    input wire file_io_progress,
    output reg file_open_req,output reg [3:0] file_index,
    input wire file_busy,input wire file_open_done,input wire file_not_found,
    input wire [31:0] file_size,input wire [7:0] file_data,
    input wire file_valid,output wire file_ready,input wire file_end,
    output reg asset_begin_toggle,output reg asset_complete_toggle,
    output reg [7:0] asset_purpose,output reg [31:0] asset_length,
    output reg [31:0] asset_crc32,
    output reg [31:0] asset_samples,
    output wire sample_valid,output wire signed [15:0] sample,
    input wire sample_ready,output reg fifo_flush,
    output reg [3:0] error_code,
    output wire stream_end,
    output wire [3:0] debug_state
);
    localparam S_IDLE=0,S_CANCEL=1,S_VERIFY_REQ=2,S_VERIFY_WAIT=3,
        S_VERIFY_STREAM=4,S_GATE=5,S_PLAY_REQ=6,S_PLAY_WAIT=7,
        S_PLAY_STREAM=8,S_DONE=9,S_ERROR=10,S_STOP=11;
    reg [3:0] state;
    assign debug_state=state;
    reg gate_seen_low;
    reg requested_loop;
    reg fault_reported;
    reg [26:0] progress_timeout;
    reg [31:0] start_sample,skip_samples;
    reg [31:0] sample_limit,sent_samples;

    reg [31:0] opened_size;
    wire parser_ready,parser_data_start,parser_data_byte_valid;
    wire [7:0] parser_data_byte;
    wire parser_sample_valid,parser_data_finish;
    wire parser_done,parser_file_valid;wire signed [15:0] parser_sample;
    wire [3:0] parser_error;wire [31:0] parser_data_length,parser_sample_count;
    wire [31:0] parser_container_length,parser_container_crc;
    wire parser_output_ready=state!=S_PLAY_STREAM||skip_samples!=0||sample_ready;
    wire parsing=state==S_VERIFY_STREAM||state==S_PLAY_STREAM;

    assign file_abort=ENABLE_STOP&&(state==S_CANCEL||state==S_STOP||state==S_ERROR);
    assign file_ready=(state==S_CANCEL||state==S_ERROR||state==S_STOP) ? 1'b1 :
        (parsing&&parser_ready&&parser_output_ready);
    assign sample_valid=state==S_PLAY_STREAM&&skip_samples==0&&parser_sample_valid&&sample_ready&&external_allowed;
    assign sample=parser_sample;

    assign stream_end=state==S_PLAY_STREAM&&(parser_done||
        (ENABLE_WINDOW&&sample_limit!=0&&sample_valid&&sent_samples+1'b1==sample_limit));
    generate if(CANONICAL_PCM)begin: canonical_profile
    wav_canonical_pcm_parser #(.COMPUTE_CRC(!DIRECT_PLAY)) parser(.clk(clk),.rst(rst|play_request),.file_start(file_open_done),
        .byte_valid(parsing&&file_valid&&file_ready),.byte_data(file_data),
        .byte_ready(parser_ready),.file_end(parsing&&file_end),.sample_ready(parser_output_ready),
        .data_start(parser_data_start),.data_byte_valid(parser_data_byte_valid),
        .data_byte(parser_data_byte),.sample_valid(parser_sample_valid),.sample(parser_sample),
        .data_finish(parser_data_finish),.parse_done(parser_done),.file_valid(parser_file_valid),
        .error_reason(parser_error),.data_length(parser_data_length),.sample_count(parser_sample_count),
        .container_length(parser_container_length),.container_crc32(parser_container_crc));
    end else begin: general_profile
    wav_stream_parser #(.SAMPLE_BACKPRESSURE(1),.ENABLE_IMA(ENABLE_IMA)) parser(.clk(clk),.rst(rst|play_request),.file_start(file_open_done),
        .byte_valid(parsing&&file_valid&&file_ready),.byte_data(file_data),
        .byte_ready(parser_ready),.file_end(parsing&&file_end),
        .sample_ready(parser_output_ready),
        .data_start(parser_data_start),.data_byte_valid(parser_data_byte_valid),
        .data_byte(parser_data_byte),.sample_valid(parser_sample_valid),
        .sample(parser_sample),.data_finish(parser_data_finish),
        .parse_done(parser_done),.file_valid(parser_file_valid),
        .error_reason(parser_error),.data_length(parser_data_length),
        .sample_count(parser_sample_count),.container_length(parser_container_length),
        .container_crc32(parser_container_crc));
    end endgenerate

    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=S_IDLE;file_open_req<=0;file_index<=0;gate_seen_low<=0;requested_loop<=0;
            asset_begin_toggle<=0;asset_complete_toggle<=0;
            asset_purpose<=0;asset_length<=0;asset_crc32<=0;
            asset_samples<=0;
            fifo_flush<=0;error_code<=0;
            fault_reported<=0;progress_timeout<=0;
            start_sample<=0;skip_samples<=0;opened_size<=0;sample_limit<=0;sent_samples<=0;
        end else begin
            fifo_flush<=0;

            if(state==S_IDLE||state==S_GATE||state==S_DONE||state==S_ERROR||
                    play_request||file_open_done||file_end||(ENABLE_IO_PROGRESS&&file_io_progress)||
                    (file_valid&&file_ready)||(parsing&&!file_ready))
                progress_timeout<=0;
            else if(progress_timeout<TIMEOUT_CYCLES-1)
                progress_timeout<=progress_timeout+1'b1;
            if(!external_allowed)gate_seen_low<=1;
            if(ENABLE_STOP&&stop_request)begin
                file_open_req<=0;requested_loop<=0;state<=S_STOP;
                fifo_flush<=1;error_code<=0;fault_reported<=0;
                asset_samples<=0;asset_begin_toggle<=!asset_begin_toggle;
                progress_timeout<=0;
            end else if(play_request)begin
                requested_loop<=loop_enable;
                file_index<=requested_index;asset_purpose<=8'h21+requested_index;
                asset_length<=0;asset_crc32<=0;asset_begin_toggle<=!asset_begin_toggle;
                asset_samples<=0;
                start_sample<=ENABLE_RESUME ? requested_start_sample : 32'd0;
                sample_limit<=ENABLE_WINDOW ? requested_sample_limit : 32'd0;sent_samples<=0;
                skip_samples<=0;
                fifo_flush<=1;error_code<=0;gate_seen_low<=!external_allowed;
                fault_reported<=0;

                file_open_req<=0;state<=(DIRECT_PLAY||file_busy) ? S_CANCEL : S_VERIFY_REQ;
            end else if((ENABLE_FILE_ERROR&&file_error!=0&&state!=S_ERROR)||
                    (progress_timeout==TIMEOUT_CYCLES-1&&state!=S_ERROR))begin
                error_code<=4;state<=S_ERROR;file_open_req<=0;
            end else case(state)
                S_IDLE:begin file_open_req<=0;end
                S_STOP:begin
                    file_open_req<=0;
                    if(!file_busy)state<=S_IDLE;
                end
                S_CANCEL:begin
                    file_open_req<=0;
                    if(!file_busy)state<=DIRECT_PLAY ? S_GATE : S_VERIFY_REQ;
                end
                S_VERIFY_REQ:begin
                    file_open_req<=1;
                    if(file_busy)begin file_open_req<=0;state<=S_VERIFY_WAIT;end
                end
                S_VERIFY_WAIT:begin
                    if(file_not_found)begin error_code<=1;state<=S_ERROR;end
                    else if(file_open_done)begin opened_size<=file_size;state<=S_VERIFY_STREAM;end
                end
                S_VERIFY_STREAM:begin
                    if(parser_done)begin
                        if(parser_file_valid&&parser_container_length==opened_size&&
                                start_sample<parser_sample_count)begin
                            asset_length<=parser_container_length;asset_crc32<=parser_container_crc;
                            asset_samples<=parser_sample_count;
                            asset_complete_toggle<=!asset_complete_toggle;state<=S_GATE;
                        end else begin error_code<={1'b1,parser_error[2:0]};state<=S_ERROR;end
                    end
                end
                S_GATE:begin
                    if((DIRECT_PLAY||gate_seen_low)&&external_allowed)state<=S_PLAY_REQ;
                end
                S_PLAY_REQ:begin
                    file_open_req<=1;
                    if(file_busy)begin file_open_req<=0;state<=S_PLAY_WAIT;end
                end
                S_PLAY_WAIT:begin
                    if(file_not_found)begin error_code<=2;state<=S_ERROR;end
                    else if(file_open_done)begin skip_samples<=start_sample;state<=S_PLAY_STREAM;end
                end
                S_PLAY_STREAM:begin

                    if(DIRECT_PLAY&&parser_data_start)begin
                        if(start_sample<(parser_data_length>>1)&&
                           (!ENABLE_WINDOW||sample_limit==0||sample_limit<=((parser_data_length>>1)-start_sample)))begin
                            asset_samples<=ENABLE_WINDOW&&sample_limit!=0 ? sample_limit : parser_data_length>>1;
                            asset_length<=0;asset_crc32<=0;
                            asset_complete_toggle<=!asset_complete_toggle;
                        end else begin error_code<=8;state<=S_ERROR;end
                    end
                    if(parser_sample_valid&&parser_output_ready&&skip_samples!=0)
                        skip_samples<=skip_samples-1'b1;
                    if(ENABLE_WINDOW&&sample_valid&&sample_limit!=0)begin
                        sent_samples<=sent_samples+1'b1;

                        if(sent_samples+1'b1==sample_limit)state<=S_STOP;
                    end
                    if(!external_allowed)begin error_code<=3;state<=S_ERROR;end
                    else if(parser_done)begin
                        if(parser_file_valid&&(DIRECT_PLAY||
                                (parser_container_length==asset_length&&
                                parser_container_crc==asset_crc32&&parser_sample_count==asset_samples)))
                            state<=S_DONE;
                        else begin error_code<={1'b1,parser_error[2:0]};state<=S_ERROR;end
                    end
                end
                S_DONE:begin
                    file_open_req<=0;
                    if((DIRECT_PLAY ? requested_loop : loop_enable) && external_allowed)state<=S_PLAY_REQ;
                end
                S_ERROR:begin
                    file_open_req<=0;
                    if(!fault_reported)begin
                        asset_begin_toggle<=!asset_begin_toggle;
                        fifo_flush<=1;fault_reported<=1;
                    end
                end
                default:begin file_open_req<=0;state<=S_ERROR;end
            endcase
        end
    end
endmodule
