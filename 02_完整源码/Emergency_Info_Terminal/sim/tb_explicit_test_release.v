`timescale 1ns/1ps
module tb_explicit_test_release;
    reg clk=0,rst=1,release_request=0,alarm=0;
    wire request,voice;wire [3:0] index;wire [7:0] subtitle;
    always #5 clk=~clk;
    human_stage_audio_requests #(.EXPLICIT_RELEASE(1)) dut(.clk(clk),.rst(rst),
        .release_request(release_request),.frame_tick(1'b0),.ready(1'b0),.narration_enable(1'b0),
        .configuration_valid(1'b1),.image_index(4'd0),.configured_narration_index(4'd0),
        .alarm_active(alarm),.alarm_drill(1'b1),.alarm_pending(1'b0),.alarm_kind(3'd1),
        .asset_complete(1'b0),.asset_purpose(8'd0),.asset_samples(32'd0),.consume(1'b0),
        .asset_failed(1'b0),.io_failed(1'b0),.request(request),.asset_index(index),
        .voice_asset(voice),.voice_subtitle(subtitle));
    initial begin
        repeat(3)@(negedge clk);rst=0;release_request=1;@(negedge clk);
        if(!request||index!=14||!voice||subtitle!=13)$fatal(1,"standalone release WAV request");
        repeat(20)begin @(negedge clk);if(request)$fatal(1,"release retrigger loop");end
        release_request=0;alarm=1;@(negedge clk);
        if(!request||index!=12||subtitle!=11)$fatal(1,"new fire failed to preempt release");
        $display("TEST_PASS standalone release requests real WAV 14 once and fire preempts it");$finish;
    end
endmodule
