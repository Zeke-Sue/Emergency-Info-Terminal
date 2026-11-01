`timescale 1ns/1ps
module tb_wav_ima_adpcm #(parameter ENABLE_IMA=1);
    reg clk=0,rst=1,start=0,bvalid=0,eof=0,ready=0;
    reg [7:0] bdata=0;
    wire bready,valid,finish,done,good;
    wire signed [15:0] sample;
    wire [3:0] reason;wire [31:0] count,length,crc;
    reg [7:0] bytes[0:511];
    integer golden[0:35];
    integer size,n,seen,expected,checks=0,mode=0,limit=34;
    reg [31:0] random_state=32'h19283745,expected_crc;
    reg done_seen,valid_result;
    reg stalled;reg signed [15:0] held_sample;
    always #5 clk=~clk;
    wav_stream_parser #(.SAMPLE_BACKPRESSURE(1),.ENABLE_IMA(ENABLE_IMA)) dut(
        .clk(clk),.rst(rst),.file_start(start),.byte_valid(bvalid),.byte_data(bdata),
        .byte_ready(bready),.file_end(eof),.sample_ready(ready),
        .sample_valid(valid),.sample(sample),.data_finish(finish),
        .parse_done(done),.file_valid(good),.error_reason(reason),.sample_count(count),
        .container_length(length),.container_crc32(crc));
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tb_wav_ima_adpcm case=%0d: %0s",mode,msg);$finish;
    end endtask
    task put;input [7:0] b;begin bytes[size]=b;size=size+1;end endtask
    task le16;input [15:0] v;begin put(v[7:0]);put(v[15:8]);end endtask
    task le32;input [31:0] v;begin le16(v[15:0]);le16(v[31:16]);end endtask
    task id;input [31:0] v;begin put(v[31:24]);put(v[23:16]);put(v[15:8]);put(v[7:0]);end endtask
    task block;input [15:0] predictor;input [7:0] index;input [31:0] codes;begin
        le16(predictor);put(index);put(0);id(codes);
    end endtask
    task fixture;begin
        size=0;id("RIFF");le32(0);id("WAVE");
        id("JUNK");le32(3);put(1);put(2);put(3);put(0);
        id("fmt ");le32(64);le16(17);le16(1);le32(24000);le32(21333);
        le16(8);le16(4);le16(2);le16(9);

        repeat(44)put(8'hff);
        id("fact");le32(4);le32(limit);
        id("data");le32(32);
        block(1000,0,32'h118877ff);block(-32000,88,32'hff770810);
        block(32000,88,32'h77ff8010);block(-1234,16,32'h23bc56f0);
        bytes[4]=size-8;bytes[5]=0;bytes[6]=0;bytes[7]=0;
    end endtask
    function [31:0] next_crc;
        input [31:0] c;input [7:0] b;reg [31:0] v;integer j;
        begin v=c^b;for(j=0;j<8;j=j+1)v=(v>>1)^(v[0]?32'hedb88320:0);next_crc=v;end
    endfunction
    always @(negedge clk)begin
        random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
        ready=random_state[3:0]>5;
    end
    always @(posedge clk)begin
        if(start)begin seen=0;done_seen=0;stalled=0;end
        else begin
            if(stalled&&(!valid||sample!==held_sample))fail("sample changed under backpressure");
            stalled=valid&&!ready;held_sample=sample;
            if(valid&&ready)begin
                if(mode==0)begin
                    if(seen>=limit*2)fail("padding emitted after fact count");
                    expected=golden[seen/2];
                    if(!seen[0]&&seen!=0)expected=(golden[seen/2-1]+golden[seen/2])>>>1;
                    if($signed(sample)!=expected)begin
                        $display("sample %0d actual %0d expected %0d",seen,$signed(sample),expected);
                        fail("golden IMA/interpolation mismatch");
                    end
                end
                seen=seen+1;
            end
            if(done)begin done_seen=1;valid_result=good;end
            if(finish&&valid)fail("data_finish overtook last sample");
        end
    end
    task run;input want_good;begin
        @(negedge clk);start=1;@(negedge clk);start=0;
        expected_crc=32'hffffffff;
        for(n=0;n<size;n=n+1)begin

            @(negedge clk);bvalid=1;bdata=bytes[n];eof=0;
            @(posedge clk);while(!bready)@(posedge clk);
            expected_crc=next_crc(expected_crc,bytes[n]);
            @(negedge clk);bvalid=0;
        end
        eof=1;@(negedge clk);eof=0;
        wait(done_seen);#1;
        if(valid_result!==want_good)fail("file verdict mismatch");
        if(length!=size||crc!=~expected_crc)fail("container CRC/length mismatch");
        if(want_good&&(count!=limit*2||seen!=limit*2||reason!=0))fail("sample length mismatch");
        if(!want_good&&reason==0)fail("missing rejection reason");
        checks=checks+1;
    end endtask
    initial begin
        golden[0]=1000;golden[1]=1001;golden[2]=1002;golden[3]=1002;golden[4]=1002;
        golden[5]=1013;golden[6]=1043;golden[7]=980;golden[8]=844;
        golden[9]=-32000;golden[10]=-32768;golden[11]=-32768;golden[12]=28668;
        golden[13]=32767;golden[14]=28672;golden[15]=32396;golden[16]=32767;golden[17]=32767;
        golden[18]=32000;golden[19]=32767;golden[20]=32767;golden[21]=-28669;
        golden[22]=-32768;golden[23]=-28673;golden[24]=-32397;golden[25]=-29012;golden[26]=-19780;
        golden[27]=-1234;golden[28]=-1205;golden[29]=-1187;golden[30]=-1218;
        golden[31]=-1247;golden[32]=-1198;golden[33]=-1124;golden[34]=-1114;golden[35]=-1250;
        repeat(4)@(negedge clk);rst=0;
        if(!ENABLE_IMA)begin
            fixture;run(0);
            if(seen!=0||reason!=3)$fatal(1,"PCM-only profile emitted compressed samples");
            $display("TEST_PASS PCM-only profile rejects IMA while retaining whole-container CRC/length");$finish;
        end
        fixture;run(1);
        limit=36;fixture;run(1);
        mode=1;limit=37;fixture;run(0);
        mode=2;limit=27;fixture;run(0);
        mode=3;limit=34;fixture;bytes[size-30]=89;run(0);
        mode=4;fixture;bytes[size-29]=1;run(0);
        mode=5;fixture;size=size-1;run(0);
        mode=6;fixture;bytes[4]=bytes[4]+1;run(0);
        mode=7;fixture;bytes[44]=7;run(0);
        mode=8;fixture;bytes[38]=2;run(0);
        $display("TEST_PASS tb_wav_ima_adpcm %0d cases: seeded blocks, saturation, fact trim, 2x interpolation, stalls, malformed RIFF",checks);
        $finish;
    end
    initial begin #3000000;fail("timeout");end
endmodule
module tb_wav_pcm_reject_ima;
    tb_wav_ima_adpcm #(.ENABLE_IMA(0)) test();
endmodule
