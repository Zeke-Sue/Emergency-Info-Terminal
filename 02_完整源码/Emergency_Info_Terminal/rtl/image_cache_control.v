// 四槽图像缓存：维护图号及视口标签，顺序播放时前向预取三张图片。
// 转场期间锁定参与显示的源槽；跨时钟域命令在完成握手前保持稳定。
`timescale 1ns/1ps

module image_cache_control #(
    parameter integer IMAGE_COUNT=16, TRANSITION_PIN=0, FAULT_CONTROL=0,
    parameter integer VIEWPORT_CACHE=0, FAST_PREVIEW=0, FORWARD_PREFETCH=0
)(
    input wire clk,rst,frame_tick,
    input wire sequential_mode,
    input wire [3:0] current_image,requested_image,
    input wire [3:0] lookup_image,
    input wire pin_valid,
    input wire [3:0] pin_image,second_lookup_image,
    output reg [1:0] second_lookup_slot,
    input wire complete_toggle,load_failed,
    input wire storage_fault,
    input wire [7:0] requested_view,
    output reg [7:0] command_view,
    output reg command_toggle,
    output reg [3:0] command_image,
    output reg [1:0] command_slot,
    output wire ready,
    output wire view_pending,
    output reg [15:0] resident,
    output reg [15:0] failed_images,
    output reg [1:0] display_slot,lookup_slot
);
    reg [3:0] tags [0:3];
    reg [7:0] views [0:3];
    wire [7:0] view_key=VIEWPORT_CACHE ? requested_view : 8'd0;
    reg view_found,base_found;
    reg failed_view_valid;
    reg [7:0] failed_view;
    reg [3:0] failed_view_image;
    reg [3:0] valid;
    reg busy;
    reg [1:0] complete_sync;
    reg complete_seen;
    wire forward=FORWARD_PREFETCH&&sequential_mode&&view_key==0;

    wire [3:0] anchor=forward ? requested_image : current_image;
    wire [3:0] next_image=anchor==IMAGE_COUNT-1 ? 4'd0 : anchor+1'b1;
    wire [3:0] prev_image=forward ? (next_image==IMAGE_COUNT-1 ? 4'd0 : next_image+1'b1) :
        (current_image==0 ? IMAGE_COUNT-1 : current_image-1'b1);
    wire [3:0] third_image=prev_image==IMAGE_COUNT-1 ? 4'd0 : prev_image+1'b1;
    reg [3:0] wanted;
    reg [7:0] wanted_view;
    reg need_load;
    reg [1:0] victim;
    reg victim_found;
    integer i,k;
    assign ready=resident[current_image];
    assign view_pending=VIEWPORT_CACHE && ready && views[display_slot]!=view_key;
    always @* begin
        resident=0;display_slot=0;lookup_slot=0;second_lookup_slot=0;view_found=0;base_found=0;
        for(k=0;k<4;k=k+1)begin
            if(valid[k])begin
                if(!VIEWPORT_CACHE || views[k]==0 || tags[k]==current_image ||
                    (tags[k]==requested_image && views[k]==view_key))resident[tags[k]]=1;
                if(tags[k]==current_image)display_slot=k;
                if(tags[k]==lookup_image)lookup_slot=k;
                if(tags[k]==second_lookup_image)second_lookup_slot=k;
                if(tags[k]==requested_image && views[k]==view_key)view_found=1;
                if(tags[k]==requested_image && views[k]==0)base_found=1;
            end
        end
        if(FAST_PREVIEW)begin

            for(k=0;k<4;k=k+1)if(valid[k]&&views[k]==0)begin
                if(tags[k]==current_image)display_slot=k;
                if(tags[k]==lookup_image)lookup_slot=k;
                if(tags[k]==second_lookup_image)second_lookup_slot=k;
            end
            for(k=0;k<4;k=k+1)
                if(valid[k]&&tags[k]==current_image&&views[k]==view_key)display_slot=k;
            if(lookup_image==current_image)lookup_slot=display_slot;
            if(second_lookup_image==current_image)second_lookup_slot=display_slot;
        end
        wanted=requested_image;wanted_view=view_key;need_load=1;
        if(!view_found && !failed_images[requested_image] &&
            !(failed_view_valid && failed_view==view_key && failed_view_image==requested_image))
            wanted=requested_image;
        else if(view_key!=0)need_load=0;
        else if(!resident[next_image] && !failed_images[next_image])wanted=next_image;
        else if(!resident[prev_image] && !failed_images[prev_image])wanted=prev_image;
        else if(forward && !resident[third_image] && !failed_images[third_image])wanted=third_image;
        else need_load=0;
        if(FAST_PREVIEW&&!base_found&&!failed_images[requested_image])begin
            wanted=requested_image;wanted_view=0;need_load=1;
        end
        victim=0;victim_found=0;
        for(k=0;k<4;k=k+1)begin
            if(!valid[k] || (FAST_PREVIEW&&tags[k]==current_image&&views[k]!=0&&k!=display_slot) || (tags[k]!=current_image &&

                (tags[k]!=requested_image || (VIEWPORT_CACHE && views[k]!=view_key &&
                    !(FAST_PREVIEW&&views[k]==0))) &&
                (!TRANSITION_PIN || !pin_valid || tags[k]!=pin_image) &&
                ((VIEWPORT_CACHE && !view_found) ||
                 (tags[k]!=next_image && tags[k]!=prev_image &&
                  (!forward || tags[k]!=third_image)))))begin
                victim=k;victim_found=1;
            end
        end

    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            valid<=0;busy<=0;complete_sync<=0;complete_seen<=0;
            failed_images<=0;
            command_toggle<=0;command_image<=0;command_slot<=0;command_view<=0;
            failed_view_valid<=0;failed_view<=0;failed_view_image<=0;
            for(i=0;i<4;i=i+1)begin tags[i]<=0;views[i]<=0;end
        end else begin
            complete_sync<={complete_sync[0],complete_toggle};
            if(failed_view_valid && (view_key!=failed_view || requested_image!=failed_view_image))
                failed_view_valid<=0;

            if(busy && complete_sync[1]!=complete_seen && (!VIEWPORT_CACHE || frame_tick))begin
                complete_seen<=complete_sync[1];busy<=0;
                if(VIEWPORT_CACHE && command_image==current_image &&
                        command_view!=view_key&&!(FAST_PREVIEW&&command_view==0))begin

                    valid[command_slot]<=0;
                end else if(!load_failed)begin
                    if(VIEWPORT_CACHE)
                        for(i=0;i<4;i=i+1)
                            if(tags[i]==command_image&&(!FAST_PREVIEW||command_view==0||views[i]!=0))valid[i]<=0;
                    valid[command_slot]<=1;tags[command_slot]<=command_image;
                    views[command_slot]<=command_view;
                end else if(VIEWPORT_CACHE && resident[command_image])begin
                    failed_view_valid<=1;failed_view<=command_view;failed_view_image<=command_image;
                end else failed_images[command_image]<=1;
            end else if(!busy && !(FAULT_CONTROL && storage_fault) &&
                    frame_tick && need_load && victim_found)begin
                valid[victim]<=0;command_image<=wanted;command_slot<=victim;
                command_view<=wanted_view;
                command_toggle<=!command_toggle;busy<=1;
            end
        end
    end
endmodule
