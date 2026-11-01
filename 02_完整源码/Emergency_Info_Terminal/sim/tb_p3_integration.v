`timescale 1ns/1ps
module tb_p3_integration;
    reg clk=0,rst=1,frame_tick=0,first_pixel=0,audio_tick=0,demo=0;always #5 clk=~clk;
    wire alarm,drill,trusted,cancel,flash,buzzer,latency_valid,result_valid;
    wire finish_valid;wire [3:0] finish_reason;wire [2:0] level;
    wire [15:0] countdown;wire [7:0] blocked;wire [3:0] result;wire [23:0] pixel_us,audio_us;wire [47:0] samples;
    emergency_control_core #(.CLK_HZ(1000000)) dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .first_active_pixel(first_pixel),.audio_sample_tick(audio_tick),.demo_alarm(demo),
        .command_valid(1'b0),.command_opcode(3'd0),.command_source(2'd0),.command_kind(3'd0),
        .command_event_id(16'd0),.command_sequence(8'd0),.command_level(3'd0),
        .command_drill(1'b0),.command_pending(1'b0),.command_region(3'd0),
        .command_time_trusted(1'b0),.command_remaining_seconds(16'd0),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .command_result_valid(result_valid),
        .command_result_code(result),.alarm_active(alarm),.alarm_level(level),.alarm_drill(drill),
        .countdown_trusted(trusted),.countdown_seconds(countdown),.cancel_notice(cancel),.flash_on(flash),
        .buzzer_on(buzzer),.blocked_set(blocked),.latency_valid(latency_valid),.pixel_latency_us(pixel_us),
        .audio_latency_us(audio_us),.finish_valid(finish_valid),
        .finish_reason(finish_reason),.sample_count(samples));
    reg [10:0] x=0,y=0;wire [23:0] rendered;
    alarm_page_renderer #(.WIDTH(64),.HEIGHT(48)) page(.clk(clk),.rst(rst),.x(x),.y(y),.rgb_in(24'h112233),
        .alarm_active(alarm),.alarm_level(level),.alarm_drill(drill),.cancel_notice(cancel),.flash_on(flash),
        .countdown_trusted(trusted),.countdown_seconds(countdown),.latency_valid(latency_valid),
        .pixel_latency_us(pixel_us),.audio_latency_us(audio_us),.rgb_out(rendered));
    reg [15:0] bcd_countdown=16'd12;
    wire [23:0] bcd_rendered;
    alarm_page_renderer #(.WIDTH(64),.HEIGHT(48)) bcd_page(.clk(clk),.rst(rst),.x(x),.y(y),.rgb_in(24'h112233),
        .alarm_active(1'b1),.alarm_level(3'd1),.alarm_drill(1'b0),.cancel_notice(1'b0),.flash_on(1'b0),
        .countdown_trusted(1'b1),.countdown_seconds(bcd_countdown),.latency_valid(1'b0),
        .pixel_latency_us(24'd0),.audio_latency_us(24'd0),.rgb_out(bcd_rendered));
    wire signed [15:0] mixed;
    emergency_audio_mixer mixer(.clk(clk),.rst(rst),.sample_valid(audio_tick),.normal_sample(16'sd100),
        .alarm_active(alarm),.voice_valid(1'b0),.voice_sample(16'sd0),
        .prompt_valid(1'b0),.prompt_sample(16'sd0),.mixed_sample(mixed));
    task pulse_frame;begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end endtask
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_p3_integration: %0s",reason);$finish;end endtask
    integer i,nonzero;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        repeat(12)@(posedge clk);#1;
        if(bcd_page.hundreds_digit!=0||bcd_page.tens_digit!=1||bcd_page.ones_digit!=2)
            fail("sequential BCD 012 conversion");
        bcd_countdown=16'd999;repeat(12)@(posedge clk);#1;
        if(bcd_page.hundreds_digit!=9||bcd_page.tens_digit!=9||bcd_page.ones_digit!=9)
            fail("sequential BCD 999 conversion");
        bcd_countdown=16'd1200;repeat(3)@(posedge clk);#1;
        if(bcd_page.hundreds_digit!=9||bcd_page.tens_digit!=9||bcd_page.ones_digit!=9)
            fail("sequential BCD saturation");
        demo=1;repeat(4)@(negedge clk);pulse_frame();repeat(2)@(posedge clk);#1;
        if(!alarm||!drill||!trusted||countdown!=12)begin $display("alarm=%b drill=%b trusted=%b countdown=%0d",alarm,drill,trusted,countdown);fail("demo did not commit at frame boundary");end
        x=0;y=0;#1;if(rendered==24'h112233)fail("L0 page depends on base image");
        repeat(5)@(negedge clk);first_pixel=1;@(negedge clk);first_pixel=0;
        repeat(3)@(negedge clk);audio_tick=1;@(negedge clk);audio_tick=0;
        repeat(3)@(posedge clk);#1;
        if(!latency_valid&&pixel_us==0&&audio_us==0)fail("latency capture");
        nonzero=0;for(i=0;i<20;i=i+1)begin @(negedge clk);audio_tick=1;@(negedge clk);audio_tick=0;repeat(63)@(negedge clk);if(mixed!=0)nonzero=1;end
        if(!nonzero)fail("alarm audio silent");
        demo=0;wait(finish_valid);#1;
        if(!finish_valid||finish_reason!=1)
            fail("cancel did not produce finish reply");
        pulse_frame();wait(dut.local_events.events.state==0&&!dut.local_events.events.summary_waiting);#1;
        if(alarm&&!cancel)fail("demo cancel did not remove event");
        $display("TEST_PASS tb_p3_integration L0 page/audio, latency and finish reply");$finish;
    end
    initial begin #500000;fail("timeout");end
endmodule
