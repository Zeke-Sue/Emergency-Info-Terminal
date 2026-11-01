`timescale 1ns/1ps

module tb_diagnostic_media_integration;
    reg sys_clk=0,clk=0,rst=1;
    always #10 sys_clk=~sys_clk;
    always #20 clk=~clk;
    reg [1:0] switches=0;
    reg sw3=0,command=0;
    reg [32:0] snapshot=0;
    wire ready,result,valid,alarm;
    wire [3:0] result_code;
    wire signed [15:0] left,right;
    media_core #(.CONTROL_HZ(25000000),.DEBOUNCE_CYCLES(4),
        .ENABLE_LOCAL_STFT(0),.ENABLE_TF_NARRATION(1),.ENABLE_TF_IMA(0),
        .ENABLE_L0_VOICE(0),.COMPACT_SCENES(1),.COMPACT_DIAGNOSTICS(1),
        .CANONICAL_PCM(1),.HUMAN_RECORDINGS(1),.SINGLE_CARD_AUDIO(1),
        .DUAL_TRANSITIONS(1),.BOARD_ROUTE_AUTHORITY(1),.BOARD_EVENT_AUTHORITY(1),
        .V5_CONTROLS(1),.FIXED_RATE_AXIS(1)) dut(
        .sys_clk(sys_clk),.pixel_clk(clk),.sys_rst(rst),.pixel_rst(rst),
        .key_zoom_n(1'b1),.key_next_n(1'b1),.key_auto_n(1'b1),.key_period_n(1'b1),
        .effect_switch(switches),.overlay_switch(sw3),.grayscale_switch(1'b0),
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
    integer n,outputs,native_count,crossings,peak;
    reg signed [15:0] previous;
    initial begin
        repeat(10)@(negedge clk);rst=0;
        repeat(1000)@(negedge clk);
        switches=2;repeat(10)@(negedge clk);
        if(dut.diagnostic_test_active)$fatal(1,"SW2 alone started test tone");
        sw3=1;repeat(250000)@(negedge clk);
        if(!dut.diagnostic_test_active||dut.narration_external_allowed)$fatal(1,"diagnostic needs card/B permission");
        outputs=0;native_count=0;crossings=0;peak=0;previous=0;
        repeat(2500000)begin
            @(negedge clk);
            if(dut.test_native_valid)native_count=native_count+1;
            if(valid)begin
                outputs=outputs+1;
                if(left!==right||(^left)===1'bx)$fatal(1,"invalid final diagnostic PCM");
                if(previous<0&&left>=0)crossings=crossings+1;
                if(left>peak)peak=left;
                previous=left;
            end
        end
        if(native_count!=4000||outputs<4799||outputs>4801||crossings<99||crossings>101||peak<500)
            $fatal(1,"end-to-end 100ms rate/pitch/amplitude native=%0d output=%0d crossings=%0d peak=%0d",native_count,outputs,crossings,peak);
        send(1,0);
        if(!alarm||dut.diagnostic_test_active||!dut.video.automatic_waveform)$fatal(1,"alarm did not preempt test and enable output waveform");
        send(0,1);
        if(dut.diagnostic_test_active||!dut.video.automatic_waveform)$fatal(1,"release did not preempt test");
        send(0,0);
        if(!dut.diagnostic_test_active)$fatal(1,"test did not resume after release");
        sw3=0;repeat(500000)@(negedge clk);
        if(dut.diagnostic_test_active)$fatal(1,"switch did not stop test");
        repeat(2000)begin @(negedge clk);if(valid&&left!==0)$fatal(1,"test tone still audible after stop");end
        $display("TEST_PASS switches -> 40k source -> 48k HDMI final PCM, 1kHz, no TF/B permission, alarm/release priority and stop");$finish;
    end
    initial begin #200000000;$fatal(1,"diagnostic integration timeout");end
endmodule
