`timescale 1ns/1ps

module display_control #(
    parameter integer OSD_FRAMES=120
)(
    input wire clk, rst, frame_tick,
    input wire zoom_key_press, zoom_key_short, zoom_key_long, zoom_key_held,
    input wire key1_press, key1_short, key1_long, key1_held,
    input wire key2_press, key2_short, key2_long, key2_held,
    input wire key3_press, key3_short, key3_long, key3_held,
    input wire grayscale_switch,
    output reg next_event, auto_event, period_event, reload_event,
    output reg zoom_mode,
    output wire grayscale_enable,
    output reg [2:0] brightness_level,
    output reg [2:0] contrast_level,
    output reg [2:0] saturation_level,
    output wire osd_visible
);
    reg [15:0] osd_count;
    reg zoom_requested;
    reg grayscale_previous;
    assign osd_visible = osd_count != 0;
    assign grayscale_enable = grayscale_switch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            next_event <= 0; auto_event <= 0; period_event <= 0; reload_event <= 0;
            zoom_mode <= 0; zoom_requested <= 0;
            brightness_level <= 3'd2; contrast_level <= 3'd2;
            saturation_level <= 3'd2;
            osd_count <= 0;
            grayscale_previous <= 0;
        end else begin
            next_event <= 0; auto_event <= 0; period_event <= 0; reload_event <= 0;
            if (frame_tick && osd_count != 0) osd_count <= osd_count-1'b1;

            if (frame_tick) zoom_mode <= zoom_requested;
            if (zoom_key_short) begin
                zoom_requested <= !zoom_requested;
                osd_count <= OSD_FRAMES;
            end
            if (zoom_key_long) reload_event <= 1;

            if (grayscale_switch!=grayscale_previous) begin
                grayscale_previous <= grayscale_switch;
                osd_count <= OSD_FRAMES;
            end

            if (key1_short) next_event <= 1;
            if (key2_short) auto_event <= 1;
            if (key2_long) begin
                saturation_level <= saturation_level == 4 ? 0 : saturation_level+1'b1;
                osd_count <= OSD_FRAMES;
            end
            if (key3_short) period_event <= 1;
            if (key1_long) begin
                brightness_level <= brightness_level == 4 ? 0 : brightness_level+1'b1;
                osd_count <= OSD_FRAMES;
            end
            if (key3_long) begin
                contrast_level <= contrast_level == 4 ? 0 : contrast_level+1'b1;
                osd_count <= OSD_FRAMES;
            end
        end
    end
endmodule
