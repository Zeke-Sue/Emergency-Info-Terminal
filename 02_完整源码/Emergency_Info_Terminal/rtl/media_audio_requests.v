`timescale 1ns/1ps

module media_audio_requests #(parameter integer CONFIGURED_PLAYLIST=0)(
    input wire clk,rst,frame_tick,ready,narration_enable,
    input wire [3:0] image_index,input wire alarm_active,
    input wire [2:0] alarm_kind,
    input wire [3:0] configured_narration_index,
    input wire configuration_valid,
    output reg request,output reg [3:0] asset_index,
    output reg alarm_asset
);
    reg have_request;
    wire [3:0] narration_index=CONFIGURED_PLAYLIST ? configured_narration_index :
        image_index<10 ? image_index : image_index-4'd10;
    wire [3:0] desired=alarm_active ? (alarm_kind==0 ? 4'd10 : 4'd11) : narration_index;
    reg [3:0] previous_image;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            request<=0;asset_index<=0;alarm_asset<=0;have_request<=0;previous_image<=0;
        end else begin
            request<=0;
            if(CONFIGURED_PLAYLIST && !configuration_valid)begin
                have_request<=0;
            end else if(alarm_active && (!have_request || !alarm_asset || desired!=asset_index))begin
                request<=1;asset_index<=desired;alarm_asset<=1;have_request<=1;
            end else if(!alarm_active && frame_tick && ready && narration_enable &&
                    (!have_request || alarm_asset || image_index!=previous_image))begin
                request<=1;asset_index<=desired;alarm_asset<=0;have_request<=1;
                previous_image<=image_index;
            end
        end
    end
endmodule
