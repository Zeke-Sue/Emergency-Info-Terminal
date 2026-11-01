`timescale 1ns/1ps
module tb_narration_wav_streamer #(parameter CANONICAL_PCM=0,CHANGE_METADATA=0);
    reg clk=0,rst=1,play_request=0,external_allowed=0,loop_enable=0;
    reg file_busy=0,file_open_done=0,file_not_found=0;
    reg [3:0] file_error=0;
    reg begin_before_fault;
    reg [31:0] file_size=52;reg [7:0] file_data=0;
    reg file_valid=0,file_end=0,sample_ready=1;
    wire file_open_req,file_ready,asset_begin_toggle,asset_complete_toggle;
    wire [3:0] file_index,error_code;wire [7:0] asset_purpose;
    wire [31:0] asset_length,asset_crc32;
    wire sample_valid,fifo_flush;wire signed [15:0] sample;
    integer open_count=0,sample_count=0,flush_count=0;
    reg complete_q=0;reg [31:0] expected_crc;
    always #5 clk=~clk;
    narration_wav_streamer #(.ENABLE_FILE_ERROR(1),.TIMEOUT_CYCLES(1000),.CANONICAL_PCM(CANONICAL_PCM)) dut(.clk(clk),.rst(rst),.play_request(play_request),
        .requested_index(4'd3),.external_allowed(external_allowed),
        .requested_start_sample(32'd0),
        .loop_enable(loop_enable),
        .file_error(file_error),
        .file_open_req(file_open_req),.file_index(file_index),
        .file_busy(file_busy),.file_open_done(file_open_done),
        .file_not_found(file_not_found),.file_size(file_size),
        .file_data(file_data),.file_valid(file_valid),.file_ready(file_ready),
        .file_end(file_end),.asset_begin_toggle(asset_begin_toggle),
        .asset_complete_toggle(asset_complete_toggle),.asset_purpose(asset_purpose),
        .asset_length(asset_length),.asset_crc32(asset_crc32),
        .sample_valid(sample_valid),.sample(sample),.sample_ready(sample_ready),
        .fifo_flush(fifo_flush),.error_code(error_code));

    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer i;reg [31:0] work;
        begin
            work=current^value;
            for(i=0;i<8;i=i+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction
    task fail;input [8*100-1:0] reason;begin
        $display("TEST_FAIL tb_narration_wav_streamer: %0s",reason);$finish;
    end endtask
    task send_byte;input [7:0] value;begin
        while(!file_ready)@(negedge clk);
        file_data=value;file_valid=1;@(negedge clk);file_valid=0;
        expected_crc=crc32_byte(expected_crc,value);
    end endtask
    task send_le16;input [15:0] value;begin
        send_byte(value[7:0]);send_byte(value[15:8]);
    end endtask
    task send_le32;input [31:0] value;begin
        send_byte(value[7:0]);send_byte(value[15:8]);
        send_byte(value[23:16]);send_byte(value[31:24]);
    end endtask
    task serve_wav;begin
        expected_crc=32'hffffffff;
        wait(file_open_req);@(negedge clk);file_busy=1;file_size=52;open_count=open_count+1;
        repeat(2)@(negedge clk);file_open_done=1;@(negedge clk);file_open_done=0;
        send_byte("R");send_byte("I");send_byte("F");send_byte("F");
        send_le32(44);send_byte("W");send_byte("A");send_byte("V");send_byte("E");
        send_byte("f");send_byte("m");send_byte("t");send_byte(" ");send_le32(16);
        send_le16(1);send_le16(1);send_le32(48000);send_le32(96000);
        send_le16(2);send_le16(16);
        send_byte("d");send_byte("a");send_byte("t");send_byte("a");send_le32(8);
        send_le16(16'sd1000);send_le16(-16'sd1000);
        send_le16(16'sd2000);send_le16(-16'sd2000);
        repeat(3)@(negedge clk);file_end=1;file_busy=0;
        if(CHANGE_METADATA)file_size=150;
        @(negedge clk);file_end=0;
    end endtask
    always @(posedge clk)begin
        complete_q<=asset_complete_toggle;
        if(fifo_flush)flush_count=flush_count+1;
        if(sample_valid)begin
            case(sample_count%4)
                0:if(sample!=16'sd1000)fail("sample 0 order");
                1:if(sample!=-16'sd1000)fail("sample 1 order");
                2:if(sample!=16'sd2000)fail("sample 2 order");
                3:if(sample!=-16'sd2000)fail("sample 3 order");
                default:fail("too many playback samples");
            endcase
            sample_count=sample_count+1;
        end
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;
        @(negedge clk);play_request=1;@(negedge clk);play_request=0;
        fork serve_wav(); join
        wait(asset_complete_toggle!=complete_q);repeat(2)@(negedge clk);
        if(open_count!=1||sample_count!=0)fail("played before certificate gate");
        if(asset_purpose!=8'h24||asset_length!=52||asset_crc32!=~expected_crc)
            fail("verified metadata mismatch");
        external_allowed=1;
        fork serve_wav(); join
        repeat(20)@(negedge clk);
        if(open_count!=2||sample_count!=4||flush_count!=1||error_code!=0)
            fail("two-pass playback result");
        loop_enable=1;
        fork serve_wav(); join
        loop_enable=0;repeat(20)@(negedge clk);
        if(open_count!=3||sample_count!=8||flush_count!=1||error_code!=0)
            fail("authorized loop did not preserve all samples");
        begin_before_fault=asset_begin_toggle;
        loop_enable=1;wait(file_open_req);@(negedge clk);
        file_busy=1;file_error=6;@(negedge clk);file_busy=0;file_error=0;
        repeat(5)@(negedge clk);
        if(error_code!=4||sample_valid||flush_count!=2||
                asset_begin_toggle==begin_before_fault)fail("card error did not revoke and flush");
        begin_before_fault=asset_begin_toggle;
        repeat(20)@(negedge clk);
        if(asset_begin_toggle!=begin_before_fault)fail("fault repeatedly toggled revocation");
        external_allowed=0;loop_enable=0;
        play_request=1;@(negedge clk);play_request=0;
        wait(file_open_req);begin_before_fault=asset_begin_toggle;
        repeat(1010)@(negedge clk);
        if(error_code!=4||file_open_req||asset_begin_toggle==begin_before_fault)
            fail("unresponsive card did not time out and revoke");
        $display("TEST_PASS tb_narration_wav_streamer CRC gate, PCM loop, read failure revocation and timeout");
        $finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
