`timescale 1ns/1ps

module emergency_control_core #(
    parameter integer CLK_HZ=25000000,
    parameter integer CONFIGURABLE_FLASH=0,
    parameter integer REMOTE_EVENTS=0,
    parameter integer REMOTE_LINK_FRAMES=180,
    parameter integer LOCAL_FIRE=0
)(
    input wire clk,
    input wire rst,
    input wire frame_tick,
    input wire first_active_pixel,
    input wire audio_sample_tick,
    input wire demo_alarm,
    input wire local_fire_active,local_fire_confirmed,local_fire_evacuation,
    input wire [1:0] flash_rate,flash_duty,
    input wire command_valid,
    input wire [2:0] command_opcode,
    input wire [1:0] command_source,
    input wire [2:0] command_kind,
    input wire [15:0] command_event_id,
    input wire [7:0] command_sequence,
    input wire [2:0] command_level,
    input wire command_drill,
    input wire command_pending,
    input wire [2:0] command_region,
    input wire command_time_trusted,
    input wire [15:0] command_remaining_seconds,
    input wire [32:0] command_snapshot,
    input wire command_epoch_changed,
    input wire sync_blocked_valid,
    input wire [7:0] sync_blocked_set,
    output wire command_result_valid,
    output wire [3:0] command_result_code,
    output wire command_ready,
    output wire alarm_active,
    output wire [2:0] alarm_level,
    output wire [2:0] alarm_kind,
    output wire alarm_drill,
    output wire alarm_pending,
    output wire local_fire_visible,
    output wire alarm_evacuation,
    output wire [25:0] alarm_identity,
    output wire countdown_trusted,
    output reg [15:0] countdown_seconds,
    output wire cancel_notice,
    output wire flash_on,
    output wire buzzer_on,
    output wire [7:0] blocked_set,
    output wire [3:0] active_count,
    output wire authority_online,
    output reg latency_valid,
    output reg [23:0] pixel_latency_us,
    output reg [23:0] audio_latency_us,
    output reg finish_valid,
    output reg [3:0] finish_reason,
    output wire [47:0] sample_count
);
    wire us_tick,sample_tick;
    wire [47:0] microseconds;
    global_timebase #(.CLK_HZ(CLK_HZ)) timebase(.clk(clk),.rst(rst),.us_tick(us_tick),
        .sample_tick(sample_tick),.microseconds(microseconds),.sample_count(sample_count));
    reg [31:0] now_seconds;
    reg [19:0] us_in_second;
    reg demo_q,demo_command,demo_deferred_valid;
    reg [10:0] local_cancel_left;
    reg [2:0] demo_opcode,demo_deferred_opcode;
    wire mux_valid=command_valid||(!REMOTE_EVENTS&&demo_command);
    wire [2:0] mux_opcode=demo_command ? demo_opcode : command_opcode;
    wire [1:0] mux_source=demo_command ? 2'd3 : command_source;
    wire [2:0] mux_kind=demo_command ? 3'd0 : command_kind;
    wire [15:0] mux_id=demo_command ? 16'hd001 : command_event_id;
    wire [7:0] mux_sequence=demo_command ? 8'd1 : command_sequence;
    wire [2:0] mux_level=demo_command ? 3'd1 : command_level;
    wire mux_drill=demo_command ? 1'b1 : command_drill;
    wire mux_pending=demo_command ? 1'b0 : command_pending;
    wire [2:0] mux_region=demo_command ? 3'd0 : command_region;
    wire mux_time_trusted=demo_command ? 1'b1 : command_time_trusted;
    wire [15:0] mux_remaining=demo_command ? 16'd12 : command_remaining_seconds;
    wire primary_valid,primary_drill,primary_pending,primary_time_trusted,full_urgent;
    wire event_cancel_notice;
    wire [1:0] primary_source;
    wire [2:0] primary_kind,primary_level,primary_region;
    wire [15:0] primary_event_id,primary_remaining;
    wire [7:0] primary_sequence;
    wire [4:0] tombstone_count;
    wire authority_recovery;
    wire [7:0] primary_blocked_set;
    wire [3:0] primary_active_count;
    reg local_fire_q;
    assign alarm_identity={primary_source,primary_event_id,primary_sequence};
    assign blocked_set=primary_blocked_set|((LOCAL_FIRE&&local_fire_active) ? 8'h01 : 8'h00);
    assign active_count=primary_active_count+((LOCAL_FIRE&&local_fire_active&&primary_active_count<15) ? 4'd1 : 4'd0);
    generate if(REMOTE_EVENTS)begin: remote_events
    event_snapshot_sink #(.LINK_FRAMES(REMOTE_LINK_FRAMES),.CHECK_ROLE(LOCAL_FIRE)) events(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .command_valid(command_valid),.command_opcode(command_opcode),
        .command_kind(command_kind),.command_level(command_level),.command_region(command_region),
        .command_event_id(command_event_id),.command_remaining(command_remaining_seconds),
        .command_sequence(command_sequence),.command_drill(command_drill),
        .command_pending(command_pending),.command_trusted(command_time_trusted),
        .epoch_changed(command_epoch_changed),.snapshot(command_snapshot),
        .command_ready(command_ready),.result_valid(command_result_valid),.result_code(command_result_code),
        .primary_valid(primary_valid),.primary_drill(primary_drill),.primary_pending(primary_pending),
        .primary_trusted(primary_time_trusted),.primary_source(primary_source),.primary_kind(primary_kind),
        .primary_level(primary_level),.primary_region(primary_region),.primary_event_id(primary_event_id),
        .primary_remaining(primary_remaining),.primary_sequence(primary_sequence),.blocked_set(primary_blocked_set),
        .active_count(primary_active_count),.cancel_notice(event_cancel_notice),.full_urgent(full_urgent),
        .online(authority_online),.recovery_required(authority_recovery));
    assign tombstone_count=0;
    end else begin: local_events
    assign authority_online=1'b1;
    assign authority_recovery=1'b0;
    event_manager events(.clk(clk),.rst(rst),.frame_tick(frame_tick),.now_seconds(now_seconds),
        .cmd_valid(mux_valid),.cmd_opcode(mux_opcode),.cmd_source(mux_source),.cmd_kind(mux_kind),
        .cmd_event_id(mux_id),.cmd_sequence(mux_sequence),.cmd_level(mux_level),.cmd_drill(mux_drill),
        .cmd_pending(mux_pending),.cmd_region(mux_region),.cmd_time_trusted(mux_time_trusted),
        .cmd_role(2'd2),
        .cmd_remaining_seconds(mux_remaining),.cmd_ready(command_ready),.result_valid(command_result_valid),
        .sync_blocked_valid(sync_blocked_valid),.sync_blocked_set(sync_blocked_set),
        .result_code(command_result_code),.primary_valid(primary_valid),.primary_source(primary_source),
        .primary_kind(primary_kind),.primary_event_id(primary_event_id),
        .primary_sequence(primary_sequence),.primary_level(primary_level),
        .primary_drill(primary_drill),.primary_pending(primary_pending),.primary_time_trusted(primary_time_trusted),
        .primary_remaining_seconds(primary_remaining),.primary_region(primary_region),
        .active_count(primary_active_count),.tombstone_count(tombstone_count),.blocked_set(primary_blocked_set),
        .cancel_notice(event_cancel_notice),.full_urgent(full_urgent));
    end endgenerate

    assign local_fire_visible=LOCAL_FIRE&&local_fire_active&&
        (!primary_valid||primary_drill||primary_level>1||primary_kind!=0);
    assign alarm_evacuation=local_fire_visible ? local_fire_evacuation :
        (primary_valid&&!primary_pending&&primary_kind==3&&
            (!REMOTE_EVENTS||(authority_online&&!authority_recovery)));
    assign cancel_notice=(event_cancel_notice||((REMOTE_EVENTS||LOCAL_FIRE)&&local_cancel_left!=0))&&
        !primary_valid&&!demo_alarm&&!full_urgent&&!(LOCAL_FIRE&&local_fire_active);

    assign alarm_active=demo_alarm||primary_valid||cancel_notice||full_urgent||
        (LOCAL_FIRE&&local_fire_active);
    assign alarm_level=local_fire_visible||demo_alarm ? 3'd1 : (primary_valid ? primary_level : 3'd1);
    assign alarm_kind=local_fire_visible ? 3'd1 : demo_alarm ? 3'd0 : primary_kind;
    assign alarm_drill=!local_fire_visible&&(demo_alarm || (primary_valid && primary_drill));
    assign alarm_pending=local_fire_visible ? !local_fire_confirmed :
        (!primary_valid||primary_pending||(REMOTE_EVENTS&&(!authority_online||authority_recovery)));
    assign countdown_trusted=!local_fire_visible&&(demo_alarm || (primary_valid && primary_time_trusted));
    assign buzzer_on=alarm_active&&flash_on;
    reg [15:0] last_event_id;
    reg [1:0] last_event_source;
    reg [7:0] last_event_sequence;
    alarm_flash_timing flash_timing(.clk(clk),.rst(rst),.tick(us_tick),
        .frame_tick(frame_tick),.enable(alarm_active),.steady(countdown_trusted&&countdown_seconds==0),
        .rate_select(CONFIGURABLE_FLASH ? flash_rate : 2'd1),
        .duty_select(CONFIGURABLE_FLASH ? flash_duty : 2'd1),.flash_on(flash_on));
    reg capture_armed,pixel_captured,audio_captured;
    reg [47:0] capture_start;
    reg [2:0] accepted_opcode;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            now_seconds<=0;us_in_second<=0;demo_q<=0;demo_command<=0;demo_opcode<=0;
            local_cancel_left<=0;local_fire_q<=0;
            demo_deferred_valid<=0;demo_deferred_opcode<=0;
            countdown_seconds<=0;last_event_id<=0;last_event_source<=0;
            last_event_sequence<=0;
            capture_armed<=0;pixel_captured<=0;audio_captured<=0;capture_start<=0;
            latency_valid<=0;pixel_latency_us<=0;audio_latency_us<=0;
            finish_valid<=0;finish_reason<=0;accepted_opcode<=0;
        end else begin
            latency_valid<=0;finish_valid<=0;demo_q<=demo_alarm;
            local_fire_q<=LOCAL_FIRE&&local_fire_active;
            if(REMOTE_EVENTS||LOCAL_FIRE)begin
                if(frame_tick&&local_cancel_left!=0)local_cancel_left<=local_cancel_left-1'b1;
                if(demo_alarm||(LOCAL_FIRE&&local_fire_active))local_cancel_left<=0;
                else if((demo_q||local_fire_q)&&!primary_valid&&!full_urgent)local_cancel_left<=1786;
            end
            if(LOCAL_FIRE&&local_fire_q&&!local_fire_active)begin finish_valid<=1;finish_reason<=1;end
            if(mux_valid&&command_ready)
                accepted_opcode<=REMOTE_EVENTS ? command_snapshot[23:21] : mux_opcode;
            if(command_result_valid&&command_result_code==0&&
                    (accepted_opcode==1||accepted_opcode==2)) begin
                finish_valid<=1;
                finish_reason<=accepted_opcode==1 ? 4'd1 : 4'd2;
            end
            if(demo_command && command_ready) begin
                if(demo_deferred_valid) begin
                    demo_command<=1;demo_opcode<=demo_deferred_opcode;
                    demo_deferred_valid<=0;
                end else demo_command<=0;
            end
            if(demo_alarm!=demo_q) begin
                if(demo_command&&!command_ready) begin
                    demo_deferred_valid<=1;
                    demo_deferred_opcode<=demo_alarm ? 0 : 1;
                end else begin
                    demo_command<=!REMOTE_EVENTS;demo_opcode<=demo_alarm ? 0 : 1;
                end
                if(demo_alarm) countdown_seconds<=16'd12;
            end
            if(us_tick) begin
                if(us_in_second==999999) begin
                    us_in_second<=0;now_seconds<=now_seconds+1'b1;
                    if(alarm_active && countdown_seconds!=0) countdown_seconds<=countdown_seconds-1'b1;
                end else us_in_second<=us_in_second+1'b1;
            end
            if(primary_valid && !demo_alarm && (demo_q ||
                    (REMOTE_EVENTS&&command_result_valid&&command_result_code!=7)||primary_event_id!=last_event_id ||
                    primary_source!=last_event_source ||
                    primary_sequence!=last_event_sequence)) begin
                last_event_id<=primary_event_id;last_event_source<=primary_source;
                last_event_sequence<=primary_sequence;countdown_seconds<=primary_remaining;
            end
            if((command_valid&&command_ready&&
                    (command_opcode==0 || (REMOTE_EVENTS&&command_opcode==6&&command_snapshot[0])))||
                    (demo_alarm&&!demo_q)||(LOCAL_FIRE&&local_fire_active&&!local_fire_q)) begin
                capture_armed<=1;pixel_captured<=0;audio_captured<=0;capture_start<=microseconds;
            end
            if(capture_armed&&alarm_active&&first_active_pixel&&!pixel_captured) begin pixel_latency_us<=microseconds-capture_start;pixel_captured<=1;end
            if(capture_armed&&alarm_active&&audio_sample_tick&&!audio_captured) begin audio_latency_us<=microseconds-capture_start;audio_captured<=1;end
            if(capture_armed&&(pixel_captured||(alarm_active&&first_active_pixel))&&
               (audio_captured||(alarm_active&&audio_sample_tick))) begin capture_armed<=0;latency_valid<=1;end
        end
    end
endmodule
