`timescale 1ns/1ps

module narration_timeline #(
    parameter integer USE_ASSET_LENGTH=0,
    parameter integer ENABLE_RESUME=0
)(
    input wire clk,
    input wire rst,
    input wire sample_tick,
    input wire start,
    input wire stop,
    input wire pause,
    input wire [3:0] image_id,
    input wire [31:0] asset_samples,
    input wire [31:0] start_sample,
    input wire cfg_we,
    input wire [7:0] cfg_index,
    input wire [31:0] cfg_sample,
    input wire [7:0] cfg_subtitle,
    input wire cfg_last,
    output reg playing,
    output reg [47:0] elapsed_samples,
    output reg [7:0] subtitle_id,
    output reg [3:0] active_image,
    output reg narration_done,
    output reg [31:0] sentence_start_sample
);
    reg [7:0] read_address;
    reg [3:0] cue_index;
    reg [4:0] cue_count [0:15];
    reg [1:0] load_delay;
    reg [31:0] current_sample;
    reg [7:0] current_subtitle;
    reg current_last,current_valid;
    reg [31:0] sample_limit;
    wire [31:0] cue_q;
    buffer_ram #(.DATA_WIDTH(32),.ADDR_WIDTH(8)) cue_memory(
        .clk(clk),.we(cfg_we),.wa(cfg_index),.ra(read_address),
        .d({1'b0,cfg_last,cfg_subtitle,cfg_sample[21:0]}),.q(cue_q));
    integer i;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            playing<=0;elapsed_samples<=0;subtitle_id<=0;active_image<=0;
            narration_done<=0;read_address<=0;cue_index<=0;load_delay<=0;
            current_sample<=0;current_subtitle<=0;current_last<=0;current_valid<=0;
            sample_limit<=0;
            sentence_start_sample<=0;
            for(i=0;i<16;i=i+1) cue_count[i]<=0;
        end else begin
            narration_done<=0;
            if(cfg_we&&{1'b0,cfg_index[3:0]}+5'd1>cue_count[cfg_index[7:4]])
                cue_count[cfg_index[7:4]]<={1'b0,cfg_index[3:0]}+5'd1;
            if(stop) begin playing<=0;subtitle_id<=0;load_delay<=0;end
            else if(start) begin
                playing<=1;elapsed_samples<=ENABLE_RESUME ? start_sample : 32'd0;
                subtitle_id<=0;cue_index<=0;sentence_start_sample<=0;current_valid<=0;
                active_image<=image_id;read_address<={image_id,4'd0};load_delay<=2;
                sample_limit<=asset_samples;
            end else if(load_delay==2) load_delay<=1;
            else if(load_delay==1) begin
                current_sample<={10'd0,cue_q[21:0]};
                current_subtitle<=cue_q[29:22];current_last<=cue_q[30];
                current_valid<=cue_index<cue_count[active_image];load_delay<=0;
            end
            else if(playing && ((sample_tick && !pause)||
                    (ENABLE_RESUME&&current_valid&&elapsed_samples>=current_sample))) begin
                if(USE_ASSET_LENGTH&&elapsed_samples+1>=sample_limit)begin
                    if(sample_tick&&!pause)begin playing<=0;narration_done<=1;end
                end else if(!current_valid&&!USE_ASSET_LENGTH) begin playing<=0;narration_done<=1;end
                else if(current_valid&&elapsed_samples+1>=current_sample) begin
                    subtitle_id<=current_subtitle;
                    sentence_start_sample<=current_sample;
                    if(current_last) begin
                        current_valid<=0;
                        if(!USE_ASSET_LENGTH)begin playing<=0;narration_done<=1;end
                    end
                    else begin
                        cue_index<=cue_index+1'b1;
                        read_address<={active_image,cue_index+1'b1};load_delay<=2;
                    end
                end
            end

            if(!stop&&!start&&playing&&sample_tick&&!pause)
                elapsed_samples<=elapsed_samples+1'b1;
        end
    end
endmodule
