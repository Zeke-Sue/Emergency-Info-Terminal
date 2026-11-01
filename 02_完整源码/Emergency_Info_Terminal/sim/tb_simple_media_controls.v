`timescale 1ns/1ps

module tb_simple_media_controls;
    reg sys_clk=0,clk=0,rst=1;
    always #10 sys_clk=~sys_clk;
    always #20 clk=~clk;
    reg [1:0] switches=0;
    reg sw3=0,sw4=0,command=0;
    reg [3:0] keys=4'b1111;
    reg [32:0] snapshot=0;
    wire ready,result,valid,alarm;
    wire [3:0] result_code;
    wire signed [15:0] left,right;
    media_core #(.FILMING_PROFILE(1),.CONTROL_HZ(25000000),.DEBOUNCE_CYCLES(4),.KEY_LONG_CYCLES(50),.SIMPLE_DEMO(1),
        .ENABLE_LOCAL_STFT(0),.ENABLE_TF_NARRATION(1),.ENABLE_TF_IMA(0),
        .ENABLE_L0_VOICE(0),.COMPACT_SCENES(1),.COMPACT_DIAGNOSTICS(1),
        .CANONICAL_PCM(1),.HUMAN_RECORDINGS(1),.SINGLE_CARD_AUDIO(1),
        .DUAL_TRANSITIONS(1),.BOARD_ROUTE_AUTHORITY(1),.BOARD_EVENT_AUTHORITY(1),
        .V5_CONTROLS(1),.FIXED_RATE_AXIS(1)) dut(
        .sys_clk(sys_clk),.pixel_clk(clk),.sys_rst(rst),.pixel_rst(rst),
        .key_zoom_n(keys[0]),.key_next_n(keys[1]),.key_auto_n(keys[3]),.key_period_n(keys[2]),
        .effect_switch(switches),.overlay_switch(sw3),.grayscale_switch(sw4),
        .mem_init(1'b0),.mem_busy(1'b0),.sd_ready(1'b0),
        .emergency_cmd_valid(command),.emergency_cmd_opcode(3'd6),.emergency_cmd_source(2'd2),
        .emergency_cmd_kind(3'd0),.emergency_cmd_event_id(16'd7),.emergency_cmd_sequence(8'd1),
        .emergency_cmd_level(3'd1),.emergency_cmd_drill(1'b0),.emergency_cmd_pending(1'b0),
        .emergency_cmd_region(3'd0),.emergency_cmd_time_trusted(1'b0),
        .emergency_cmd_remaining_seconds(16'd0),.emergency_cmd_snapshot(snapshot),
        .emergency_cmd_epoch_changed(1'b0),.sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .console_proxy_valid(1'b0),.console_proxy_status(96'd0),
        .spectrum_message_valid(1'b0),.spectrum_message_type(8'd0),.spectrum_message_payload(96'd0),
        .narration_enable(1'b1),.narration_cfg_we(1'b0),.narration_cfg_index(8'd0),
        .narration_cfg_sample(32'd0),.narration_cfg_subtitle(8'd0),.narration_cfg_last(1'b0),
        .narration_sample_valid(1'b0),.narration_sample(16'd0),
        .narration_asset_begin(1'b0),.narration_asset_complete(1'b0),
        .narration_asset_purpose(8'd0),.narration_asset_length(32'd0),.narration_asset_crc32(32'd0),
        .narration_certificate_valid(1'b0),.narration_certificate(96'd0),.audio_play_permitted(1'b0),
        .sector_data(8'd0),.sector_valid(1'b0),.sector_end(1'b0),
        .rd_valid(1'b0),.rd_data(32'd0),.axis_ready(1'b1),
        .audio_valid(valid),.audio_left(left),.audio_right(right),.alarm_active(alarm),
        .emergency_cmd_ready(ready),.emergency_result_valid(result),.emergency_result_code(result_code));
    task send;
        input active,cancel;
        begin
            @(negedge clk);while(!ready)@(negedge clk);
            snapshot={8'hc0,25'd0};snapshot[0]=active;snapshot[1]=cancel;snapshot[8:5]=active;
            command=1;@(negedge clk);command=0;
            while(!result)@(negedge clk);
            if(result_code!=0)$fatal(1,"diagnostic preemption command rejected");
            repeat(10)@(negedge clk);
        end
    endtask
    task key;input integer k;input integer hold;begin
        @(negedge clk);keys[k]=0;repeat(hold)@(negedge clk);
        keys[k]=1;repeat(20)@(negedge clk);
    end endtask
    task frame;begin
        @(negedge clk);while(!dut.frame_tick)@(negedge clk);@(negedge clk);
    end endtask
    integer i,nonzero,native;
    initial begin
        repeat(10)@(negedge clk);rst=0;repeat(20)@(negedge clk);
        switches=1;repeat(20)@(negedge clk);
        if(!dut.panel_mode||!dut.panel_running||alarm||dut.panel_selection!=0)$fatal(1,"test entry");
        native=0;nonzero=0;
        repeat(250000)begin @(negedge clk);
            if(dut.test_native_valid)native=native+1;
            if(valid&&left!=0)nonzero=nonzero+1;
        end
        if(native!=480||nonzero<100)$fatal(1,"native 48k rate or final PCM missing");
        for(i=1;i<=20;i=i+1)begin
            key(1,20);
            if(dut.panel_selection!=i||!dut.panel_running||!dut.diagnostic_test_active)$fatal(1,"manual navigation");
        end
        if(!dut.alarm_cancel_notice||dut.audible_alarm)$fatal(1,"silent release page");
        key(0,20);if(dut.panel_selection!=19||!dut.alarm_evacuation)$fatal(1,"previous evacuation");
        sw4=1;repeat(30)@(negedge clk);
        if(dut.diagnostic_test_active||!dut.audible_alarm)$fatal(1,"voice source switch");
        key(2,20);if(dut.panel_running||dut.audible_alarm||!dut.alarm_evacuation)$fatal(1,"audio pause");
        sw4=0;
        send(1,0);
        if(dut.panel_mode||dut.panel_running||dut.alarm_drill)$fatal(1,"remote real alarm failed to preempt local test");
        send(0,0);repeat(20)@(negedge clk);
        if(dut.panel_running)$fatal(1,"test resumed without confirmation after remote clear");
        switches=0;repeat(30)@(negedge clk);
        if(dut.panel_mode||dut.diagnostic_test_active)$fatal(1,"test did not exit");
        sw3=1;repeat(20)@(negedge clk);
        if(!dut.osd_visible||dut.quality_selection!=0)$fatal(1,"SW3 menu");
        key(1,20);if(dut.brightness_level!=3)$fatal(1,"KEY2 increase brightness");
        key(2,20);if(dut.quality_selection!=1)$fatal(1,"KEY3 next item");
        key(3,20);if(dut.quality_selection!=0)$fatal(1,"KEY4 previous item");
        sw3=0;repeat(20)@(negedge clk);if(dut.osd_visible)$fatal(1,"menu switch off");
        key(3,60);frame();if(dut.daily_zoom_scale!=1)$fatal(1,"KEY4 long zoom");
        key(2,20);frame();if(dut.daily_pan_y!=1)$fatal(1,"KEY3 pan up");
        key(3,20);frame();if(dut.daily_pan_y!=2)$fatal(1,"KEY4 pan down");
        key(3,60);frame();key(3,60);frame();
        if(dut.daily_zoom_scale!=0)$fatal(1,"failed to return to Fit");
        if(dut.broadcast_mode||dut.period_select!=0||dut.period_seconds!=2)$fatal(1,"default 2-second timed mode");

        force dut.ready_sync=2'b11;
        for(i=0;i<6;i=i+1)begin
            key(2,60);
            if(dut.period_select!=((i+1)%3)||dut.period_seconds!=
                ((i%3)==0 ? 5 : (i%3)==1 ? 10 : 2))
                $fatal(1,"physical KEY3 did not cycle 2/5/10 only");
        end
        release dut.ready_sync;
        sw4=1;frame();repeat(10)@(negedge clk);
        if(!dut.broadcast_mode||dut.brightness_level!=3||dut.audio_volume!=7||dut.local_fire_active)
            $fatal(1,"SW4 must select broadcast without changing quality or alarm");
        key(2,60);if(!dut.broadcast_mode||dut.period_select!=0)$fatal(1,"long KEY3 overrides SW4");
        sw3=1;repeat(20)@(negedge clk);sw4=0;frame();repeat(10)@(negedge clk);
        if(dut.broadcast_mode||!dut.osd_visible||!dut.autoplay)$fatal(1,"SW4 exit while menu open");
        sw3=0;sw4=1;switches=1;frame();repeat(10)@(negedge clk);
        if(!dut.panel_mode||!dut.panel_running||dut.panel_selection!=0)$fatal(1,"test reentry must start daily one");
        switches=0;frame();repeat(10)@(negedge clk);
        if(!dut.broadcast_mode||dut.panel_mode)$fatal(1,"test exit lost SW4 mode");

        rst=1;repeat(10)@(negedge clk);rst=0;frame();repeat(10)@(negedge clk);
        if(!dut.broadcast_mode||!dut.autoplay||dut.brightness_level!=2||dut.audio_volume!=7)$fatal(1,"boot with SW4 high");
        $display("TEST_PASS production A switches/keys, manual 21 pages, native 48k PCM, remote priority, menu, zoom, SW4 broadcast, timed periods and reset");$finish;
    end
    initial begin #1000000000;$fatal(1,"simple controls timeout");end
endmodule
