// 帧边界提交切图请求；目标图完整显示且转场结束后开始停留计时。
`timescale 1ns/1ps

module player_control #(
    parameter integer CLK_HZ = 25000000,
    parameter integer MANUAL_TARGET = 0,

    parameter integer FADE_STEPS = 16,
    parameter integer EXTERNAL_CONTROL = 0,
    parameter integer START_AUTOPLAY = 0,
    parameter integer DEFAULT_PERIOD = 2,
    parameter integer USE_CACHE = 0,
    parameter integer SKIP_FAILED = 0,
    parameter integer DUAL_SOURCE = 0,
    parameter integer EASING_CONTROL = 0,
    parameter integer PIPELINED_PHASE = 0,
    parameter integer NAVIGATION_HOLD = 0,
    parameter integer IMAGE_COUNT = 16,
    parameter integer PERIOD_COUNT = 4,
    parameter integer PERIOD_0 = 1,
    parameter integer PERIOD_1 = 2,
    parameter integer PERIOD_2 = 5,
    parameter integer PERIOD_3 = 10
)(
    input wire clk, rst, ready, frame_tick,
    input wire next_event, auto_event, period_event,
    input wire target_enable,
    input wire [3:0] target_index,
    input wire [2:0] effect_select,
    input wire external_play, previous_event, external_activity,
    input wire follow_narration,
    input wire [1:0] external_period,
    input wire [15:0] resident,
    input wire [15:0] failed_images,
    input wire emergency_abort,
    input wire navigation_hold,
    input wire [1:0] transition_duration,
    input wire transition_easing,
    output wire [3:0] desired_image,
    output reg [3:0] image_index,
    output reg autoplay,
    output reg [1:0] period_select,
    output reg [5:0] period_seconds,
    output reg [4:0] video_gain,
    output reg [2:0] transition_mode,
    output reg [3:0] transition_target,
    output reg [4:0] slide_progress,
    output wire [6:0] transition_phase,
    output wire slide_active,
    output wire transition_active
);
    localparam [1:0] TRANS_IDLE=0, TRANS_OUT=1, TRANS_IN=2, TRANS_SLIDE=3;
    localparam integer FADE_DELTA = FADE_STEPS<=1 ? 16 : 16/FADE_STEPS;
    reg [3:0] requested_index;
    reg requested_reverse;
    wire requested_bad=SKIP_FAILED && failed_images[requested_index];
    wire [3:0] skip_index=requested_reverse ?
        (requested_index==0 ? IMAGE_COUNT-1 : requested_index-1'b1) :
        (requested_index==IMAGE_COUNT-1 ? 0 : requested_index+1'b1);
    wire all_failed=SKIP_FAILED &&
        ((failed_images & ((16'hffff)>>(16-IMAGE_COUNT))) ==
         ((16'hffff)>>(16-IMAGE_COUNT)));
    assign desired_image=requested_index;
    wire target_ready=!USE_CACHE || resident[requested_index];
    reg [2:0] requested_mode;
    reg [1:0] transition_state;
    reg [31:0] second_div;
    reg [5:0] elapsed_seconds;
    reg [6:0] phase_step;
    reg [6:0] linear_phase;
    reg ease_latched;
    wire [6:0] ease_distance=linear_phase<=32 ? linear_phase : 7'd64-linear_phase;
    wire [13:0] ease_square=ease_distance*ease_distance;
    wire [6:0] ease_half=(ease_square+14'd16)>>5;
    wire [6:0] evaluated_phase=EASING_CONTROL && ease_latched ?
        (linear_phase<=32 ? ease_half : 7'd64-ease_half) : linear_phase;

    reg [6:0] phase_q;
    always @(posedge clk or posedge rst)
        if(rst)phase_q<=0;else phase_q<=evaluated_phase;
    assign transition_phase=PIPELINED_PHASE ? phase_q : evaluated_phase;
    wire hold_navigation=NAVIGATION_HOLD && navigation_hold;
    wire [1:0] external_period_safe=external_period>=PERIOD_COUNT ? 2'd0 : external_period;
    wire auto_advance = !transition_active && ready && autoplay && !follow_narration && !hold_navigation &&
                        (!EXTERNAL_CONTROL || (external_play && !external_activity && !previous_event)) && second_div == CLK_HZ-1 &&
                        elapsed_seconds == period_seconds-1;
    assign transition_active = transition_state!=TRANS_IDLE || requested_index!=image_index;
    assign slide_active = transition_state==TRANS_SLIDE;
    always @* begin
        case (period_select)
            0: period_seconds = PERIOD_0;
            1: period_seconds = PERIOD_1;
            2: period_seconds = PERIOD_2;
            default: period_seconds = PERIOD_3;
        endcase
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            image_index <= 0; requested_index <= 0; requested_mode <= 0; autoplay <= START_AUTOPLAY;
            requested_reverse<=0;
            period_select <= DEFAULT_PERIOD<PERIOD_COUNT ? DEFAULT_PERIOD : 0;
            second_div <= 0; elapsed_seconds <= 0;
            video_gain <= 16; transition_state <= TRANS_IDLE;
            transition_mode <= 0; transition_target <= 0; slide_progress <= 0;
            linear_phase<=0;phase_step<=4;ease_latched<=0;
        end else if (!ready) begin
            if(SKIP_FAILED)begin
                if(frame_tick && requested_bad && !all_failed)requested_index<=skip_index;
                else if(frame_tick && resident[requested_index])image_index<=requested_index;
            end else begin image_index<=0;requested_index<=0;end
            requested_mode <= 0; autoplay <= START_AUTOPLAY;
            second_div <= 0; elapsed_seconds <= 0;
            video_gain <= 16; transition_state <= TRANS_IDLE;
            transition_mode <= 0; transition_target <= 0; slide_progress <= 0;
            linear_phase<=0;phase_step<=4;ease_latched<=0;
        end else begin
            if (MANUAL_TARGET && target_enable) begin
                requested_index<=target_index;requested_mode<=effect_select;requested_reverse<=0;
            end else if (!hold_navigation && (next_event || previous_event || (auto_advance && !auto_event && !period_event))) begin
                requested_reverse<=previous_event;
                if(previous_event)
                    requested_index <= requested_index==0 ? IMAGE_COUNT-1 : requested_index-1'b1;
                else
                    requested_index <= requested_index==IMAGE_COUNT-1 ? 0 : requested_index+1'b1;
                requested_mode <= effect_select;
            end else if(frame_tick && requested_bad && !all_failed)begin
                requested_index<=skip_index;
            end
            if(EXTERNAL_CONTROL) begin
                autoplay<=external_play;
                period_select<=external_period_safe;
            end else begin
                if (auto_event) autoplay <= !autoplay;
                if (period_event) period_select <= period_select==PERIOD_COUNT-1 ? 2'd0 : period_select+1'b1;
            end

            if (hold_navigation || follow_narration || !autoplay || emergency_abort || transition_active || next_event || previous_event || auto_event ||
                    period_event || auto_advance ||
                    (EXTERNAL_CONTROL && (previous_event || external_activity || !external_play || period_select!=external_period_safe))) begin
                second_div <= 0; elapsed_seconds <= 0;
            end else if (second_div == CLK_HZ-1) begin
                second_div <= 0; elapsed_seconds <= elapsed_seconds + 1'b1;
            end else second_div <= second_div + 1'b1;
            if(frame_tick)begin
                if(emergency_abort || hold_navigation) begin
                    requested_index<=image_index;transition_target<=image_index;
                    video_gain<=16;slide_progress<=0;transition_state<=TRANS_IDLE;
                    linear_phase<=0;
                end else begin
                case(transition_state)
                    TRANS_IDLE:if(requested_index!=image_index && target_ready)begin
                        transition_mode<=requested_mode;
                        transition_target<=requested_index;
                        if(DUAL_SOURCE)begin
                            phase_step<=transition_duration==0 ? 7'd4 :
                                (transition_duration==1 ? 7'd2 : 7'd1);
                            linear_phase<=0;ease_latched<=transition_easing;
                            video_gain<=16;slide_progress<=0;
                            transition_state<=TRANS_SLIDE;
                        end else if(requested_mode==3'd2)begin
                            video_gain<=16;slide_progress<=FADE_DELTA;
                            transition_state<=TRANS_SLIDE;
                        end else if(FADE_DELTA>=16)begin
                            video_gain<=0;image_index<=requested_index;transition_state<=TRANS_IN;
                        end else begin
                            video_gain<=16-FADE_DELTA;transition_state<=TRANS_OUT;
                        end
                    end
                    TRANS_OUT:begin
                        if(requested_index==image_index)begin
                            video_gain<=16;transition_state<=TRANS_IDLE;
                        end else if(video_gain<=FADE_DELTA && target_ready)begin
                            video_gain<=0;image_index<=requested_index;transition_state<=TRANS_IN;
                        end else if(video_gain>FADE_DELTA)video_gain<=video_gain-FADE_DELTA;
                    end
                    TRANS_IN:begin
                        if(requested_index!=image_index)begin
                            if(video_gain<=FADE_DELTA && target_ready)begin
                                video_gain<=0;image_index<=requested_index;
                            end else if(video_gain>FADE_DELTA)begin
                                video_gain<=video_gain-FADE_DELTA;transition_state<=TRANS_OUT;
                            end
                        end else if(video_gain+FADE_DELTA>=16)begin
                            video_gain<=16;transition_state<=TRANS_IDLE;
                        end else video_gain<=video_gain+FADE_DELTA;
                    end
                    TRANS_SLIDE:begin
                        if(DUAL_SOURCE)begin
                            if(linear_phase+phase_step>=64)begin
                                image_index<=transition_target;linear_phase<=64;
                                transition_state<=TRANS_IDLE;slide_progress<=0;
                            end else begin
                                linear_phase<=linear_phase+phase_step;
                                slide_progress<=(linear_phase+phase_step)>>2;
                            end
                        end else if(slide_progress>=16)begin
                            image_index<=transition_target;
                            slide_progress<=0;
                            video_gain<=16;
                            transition_state<=TRANS_IDLE;
                        end else if(slide_progress+FADE_DELTA>=16)
                            slide_progress<=16;
                        else slide_progress<=slide_progress+FADE_DELTA;
                    end
                    default:begin
                        video_gain<=16;slide_progress<=0;transition_state<=TRANS_IDLE;
                    end
                endcase
                end
            end
        end
    end
endmodule
