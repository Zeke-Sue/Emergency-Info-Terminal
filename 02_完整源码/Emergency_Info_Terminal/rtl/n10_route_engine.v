`timescale 1ns/1ps

module n10_route_engine #(
    parameter integer SHAPED_ARROWS=0
)(
    input wire clk,input wire rst,input wire frame_tick,
    input wire cfg_write,input wire [7:0] cfg_blocked_key,
    input wire [31:0] cfg_segment_mask,input wire [31:0] cfg_direction_mask,
    input wire [2:0] cfg_exit,input wire [1:0] cfg_status,
    input wire cfg_commit,input wire cfg_crc_ok,input wire cfg_checked,
    input wire cfg_assets_match,input wire [15:0] cfg_version,
    input wire [31:0] cfg_crc32,
    input wire [7:0] blocked_set,
    input wire pixel_valid,input wire [5:0] segment_id,
    input wire [7:0] segment_phase,input wire blocked_exit_pixel,
    input wire [1:0] segment_distance,
    input wire flash_on,
    output reg route_valid,output wire route_reachable,output wire cfg_ready,
    output wire all_exits_blocked,output wire route_unreachable,
    output wire [2:0] selected_exit,output wire [1:0] selected_status,
    output wire [31:0] selected_segment_mask,
    output wire [31:0] selected_direction_mask,
    output reg overlay_valid,output reg [23:0] overlay_rgb,
    output wire safe_fallback,output reg route_changed,
    output reg [15:0] active_version,output reg [31:0] active_crc32
);

    reg active_bank,pending_commit,pending_bank;
    reg [15:0] pending_version;
    reg [31:0] pending_crc;
    reg [7:0] frame_count;
    reg [7:0] frame_blocked;
    reg highlight_active;
    reg [5:0] highlight_frame;
    assign cfg_ready=!pending_commit;

    wire config_accepted=cfg_crc_ok&&cfg_checked&&cfg_assets_match;
    wire [71:0] cfg_entry={3'd0,cfg_status,cfg_exit,
        cfg_direction_mask,cfg_segment_mask};
    wire [71:0] active_entry;

    genvar lane;
    generate for(lane=0;lane<4;lane=lane+1)begin: packed_banks
        buffer_ram #(.DATA_WIDTH(18),.ADDR_WIDTH(9)) entries(
            .clk(clk),.we(cfg_write&&cfg_ready),.wa({~active_bank,cfg_blocked_key}),
            .ra({active_bank,frame_blocked}),.d(cfg_entry[lane*18+:18]),
            .q(active_entry[lane*18+:18]));
    end endgenerate
    wire [5:0] segment_index=segment_id-1'b1;
    wire segment_in_range=segment_id>=1&&segment_id<=32;
    wire selected_segment=segment_in_range&&selected_segment_mask[segment_index];
    wire reverse_segment=segment_in_range&&selected_direction_mask[segment_index];
    wire [7:0] directed_phase=reverse_segment ? (~segment_phase+1'b1) : segment_phase;
    wire [3:0] animation_phase=frame_count[5:2];
    wire [3:0] arrow_phase=directed_phase[3:0]-animation_phase;

    wire arrow_ink=(segment_distance==0&&arrow_phase<5)||
        (arrow_phase>=5&&arrow_phase<=7&&
            {2'b0,segment_distance}<=4'd7-arrow_phase);

    assign selected_segment_mask=active_entry[31:0];
    assign selected_direction_mask=active_entry[63:32];
    assign selected_exit=active_entry[66:64];
    assign selected_status=active_entry[68:67];
    assign route_reachable=route_valid&&selected_status==2'd0;
    assign all_exits_blocked=route_valid&&selected_status==2'd1;
    assign route_unreachable=route_valid&&selected_status==2'd2;
    assign safe_fallback=!route_valid||selected_status==2'd3;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            active_bank<=0;pending_commit<=0;pending_bank<=1;
            route_valid<=0;route_changed<=0;active_version<=0;
            active_crc32<=0;pending_version<=0;
            pending_crc<=0;frame_count<=0;frame_blocked<=0;
            highlight_active<=0;highlight_frame<=0;
        end else begin
            route_changed<=0;
            if(frame_tick)begin
                frame_count<=frame_count+1'b1;frame_blocked<=blocked_set;
                if(highlight_active)begin
                    if(highlight_frame==47)highlight_active<=0;
                    else highlight_frame<=highlight_frame+1'b1;
                end
                if(route_valid&&frame_blocked!=blocked_set)begin
                    route_changed<=1;highlight_active<=1;highlight_frame<=0;
                end
            end
            if(cfg_commit&&config_accepted&&cfg_ready)begin
                pending_commit<=1;pending_bank<=~active_bank;
                pending_version<=cfg_version;pending_crc<=cfg_crc32;
            end
            if(frame_tick&&pending_commit)begin
                active_bank<=pending_bank;pending_commit<=0;route_valid<=1;
                active_version<=pending_version;active_crc32<=pending_crc;
                route_changed<=1;
                highlight_active<=1;highlight_frame<=0;
            end
        end
    end

    always @* begin
        overlay_valid=0;overlay_rgb=24'h000000;
        if(pixel_valid&&route_valid)begin
            if(blocked_exit_pixel)begin
                overlay_valid=1;overlay_rgb=24'hff2020;
            end else if(route_reachable&&selected_segment)begin
                overlay_valid=1;
                overlay_rgb=(SHAPED_ARROWS ? arrow_ink : arrow_phase<5) ?
                    24'h20ff60 : 24'h087832;
                if(highlight_active&&!highlight_frame[3])overlay_rgb=24'hb0ffb0;
            end
        end
    end
endmodule
