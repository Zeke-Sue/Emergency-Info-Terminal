// 管理拨码角色、事件参数、二次确认及应答超时状态。
`timescale 1ns/1ps
module duty_console_core #(
    parameter integer LINK_TIMEOUT_MS=3000,
    parameter integer ACK_TIMEOUT_MS=500,
    parameter integer MAX_RETRIES=2,
    parameter integer V5_CONTROLS=0,
    parameter integer SIMPLE_ACTIONS=0,
    parameter integer CONFIRM_UI=V5_CONTROLS,
    parameter integer CONFIRM_HOLD_MS=2000,
    parameter integer CONFIRM_TIMEOUT_MS=10000
)(
    input wire clk,input wire rst,input wire ms_tick,
    input wire [3:0] key_press,input wire [3:0] key_long_press,
    input wire [3:0] key_held,
    input wire [3:0] switches,
    output reg request_valid,input wire request_ready,
    output reg [1:0] request_action,output wire [1:0] request_source,
    output reg [31:0] request_session,output reg [31:0] request_sequence,
    output reg [15:0] request_event_id,output reg [7:0] request_event_sequence,
    output reg [2:0] request_level,output reg request_drill,
    output reg request_pending,output reg [2:0] request_region,
    output reg request_time_trusted,output reg [15:0] request_remaining_seconds,
    output reg [2:0] request_kind,
    output reg [1:0] request_role,
    input wire ack_valid,input wire [3:0] ack_result,
    input wire [31:0] ack_session,input wire [31:0] ack_sequence,
    input wire heartbeat_valid,input wire heartbeat_alarm,
    input wire [2:0] heartbeat_level,input wire [3:0] heartbeat_active_count,
    input wire [7:0] heartbeat_blocked_set,
    input wire rx_frame_error,input wire rx_crc_error,
    output reg [2:0] selected_level,output reg [2:0] selected_region,
    output reg [1:0] selected_action,output wire [1:0] selected_role,
    output reg selected_evacuation,
    output wire confirmation_armed,confirmation_expired,
    output wire [4:0] confirmation_progress,
    output reg link_alive,output reg ack_pending,
    output reg [3:0] last_ack_result,output reg permission_denied,
    output reg error_latched,output reg remote_alarm,
    output reg [2:0] remote_level,output reg [3:0] remote_active_count,
    output reg [7:0] remote_blocked_set
);
    localparam integer LINK_BITS=LINK_TIMEOUT_MS<2 ? 1 : $clog2(LINK_TIMEOUT_MS+1);
    localparam integer ACK_BITS=ACK_TIMEOUT_MS<2 ? 1 : $clog2(ACK_TIMEOUT_MS+1);
    localparam integer RETRY_BITS=MAX_RETRIES<1 ? 1 : $clog2(MAX_RETRIES+1);
    reg [LINK_BITS-1:0] link_timer;
    reg [ACK_BITS-1:0] ack_timer;
    reg [RETRY_BITS-1:0] retry_count;
    reg [31:0] uptime,session_id;
    reg session_valid;
    reg [15:0] next_event_id,last_event_id;
    reg last_event_drill;
    reg [2:0] last_event_kind;
    reg [2:0] last_event_region,last_event_level;
    reg last_event_accepted;
    assign request_source=2'd2;
    assign selected_role=switches[1:0];
    wire real_mode=switches[2];
    wire fire_confirm=switches[3];
    wire [2:0] selected_kind=selected_action==3 ? last_event_kind :
        fire_confirm ? ((V5_CONTROLS&&selected_evacuation) ? 3'd3 : 3'd1) : 3'd0;
    wire selected_drill=selected_action==3 ? last_event_drill : !real_mode;
    wire fire_workflow=V5_CONTROLS&&SIMPLE_ACTIONS&&fire_confirm&&last_event_accepted&&
        (last_event_kind==1||last_event_kind==3)&&last_event_drill==!real_mode;
    wire fire_update=fire_workflow&&selected_action==0;
    wire v5_authorized;
    operator_permission permission(.role(selected_role),
        .opcode(selected_action==0 ? 3'd0 : selected_action==1 ? 3'd3 : selected_action==2 ? 3'd4 : 3'd1),
        .kind(selected_kind),.drill(selected_drill),.allowed(v5_authorized));
    wire authorized=V5_CONTROLS ? v5_authorized&&
        (!(selected_action==0&&selected_evacuation)||
            (fire_confirm&&last_event_accepted&&(last_event_kind==1||(SIMPLE_ACTIONS&&last_event_kind==3))&&last_event_drill==!real_mode)) :
        (switches[1:0]!=0)&&(!real_mode||switches[1]);
    wire [31:0] request_sequence_handoff;
    console_hold_buffer #(.WIDTH(32)) sequence_hold(
        .d(request_sequence),.q(request_sequence_handoff));
    wire matching_ack=ack_valid&&ack_pending&&ack_session==request_session&&
                      ack_sequence==request_sequence_handoff;
    wire dialog_confirmed,dialog_denied;
    wire [15:0] confirmed_context;
    wire dialog_idle=!ack_pending&&!request_valid;
    wire new_alarm=heartbeat_valid&&heartbeat_alarm&&
        (!remote_alarm||heartbeat_level!=remote_level||heartbeat_active_count!=remote_active_count);
    wire [15:0] dialog_context={switches,selected_action,selected_level,
        selected_region,selected_evacuation,3'd0};
    wire dialog_cancel=(|key_press[2:0])||key_long_press[0]||new_alarm;
    operator_confirmation #(.HOLD_MS(CONFIRM_HOLD_MS),.TIMEOUT_MS(CONFIRM_TIMEOUT_MS)) confirmation(
        .clk(clk),.rst(rst),.ms_tick(ms_tick),
        .arm(CONFIRM_UI&&key_press[3]&&dialog_idle),.cancel(dialog_cancel),
        .held(CONFIRM_UI&&key_held[3]),.eligible(authorized&&link_alive&&dialog_idle),
        .context(dialog_context),.armed(confirmation_armed),.confirmed(dialog_confirmed),
        .confirmed_context(confirmed_context),
        .expired(confirmation_expired),.denied(dialog_denied),.progress(confirmation_progress));
    wire execute=CONFIRM_UI ? dialog_confirmed&&!dialog_cancel&&link_alive&&
        dialog_context==confirmed_context : key_long_press[3];

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            selected_level<=3'd1;selected_region<=0;selected_action<=0;
            request_valid<=0;request_action<=0;request_session<=0;
            request_sequence<=0;request_event_id<=16'h1001;
            request_event_sequence<=0;request_level<=1;request_drill<=1;
            request_pending<=0;request_region<=0;request_time_trusted<=0;
            request_remaining_seconds<=120;request_kind<=0;
            request_role<=0;
            link_alive<=0;ack_pending<=0;last_ack_result<=0;
            permission_denied<=0;error_latched<=0;remote_alarm<=0;
            remote_level<=0;remote_active_count<=0;remote_blocked_set<=0;
            link_timer<=0;ack_timer<=0;retry_count<=0;uptime<=0;
            session_id<=0;session_valid<=0;
            next_event_id<=16'h1001;last_event_id<=16'h1001;
            selected_evacuation<=0;last_event_drill<=0;last_event_kind<=0;last_event_accepted<=0;
            last_event_region<=0;last_event_level<=1;
        end else begin
            uptime<=uptime+1'b1;
            if(CONFIRM_UI&&dialog_denied)begin permission_denied<=1;error_latched<=1;end
            if(CONFIRM_UI&&key_press[3]&&authorized&&link_alive)permission_denied<=0;
            if(V5_CONTROLS&&!fire_confirm)selected_evacuation<=0;
            if(V5_CONTROLS&&!SIMPLE_ACTIONS&&fire_confirm&&key_long_press[0]&&!ack_pending&&!request_valid)
                selected_evacuation<=!selected_evacuation;
            if(key_press[0]&&!ack_pending&&!request_valid)begin
                if(fire_workflow)selected_region<=selected_region-1'b1;
                else selected_level<=selected_level==4 ? 1 : selected_level+1'b1;
                permission_denied<=0;
            end
            if(key_press[1]&&!ack_pending&&!request_valid)begin
                selected_region<=selected_region+1'b1;permission_denied<=0;
            end

            if(V5_CONTROLS&&SIMPLE_ACTIONS&&selected_role==2&&key_long_press[1]&&!ack_pending&&!request_valid)
                selected_action<=selected_action==1 ? 2 : 1;
            if(key_press[2]&&!ack_pending&&!request_valid)begin
                selected_action<=SIMPLE_ACTIONS ? (selected_action==0 ? 3 : 0) : selected_action+1'b1;permission_denied<=0;
            end
            if(execute&&!ack_pending&&!request_valid)begin
                if(!authorized)begin permission_denied<=1;error_latched<=1;end
                else begin
                    if(!session_valid)begin
                        session_id<=32'hb0000000^uptime^{22'd0,switches,selected_region,selected_level};
                        request_session<=32'hb0000000^uptime^{22'd0,switches,selected_region,selected_level};
                        session_valid<=1;
                    end else request_session<=session_id;

                    request_sequence<=request_sequence+1'b1;
                    request_event_sequence<=request_sequence[7:0]+1'b1;
                    request_action<=selected_action;request_level<=selected_level;
                    request_role<=selected_role;
                    request_region<=selected_region;request_drill<=V5_CONTROLS ? selected_drill : !real_mode;
                    if(V5_CONTROLS&&selected_evacuation&&selected_action==0)begin
                        request_level<=last_event_level;request_region<=SIMPLE_ACTIONS ? selected_region : last_event_region;
                    end
                    request_pending<=0;request_time_trusted<=0;
                    request_remaining_seconds<=16'd120;
                    request_kind<=V5_CONTROLS ? selected_kind : fire_confirm&&selected_action==0 ? 3'd1 : 3'd0;
                    if(selected_action==3||fire_update||(V5_CONTROLS&&selected_action==0&&selected_evacuation))request_event_id<=last_event_id;
                    else request_event_id<=next_event_id;
                    if(selected_action==0&&!fire_update&&!(V5_CONTROLS&&selected_evacuation))begin
                        last_event_id<=next_event_id;next_event_id<=next_event_id+1'b1;
                        last_event_drill<=selected_drill;last_event_kind<=selected_kind;last_event_accepted<=0;
                        last_event_level<=selected_level;last_event_region<=selected_region;
                    end
                    request_valid<=1;
                    if(CONFIRM_UI)last_ack_result<=4'he;
                    permission_denied<=0;error_latched<=0;retry_count<=0;
                end
            end
            if(request_valid&&request_ready)begin
                request_valid<=0;ack_pending<=1;ack_timer<=0;
            end
            if(matching_ack)begin
                ack_pending<=0;ack_timer<=0;last_ack_result<=ack_result;
                link_alive<=1;link_timer<=0;
                if(ack_result<=1)error_latched<=0;else error_latched<=1;
                if(V5_CONTROLS&&request_action==0)begin
                    last_event_accepted<=ack_result<=1;
                    if(ack_result<=1)begin
                        last_event_kind<=request_kind;
                        if(SIMPLE_ACTIONS&&(request_kind==1||request_kind==3))selected_evacuation<=1;
                    end
                end
                if(V5_CONTROLS&&request_action==3&&ack_result<=1)begin last_event_accepted<=0;selected_evacuation<=0;end
            end
            if(heartbeat_valid)begin
                link_alive<=1;link_timer<=0;remote_alarm<=heartbeat_alarm;
                remote_level<=heartbeat_level;remote_active_count<=heartbeat_active_count;
                remote_blocked_set<=heartbeat_blocked_set;
            end
            if(rx_frame_error||rx_crc_error)error_latched<=1;
            if(ms_tick)begin
                if(link_alive&&!heartbeat_valid&&!matching_ack)begin
                    if(link_timer==LINK_TIMEOUT_MS-1)begin
                        link_alive<=0;link_timer<=0;error_latched<=1;
                    end else link_timer<=link_timer+1'b1;
                end
                if(ack_pending&&!matching_ack&&!request_valid)begin
                    if(ack_timer==ACK_TIMEOUT_MS-1)begin
                        ack_timer<=0;
                        if(retry_count<MAX_RETRIES)begin
                            retry_count<=retry_count+1'b1;request_valid<=1;
                        end else begin
                            ack_pending<=0;last_ack_result<=4'hf;error_latched<=1;
                        end
                    end else ack_timer<=ack_timer+1'b1;
                end
            end
        end
    end
endmodule
