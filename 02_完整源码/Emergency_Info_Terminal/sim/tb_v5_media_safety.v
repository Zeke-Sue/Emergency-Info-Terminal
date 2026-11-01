`timescale 1ns/1ps
module tb_v5_media_safety;
    reg sys_clk=0,clk=0,rst=1;
    always #5 sys_clk=~sys_clk;
    always #10 clk=~clk;
    reg [3:0] keys=15;
    reg [1:0] switches=0;
    reg sw3=0,contact=0;
    wire alarm,mono,video_valid,video_first;wire [3:0] count;wire [7:0] blocked;
    integer frames=0,n;
    media_core #(.WIDTH(8),.HEIGHT(4),.BURST(4),.HTOTAL(128),.VTOTAL(16),.HSTART(32),.VSTART(4),
        .CONTROL_HZ(1000),.DEBOUNCE_CYCLES(4),.KEY_LONG_CYCLES(1000),.ENABLE_EFFECTS(0),
        .ENABLE_LOCAL_STFT(0),.V5_CONTROLS(1),.BOARD_EVENT_AUTHORITY(1),.BOARD_ROUTE_AUTHORITY(1)) dut(
        .sys_clk(sys_clk),.pixel_clk(clk),.sys_rst(rst),.pixel_rst(rst),
        .key_zoom_n(keys[0]),.key_next_n(keys[1]),.key_auto_n(keys[2]),.key_period_n(keys[3]),
        .effect_switch(switches),.overlay_switch(sw3),.grayscale_switch(contact),
        .mem_init(1'b0),.mem_busy(1'b0),.sd_ready(1'b0),
        .emergency_cmd_valid(1'b0),.emergency_cmd_opcode(3'd0),.emergency_cmd_source(2'd0),
        .emergency_cmd_kind(3'd0),.emergency_cmd_event_id(16'd0),.emergency_cmd_sequence(8'd0),
        .emergency_cmd_level(3'd0),.emergency_cmd_drill(1'b0),.emergency_cmd_pending(1'b0),
        .emergency_cmd_region(3'd0),.emergency_cmd_time_trusted(1'b0),.emergency_cmd_remaining_seconds(16'd0),
        .emergency_cmd_snapshot(33'd0),.emergency_cmd_epoch_changed(1'b0),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),.console_proxy_valid(1'b0),.console_proxy_status(96'd0),
        .spectrum_message_valid(1'b0),.spectrum_message_type(8'd0),.spectrum_message_payload(96'd0),
        .narration_enable(1'b0),.narration_cfg_we(1'b0),.narration_cfg_index(8'd0),.narration_cfg_sample(32'd0),
        .narration_cfg_subtitle(8'd0),.narration_cfg_last(1'b0),.narration_sample_valid(1'b0),.narration_sample(16'd0),
        .narration_asset_begin(1'b0),.narration_asset_complete(1'b0),.narration_asset_purpose(8'd0),
        .narration_asset_length(32'd0),.narration_asset_crc32(32'd0),.narration_certificate_valid(1'b0),
        .narration_certificate(96'd0),.sector_data(8'd0),.sector_valid(1'b0),.sector_end(1'b0),
        .rd_valid(1'b0),.rd_data(32'd0),.axis_ready(1'b1),.axis_valid(video_valid),.axis_user(video_first),
        .alarm_active(alarm),.alarm_active_count(count),.alarm_blocked_set(blocked),.grayscale_enable(mono));
    always @(posedge clk)if(!rst)begin
        if(video_valid&&video_first)frames=frames+1;
        if(dut.l0_enqueue&&dut.l0_enqueue_segment==12)begin
            $display("TEST_FAIL V5 media: fire selected earthquake speech");$finish;
        end
    end
    task step;input integer clocks;begin repeat(clocks)@(negedge clk);end endtask
    task short_key;input integer key;begin keys[key]=0;step(16);keys[key]=1;step(16);end endtask
    task execute;begin short_key(2);keys[2]=0;step(2020);keys[2]=1;step(16);end endtask
    task fail;input [799:0] reason;begin $display("TEST_FAIL V5 media: %0s",reason);$finish;end endtask
    initial begin
        step(4);rst=0;step(16);contact=1;step(16);
        if(!alarm||mono||count!=1||blocked!=1||dut.alarm_kind!=1||!dut.alarm_pending)
            fail("actual switch to emergency integration without card/RAM/B");
        short_key(3);short_key(1);short_key(1);short_key(2);
        if(!dut.local_menu||dut.local_role!=2||dut.local_selection!=1)fail("physical KEY mapping");
        execute();if(!dut.local_fire_confirmed||dut.alarm_evacuation)fail("confirmation implicitly evacuated");
        short_key(1);execute();if(!dut.alarm_evacuation)fail("authorized evacuation unreachable");
        short_key(1);execute();if(!alarm||dut.local_result!=3)fail("closed input reset");
        contact=0;step(16);if(!alarm)fail("open input automatically cleared");
        execute();if(dut.local_fire_active||blocked!=0||count!=0)fail("reset did not release local state");
        short_key(3);switches=3;sw3=1;step(3000);
        if(dut.local_demo_alarm||mono||dut.brightness_level!=1)fail("legacy switch combination still owns V5 controls");
        if(frames<4)fail("video stalled while operating without media/B");
        $display("TEST_PASS V5 media: actual media_core, all four keys, SW4 latch/confirmation/evacuation/reset, no-TF/no-RAM/no-B operation, continuous raster, night preset");$finish;
    end
    initial begin #1000000;fail("timeout");end
endmodule
