`timescale 1ns/1ps

module console_video_source(
    input wire clk,input wire rst,
    input wire link_alive,input wire ack_pending,input wire error_latched,
    input wire permission_denied,input wire remote_alarm,
    input wire [1:0] role,input wire [1:0] action,
    input wire [2:0] selected_level,input wire [2:0] selected_region,
    input wire [2:0] remote_level,input wire [3:0] remote_active_count,
    input wire [7:0] remote_blocked_set,input wire [23:0] pixel_latency_us,
    input wire [15:0] telemetry_max_line,
    input wire [15:0] telemetry_video_underflows,
    input wire [15:0] telemetry_uart_errors,
    input wire [15:0] log_records,input wire [15:0] log_dropped,
    input wire [7:0] log_digest,
    input wire admission_busy,input wire [4:0] admission_completed,
    input wire [4:0] admission_total,input wire [15:0] admission_pass_bitmap,
    input wire [3:0] admission_error,input wire [3:0] admission_reason,
    output reg axis_valid,output reg axis_user,output reg axis_last,
    output reg [23:0] axis_data,output reg frame_tick
);
    reg [9:0] h_count;reg [9:0] v_count;
    wire active=h_count<640&&v_count<480;
    wire [23:0] dashboard_rgb;
    console_dashboard_renderer dashboard(.x({1'b0,h_count}),.y({1'b0,v_count}),
        .link_alive(link_alive),.ack_pending(ack_pending),
        .error_latched(error_latched),.permission_denied(permission_denied),
        .remote_alarm(remote_alarm),.role(role),.action(action),
        .selected_level(selected_level),.selected_region(selected_region),
        .remote_level(remote_level),.remote_active_count(remote_active_count),
        .remote_blocked_set(remote_blocked_set),.pixel_latency_us(pixel_latency_us),
        .telemetry_max_line(telemetry_max_line),
        .telemetry_video_underflows(telemetry_video_underflows),
        .telemetry_uart_errors(telemetry_uart_errors),.log_records(log_records),
        .log_dropped(log_dropped),.log_digest(log_digest),
        .admission_busy(admission_busy),.admission_completed(admission_completed),
        .admission_total(admission_total),
        .admission_pass_bitmap(admission_pass_bitmap),
        .admission_error(admission_error),.admission_reason(admission_reason),
        .rgb(dashboard_rgb));
    always @(posedge clk or posedge rst)begin
        if(rst)begin h_count<=0;v_count<=0;axis_valid<=0;axis_user<=0;
            axis_last<=0;axis_data<=0;frame_tick<=0;end
        else begin
            axis_valid<=active;axis_user<=active&&h_count==0&&v_count==0;
            axis_last<=active&&h_count==639;axis_data<=dashboard_rgb;
            frame_tick<=h_count==799&&v_count==524;
            if(h_count==799)begin h_count<=0;
                if(v_count==524)v_count<=0;else v_count<=v_count+1'b1;
            end else h_count<=h_count+1'b1;
        end
    end
endmodule
