`timescale 1ns/1ps
module tb_single_card_streamer;
    reg clk=0,rst=1,request=0,permit=0,looping=1;
    always #5 clk=~clk;
    reg [3:0] index=3;
    reg busy=0,opened=0,missing=0,valid=0,ended=0,ready=1;
    reg [7:0] data=0;
    wire open_req,take,sample_valid;wire [3:0] slot,error;
    wire signed [15:0] sample;
    wire [31:0] length,crc,samples;
    integer count=0,base=1000,opens=0;
    narration_wav_streamer #(.CANONICAL_PCM(1),.DIRECT_PLAY(1),.TIMEOUT_CYCLES(1000)) dut(
        .clk(clk),.rst(rst),.play_request(request),.requested_index(index),
        .external_allowed(permit),.requested_start_sample(32'd0),.loop_enable(looping),
        .file_error(4'd0),.file_io_progress(1'b0),.file_open_req(open_req),.file_index(slot),
        .file_busy(busy),.file_open_done(opened),.file_not_found(missing),.file_size(32'd999),
        .file_data(data),.file_valid(valid),.file_ready(take),.file_end(ended),
        .asset_length(length),.asset_crc32(crc),.asset_samples(samples),
        .sample_valid(sample_valid),.sample(sample),.sample_ready(ready),.error_code(error));
    always @(posedge clk)if(sample_valid)begin
        if(sample!==base+count)$fatal(1,"wrong/repeated PCM: %0d expected %0d",sample,base+count);
        count=count+1;
    end
    task pulse_request;begin
        @(negedge clk);request=1;@(negedge clk);request=0;
    end endtask
    task byte;input [7:0] b;begin
        @(negedge clk);while(!take)@(negedge clk);
        data=b;valid=1;@(negedge clk);valid=0;
    end endtask
    task word;input [31:0] w;begin byte(w[7:0]);byte(w[15:8]);byte(w[23:16]);byte(w[31:24]);end endtask
    task pcm;input [15:0] s;begin byte(s[7:0]);byte(s[15:8]);end endtask
    task header;begin
        byte("R");byte("I");byte("F");byte("F");word(44);
        byte("W");byte("A");byte("V");byte("E");
        byte("f");byte("m");byte("t");byte(" ");word(16);
        pcm(1);pcm(1);word(48000);word(96000);pcm(2);pcm(16);
        byte("d");byte("a");byte("t");byte("a");word(8);
    end endtask
    task accept_open;begin
        wait(open_req);@(negedge clk);busy=1;opens=opens+1;
        repeat(2)@(negedge clk);opened=1;@(negedge clk);opened=0;
    end endtask
    task eof;begin
        repeat(3)@(negedge clk);ended=1;busy=0;@(negedge clk);ended=0;
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;pulse_request();
        repeat(40)@(negedge clk);if(open_req||count!=0)$fatal(1,"permission gate bypass");
        permit=1;accept_open();header();pcm(1000);repeat(4)@(negedge clk);
        if(count!=1||opens!=1||samples!=4||length!=0||crc!=0)
            $fatal(1,"direct playback waited for EOF or checked directory size/CRC");
        ready=0;repeat(40)@(negedge clk);if(error!=0)$fatal(1,"backpressure fault");
        ready=1;pcm(1001);pcm(1002);pcm(1003);eof();
        wait(open_req);

        @(negedge clk);busy=1;request=1;index=4;looping=0;
        @(negedge clk);request=0;
        opened=1;@(negedge clk);opened=0;
        header();pcm(9000);pcm(9001);pcm(9002);pcm(9003);eof();
        if(count!=4)$fatal(1,"old loop PCM escaped cancellation");
        base=2000;count=0;accept_open();if(slot!=4)$fatal(1,"new slot lost");
        header();pcm(2000);pcm(2001);pcm(2002);pcm(2003);eof();
        repeat(20)@(negedge clk);
        if(count!=4||error!=0)$fatal(1,"new asset did not play exactly once");
        pulse_request();base=3000;count=0;accept_open();header();pcm(3000);eof();
        repeat(30)@(negedge clk);if(error==0)$fatal(1,"early EOF not stopped");
        pulse_request();wait(open_req);@(negedge clk);busy=1;
        repeat(2)@(negedge clk);missing=1;@(negedge clk);missing=0;busy=0;
        repeat(10)@(negedge clk);if(error==0)$fatal(1,"missing file not stopped");
        $display("TEST_PASS direct PCM: early first sample, no CRC/size comparison, backpressure, loop-open cancellation, truncation and missing file");
        $finish;
    end
    initial begin #2000000;$fatal(1,"direct streamer timeout");end
endmodule
