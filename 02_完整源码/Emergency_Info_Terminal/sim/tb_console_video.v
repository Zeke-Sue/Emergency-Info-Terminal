`timescale 1ns/1ps
module tb_console_video;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg [10:0] x=0,y=0;reg link=0,ack=0,error=0,deny=0,alarm=0;
    reg [1:0] role=0,action=0;reg [2:0] level=1,region=0,remote_level=1;
    reg [3:0] active_count=0;reg [7:0] blocked=0;
    reg [23:0] latency=0;reg [15:0] max_line=0,underflow=0,uart_errors=0;
    wire [23:0] rgb;
    console_dashboard_renderer renderer(.x(x),.y(y),.link_alive(link),
        .ack_pending(ack),.error_latched(error),.permission_denied(deny),
        .remote_alarm(alarm),.role(role),.action(action),.selected_level(level),
        .selected_region(region),.remote_level(remote_level),
        .remote_active_count(active_count),.remote_blocked_set(blocked),
        .pixel_latency_us(latency),.telemetry_max_line(max_line),
        .telemetry_video_underflows(underflow),.telemetry_uart_errors(uart_errors),
        .log_records(16'd2),.log_dropped(16'd0),.log_digest(8'ha5),
        .admission_busy(1'b1),.admission_completed(5'd4),
        .admission_total(5'd10),.admission_pass_bitmap(16'h000f),
        .admission_error(4'd0),.admission_reason(4'd0),.rgb(rgb));
    wire valid,user,last,frame;wire [23:0] data;
    console_video_source source(.clk(clk),.rst(rst),.link_alive(link),
        .ack_pending(ack),.error_latched(error),.permission_denied(deny),
        .remote_alarm(alarm),.role(role),.action(action),.selected_level(level),
        .selected_region(region),.remote_level(remote_level),
        .remote_active_count(active_count),.remote_blocked_set(blocked),
        .pixel_latency_us(latency),.telemetry_max_line(max_line),
        .telemetry_video_underflows(underflow),.telemetry_uart_errors(uart_errors),
        .log_records(16'd2),.log_dropped(16'd0),.log_digest(8'ha5),
        .admission_busy(1'b1),.admission_completed(5'd4),
        .admission_total(5'd10),.admission_pass_bitmap(16'h000f),
        .admission_error(4'd0),.admission_reason(4'd0),
        .axis_valid(valid),.axis_user(user),.axis_last(last),.axis_data(data),
        .frame_tick(frame));
    integer cycles,valid_count,user_count,last_count,frame_count;
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tb_console_video: %0s",msg);$finish;end endtask
    initial begin
        x=500;y=20;#1;if(rgb!=24'h9c3440)fail("offline status colour");
        link=1;#1;if(rgb!=24'h137a56)fail("online status colour");
        x=40;y=112;alarm=1;remote_level=1;#1;
        if(rgb!=24'hb6202b)fail("level-one alarm colour");
        remote_level=2;#1;if(rgb!=24'hc95c18)fail("level-two alarm colour");
        alarm=0;#1;if(rgb!=24'h1c3948)fail("standby colour");
        x=340;y=112;deny=1;#1;if(rgb!=24'h8d323d)fail("permission colour");
        x=350;y=295;#1;if(rgb!=24'h72b7ff)fail("WAV admission progress colour");
        @(negedge clk);rst=0;valid_count=0;user_count=0;last_count=0;frame_count=0;
        for(cycles=0;cycles<420001;cycles=cycles+1)begin
            @(posedge clk);#1;
            if(valid)valid_count=valid_count+1;
            if(user)user_count=user_count+1;
            if(last)last_count=last_count+1;
            if(frame)frame_count=frame_count+1;
        end
        if(valid_count!=307201)fail("active pixel count");
        if(user_count!=2)fail("start-of-frame count");
        if(last_count!=480)fail("end-of-line count");
        if(frame_count!=1)fail("frame tick count");
        $display("TEST_PASS tb_console_video dashboard states and exact 640x480 raster");
        $finish;
    end
    initial begin #6000000;fail("timeout");end
endmodule
