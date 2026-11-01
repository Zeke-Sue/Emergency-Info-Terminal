`timescale 1ns/1ps

module wav_stream_parser #(
    parameter integer SAMPLE_BACKPRESSURE=0,
    parameter integer ENABLE_IMA=1
)(
    input wire clk,input wire rst,input wire file_start,
    input wire byte_valid,input wire [7:0] byte_data,output wire byte_ready,
    input wire file_end,input wire sample_ready,
    output reg data_start,output wire data_byte_valid,output wire [7:0] data_byte,
    output reg sample_valid,output reg signed [15:0] sample,
    output reg data_finish,output reg parse_done,output reg file_valid,
    output reg [3:0] error_reason,
    output reg [31:0] data_length,output reg [31:0] sample_count,
    output reg [15:0] audio_format,output reg [31:0] sample_rate,
    output reg [15:0] channels,
    output reg [31:0] container_length,output wire [31:0] container_crc32
);
    localparam S_HEADER=0,S_CHUNK_HEADER=1,S_FMT=2,S_DATA=3,
        S_SKIP=4,S_PAD=5,S_DATA_FINISH=6,S_ERROR=7,S_FACT=8;
    localparam A_IDLE=0,A_LOW=1,A_LOW_WAIT=2,A_HIGH=3,
        A_HIGH_WAIT=4,A_SEED_WAIT=5,A_REPEAT=6;
    reg [3:0] state;
    reg [2:0] audio_state;
    reg active,header_valid,fmt_seen,data_seen,fact_seen,end_pending;
    reg [4:0] index;
    reg [31:0] chunk_id,chunk_size,remaining,riff_size,byte_rate,fact_samples;
    reg [31:0] crc,decoded_count;
    reg [15:0] bits_per_sample,block_align,samples_per_block,extension_size;
    reg [15:0] block_position,seed_predictor;
    reg [6:0] seed_index;
    reg [7:0] low_byte,encoded_byte;
    reg sample_half,chunk_odd,have_previous;
    reg signed [15:0] previous_sample,repeat_sample;
    wire output_ready=SAMPLE_BACKPRESSURE ? sample_ready : 1'b1;
    wire output_free=!sample_valid||output_ready;
    wire ima=ENABLE_IMA&&audio_format==16'h0011;
    wire pcm_ok=audio_format==1&&channels==1&&sample_rate==48000&&
        bits_per_sample==16&&block_align==2&&byte_rate==96000;
    wire ima_ok=ima&&channels==1&&sample_rate==24000&&bits_per_sample==4&&
        block_align>=4&&block_align<=32767&&extension_size>=2&&
        samples_per_block==(({1'b0,block_align}-17'd4)<<1)+17'd1&&
        fact_seen&&fact_samples!=0&&!fact_samples[31];
    wire [31:0] complete_size={byte_data,chunk_size[23:0]};
    wire take_byte=byte_valid&&byte_ready;
    assign byte_ready=active&&!end_pending&&state!=S_DATA_FINISH&&
        audio_state==A_IDLE&&output_free;
    assign data_byte_valid=take_byte&&state==S_DATA;
    assign data_byte=byte_data;
    assign container_crc32=~crc;

    wire seed_valid=take_byte&&state==S_DATA&&ima&&block_position==3&&byte_data==0;
    wire nibble_valid=(audio_state==A_LOW||audio_state==A_HIGH)&&output_free;
    wire [3:0] nibble=audio_state==A_LOW ? encoded_byte[3:0] : encoded_byte[7:4];
    wire decoded_valid;wire signed [15:0] decoded_sample;
    wire [6:0] decoder_index;
    generate if(ENABLE_IMA)begin: ima_decoder
    ima_adpcm_decoder #(.SEEDED_BLOCKS(1)) decoder(
        .clk(clk),.rst(rst),.restart(file_start),.seed_valid(seed_valid),
        .seed_predictor(seed_predictor),.seed_index(seed_index),
        .nibble_valid(nibble_valid),.nibble(nibble),
        .sample_valid(decoded_valid),.pcm_sample(decoded_sample),.step_index(decoder_index));
    end else begin: pcm_only
        assign decoded_valid=0;
        assign decoded_sample=0;
        assign decoder_index=0;
    end endgenerate
    reg [2:0] after_repeat;
    wire signed [16:0] interpolation_sum=
        {previous_sample[15],previous_sample}+{decoded_sample[15],decoded_sample};

    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer k;reg [31:0] work;
        begin
            work=current^value;
            for(k=0;k<8;k=k+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction
    task reject;
        input [3:0] reason;
        begin state<=S_ERROR;if(error_reason==0)error_reason<=reason;end
    endtask
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=S_HEADER;audio_state<=A_IDLE;active<=0;end_pending<=0;
            header_valid<=0;fmt_seen<=0;data_seen<=0;fact_seen<=0;index<=0;
            chunk_id<=0;chunk_size<=0;remaining<=0;riff_size<=0;byte_rate<=0;
            fact_samples<=0;crc<=32'hffffffff;decoded_count<=0;
            bits_per_sample<=0;block_align<=0;samples_per_block<=0;extension_size<=0;
            block_position<=0;seed_predictor<=0;seed_index<=0;low_byte<=0;
            encoded_byte<=0;sample_half<=0;chunk_odd<=0;have_previous<=0;
            previous_sample<=0;repeat_sample<=0;after_repeat<=A_IDLE;
            data_start<=0;sample_valid<=0;sample<=0;data_finish<=0;
            parse_done<=0;file_valid<=0;error_reason<=0;data_length<=0;sample_count<=0;
            audio_format<=0;sample_rate<=0;channels<=0;container_length<=0;
        end else begin
            data_start<=0;data_finish<=0;parse_done<=0;
            if(sample_valid&&output_ready)sample_valid<=0;
            if(file_start)begin
                state<=S_HEADER;audio_state<=A_IDLE;active<=1;end_pending<=0;
                header_valid<=1;fmt_seen<=0;data_seen<=0;fact_seen<=0;index<=0;
                chunk_id<=0;chunk_size<=0;remaining<=0;riff_size<=0;
                sample_half<=0;sample_valid<=0;file_valid<=0;error_reason<=0;
                data_length<=0;sample_count<=0;container_length<=0;crc<=32'hffffffff;
                decoded_count<=0;block_position<=0;have_previous<=0;
                audio_format<=0;sample_rate<=0;channels<=0;byte_rate<=0;
                bits_per_sample<=0;block_align<=0;extension_size<=0;samples_per_block<=0;
                fact_samples<=0;
            end else if(active)begin
                if(file_end)end_pending<=1;

                if(end_pending&&audio_state==A_IDLE&&!sample_valid&&state!=S_DATA_FINISH)begin
                    active<=0;parse_done<=1;
                    file_valid<=error_reason==0&&header_valid&&fmt_seen&&data_seen&&
                        state==S_CHUNK_HEADER&&index==0&&
                        {1'b0,container_length}=={1'b0,riff_size}+33'd8;
                    if(error_reason==0&&!(header_valid&&fmt_seen&&data_seen&&
                            state==S_CHUNK_HEADER&&index==0&&
                            {1'b0,container_length}=={1'b0,riff_size}+33'd8))error_reason<=2;
                end
                if(nibble_valid)audio_state<=audio_state==A_LOW ? A_LOW_WAIT : A_HIGH_WAIT;
                if(decoded_valid)begin
                    decoded_count<=decoded_count+1'b1;
                    if(decoded_count<fact_samples)begin
                        sample<=have_previous ? (interpolation_sum>>>1) : decoded_sample;
                        sample_valid<=1;sample_count<=sample_count+1'b1;
                        repeat_sample<=decoded_sample;previous_sample<=decoded_sample;
                        have_previous<=1;audio_state<=A_REPEAT;
                        after_repeat<=audio_state==A_LOW_WAIT ? A_HIGH : A_IDLE;
                    end else audio_state<=audio_state==A_LOW_WAIT ? A_HIGH : A_IDLE;
                end
                if(audio_state==A_REPEAT&&output_free)begin
                    sample<=repeat_sample;sample_valid<=1;sample_count<=sample_count+1'b1;
                    audio_state<=after_repeat;
                end
                if(take_byte)begin
                    container_length<=container_length+1'b1;crc<=crc32_byte(crc,byte_data);
                    case(state)
                        S_HEADER:begin
                            case(index)
                                0:if(byte_data!="R")header_valid<=0;
                                1:if(byte_data!="I")header_valid<=0;
                                2:if(byte_data!="F")header_valid<=0;
                                3:if(byte_data!="F")header_valid<=0;
                                4:riff_size[7:0]<=byte_data;
                                5:riff_size[15:8]<=byte_data;
                                6:riff_size[23:16]<=byte_data;
                                7:riff_size[31:24]<=byte_data;
                                8:if(byte_data!="W")header_valid<=0;
                                9:if(byte_data!="A")header_valid<=0;
                                10:if(byte_data!="V")header_valid<=0;
                                11:if(byte_data!="E")header_valid<=0;
                            endcase
                            if(index==11)begin
                                index<=0;
                                if(header_valid&&byte_data=="E"&&riff_size>=4&&riff_size<=32'hfffffff7)
                                    state<=S_CHUNK_HEADER;
                                else reject(1);
                            end else index<=index+1'b1;
                        end
                        S_CHUNK_HEADER:begin
                            if(index<4)chunk_id<={chunk_id[23:0],byte_data};
                            else case(index)
                                4:chunk_size[7:0]<=byte_data;
                                5:chunk_size[15:8]<=byte_data;
                                6:chunk_size[23:16]<=byte_data;
                                7:begin
                                    chunk_size<=complete_size;remaining<=complete_size;
                                    chunk_odd<=complete_size[0];index<=0;
                                    if({1'b0,container_length}+33'd1+{1'b0,complete_size}+
                                            complete_size[0]>{1'b0,riff_size}+33'd8)reject(2);
                                    else if(chunk_id==32'h666d7420)begin
                                        if(complete_size<16||fmt_seen||data_seen)reject(3);
                                        else begin state<=S_FMT;fmt_seen<=1;end
                                    end else if(chunk_id==32'h66616374)begin
                                        if(complete_size<4||fact_seen||data_seen)reject(3);
                                        else begin state<=S_FACT;fact_seen<=1;end
                                    end else if(chunk_id==32'h64617461)begin
                                        if(!fmt_seen||!(pcm_ok||ima_ok)||data_seen||
                                                complete_size==0||(pcm_ok&&complete_size[0]))reject(3);
                                        else begin
                                            state<=S_DATA;data_seen<=1;data_length<=complete_size;
                                            data_start<=1;sample_half<=0;block_position<=0;
                                        end
                                    end else state<=complete_size==0 ? S_CHUNK_HEADER : S_SKIP;
                                end
                            endcase
                            if(index!=7)index<=index+1'b1;
                        end
                        S_FMT,S_FACT,S_SKIP:begin
                            if(state==S_FMT)case(index)
                                0:audio_format[7:0]<=byte_data;
                                1:audio_format[15:8]<=byte_data;
                                2:channels[7:0]<=byte_data;
                                3:channels[15:8]<=byte_data;
                                4:sample_rate[7:0]<=byte_data;
                                5:sample_rate[15:8]<=byte_data;
                                6:sample_rate[23:16]<=byte_data;
                                7:sample_rate[31:24]<=byte_data;
                                8:byte_rate[7:0]<=byte_data;
                                9:byte_rate[15:8]<=byte_data;
                                10:byte_rate[23:16]<=byte_data;
                                11:byte_rate[31:24]<=byte_data;
                                12:block_align[7:0]<=byte_data;
                                13:block_align[15:8]<=byte_data;
                                14:bits_per_sample[7:0]<=byte_data;
                                15:bits_per_sample[15:8]<=byte_data;
                                16:extension_size[7:0]<=byte_data;
                                17:extension_size[15:8]<=byte_data;
                                18:samples_per_block[7:0]<=byte_data;
                                19:samples_per_block[15:8]<=byte_data;
                            endcase
                            if(state==S_FACT)case(index)
                                0:fact_samples[7:0]<=byte_data;
                                1:fact_samples[15:8]<=byte_data;
                                2:fact_samples[23:16]<=byte_data;
                                3:fact_samples[31:24]<=byte_data;
                            endcase

                            if(index!=31)index<=index+1'b1;
                            remaining<=remaining-1'b1;
                            if(remaining==1)begin
                                index<=0;chunk_id<=0;chunk_size<=0;
                                state<=chunk_odd ? S_PAD : S_CHUNK_HEADER;
                                if(state==S_FMT&&audio_format==17&&
                                        (chunk_size<20||{16'd0,extension_size}+32'd18>chunk_size))reject(3);
                            end
                        end
                        S_DATA:begin
                            remaining<=remaining-1'b1;
                            if(ima)begin
                                block_position<=block_position==block_align-1'b1 ?
                                    16'd0 : block_position+1'b1;
                                case(block_position)
                                    0:seed_predictor[7:0]<=byte_data;
                                    1:seed_predictor[15:8]<=byte_data;
                                    2:begin seed_index<=byte_data[6:0];if(byte_data>88)reject(6);end
                                    3:begin
                                        if(byte_data!=0)reject(6);
                                        else audio_state<=A_SEED_WAIT;
                                    end
                                    default:begin encoded_byte<=byte_data;audio_state<=A_LOW;end
                                endcase
                            end else if(!sample_half)begin low_byte<=byte_data;sample_half<=1;end
                            else begin
                                sample<={byte_data,low_byte};sample_valid<=1;
                                sample_count<=sample_count+1'b1;sample_half<=0;
                            end
                            if(remaining==1)begin
                                if(ima&&block_position<3)reject(6);
                                else if(error_reason==0&&!(ima&&block_position==3&&byte_data!=0))
                                    state<=S_DATA_FINISH;
                            end
                        end
                        S_PAD:begin state<=S_CHUNK_HEADER;chunk_id<=0;chunk_size<=0;index<=0;end
                        S_ERROR:begin end
                        default:reject(2);
                    endcase
                end
                if(state==S_DATA_FINISH&&audio_state==A_IDLE&&!sample_valid)begin
                    data_finish<=1;chunk_id<=0;chunk_size<=0;index<=0;
                    state<=chunk_odd ? S_PAD : S_CHUNK_HEADER;
                    if(ima&&(decoded_count<fact_samples||decoded_count-fact_samples>=samples_per_block))reject(6);
                end
            end
        end
    end
endmodule
