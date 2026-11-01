`timescale 1ns/1ps

module console_event_log_manager(
    input wire clk,input wire rst,input wire ms_tick,input wire [15:0] b_boot,
    input wire [31:0] a_boot,
    input wire ack_valid,input wire [3:0] ack_result,
    input wire [31:0] ack_session,input wire [31:0] ack_sequence,
    input wire heartbeat_valid,input wire heartbeat_alarm,
    input wire [2:0] heartbeat_level,input wire [3:0] heartbeat_active_count,
    input wire [7:0] heartbeat_blocked_set,
    input wire telemetry_valid,input wire [15:0] telemetry_last_line,
    input wire [15:0] telemetry_max_line,
    input wire [15:0] telemetry_video_underflows,
    input wire [15:0] telemetry_uart_errors,
    input wire latency_valid,input wire [23:0] pixel_latency_us,
    input wire [23:0] audio_latency_us,
    input wire finish_valid,input wire [3:0] finish_reason,
    input wire admission_valid,input wire admission_pass,
    input wire [3:0] admission_reason,input wire [7:0] admission_purpose,
    input wire [31:0] admission_length,input wire [15:0] admission_version,
    input wire append_ready,output wire append_valid,
    output reg [1:0] category,output reg [5:0] flags,
    output reg [15:0] log_b_boot,output reg [31:0] log_b_ms,
    output reg [31:0] log_a_boot,output reg [31:0] log_a_us,
    output reg [7:0] event_type,output reg [55:0] payload,
    output reg [15:0] dropped_count,output reg [31:0] uptime_ms
);
    reg pending;
    wire [31:0] ack_sequence_handoff;
    console_hold_buffer #(.WIDTH(32)) ack_hold(
        .d(ack_sequence),.q(ack_sequence_handoff));
    wire any_event=admission_valid||latency_valid||finish_valid||ack_valid||
        telemetry_valid||heartbeat_valid;
    assign append_valid=pending;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            pending<=0;category<=0;flags<=0;log_b_boot<=0;log_b_ms<=0;
            log_a_boot<=0;log_a_us<=0;event_type<=0;payload<=0;
            dropped_count<=0;uptime_ms<=0;
        end else begin
            if(ms_tick)uptime_ms<=uptime_ms+1'b1;
            if(pending&&append_ready)pending<=0;
            if(any_event)begin
                if(pending&&!append_ready)dropped_count<=dropped_count+1'b1;
                else begin
                    pending<=1;log_b_boot<=b_boot;log_b_ms<=uptime_ms;
                    log_a_boot<=a_boot;log_a_us<=0;flags<=0;payload<=0;
                    if(admission_valid)begin
                        category<=2;event_type<=8'he5;
                        flags<={1'b0,admission_reason,admission_pass};
                        payload<={admission_purpose,admission_pass,
                            admission_reason,admission_version,admission_length[26:0]};
                    end else if(latency_valid)begin
                        category<=2;event_type<=8'h82;
                        log_a_us<={8'd0,pixel_latency_us};
                        payload<={pixel_latency_us,audio_latency_us,8'd0};
                    end else if(finish_valid)begin
                        category<=1;event_type<=8'h83;flags<={2'd0,finish_reason};
                        payload<={52'd0,finish_reason};
                    end else if(ack_valid)begin
                        category<=1;event_type<=8'h81;flags<={2'd0,ack_result};
                        payload<={ack_session[15:0],ack_sequence_handoff,ack_result,4'd0};
                    end else if(telemetry_valid)begin
                        category<=0;event_type<=8'h91;
                        payload<={telemetry_max_line,telemetry_video_underflows,
                            telemetry_uart_errors,telemetry_last_line[7:0]};
                    end else begin
                        category<=0;event_type<=8'h90;
                        payload<={a_boot,heartbeat_alarm,heartbeat_level,
                            heartbeat_active_count,heartbeat_blocked_set,8'd0};
                    end
                end
            end
        end
    end
endmodule
