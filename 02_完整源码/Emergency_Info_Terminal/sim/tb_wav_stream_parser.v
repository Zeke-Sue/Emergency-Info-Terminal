`timescale 1ns/1ps
module tb_wav_stream_parser #(parameter ENABLE_IMA=1);
    reg clk=0,rst=1,file_start=0,byte_valid=0,file_end=0;
    reg [7:0] byte_data=0;wire byte_ready,data_start,sample_valid,data_finish;
    wire signed [15:0] sample;wire parse_done,file_valid;wire [3:0] parse_reason;
    wire [31:0] data_length,sample_count;
    reg checker_start=0,checker_finish=0;
    wire result_valid,admitted;wire [3:0] admission_reason;
    wire [31:0] file_length,file_crc,samples,clips,silence,crossings;
    integer k,parsed_samples=0;
    always #5 clk=~clk;
    wav_stream_parser #(.ENABLE_IMA(ENABLE_IMA)) parser(.clk(clk),.rst(rst),.file_start(file_start),
        .byte_valid(byte_valid),.byte_data(byte_data),.byte_ready(byte_ready),
        .sample_ready(1'b1),
        .file_end(file_end),.data_start(data_start),.sample_valid(sample_valid),
        .sample(sample),.data_finish(data_finish),.parse_done(parse_done),
        .file_valid(file_valid),.error_reason(parse_reason),
        .data_length(data_length),.sample_count(sample_count));
    wav_admission_checker #(.SILENCE_LEVEL(100),.CLIP_LEVEL(20000),
        .MIN_NON_SILENT(8),.MAX_CLIPPED(1),.MAX_SILENT_RUN(8),
        .MIN_ZERO_CROSS(4),.MAX_ZERO_CROSS(100),.WINDOW_SAMPLES(4),
        .WINDOW_RMS_SQ(10000),.WHOLE_RMS_SQ(10000),.MIN_PEAK(500),
        .MAX_PEAK(20000),.FULL_SCALE_LEVEL(32000),.MAX_FULL_SCALE_RUN(2)) checker(
        .clk(clk),.rst(rst),.start(data_start),.sample_valid(sample_valid),
        .sample(sample),.trajectory_error(1'b0),.finish(data_finish),.purpose(8'h21),
        .result_valid(result_valid),.admitted(admitted),.reason(admission_reason),
        .file_length(file_length),.file_crc32(file_crc),.certificate_purpose(),
        .certificate_version(),.sample_count_out(samples),.clipped_count_out(clips),
        .longest_silence_out(silence),.zero_crossings_out(crossings));
    task fail;input [8*100-1:0] message;begin
        $display("TEST_FAIL tb_wav_stream_parser: %0s",message);$finish;end endtask
    task send_byte;input [7:0] value;begin
        while(!byte_ready)@(negedge clk);byte_data=value;byte_valid=1;
        @(negedge clk);byte_valid=0;
    end endtask
    task send_le16;input [15:0] value;begin send_byte(value[7:0]);send_byte(value[15:8]);end endtask
    task send_le32;input [31:0] value;begin
        send_byte(value[7:0]);send_byte(value[15:8]);send_byte(value[23:16]);send_byte(value[31:24]);
    end endtask
    task begin_file;begin @(negedge clk);file_start=1;@(negedge clk);file_start=0;
        send_byte("R");send_byte("I");send_byte("F");send_byte("F");
        send_le32(32'd88);send_byte("W");send_byte("A");send_byte("V");send_byte("E");
    end endtask
    task send_fmt;input [15:0] channel_count;input [31:0] rate;begin
        send_byte("f");send_byte("m");send_byte("t");send_byte(" ");send_le32(16);
        send_le16(1);send_le16(channel_count);send_le32(rate);send_le32(rate*2);
        send_le16(2);send_le16(16);
    end endtask
    task end_file;begin
        repeat(3)@(negedge clk);file_end=1;@(negedge clk);file_end=0;
    end endtask
    always @(posedge clk)if(sample_valid)begin
        if(sample!=(parsed_samples[0] ? -16'sd1000 : 16'sd1000))fail("PCM endian/order");
        parsed_samples=parsed_samples+1;
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;begin_file;
        send_byte("J");send_byte("U");send_byte("N");send_byte("K");send_le32(3);
        send_byte(8'h11);send_byte(8'h22);send_byte(8'h33);send_byte(0);
        send_fmt(1,48000);
        send_byte("d");send_byte("a");send_byte("t");send_byte("a");send_le32(40);
        for(k=0;k<20;k=k+1)send_le16(k[0] ? -16'sd1000 : 16'sd1000);
        wait(data_finish);wait(result_valid);#1;
        if(!admitted||admission_reason!=0||samples!=20||parsed_samples!=20)
            fail("valid WAV admission");
        end_file;wait(parse_done);#1;
        if(!file_valid||parse_reason!=0||data_length!=40||sample_count!=20)
            fail("valid RIFF result");

        parsed_samples=0;begin_file;send_fmt(2,44100);
        send_byte("d");send_byte("a");send_byte("t");send_byte("a");send_le32(4);
        send_le16(1000);send_le16(-1000);end_file;wait(parse_done);#1;
        if(file_valid||parse_reason!=3||parsed_samples!=0)
            fail("invalid format accepted");
        $display("TEST_PASS tb_wav_stream_parser RIFF chunks, padding, PCM format and admission stream");
        $finish;
    end
    initial begin #3000000;fail("timeout");end
endmodule
module tb_wav_pcm_profile;
    tb_wav_stream_parser #(.ENABLE_IMA(0)) test();
endmodule
