`timescale 1ns/1ps

module emergency_audio_mixer #(
    parameter integer ENABLE_EXTERNAL_ALARM=0,
    parameter integer SOURCE_FADES=0,
    parameter integer FADE_SAMPLES=240,
    parameter integer PIPELINED_MIX=0
)(
    input wire clk,
    input wire rst,
    input wire sample_valid,
    input wire signed [15:0] normal_sample,
    input wire alarm_active,
    input wire [2:0] alarm_kind,
    input wire voice_valid,
    input wire signed [15:0] voice_sample,
    input wire prompt_valid,
    input wire signed [15:0] prompt_sample,
    input wire external_alarm_valid,input wire signed [15:0] external_alarm_sample,
    output reg signed [15:0] mixed_sample,
    output reg signed [17:0] unlimited_sample,
    output reg output_valid,
    output wire alarm_overrun
);
    wire signed [15:0] tone_sum,earthquake_tone,site_tone;
    wire site_mode=SOURCE_FADES&&alarm_kind!=0;
    assign tone_sum=site_mode ? site_tone : earthquake_tone;
    wire tone_ready,tone_overrun;
    localparam GAIN_BITS=$clog2(FADE_SAMPLES+1);
    localparam PRODUCT_BITS=17+GAIN_BITS;
    localparam SUM_BITS=PRODUCT_BITS+3;
    localparam signed [SUM_BITS-1:0] FADE_DIVISOR=FADE_SAMPLES;
    localparam PIPELINE=PIPELINED_MIX&&SOURCE_FADES;
    reg pending_sample;
    reg signed [15:0] normal_q,tone_q,external_q,voice_q,prompt_q;
    reg [GAIN_BITS-1:0] normal_gain,tone_gain,external_gain,voice_gain,prompt_gain;
    wire signed [15:0] alarm_sample=(ENABLE_EXTERNAL_ALARM && external_alarm_valid) ?
        external_alarm_sample : tone_sum;
    assign alarm_overrun=tone_overrun;
    earthquake_tone_generator generator(.clk(clk),.rst(rst),
        .enable(!site_mode&&(alarm_active||(SOURCE_FADES&&tone_gain!=0))),
        .sample_tick(sample_valid),.tone(earthquake_tone),.ready(tone_ready),.overrun(tone_overrun));
    site_notice_tone site_generator(.clk(clk),.rst(rst),
        .enable(site_mode&&(alarm_active||tone_gain!=0)),.sample_tick(sample_valid),.tone(site_tone));
    reg signed [17:0] mix_value;
    reg signed [15:0] held_voice,held_prompt,held_external;
    reg [GAIN_BITS-1:0] target_normal,target_tone,target_external,target_voice,target_prompt;
    reg [GAIN_BITS-1:0] next_normal,next_tone,next_external,next_voice,next_prompt;
    reg signed [PRODUCT_BITS-1:0] normal_product,tone_product,external_product,voice_product,prompt_product;
    wire signed [SUM_BITS-1:0] product_sum=normal_product+tone_product+external_product+voice_product+prompt_product;
    function [GAIN_BITS-1:0] approach;
        input [GAIN_BITS-1:0] current,target;
        begin approach=current<target ? current+1 : current>target ? current-1 : current;end
    endfunction
    always @* begin
        target_normal=alarm_active ? 0 : (prompt_valid ? FADE_SAMPLES/2 : FADE_SAMPLES);
        target_tone=alarm_active&&!(ENABLE_EXTERNAL_ALARM&&external_alarm_valid) ?
            (voice_valid ? FADE_SAMPLES/2 : FADE_SAMPLES) : 0;
        target_external=alarm_active&&ENABLE_EXTERNAL_ALARM&&external_alarm_valid ?
            (voice_valid ? FADE_SAMPLES/2 : FADE_SAMPLES) : 0;
        target_voice=alarm_active&&voice_valid ? FADE_SAMPLES/2 : 0;
        target_prompt=!alarm_active&&prompt_valid ? FADE_SAMPLES/2 : 0;
        next_normal=approach(normal_gain,target_normal);
        next_tone=approach(tone_gain,target_tone);
        next_external=approach(external_gain,target_external);
        next_voice=approach(voice_gain,target_voice);
        next_prompt=approach(prompt_gain,target_prompt);
        normal_product=$signed(PIPELINE ? normal_q : normal_sample)*$signed({1'b0,(PIPELINE ? normal_gain : next_normal)});
        tone_product=$signed(PIPELINE ? tone_q : tone_sum)*$signed({1'b0,(PIPELINE ? tone_gain : next_tone)});
        external_product=$signed(PIPELINE ? external_q : (external_alarm_valid ? external_alarm_sample : held_external))*$signed({1'b0,(PIPELINE ? external_gain : next_external)});
        voice_product=$signed(PIPELINE ? voice_q : (voice_valid ? voice_sample : held_voice))*$signed({1'b0,(PIPELINE ? voice_gain : next_voice)});
        prompt_product=$signed(PIPELINE ? prompt_q : (prompt_valid ? prompt_sample : held_prompt))*$signed({1'b0,(PIPELINE ? prompt_gain : next_prompt)});
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            mixed_sample<=0;
            unlimited_sample<=0;output_valid<=0;
            normal_gain<=0;tone_gain<=0;external_gain<=0;voice_gain<=0;prompt_gain<=0;
            held_voice<=0;held_prompt<=0;held_external<=0;
            pending_sample<=0;normal_q<=0;tone_q<=0;external_q<=0;voice_q<=0;prompt_q<=0;
        end else begin
            pending_sample<=sample_valid;
            output_valid<=PIPELINE ? pending_sample : sample_valid;
            if(sample_valid&&SOURCE_FADES)begin
                normal_gain<=next_normal;tone_gain<=next_tone;external_gain<=next_external;
                voice_gain<=next_voice;prompt_gain<=next_prompt;
                if(voice_valid)held_voice<=voice_sample;
                if(prompt_valid)held_prompt<=prompt_sample;
                if(external_alarm_valid)held_external<=external_alarm_sample;
                if(PIPELINE)begin
                    normal_q<=normal_sample;tone_q<=tone_sum;
                    external_q<=external_alarm_valid ? external_alarm_sample : held_external;
                    voice_q<=voice_valid ? voice_sample : held_voice;
                    prompt_q<=prompt_valid ? prompt_sample : held_prompt;
                end
            end
            if(PIPELINE ? pending_sample : sample_valid)begin
            if(SOURCE_FADES)begin
                mix_value=product_sum/FADE_DIVISOR;
            end else begin
                mix_value=alarm_active ? (voice_valid ? ((alarm_sample>>>1)+(voice_sample>>>1)) : alarm_sample) : normal_sample;
                if(prompt_valid)mix_value=mix_value+(prompt_sample>>>1);
            end
            unlimited_sample<=mix_value;
            if(mix_value>32767)mixed_sample<=32767;
            else if(mix_value< -32768)mixed_sample<=-32768;
            else mixed_sample<=mix_value[15:0];
            end
        end
    end
endmodule
