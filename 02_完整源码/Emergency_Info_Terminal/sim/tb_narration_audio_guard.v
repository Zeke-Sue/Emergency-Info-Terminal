`timescale 1ns/1ps
module tb_narration_audio_guard;
    reg clk=0,rst=1,asset_begin=0,asset_complete=0,certificate_valid=0;
    reg sample_tick=0,playing=1,sample_valid=0,alarm_active=0;
    reg [7:0] asset_purpose=8'h21,certificate_purpose=8'h21;
    reg [31:0] asset_length=32'd4096,asset_crc=32'h12345678;
    reg [31:0] certificate_length=32'd4096,certificate_crc=32'h12345678;
    reg certificate_pass=1;
    reg [15:0] certificate_version=16'h0500;
    wire external_allowed,prompt_valid,audio_underflow;
    wire [3:0] reject_reason;
    always #5 clk=~clk;
    narration_audio_guard dut(.clk(clk),.rst(rst),.asset_begin(asset_begin),
        .asset_complete(asset_complete),.asset_purpose(asset_purpose),
        .asset_length(asset_length),.asset_crc32(asset_crc),
        .certificate_valid(certificate_valid),.certificate_purpose(certificate_purpose),
        .certificate_length(certificate_length),.certificate_crc32(certificate_crc),
        .certificate_pass(certificate_pass),.certificate_version(certificate_version),
        .sample_tick(sample_tick),.narration_playing(playing),.sample_valid(sample_valid),
        .alarm_active(alarm_active),.external_allowed(external_allowed),
        .reject_reason(reject_reason),.prompt_valid(prompt_valid),
        .audio_underflow(audio_underflow));
    task fail;input [8*120-1:0] reason;begin
        $display("TEST_FAIL tb_narration_audio_guard: %0s",reason);$finish;end endtask
    task pulse_asset_complete;begin
        @(negedge clk);asset_complete=1;@(negedge clk);asset_complete=0;#1;end endtask
    task pulse_certificate;begin
        @(negedge clk);certificate_valid=1;@(negedge clk);certificate_valid=0;#1;end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;sample_tick=1;#1;
        if(external_allowed||prompt_valid||audio_underflow||reject_reason!=1)
            fail("unloaded asset affected audio");
        certificate_version=16'h0402;pulse_certificate();pulse_asset_complete();
        if(external_allowed||reject_reason!=4)fail("legacy payload-only certificate authorized container");
        certificate_version=16'h0500;
        pulse_certificate();asset_crc=32'h12345679;pulse_asset_complete();
        if(external_allowed||audio_underflow||reject_reason!=7)
            fail("CRC mismatch was not safely rejected");
        @(negedge clk);asset_begin=1;@(negedge clk);asset_begin=0;
        asset_crc=certificate_crc;pulse_asset_complete();
        if(!external_allowed||reject_reason!=0||!audio_underflow||prompt_valid)
            fail("authorized missing sample did not report underrun");
        sample_valid=1;#1;
        if(audio_underflow||!prompt_valid)fail("authorized sample was not admitted");
        alarm_active=1;#1;
        if(prompt_valid||audio_underflow)fail("alarm did not suppress narration path");
        alarm_active=0;playing=0;sample_valid=0;#1;
        if(audio_underflow||prompt_valid)fail("stopped narration reported underrun");
        @(negedge clk);asset_begin=1;asset_complete=1;#1;
        if(external_allowed)fail("revocation did not mask output immediately");
        @(negedge clk);asset_begin=0;asset_complete=0;#1;
        if(external_allowed||reject_reason!=1)fail("completion overrode same-cycle revocation");
        $display("TEST_PASS tb_narration_audio_guard rejection, authorization, underrun, alarm priority and revocation");
        $finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
