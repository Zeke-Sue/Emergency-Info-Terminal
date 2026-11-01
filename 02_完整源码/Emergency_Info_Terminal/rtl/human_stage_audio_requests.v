`timescale 1ns/1ps

module human_stage_audio_requests #(parameter integer EXPLICIT_RELEASE=0,
    parameter integer RESTART_DAILY=0,ROUTE_GUIDANCE=0,ROUTE_STABLE_FRAMES=30)(
    input wire route_enabled,route_fresh,input wire [2:0] route_exit,input wire [1:0] route_status,
    output reg [31:0] route_start_sample,output wire route_speech_current,
    input wire release_request,
    input wire daily_blocked,
    input wire clk,rst,frame_tick,ready,narration_enable,configuration_valid,
    input wire [3:0] image_index,configured_narration_index,
    input wire alarm_active,alarm_drill,alarm_pending,
    input wire [2:0] alarm_kind,
    input wire asset_complete,input wire [7:0] asset_purpose,
    input wire [31:0] asset_samples,input wire consume,asset_failed,io_failed,
    output reg request,output reg [3:0] asset_index,
    output reg alarm_asset,voice_asset,
    output wire [7:0] voice_subtitle
);
    wire [2:0] stage=alarm_kind==0 ? 3'd1 : alarm_kind==3 ? 3'd4 :
        alarm_pending ? 3'd2 : 3'd3;
    wire [3:0] stage_index=stage==1 ? 4'd8 : stage==2 ? 4'd9 :
        stage==3 ? 4'd12 : 4'd13;
    wire [3:0] tone_index=alarm_kind==0 ? 4'd10 : 4'd11;
    reg have_request,had_alarm,previous_drill;
    reg [2:0] previous_stage;
    reg [3:0] previous_image;
    reg [23:0] remaining;
    reg measured;
    reg release_seen;
    wire [2:0] route_code=route_status==0 ? route_exit : 3'd4;
    reg [2:0] stable_code,spoken_code;reg [5:0] stable_frames;
    reg spoken;
    assign route_speech_current=!ROUTE_GUIDANCE||asset_index!=15||
        (route_enabled&&route_fresh&&route_code==spoken_code);
    always @(posedge clk or posedge rst)begin
        if(rst)begin stable_code<=0;stable_frames<=0;end
        else if(!route_enabled||!route_fresh||route_code!=stable_code)begin
            stable_code<=route_code;stable_frames<=0;
        end else if(frame_tick&&stable_frames<ROUTE_STABLE_FRAMES)stable_frames<=stable_frames+1'b1;
    end
    assign voice_subtitle=!voice_asset||(ROUTE_GUIDANCE&&asset_index==15) ? 0 : asset_index==8 ? 8'd9 :
        asset_index==9 ? 8'd10 : asset_index==12 ? 8'd11 :
        asset_index==13 ? 8'd12 : 8'd13;
    task finish_voice;
        begin
            remaining<=0;measured<=0;voice_asset<=0;
            if(alarm_active)begin
                request<=1;asset_index<=tone_index;alarm_asset<=1;have_request<=1;
            end else begin alarm_asset<=0;have_request<=0;end
        end
    endtask
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            request<=0;asset_index<=0;alarm_asset<=0;voice_asset<=0;
            have_request<=0;had_alarm<=0;previous_drill<=0;
            previous_stage<=0;previous_image<=0;remaining<=0;measured<=0;release_seen<=0;
            route_start_sample<=0;spoken<=0;spoken_code<=0;
        end else begin
            request<=0;
            if(!route_enabled||!route_fresh)spoken<=0;
            if(!release_request)release_seen<=0;
            if(!configuration_valid)begin
                have_request<=0;voice_asset<=0;remaining<=0;measured<=0;
                had_alarm<=0;spoken<=0;
            end else if(EXPLICIT_RELEASE&&release_request&&!release_seen)begin
                release_seen<=1;request<=1;asset_index<=14;voice_asset<=1;
                alarm_asset<=0;have_request<=1;had_alarm<=0;remaining<=0;measured<=0;
            end else if(alarm_active&&(!had_alarm||stage!=previous_stage||alarm_drill!=previous_drill))begin
                request<=1;asset_index<=alarm_drill ? stage_index : tone_index;
                voice_asset<=alarm_drill;alarm_asset<=1;have_request<=1;
                had_alarm<=1;previous_drill<=alarm_drill;previous_stage<=stage;
                remaining<=0;measured<=0;
            end else if(!alarm_active&&had_alarm)begin
                had_alarm<=0;remaining<=0;measured<=0;
                if(previous_drill)begin
                    request<=1;asset_index<=14;voice_asset<=1;alarm_asset<=0;have_request<=1;
                end else begin voice_asset<=0;alarm_asset<=0;have_request<=0;end
            end else if(voice_asset&&(!route_speech_current||io_failed||(measured&&asset_failed)))finish_voice;
            else if(voice_asset&&asset_complete&&asset_purpose==8'h21+asset_index)begin
                remaining<=asset_samples[23:0];measured<=1;
            end else if(voice_asset&&consume&&remaining!=0)begin
                if(remaining==1)finish_voice;
                else remaining<=remaining-1'b1;
            end else if(ROUTE_GUIDANCE&&alarm_active&&!voice_asset&&route_enabled&&route_fresh&&
                    stable_frames==ROUTE_STABLE_FRAMES&&(!spoken||spoken_code!=route_code)&&route_code!=0)begin
                request<=1;asset_index<=15;voice_asset<=1;alarm_asset<=1;have_request<=1;
                spoken<=1;spoken_code<=route_code;remaining<=0;measured<=0;
                case(route_code)
                    1:route_start_sample<=0;2:route_start_sample<=240000;
                    3:route_start_sample<=480000;default:route_start_sample<=720000;
                endcase
            end else if(RESTART_DAILY&&!alarm_active&&!voice_asset&&daily_blocked)begin

                have_request<=0;
            end else if(!alarm_active&&!voice_asset&&frame_tick&&ready&&narration_enable&&
                    (!have_request||image_index!=previous_image))begin
                request<=1;asset_index<=configured_narration_index;
                alarm_asset<=0;have_request<=1;previous_image<=image_index;
            end
        end
    end
endmodule
