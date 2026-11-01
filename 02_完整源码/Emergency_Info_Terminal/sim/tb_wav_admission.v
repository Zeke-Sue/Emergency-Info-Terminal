`timescale 1ns/1ps
module tb_wav_admission;
    reg clk=0,rst=1,start=0,sample_valid=0,trajectory_error=0,finish=0;
    reg signed [15:0] sample=0;reg [7:0] purpose=8'h21;integer k;
    wire result_valid,admitted;wire [3:0] reason;wire [31:0] length,crc,samples,clips,silence,crossings;
    wire [7:0] cert_purpose;wire [15:0] cert_version;
    reg load_begin=0,load_complete=0,certificate_valid=0,certificate_pass=0;
    reg [7:0] file_purpose=0,gate_cert_purpose=0;reg [31:0] file_length=0,file_crc=0;
    reg [31:0] cert_length=0,cert_crc=0;reg [15:0] gate_version=0;
    wire use_external;wire [3:0] reject;
    always #5 clk=~clk;
    wav_admission_checker #(.SILENCE_LEVEL(100),.CLIP_LEVEL(20000),
        .MIN_NON_SILENT(8),.MAX_CLIPPED(1),.MAX_SILENT_RUN(8),
        .MIN_ZERO_CROSS(4),.MAX_ZERO_CROSS(100),.WINDOW_SAMPLES(4),
        .WINDOW_RMS_SQ(10000),.WHOLE_RMS_SQ(10000),.MIN_PEAK(500),
        .MAX_PEAK(20000),.FULL_SCALE_LEVEL(32000),.MAX_FULL_SCALE_RUN(2)) checker(
        .clk(clk),.rst(rst),.start(start),.sample_valid(sample_valid),.sample(sample),
        .trajectory_error(trajectory_error),.finish(finish),.purpose(purpose),
        .result_valid(result_valid),.admitted(admitted),.reason(reason),
        .file_length(length),.file_crc32(crc),.certificate_purpose(cert_purpose),
        .certificate_version(cert_version),.sample_count_out(samples),
        .clipped_count_out(clips),.longest_silence_out(silence),
        .zero_crossings_out(crossings));

    admission_certificate_gate #(.EXPECTED_VERSION(16'h0402)) gate(.clk(clk),.rst(rst),.load_begin(load_begin),
        .load_complete(load_complete),.file_purpose(file_purpose),.file_length(file_length),
        .file_crc32(file_crc),.certificate_valid(certificate_valid),
        .certificate_purpose(gate_cert_purpose),.certificate_length(cert_length),
        .certificate_crc32(cert_crc),.certificate_pass(certificate_pass),
        .certificate_version(gate_version),.use_external(use_external),.reject_reason(reject));
    task fail;input [8*100-1:0] msg;begin $display("TEST_FAIL tb_wav_admission: %0s",msg);$finish;end endtask
    task pulse_start;begin @(negedge clk);start=1;@(negedge clk);start=0;end endtask
    task send_sample;input signed [15:0] value;begin @(negedge clk);sample=value;sample_valid=1;@(negedge clk);sample_valid=0;end endtask
    task pulse_finish;begin @(negedge clk);finish=1;@(negedge clk);finish=0;end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;pulse_start;
        for(k=0;k<20;k=k+1)send_sample(k[0] ? -16'sd1000 : 16'sd1000);
        pulse_finish;wait(result_valid);#1;
        if(!admitted||reason!=0||length!=40||crossings<18)fail("valid waveform rejected");
        @(negedge clk);gate_cert_purpose=cert_purpose;cert_length=length;cert_crc=crc;
        certificate_pass=admitted;gate_version=cert_version;certificate_valid=1;
        @(negedge clk);certificate_valid=0;file_purpose=cert_purpose;file_length=length;file_crc=crc;load_complete=1;
        @(negedge clk);load_complete=0;#1;if(!use_external||reject!=0)fail("matching certificate rejected");
        @(negedge clk);load_begin=1;@(negedge clk);load_begin=0;file_crc=crc^1;load_complete=1;
        @(negedge clk);load_complete=0;#1;if(use_external||reject!=7)fail("CRC mismatch accepted");
        pulse_start;for(k=0;k<5;k=k+1)send_sample(16'sd32767);pulse_finish;wait(result_valid);#1;
        if(admitted||reason!=2)fail("clipped waveform accepted");
        pulse_start;for(k=0;k<20;k=k+1)send_sample(0);pulse_finish;wait(result_valid);#1;
        if(admitted||reason!=1)fail("silent waveform accepted");
        purpose=8'h01;
        pulse_start;for(k=0;k<8;k=k+1)send_sample(k[0] ? -16'sd1000 : 16'sd1000);
        for(k=0;k<12;k=k+1)send_sample(0);
        for(k=0;k<8;k=k+1)send_sample(k[0] ? -16'sd1000 : 16'sd1000);
        pulse_finish;wait(result_valid);#1;
        if(admitted||reason!=3)fail("long low-RMS window accepted");
        purpose=8'h21;
        pulse_start;for(k=0;k<8;k=k+1)send_sample(k[0] ? -16'sd1000 : 16'sd1000);
        for(k=0;k<12;k=k+1)send_sample(0);
        for(k=0;k<120;k=k+1)send_sample(k[0] ? -16'sd1000 : 16'sd1000);
        pulse_finish;wait(result_valid);#1;
        if(!admitted||reason!=0)fail("narration pause or whole-file crossing count rejected");
        pulse_start;for(k=0;k<20;k=k+1)send_sample(k[0] ? -16'sd200 : 16'sd200);
        pulse_finish;wait(result_valid);#1;
        if(admitted||reason!=5)fail("below-minimum peak accepted");
        pulse_start;for(k=0;k<12;k=k+1)send_sample(k[0] ? -16'sd1000 : 16'sd1000);
        @(negedge clk);trajectory_error=1;@(negedge clk);trajectory_error=0;pulse_finish;wait(result_valid);#1;
        if(admitted||reason!=4)fail("trajectory error accepted");
        $display("TEST_PASS tb_wav_admission digital waveform checks and length/CRC/version certificate gate");$finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
