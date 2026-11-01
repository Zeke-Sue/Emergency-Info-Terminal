`timescale 1ns/1ps

module voice_segment_player #(
    parameter integer GAP_SAMPLES=1440,
    parameter integer ENABLE_CANCEL=0,
    parameter integer FADE_SAMPLES=0
)(
    input wire clk,rst,sample_tick,enqueue_valid,
    input wire [5:0] enqueue_segment,
    input wire enqueue_urgent,
    output wire enqueue_ready,
    input wire cancel_queue,
    input wire cfg_we,
    input wire [5:0] cfg_segment,
    input wire [15:0] cfg_start,cfg_length,
    output reg [15:0] rom_address,
    input wire [3:0] rom_nibble,
    output reg voice_valid,
    output reg signed [15:0] voice_sample,
    output reg playing,
    output wire active_audio,
    output reg [5:0] active_segment,
    output reg queue_overflow,
    output reg decode_underflow
);
    reg [5:0] metadata_address;
    wire [31:0] metadata_q;
    buffer_ram #(.DATA_WIDTH(32),.ADDR_WIDTH(6)) segment_metadata(
        .clk(clk),.we(cfg_we),.wa(cfg_segment),.ra(metadata_address),
        .d({cfg_start,cfg_length}),.q(metadata_q));
    reg [5:0] queue [0:15];
    reg [3:0] read_pointer,write_pointer;
    reg [4:0] queue_count;
    reg [15:0] nibble_position,active_length;
    reg [2:0] metadata_wait,fetch_wait,upsample_phase;
    localparam GAP_BITS=GAP_SAMPLES>0 ? $clog2(GAP_SAMPLES+1) : 1;
    localparam FADE_BITS=FADE_SAMPLES>0 ? $clog2(FADE_SAMPLES+1) : 1;
    localparam PRODUCT_BITS=17+FADE_BITS;
    localparam signed [PRODUCT_BITS-1:0] FADE_DIVISOR=FADE_SAMPLES==0 ? 1 : FADE_SAMPLES;
    reg [GAP_BITS-1:0] gap_left;
    reg [FADE_BITS-1:0] fade_left,fade_in;
    reg decode_valid,decode_restart,first_decode,next_ready;
    reg output_present;
    wire decode_sample_valid;
    wire signed [15:0] decoded_sample;
    reg signed [15:0] previous_sample,target_sample,next_sample,fade_hold;
    reg signed [15:0] interpolated;
    reg [18:0] remaining_samples;
    reg [FADE_BITS-1:0] gain;
    wire signed [16:0] sample_difference=$signed({target_sample[15],target_sample})-
        $signed({previous_sample[15],previous_sample});
    wire signed [3:0] phase_weight=$signed({1'b0,upsample_phase})+4'sd1;
    wire signed [20:0] interpolation_product=sample_difference*phase_weight;
    reg signed [PRODUCT_BITS-1:0] scaled_sample;
    assign enqueue_ready=queue_count<16;
    assign active_audio=output_present;
    ima_adpcm_decoder decoder(.clk(clk),.rst(rst),.restart(decode_restart),
        .seed_valid(1'b0),.seed_predictor(16'd0),.seed_index(7'd0),
        .nibble_valid(decode_valid),.nibble(rom_nibble),.sample_valid(decode_sample_valid),
        .pcm_sample(decoded_sample),.step_index());
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            read_pointer<=0;write_pointer<=0;queue_count<=0;nibble_position<=0;
            active_length<=0;metadata_address<=0;metadata_wait<=0;fetch_wait<=0;
            gap_left<=0;fade_left<=0;fade_in<=0;fade_hold<=0;
            upsample_phase<=0;decode_valid<=0;decode_restart<=0;rom_address<=0;
            voice_valid<=0;voice_sample<=0;playing<=0;active_segment<=0;queue_overflow<=0;
            decode_underflow<=0;previous_sample<=0;target_sample<=0;next_sample<=0;
            first_decode<=0;next_ready<=0;
            output_present<=0;
        end else begin
            decode_valid<=0;decode_restart<=0;voice_valid<=0;queue_overflow<=0;
            if(metadata_wait==1)metadata_wait<=2;
            else if(metadata_wait==2)begin
                metadata_wait<=0;rom_address<=metadata_q[31:16];active_length<=metadata_q[15:0];
                nibble_position<=0;upsample_phase<=0;decode_restart<=1;
                previous_sample<=0;target_sample<=0;next_sample<=0;next_ready<=0;fade_in<=0;
                first_decode<=metadata_q[15:0]!=0;
                fetch_wait<=metadata_q[15:0]!=0 ? 3 : 0;
            end
            if(fetch_wait!=0)begin
                fetch_wait<=fetch_wait-1'b1;
                if(fetch_wait==1)decode_valid<=1;
            end
            if(decode_sample_valid)begin
                if(first_decode)begin target_sample<=decoded_sample;playing<=1;first_decode<=0;end
                else begin next_sample<=decoded_sample;next_ready<=1;end
            end
            if(enqueue_valid&&!enqueue_urgent)begin
                if(enqueue_ready)begin
                    queue[write_pointer]<=enqueue_segment;write_pointer<=write_pointer+1'b1;
                    queue_count<=queue_count+1'b1;
                end else queue_overflow<=1;
            end
            if(sample_tick)begin
                voice_valid<=playing||fade_left!=0;
                output_present<=playing||fade_left!=0;
                if(fade_left!=0)begin
                    scaled_sample=$signed(fade_hold)*$signed({1'b0,fade_left-1'b1});
                    voice_sample<=FADE_SAMPLES!=0 ? scaled_sample/FADE_DIVISOR : 0;
                    fade_left<=fade_left-1'b1;
                end else if(gap_left!=0)begin gap_left<=gap_left-1'b1;voice_sample<=0;end
                else if(!playing&&metadata_wait==0&&!first_decode&&queue_count!=0&&!enqueue_valid)begin
                    active_segment<=queue[read_pointer];read_pointer<=read_pointer+1'b1;
                    queue_count<=queue_count-1'b1;metadata_address<=queue[read_pointer];metadata_wait<=1;
                end else if(playing)begin
                    interpolated=$signed(previous_sample)+
                        interpolation_product/21'sd6;
                    remaining_samples=(active_length-nibble_position)*6-upsample_phase;
                    gain=FADE_SAMPLES;
                    if(fade_in<FADE_SAMPLES)begin gain=fade_in+1;fade_in<=fade_in+1'b1;end
                    if(remaining_samples<gain)gain=remaining_samples;
                    scaled_sample=interpolated*$signed({1'b0,gain});
                    voice_sample<=FADE_SAMPLES!=0 ? scaled_sample/FADE_DIVISOR : interpolated;
                    if(upsample_phase==0&&nibble_position+1<active_length)begin
                        rom_address<=rom_address+1'b1;fetch_wait<=2;
                    end
                    if(upsample_phase==5)begin
                        upsample_phase<=0;
                        if(nibble_position+1>=active_length)begin
                            playing<=0;gap_left<=GAP_SAMPLES;nibble_position<=0;
                        end else if(next_ready)begin
                            nibble_position<=nibble_position+1'b1;
                            previous_sample<=target_sample;target_sample<=next_sample;next_ready<=0;
                        end else begin playing<=0;decode_underflow<=1;end
                    end else upsample_phase<=upsample_phase+1'b1;
                end
            end

            if((ENABLE_CANCEL&&cancel_queue)||(enqueue_valid&&enqueue_urgent))begin
                read_pointer<=0;write_pointer<=enqueue_valid&&enqueue_urgent ? 1 : 0;
                queue_count<=enqueue_valid&&enqueue_urgent ? 1 : 0;
                if(enqueue_valid&&enqueue_urgent)queue[0]<=enqueue_segment;
                fade_hold<=voice_sample;fade_left<=active_audio ? FADE_SAMPLES : 0;
                playing<=0;metadata_wait<=0;fetch_wait<=0;first_decode<=0;next_ready<=0;
                gap_left<=0;decode_valid<=0;decode_restart<=1;
            end
        end
    end
endmodule
