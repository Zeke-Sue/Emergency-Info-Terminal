`timescale 1ns/1ps

module console_event_authority #(
    parameter integer FRAME_CYCLES=840000,RETRY_MS=100,REFRESH_MS=200,SECOND_MS=1000,
    parameter integer CHECK_ROLE=0
)(
    input wire clk,rst,ms_tick,
    input wire request_valid,output wire request_ready,
    input wire [1:0] request_action,request_source,
    input wire [31:0] request_session,request_sequence,
    input wire [15:0] request_event_id,request_remaining,
    input wire [7:0] request_event_sequence,
    input wire [2:0] request_level,request_region,request_kind,
    input wire request_drill,request_pending,request_trusted,
    input wire [1:0] request_role,
    input wire ack_valid,input wire [3:0] ack_result,
    input wire [31:0] ack_session,ack_sequence,
    input wire heartbeat_valid,input wire [31:0] remote_boot,remote_session,
    output reg user_ack_valid,output reg [3:0] user_ack_result,
    output reg [31:0] user_ack_session,user_ack_sequence,
    output reg snapshot_valid,input wire snapshot_ready,
    output reg [95:0] snapshot_payload,
    output reg [31:0] snapshot_session,snapshot_sequence,
    output wire [63:0] authoritative_event,
    output wire [7:0] blocked_set,
    output reg recovery_required
);
    localparam FRAME_BITS=FRAME_CYCLES<2 ? 1 : $clog2(FRAME_CYCLES);
    reg [FRAME_BITS-1:0] frame_div;
    wire frame_tick=frame_div==FRAME_CYCLES-1;
    reg [9:0] second_div;
    reg [31:0] now_seconds;
    reg [7:0] refresh_ms,retry_ms;
    reg refresh_due;
    wire manager_ready,manager_result,settled;
    wire [3:0] manager_code,active_count;
    wire primary_valid,primary_drill,primary_pending,primary_trusted,cancel_notice,full_urgent;
    wire [1:0] primary_source;
    wire [2:0] primary_kind,primary_level,primary_region;
    wire [15:0] primary_id,primary_remaining;
    wire [7:0] primary_sequence;
    reg initialized,processing,result_seen,user_pending,dirty,outstanding;
    reg processed_valid,packet_for_user,packet_takeover,takeover;
    reg [3:0] saved_result;
    reg [2:0] saved_opcode;
    reg [7:0] saved_permission;
    reg [31:0] saved_user_session,saved_user_sequence,next_wire_sequence;
    wire [31:0] request_sequence_handoff;
    console_hold_buffer #(.WIDTH(32)) request_hold(.d(request_sequence),.q(request_sequence_handoff));
    reg [31:0] boot_seen_value;
    reg boot_seen;
    reg identity_ready;
    reg [31:0] wire_session;
    reg [15:0] countdown;
    reg [25:0] last_primary;
    wire new_request=!processed_valid || request_sequence!=saved_user_sequence ||
        request_session!=saved_user_session;
    assign request_ready=manager_ready&&!processing;
    wire accepted=request_valid&&request_ready;
    wire clearing_recovery=request_action==3 && (!initialized||recovery_required);
    wire [2:0] opcode=clearing_recovery ? 3'd5 :
        request_action==0 ? 3'd0 : request_action==1 ? 3'd3 :
        request_action==2 ? 3'd4 : 3'd1;
    wire operator_allowed;
    operator_permission permission(.role(request_role),.opcode(opcode),
        .kind(request_kind),.drill(request_drill),.allowed(operator_allowed));
    wire denied=CHECK_ROLE&&!operator_allowed;
    event_manager #(.CHECK_ROLE(CHECK_ROLE)) events(.clk(clk),.rst(rst),.frame_tick(frame_tick||manager_result),
        .now_seconds(now_seconds),.cmd_valid(accepted&&new_request&&!denied),.cmd_opcode(opcode),
        .cmd_source(request_source),.cmd_kind(request_kind),.cmd_event_id(request_event_id),
        .cmd_sequence(request_event_sequence),.cmd_level(request_level),.cmd_drill(request_drill),
        .cmd_pending(request_pending),.cmd_region(request_region),.cmd_time_trusted(request_trusted),
        .cmd_role(request_role),
        .cmd_remaining_seconds(request_remaining),.sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .cmd_ready(manager_ready),.result_valid(manager_result),.result_code(manager_code),
        .primary_valid(primary_valid),.primary_source(primary_source),.primary_kind(primary_kind),
        .primary_event_id(primary_id),.primary_sequence(primary_sequence),.primary_level(primary_level),
        .primary_drill(primary_drill),.primary_pending(primary_pending),.primary_time_trusted(primary_trusted),
        .primary_remaining_seconds(primary_remaining),.primary_region(primary_region),
        .active_count(active_count),.tombstone_count(),.blocked_set(blocked_set),
        .cancel_notice(cancel_notice),.full_urgent(full_urgent),.settled(settled));
    assign authoritative_event={11'd0,primary_trusted,primary_valid,primary_kind,countdown,
        primary_region,primary_pending,primary_drill,primary_level,primary_sequence,primary_id};
    wire [95:0] next_payload={
        1'b0,(user_pending&&takeover),full_urgent,cancel_notice,primary_trusted,
            primary_pending,primary_drill,primary_valid,
        primary_level,primary_kind,primary_source,primary_id,primary_sequence,
        1'b0,active_count,primary_region,countdown,blocked_set,
        1'b0,(user_pending ? saved_opcode : 3'd7),(user_pending ? saved_result : 4'd0),
        (CHECK_ROLE ? (user_pending ? saved_permission : 8'h80) : 8'd0),8'd0};
    reg [79:0] last_state;
    wire state_changed=next_payload[95:16]!=last_state;
    wire critical_state_changed={next_payload[95:48],next_payload[31:16]}!=
        {last_state[79:32],last_state[15:0]};
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            frame_div<=0;second_div<=0;now_seconds<=0;refresh_ms<=0;retry_ms<=0;refresh_due<=0;
            initialized<=0;processing<=0;result_seen<=0;user_pending<=0;dirty<=0;outstanding<=0;
            processed_valid<=0;packet_for_user<=0;packet_takeover<=0;takeover<=0;
            saved_result<=0;saved_opcode<=0;saved_user_session<=0;saved_user_sequence<=0;
            saved_permission<=0;
            next_wire_sequence<=1;boot_seen<=0;boot_seen_value<=0;countdown<=0;last_primary<=0;
            identity_ready<=0;wire_session<=0;
            snapshot_valid<=0;snapshot_payload<=0;snapshot_session<=0;snapshot_sequence<=0;
            user_ack_valid<=0;user_ack_result<=0;user_ack_session<=0;user_ack_sequence<=0;
            recovery_required<=0;last_state<=0;
        end else begin
            user_ack_valid<=0;
            frame_div<=frame_tick ? 0 : frame_div+1'b1;
            if(ms_tick)begin
                if(second_div==SECOND_MS-1)begin
                    second_div<=0;now_seconds<=now_seconds+1'b1;
                    if(countdown!=0)countdown<=countdown-1'b1;
                end else second_div<=second_div+1'b1;
                if(refresh_ms==REFRESH_MS-1)begin refresh_ms<=0;refresh_due<=1;end
                else refresh_ms<=refresh_ms+1'b1;
                if(outstanding&&!snapshot_valid)begin
                    if(retry_ms==RETRY_MS-1)begin
                        retry_ms<=0;
                        if(state_changed)begin outstanding<=0;dirty<=1;end
                        else snapshot_valid<=1;
                    end
                    else retry_ms<=retry_ms+1'b1;
                end
            end
            if(primary_valid && {primary_source,primary_id,primary_sequence}!=last_primary)begin
                last_primary<={primary_source,primary_id,primary_sequence};countdown<=primary_remaining;
            end
            if(accepted&&denied)begin
                user_ack_valid<=1;user_ack_result<=8;
                user_ack_session<=request_session;user_ack_sequence<=request_sequence;
            end else if(accepted)begin
                if(new_request)begin
                    initialized<=1;processing<=1;result_seen<=0;user_pending<=1;processed_valid<=1;

                    outstanding<=0;snapshot_valid<=0;packet_for_user<=0;dirty<=1;
                    saved_user_session<=request_session;saved_user_sequence<=request_sequence_handoff;
                    saved_opcode<=clearing_recovery ? 3'd1 : opcode;takeover<=clearing_recovery;
                    saved_permission<={1'b1,request_role,request_drill,request_kind,1'b0};
                end else if(!user_pending)begin
                    user_ack_valid<=1;user_ack_result<=saved_result;
                    user_ack_session<=saved_user_session;user_ack_sequence<=saved_user_sequence;
                end
            end
            if(manager_result)begin saved_result<=manager_code;result_seen<=1;end
            if(processing&&result_seen&&settled)begin processing<=0;dirty<=1;end
            if(snapshot_valid&&snapshot_ready&&!(accepted&&new_request))begin
                snapshot_valid<=0;outstanding<=1;retry_ms<=0;
            end

            if(outstanding&&!snapshot_valid&&!processing&&settled&&critical_state_changed)begin
                outstanding<=0;dirty<=1;
            end
            if(initialized&&identity_ready&&!processing&&settled&&!outstanding&&!snapshot_valid&&
                    !(accepted&&new_request)&&
                    (!recovery_required||user_pending)&&
                    (dirty||refresh_due||state_changed||user_pending))begin
                snapshot_payload<=next_payload;snapshot_valid<=1;
                snapshot_session<=wire_session;snapshot_sequence<=next_wire_sequence;
                next_wire_sequence<=next_wire_sequence+1'b1;
                packet_for_user<=user_pending;packet_takeover<=user_pending&&takeover;
                last_state<=next_payload[95:16];dirty<=0;refresh_due<=0;
            end
            if(ack_valid&&outstanding&&ack_session==snapshot_session&&ack_sequence==snapshot_sequence&&
                    ack_result!=6&&!(accepted&&new_request))begin
                outstanding<=0;snapshot_valid<=0;retry_ms<=0;
                if(ack_result==7)recovery_required<=1;
                else if(packet_takeover)recovery_required<=0;
                if(packet_for_user)begin
                    user_pending<=0;user_ack_valid<=1;
                    user_ack_result<=ack_result!=0 ? ack_result : saved_result;
                    if(ack_result!=0)saved_result<=ack_result;
                    user_ack_session<=saved_user_session;user_ack_sequence<=saved_user_sequence;
                end
            end
            if(heartbeat_valid)begin
                if(!identity_ready)begin

                    wire_session<=remote_session+1'b1;identity_ready<=1;
                end
                boot_seen<=1;boot_seen_value<=remote_boot;
                if(!boot_seen||boot_seen_value!=remote_boot)begin

                    outstanding<=0;snapshot_valid<=0;dirty<=1;
                end
            end
        end
    end
endmodule
