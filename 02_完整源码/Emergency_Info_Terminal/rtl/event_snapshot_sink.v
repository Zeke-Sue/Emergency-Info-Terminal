`timescale 1ns/1ps

module event_snapshot_sink #(
    parameter integer LINK_FRAMES=180,CANCEL_FRAMES=1786,CHECK_ROLE=0
)(
    input wire clk,rst,frame_tick,command_valid,
    input wire [2:0] command_opcode,command_kind,command_level,command_region,
    input wire [15:0] command_event_id,command_remaining,
    input wire [7:0] command_sequence,
    input wire command_drill,command_pending,command_trusted,epoch_changed,
    input wire [32:0] snapshot,
    output wire command_ready,output reg result_valid,
    output reg [3:0] result_code,
    output reg primary_valid,primary_drill,primary_pending,primary_trusted,
    output reg [1:0] primary_source,
    output reg [2:0] primary_kind,primary_level,primary_region,
    output reg [15:0] primary_event_id,primary_remaining,
    output reg [7:0] primary_sequence,blocked_set,
    output reg [3:0] active_count,
    output reg cancel_notice,full_urgent,online,recovery_required
);
    reg pending,pending_epoch;
    reg [84:0] pending_data;
    reg [7:0] age;
    reg [10:0] cancel_left;
    reg received_cancel;
    wire [24:0] pending_snapshot=pending_data[24:0];
    wire [7:0] permission_tag=pending_data[32:25];
    wire permission_allowed;
    operator_permission permission(.role(permission_tag[6:5]),.opcode(pending_snapshot[23:21]),
        .kind(permission_tag[3:1]),.drill(permission_tag[4]),.allowed(permission_allowed));
    assign command_ready=!pending;
    always @(posedge clk)begin
        if(command_valid&&command_ready)
            pending_data<={command_kind,command_level,command_region,
                command_event_id,command_remaining,command_sequence,
                command_drill,command_pending,command_trusted,snapshot};
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            pending<=0;pending_epoch<=0;result_valid<=0;result_code<=0;
            primary_valid<=0;primary_drill<=0;primary_pending<=0;primary_trusted<=0;
            primary_source<=0;primary_kind<=0;primary_level<=1;primary_region<=0;
            primary_event_id<=0;primary_remaining<=0;primary_sequence<=0;
            blocked_set<=0;active_count<=0;cancel_notice<=0;full_urgent<=0;
            online<=0;age<=0;recovery_required<=0;cancel_left<=0;received_cancel<=0;
        end else begin
            result_valid<=0;
            if(command_valid&&command_ready)begin
                if(command_opcode==6)begin pending<=1;pending_epoch<=epoch_changed;end
                else begin result_valid<=1;result_code<=5;end
            end
            if(frame_tick)begin
                if(online)begin
                    if(age==LINK_FRAMES-1)online<=0;
                    else age<=age+1'b1;
                end
                if(cancel_left!=0)begin
                    cancel_left<=cancel_left-1'b1;
                    if(cancel_left==1)cancel_notice<=0;
                end
                if(pending)begin
                    pending<=0;result_valid<=1;online<=1;age<=0;
                    if(CHECK_ROLE&&(!permission_tag[7]||permission_tag[0]||
                            (pending_snapshot[24]&&permission_tag[6:5]!=2)||
                            (pending_snapshot[23:21]!=7&&pending_snapshot[20:17]==0&&!permission_allowed)))begin
                        result_code<=8;
                    end else if((recovery_required || (pending_epoch&&(primary_valid||full_urgent))) &&
                            !pending_snapshot[24])begin
                        recovery_required<=1;result_code<=7;
                    end else begin
                        recovery_required<=0;result_code<=pending_snapshot[20:17];
                        {primary_kind,primary_level,primary_region,primary_event_id,
                            primary_remaining,primary_sequence,primary_drill,
                            primary_pending,primary_trusted}<=pending_data[84:33];
                        primary_source<=pending_snapshot[4:3];
                        primary_valid<=pending_snapshot[0];full_urgent<=pending_snapshot[2];
                        active_count<=pending_snapshot[8:5];blocked_set<=pending_snapshot[16:9];
                        received_cancel<=pending_snapshot[1];
                        if(!pending_snapshot[1])begin cancel_notice<=0;cancel_left<=0;end
                        else if(!received_cancel)begin cancel_notice<=1;cancel_left<=CANCEL_FRAMES;end
                    end
                end
            end
        end
    end
endmodule
