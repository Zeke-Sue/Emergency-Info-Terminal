`timescale 1ns/1ps

module l0_voice_scheduler #(
    parameter integer ENABLE_CONTEXT=0
)(
    input wire clk,rst,alarm_active,alarm_drill,cancel_notice,
    input wire [2:0] alarm_level,
    input wire countdown_trusted,
    input wire [15:0] countdown_seconds,
    input wire enqueue_ready,
    input wire [2:0] alarm_kind,
    input wire alarm_pending,alarm_evacuation,
    input wire [25:0] event_identity,
    output reg cancel_queue,
    output wire cfg_we,
    output wire [5:0] cfg_segment,
    output wire [15:0] cfg_start,cfg_length,
    output reg enqueue_valid,
    output reg [5:0] enqueue_segment,
    output reg enqueue_urgent
);
    reg config_active;
    reg [5:0] config_index;
    l0_voice_catalog catalog(.segment(config_index),.start(cfg_start),.length(cfg_length));
    assign cfg_we=config_active;
    assign cfg_segment=config_index;
    reg [5:0] sequence [0:7];
    reg [3:0] sequence_count;
    reg [2:0] sequence_index;
    reg sequence_urgent,alarm_q,cancel_q;
    reg [15:0] countdown_q;
    reg [2:0] five_second_count;
    wire [35:0] context_now=ENABLE_CONTEXT ?
        {event_identity,alarm_kind,alarm_level,alarm_pending,alarm_evacuation,alarm_drill,1'b0} : 36'd0;
    reg [35:0] context_q;
    integer tens,ones;
    always @* begin tens=countdown_seconds/10;ones=countdown_seconds%10;end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            config_active<=1;config_index<=0;sequence_count<=0;sequence_index<=0;
            sequence_urgent<=0;enqueue_valid<=0;enqueue_segment<=0;enqueue_urgent<=0;
            cancel_queue<=0;alarm_q<=0;cancel_q<=0;countdown_q<=0;
            five_second_count<=5;context_q<=0;
        end else begin
            enqueue_valid<=0;enqueue_urgent<=0;cancel_queue<=0;
            if(config_active)begin
                if(config_index==(ENABLE_CONTEXT ? 27 : 22))config_active<=0;
                else config_index<=config_index+1'b1;
            end else begin
                alarm_q<=alarm_active;cancel_q<=cancel_notice;context_q<=context_now;
                if(cancel_notice&&!cancel_q)begin
                    sequence[0]<=19;sequence_count<=1;sequence_index<=0;sequence_urgent<=1;
                end else if(!alarm_active)begin
                    sequence_count<=0;sequence_index<=0;
                    if(alarm_q)cancel_queue<=1;
                end else if(!cancel_notice&&(!alarm_q||context_q!=context_now))begin
                    sequence_index<=0;sequence_urgent<=1;five_second_count<=5;
                    countdown_q<=countdown_seconds;
                    if(ENABLE_CONTEXT&&alarm_kind!=0)begin
                        if(alarm_evacuation)begin sequence[0]<=25;sequence_count<=1;end
                        else if(alarm_kind==1)begin
                            sequence[0]<=23;sequence[1]<=alarm_pending ? 26 : 24;sequence_count<=2;
                        end else begin sequence[0]<=27;sequence_count<=1;end
                        if(alarm_drill)begin
                            sequence[0]<=13;
                            sequence[1]<=alarm_evacuation ? 25 : alarm_kind==1 ? 23 : 27;
                            sequence[2]<=alarm_pending ? 26 : 24;
                            sequence_count<=alarm_kind==1&&!alarm_evacuation ? 3 : 2;
                        end
                    end else if(alarm_drill)begin
                        sequence[0]<=13;sequence[1]<=12;sequence[2]<=13+alarm_level;sequence_count<=3;
                    end else begin sequence[0]<=12;sequence[1]<=13+alarm_level;sequence_count<=2;end
                end else if(!cancel_notice&&countdown_trusted&&(!ENABLE_CONTEXT||alarm_kind==0)&&
                        countdown_seconds!=countdown_q&&sequence_count==0)begin
                    countdown_q<=countdown_seconds;
                    if(countdown_seconds<=10||five_second_count==1)begin
                        sequence_index<=0;sequence_urgent<=1;five_second_count<=5;
                        if(countdown_seconds==0)begin sequence[0]<=18;sequence_count<=1;end
                        else if(countdown_seconds<=10)begin
                            sequence[0]<=countdown_seconds[5:0];sequence[1]<=11;sequence_count<=2;
                        end else if(countdown_seconds<20)begin
                            sequence[0]<=10;sequence[1]<=ones;sequence[2]<=11;sequence_count<=3;
                        end else if(countdown_seconds<100&&ones==0)begin
                            sequence[0]<=tens;sequence[1]<=10;sequence[2]<=11;sequence_count<=3;
                        end else if(countdown_seconds<100)begin
                            sequence[0]<=tens;sequence[1]<=10;sequence[2]<=ones;
                            sequence[3]<=11;sequence_count<=4;
                        end
                    end else five_second_count<=five_second_count-1'b1;
                end else if(sequence_count!=0&&!enqueue_valid&&
                        (enqueue_ready||(sequence_urgent&&sequence_index==0)))begin
                    enqueue_valid<=1;enqueue_segment<=sequence[sequence_index];
                    enqueue_urgent<=sequence_urgent&&sequence_index==0;
                    sequence_index<=sequence_index+1'b1;sequence_count<=sequence_count-1'b1;
                end
            end
        end
    end
endmodule
