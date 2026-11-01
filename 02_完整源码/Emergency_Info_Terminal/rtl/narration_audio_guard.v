`timescale 1ns/1ps

module narration_audio_guard #(
    parameter [15:0] EXPECTED_VERSION=16'h0500,
    parameter integer LIVE_CERTIFICATE=0
)(
    input wire clk,input wire rst,
    input wire asset_begin,input wire asset_complete,
    input wire [7:0] asset_purpose,input wire [31:0] asset_length,
    input wire [31:0] asset_crc32,input wire certificate_valid,
    input wire [7:0] certificate_purpose,input wire [31:0] certificate_length,
    input wire [31:0] certificate_crc32,input wire certificate_pass,
    input wire [15:0] certificate_version,
    input wire sample_tick,input wire narration_playing,
    input wire sample_valid,input wire alarm_active,
    output wire external_allowed,output wire [3:0] reject_reason,
    output wire prompt_valid,output wire audio_underflow
);
    admission_certificate_gate #(.EXPECTED_VERSION(EXPECTED_VERSION),
        .LIVE_CERTIFICATE(LIVE_CERTIFICATE)) gate(
        .clk(clk),.rst(rst),.load_begin(asset_begin),.load_complete(asset_complete),
        .file_purpose(asset_purpose),.file_length(asset_length),.file_crc32(asset_crc32),
        .certificate_valid(certificate_valid),.certificate_purpose(certificate_purpose),
        .certificate_length(certificate_length),.certificate_crc32(certificate_crc32),
        .certificate_pass(certificate_pass),.certificate_version(certificate_version),
        .use_external(external_allowed),.reject_reason(reject_reason));
    assign prompt_valid=sample_valid&&narration_playing&&!alarm_active&&external_allowed;
    assign audio_underflow=sample_tick&&narration_playing&&!alarm_active&&
        external_allowed&&!sample_valid;
endmodule
