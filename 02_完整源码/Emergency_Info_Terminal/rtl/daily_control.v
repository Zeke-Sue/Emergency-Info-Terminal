`timescale 1ns/1ps

module daily_control #(
    parameter integer EXTENDED_MENU=0,
    parameter integer MAX_EFFECT_MODE=6,
    parameter integer FILMING_EFFECTS=0,
    parameter integer AUDIO_MENU=0,
    parameter integer ALERT_MENU=0,
    parameter integer V5_CONTROLS=0,
    parameter integer DIRECT_MENU=0,
    parameter integer DEFAULT_FOLLOW_NARRATION=0,
    parameter integer FOLLOW_SWITCH_CONTROL=0,
    parameter integer ENABLE_AUTO_CONTRAST=1,
    parameter integer MAINTENANCE_FRAMES=179
)(
    input wire clk, rst, frame_tick, maintenance_enable, grayscale_switch,
    input wire key1_short, key1_long, key2_short,
    input wire key3_short, key3_long, key4_long,
    input wire key4_short,night_switch,follow_switch,
    input wire [1:0] period_select,
    output reg follow_narration,
    output reg [1:0] zoom_scale,
    output reg [2:0] pan_x_level,pan_y_level,
    output reg auto_contrast_enable,
    output wire previous_event, next_event, auto_event, period_event, reload_event,
    output wire zoom_mode, grayscale_enable, osd_visible,
    output reg [2:0] brightness_level, contrast_level, saturation_level,
    output reg [1:0] gamma_mode,temperature_mode,
    output reg [2:0] effect_mode,
    output reg [1:0] effect_duration,
    output reg effect_easing,
    output reg [3:0] maintenance_selection,
    output reg [2:0] volume_level,
    output reg [1:0] flash_rate,flash_duty
);
    reg maintenance_active;
    reg maintenance_switch_q;
    reg zoom_requested,zoom_active;
    localparam INACTIVITY_BITS=MAINTENANCE_FRAMES<2 ? 1 : $clog2(MAINTENANCE_FRAMES);
    reg [INACTIVITY_BITS-1:0] inactivity_frames;
    reg night_active;
    reg mono_requested,mono_active,auto_requested;
    reg [1:0] zoom_level;
    reg [2:0] pan_x_requested,pan_y_requested;

    wire detail_navigation=V5_CONTROLS && zoom_level!=0;
    assign previous_event = key1_short && !key4_long && !maintenance_active && !detail_navigation;
    assign next_event = key2_short && !key1_short && !key4_long &&
                        !maintenance_active && !detail_navigation;
    assign auto_event = key3_short && !key3_long && !key4_long &&
                        !maintenance_active && !detail_navigation;
    assign period_event = key3_long && !key4_long && !maintenance_active && !detail_navigation &&
        (!V5_CONTROLS || (FOLLOW_SWITCH_CONTROL ? !follow_narration :
            follow_narration || period_select!=3));

    assign reload_event = !DIRECT_MENU && key4_long && !maintenance_enable;
    assign zoom_mode = V5_CONTROLS ? zoom_scale!=0 : zoom_active;
    assign grayscale_enable = V5_CONTROLS ? mono_active : grayscale_switch;
    assign osd_visible = maintenance_active;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            maintenance_active<=0;maintenance_selection<=0;maintenance_switch_q<=0;
            zoom_requested<=0;zoom_active<=0;
            brightness_level<=3'd2;contrast_level<=3'd2;
            saturation_level<=3'd2;
            gamma_mode<=1;temperature_mode<=1;inactivity_frames<=0;
            effect_mode<=0;effect_duration<=0;effect_easing<=0;
            volume_level<=7;flash_rate<=1;flash_duty<=1;
            night_active<=0;follow_narration<=DEFAULT_FOLLOW_NARRATION;
            mono_requested<=0;mono_active<=0;zoom_level<=0;zoom_scale<=0;
            pan_x_requested<=2;pan_y_requested<=2;pan_x_level<=2;pan_y_level<=2;
            auto_requested<=0;auto_contrast_enable<=0;
        end else begin
            maintenance_switch_q<=maintenance_enable;
            if(DIRECT_MENU)begin
                maintenance_active<=maintenance_enable;
                if(maintenance_enable&&!maintenance_switch_q)maintenance_selection<=0;
            end
            if(V5_CONTROLS&&frame_tick&&night_active!=night_switch)begin
                night_active<=night_switch;
                brightness_level<=night_switch ? 1 : 2;
                contrast_level<=2;saturation_level<=night_switch ? 1 : 2;
                gamma_mode<=night_switch ? 2 : 1;temperature_mode<=night_switch ? 0 : 1;
                volume_level<=night_switch ? 4 : 7;
            end

            if(FOLLOW_SWITCH_CONTROL)begin
                if(frame_tick)follow_narration<=follow_switch;
            end else if(V5_CONTROLS&&key3_long&&!key4_long&&!maintenance_active&&!detail_navigation)
                if(follow_narration)follow_narration<=0;
                else if(period_select==3)follow_narration<=1;
            if(!DIRECT_MENU)begin
                if(!maintenance_enable) maintenance_active<=0;
                else if(key4_long) maintenance_active<=!maintenance_active;
                if(V5_CONTROLS&&key4_short)maintenance_active<=0;
            end
            if(key1_long && !maintenance_active)begin
                zoom_requested<=!zoom_requested;
                if(V5_CONTROLS)zoom_level<=zoom_level==2 ? 0 : zoom_level+1'b1;
            end
            if(detail_navigation&&!maintenance_active&&!key4_long)begin
                if(key1_short&&pan_x_requested!=0)pan_x_requested<=pan_x_requested-1'b1;
                else if(key2_short&&pan_x_requested!=4)pan_x_requested<=pan_x_requested+1'b1;
                if((DIRECT_MENU ? key4_short : key3_long)&&pan_y_requested!=4)pan_y_requested<=pan_y_requested+1'b1;
                else if(key3_short&&pan_y_requested!=0)pan_y_requested<=pan_y_requested-1'b1;
            end
            if(frame_tick)begin
                zoom_active<=zoom_requested;zoom_scale<=zoom_level;
                mono_active<=mono_requested;auto_contrast_enable<=auto_requested;
                pan_x_level<=pan_x_requested;pan_y_level<=pan_y_requested;
            end
            if(key1_short||key2_short||key3_short||key4_long)inactivity_frames<=0;
            else if(!DIRECT_MENU&&frame_tick&&maintenance_active)begin
                if(inactivity_frames==MAINTENANCE_FRAMES-1)begin maintenance_active<=0;inactivity_frames<=0;end
                else inactivity_frames<=inactivity_frames+1'b1;
            end

            if(maintenance_active) begin
                if(DIRECT_MENU&&key4_short)
                    maintenance_selection<=maintenance_selection==0 ? 14 : maintenance_selection-1'b1;
                if(key3_short)
                    maintenance_selection<=maintenance_selection==(V5_CONTROLS ? (ENABLE_AUTO_CONTRAST ? 15 : 14) : (ALERT_MENU ? 10 : (AUDIO_MENU ? 8 : (EXTENDED_MENU ? 7 : 4)))) ?
                        0 : maintenance_selection+1'b1;
                else if(key1_short) begin
                    case(maintenance_selection)
                        0:if(brightness_level!=0)
                            brightness_level<=brightness_level-1'b1;
                        1:if(contrast_level!=0)
                            contrast_level<=contrast_level-1'b1;
                        2:if(saturation_level!=0)
                            saturation_level<=saturation_level-1'b1;
                        3:if(gamma_mode!=0)gamma_mode<=gamma_mode-1'b1;
                        4:if(temperature_mode!=0)temperature_mode<=temperature_mode-1'b1;
                        5:if(effect_mode!=0)effect_mode<=FILMING_EFFECTS&&effect_mode==5 ? 2 : effect_mode-1'b1;
                        6:if(effect_duration!=0)effect_duration<=effect_duration-1'b1;
                        7:effect_easing<=0;
                        8:if(volume_level!=0)volume_level<=volume_level-1'b1;
                        9:if(flash_rate!=0)flash_rate<=flash_rate-1'b1;
                        10:if(flash_duty!=0)flash_duty<=flash_duty-1'b1;
                        11:mono_requested<=0;
                        12:if(zoom_level!=0)zoom_level<=zoom_level-1'b1;
                        13:if(pan_x_requested!=0)pan_x_requested<=pan_x_requested-1'b1;
                        14:if(pan_y_requested!=0)pan_y_requested<=pan_y_requested-1'b1;
                        15:auto_requested<=0;
                    endcase
                end else if(key2_short) begin
                    case(maintenance_selection)
                        0:if(brightness_level!=4)
                            brightness_level<=brightness_level+1'b1;
                        1:if(contrast_level!=4)
                            contrast_level<=contrast_level+1'b1;
                        2:if(saturation_level!=4)
                            saturation_level<=saturation_level+1'b1;
                        3:if(gamma_mode!=2)gamma_mode<=gamma_mode+1'b1;
                        4:if(temperature_mode!=2)temperature_mode<=temperature_mode+1'b1;
                        5:if(effect_mode!=MAX_EFFECT_MODE)effect_mode<=FILMING_EFFECTS&&effect_mode==2 ? 5 : effect_mode+1'b1;
                        6:if(effect_duration!=2)effect_duration<=effect_duration+1'b1;
                        7:effect_easing<=1;
                        8:if(volume_level!=7)volume_level<=volume_level+1'b1;
                        9:if(flash_rate!=2)flash_rate<=flash_rate+1'b1;
                        10:if(flash_duty!=2)flash_duty<=flash_duty+1'b1;
                        11:mono_requested<=1;
                        12:if(zoom_level!=2)zoom_level<=zoom_level+1'b1;
                        13:if(pan_x_requested!=4)pan_x_requested<=pan_x_requested+1'b1;
                        14:if(pan_y_requested!=4)pan_y_requested<=pan_y_requested+1'b1;
                        15:if(ENABLE_AUTO_CONTRAST)auto_requested<=1;
                    endcase
                end
            end
        end
    end
endmodule
