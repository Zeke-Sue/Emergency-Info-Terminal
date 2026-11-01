`timescale 1ns/1ps

module tb_wav_actual_file;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg [7:0] wav[0:2097151];
    reg [2047:0] path;
    integer fd,size,expected,purpose_arg,rc,read_state=0,offset=0,lba_q=0;
    integer clocks=0,max_fft_clocks=0,fft_clocks=0;
    reg [7:0] byte_data=0;reg valid=0,last=0;
    wire req,busy,result,admitted;wire [31:0] lba,length,crc;
    wire [3:0] reason,error_code;wire [31:0] bad_windows,first_bad;
    wire [4:0] missing;
    reg [7:0] purpose;
    console_wav_admission_pipeline #(.MAX_AUDIO_FILES(1),
        .CLK_HZ(1000000),.STREAM_BYTES_PER_SECOND(1000000)) dut(
        .clk(clk),.rst(rst),.start_ready(!rst),.sd_ready(!rst),.reload(1'b0),
        .trajectory_error(1'b0),.purpose(purpose),.sector_req(req),.sector_lba(lba),
        .sector_data(byte_data),.sector_valid(valid),.sector_end(last),
        .result_valid(result),.admitted(admitted),.reason(reason),
        .admitted_length(length),.admitted_crc32(crc),.busy(busy),.error_code(error_code),
        .trajectory_bad_windows(bad_windows),.trajectory_first_bad_sample(first_bad),
        .trajectory_missing_voices(missing));
    function [7:0] card_byte;
        input integer block,pos;
        integer word,cluster,idx;
        begin
            card_byte=0;
            if(block==0)case(pos)
                11:card_byte=0;12:card_byte=2;13:card_byte=128;
                14:card_byte=1;16:card_byte=1;36:card_byte=1;
                44:card_byte=2;510:card_byte=8'h55;511:card_byte=8'haa;
            endcase
            else if(block==1)begin
                cluster=pos>>2;
                word=(cluster==2 || cluster==3+(size-1)/65536) ? 32'h0fffffff : cluster+1;
                card_byte=word>>((pos&3)*8);
            end else if(block==2)case(pos)
                0:card_byte="A";1:card_byte="L";2:card_byte="A";
                3:card_byte="R";4:card_byte="M";5:card_byte="0";6:card_byte="1";
                7:card_byte=" ";8:card_byte="W";9:card_byte="A";10:card_byte="V";
                11:card_byte=8'h20;26:card_byte=3;
                28,29,30,31:card_byte=size>>((pos-28)*8);
            endcase
            else if(block>=130)begin
                idx=(block-130)*512+pos;
                if(idx<size)card_byte=wav[idx];
            end
        end
    endfunction
    always @(posedge clk)begin
        clocks<=clocks+1;valid<=0;last<=0;
        if(dut.stft_busy)fft_clocks<=fft_clocks+1;
        else begin
            if(fft_clocks>max_fft_clocks)max_fft_clocks<=fft_clocks;
            fft_clocks<=0;
        end
        if(rst)begin read_state<=0;offset<=0;end
        else case(read_state)
            0:if(req)begin lba_q<=lba;offset<=0;read_state<=1;end
            1:begin
                byte_data<=card_byte(lba_q,offset);valid<=1;
                if(offset==511)read_state<=2;else offset<=offset+1;
            end
            2:begin last<=1;read_state<=3;end
            3:if(!req)read_state<=0;
        endcase
    end
    initial begin
        if(!$value$plusargs("FILE=%s",path) || !$value$plusargs("PURPOSE=%d",purpose_arg) ||
                !$value$plusargs("REASON=%d",expected))begin
            $display("TEST_FAIL tb_wav_actual_file requires FILE, PURPOSE, REASON");$finish;
        end
        purpose=purpose_arg;fd=$fopen(path,"rb");
        if(fd==0)begin $display("TEST_FAIL cannot open actual WAV");$finish;end
        size=$fread(wav,fd);$fclose(fd);
        if(size<44 || size>=2097152)begin $display("TEST_FAIL fixture size");$finish;end
        repeat(5)@(negedge clk);rst=0;
        wait(result);#1;
        $display("ACTUAL_WAV purpose=%h reason=%0d length=%0d crc=%h windows=%0d bad=%0d first=%0d missing=%b clocks=%0d max_fft=%0d",
            purpose,reason,length,crc,dut.spectral_windows,bad_windows,first_bad,missing,clocks,max_fft_clocks);
        if(reason!=expected || admitted!==(expected==0) || error_code!=0 || dut.stft_overrun ||
                max_fft_clocks>133333)begin
            $display("TEST_FAIL tb_wav_actual_file decision or analysis budget");$finish;
        end
        $display("TEST_PASS tb_wav_actual_file actual FAT/WAV/FFT/trajectory/certificate chain");$finish;
    end
    initial begin #2000000000;$display("TEST_FAIL actual WAV timeout");$finish;end
endmodule
