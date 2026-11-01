`timescale 1ns/1ps

module admission_certificate_gate #(
    parameter [15:0] EXPECTED_VERSION=16'h0500,
    parameter integer LIVE_CERTIFICATE=0
)(
    input wire clk,input wire rst,input wire load_begin,
    input wire load_complete,input wire [7:0] file_purpose,
    input wire [31:0] file_length,input wire [31:0] file_crc32,
    input wire certificate_valid,input wire [7:0] certificate_purpose,
    input wire [31:0] certificate_length,input wire [31:0] certificate_crc32,
    input wire certificate_pass,input wire [15:0] certificate_version,
    output wire use_external,output reg [3:0] reject_reason
);
    reg file_ready,cert_ready;reg [7:0] file_purpose_q,cert_purpose_q;
    reg [31:0] file_length_q,file_crc_q,cert_length_q,cert_crc_q;
    reg cert_pass_q;reg [15:0] cert_version_q;
    wire ready=LIVE_CERTIFICATE ? certificate_valid : cert_ready;
    wire pass=LIVE_CERTIFICATE ? certificate_pass : cert_pass_q;
    wire [7:0] purpose=LIVE_CERTIFICATE ? certificate_purpose : cert_purpose_q;
    wire [31:0] length=LIVE_CERTIFICATE ? certificate_length : cert_length_q;
    wire [31:0] crc=LIVE_CERTIFICATE ? certificate_crc32 : cert_crc_q;
    wire [15:0] version=LIVE_CERTIFICATE ? certificate_version : cert_version_q;
    assign use_external=!load_begin&&file_ready&&ready&&pass&&
        file_purpose_q==purpose&&file_length_q==length&&
        file_crc_q==crc&&version==EXPECTED_VERSION;
    always @* begin
        if(!file_ready)reject_reason=1;
        else if(!ready)reject_reason=2;
        else if(!pass)reject_reason=3;
        else if(version!=EXPECTED_VERSION)reject_reason=4;
        else if(file_purpose_q!=purpose)reject_reason=5;
        else if(file_length_q!=length)reject_reason=6;
        else if(file_crc_q!=crc)reject_reason=7;
        else reject_reason=0;
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            file_ready<=0;cert_ready<=0;file_purpose_q<=0;cert_purpose_q<=0;
            file_length_q<=0;file_crc_q<=0;cert_length_q<=0;cert_crc_q<=0;
            cert_pass_q<=0;cert_version_q<=0;
        end else begin
            if(load_begin)file_ready<=0;
            else if(load_complete)begin
                file_ready<=1;file_purpose_q<=file_purpose;
                file_length_q<=file_length;file_crc_q<=file_crc32;
            end
            if(certificate_valid)begin
                cert_ready<=1;cert_purpose_q<=certificate_purpose;
                cert_length_q<=certificate_length;cert_crc_q<=certificate_crc32;
                cert_pass_q<=certificate_pass;cert_version_q<=certificate_version;
            end
        end
    end
endmodule
