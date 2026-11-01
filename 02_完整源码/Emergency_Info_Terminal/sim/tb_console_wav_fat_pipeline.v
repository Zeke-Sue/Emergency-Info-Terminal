`timescale 1ns/1ps
module tb_console_wav_fat_pipeline #(
    parameter integer IMA=0, CORRUPT=0, STRICT_CHAIN=0, BAD_CHAIN=0
);
    localparam WAV_SIZE=IMA ? 316 : 108;
    reg clk=0,rst=1;always #5 clk=~clk;
    wire req,valid,last,mounted,busy,result,admitted,certificate_valid;
    wire [31:0] lba,length,crc;wire [7:0] sec_data,purpose;
    wire [3:0] reason,error_code,result_index;wire [4:0] wav_count,completed_count;
    wire [15:0] version,certificate_bitmap,admitted_bitmap;
    wire [95:0] certificate;
    console_wav_admission_pipeline #(.MAX_AUDIO_FILES(10),.STRICT_CHAIN(STRICT_CHAIN)) dut(
        .clk(clk),.rst(rst),.start_ready(!rst),.sd_ready(!rst),.reload(1'b0),
        .trajectory_error(1'b0),.purpose(8'h21),.sector_req(req),
        .sector_lba(lba),.sector_data(sec_data),.sector_valid(valid),
        .sector_end(last),.result_valid(result),.admitted(admitted),
        .reason(reason),.admitted_length(length),.admitted_crc32(crc),
        .admitted_purpose(purpose),.admitted_version(version),
        .certificate(certificate),.certificate_valid(certificate_valid),
        .result_index(result_index),.completed_count(completed_count),
        .certificate_valid_bitmap(certificate_bitmap),
        .admitted_bitmap(admitted_bitmap),.mounted(mounted),
        .wav_count(wav_count),.busy(busy),.error_code(error_code));

    function [7:0] wav_byte;input integer pos;integer sample_index;reg signed [15:0] value;
        begin
            wav_byte=0;
            case(pos)
                0:wav_byte="R";1:wav_byte="I";2:wav_byte="F";3:wav_byte="F";
                4:wav_byte=100;8:wav_byte="W";9:wav_byte="A";
                10:wav_byte="V";11:wav_byte="E";
                12:wav_byte="f";13:wav_byte="m";14:wav_byte="t";15:wav_byte=" ";
                16:wav_byte=16;20:wav_byte=1;22:wav_byte=1;
                24:wav_byte=8'h80;25:wav_byte=8'hbb;
                28:wav_byte=8'h00;29:wav_byte=8'h77;30:wav_byte=8'h01;
                32:wav_byte=2;34:wav_byte=16;
                36:wav_byte="d";37:wav_byte="a";38:wav_byte="t";39:wav_byte="a";
                40:wav_byte=64;
                default:if(pos>=44&&pos<108)begin
                    sample_index=(pos-44)>>1;
                    value=sample_index[0] ? -16'sd5000 : 16'sd5000;
                    wav_byte=pos[0] ? value[15:8] : value[7:0];
                end
            endcase
            if(IMA)begin
                wav_byte=0;
                case(pos)
                    0:wav_byte="R";1:wav_byte="I";2:wav_byte="F";3:wav_byte="F";
                    4:wav_byte=(WAV_SIZE-8)&255;5:wav_byte=(WAV_SIZE-8)>>8;
                    8:wav_byte="W";9:wav_byte="A";10:wav_byte="V";11:wav_byte="E";
                    12:wav_byte="f";13:wav_byte="m";14:wav_byte="t";15:wav_byte=" ";
                    16:wav_byte=20;20:wav_byte=17;22:wav_byte=1;
                    24:wav_byte=8'hc0;25:wav_byte=8'h5d;
                    28:wav_byte=8'ha1;29:wav_byte=8'h34;
                    32:wav_byte=32;34:wav_byte=4;36:wav_byte=2;38:wav_byte=57;
                    40:wav_byte="f";41:wav_byte="a";42:wav_byte="c";43:wav_byte="t";
                    44:wav_byte=4;48:wav_byte=8'hc8;49:wav_byte=1;
                    52:wav_byte="d";53:wav_byte="a";54:wav_byte="t";55:wav_byte="a";
                    57:wav_byte=1;
                    default:if(pos>=60)begin
                        sample_index=(pos-60)>>5;
                        value=sample_index[0] ? -16'sd5000 : 16'sd5000;
                        if((pos-60)%32==0)wav_byte=value[7:0];
                        if((pos-60)%32==1)wav_byte=value[15:8];
                    end
                endcase
            end
            if(CORRUPT&&pos==4)wav_byte=wav_byte+1;
        end
    endfunction
    function [7:0] card_byte;input integer block,pos;
        integer cluster,value,entry,entry_pos;
        begin
            card_byte=0;
            if(block==0)begin
                case(pos)
                    11:card_byte=0;12:card_byte=2;13:card_byte=1;
                    14:card_byte=1;16:card_byte=1;36:card_byte=1;
                    44:card_byte=2;510:card_byte=8'h55;511:card_byte=8'haa;
                endcase
            end else if(block==1)begin
                cluster=pos>>2;value=(cluster>=2&&cluster<=12)?32'h0fffffff:0;
                if(BAD_CHAIN&&cluster==7)value=7;
                card_byte=value>>((pos&3)*8);
            end else if(block==2)begin
                entry=pos>>5;entry_pos=pos&31;
                if(entry<10)begin
                    case(entry_pos)
                        0:card_byte="A";1:card_byte="L";2:card_byte="A";
                        3:card_byte="R";4:card_byte="M";
                        5:card_byte="0"+(entry/10);
                        6:card_byte="0"+(entry%10);7:card_byte=" ";
                        8:card_byte="W";9:card_byte="A";10:card_byte="V";
                        11:card_byte=8'h20;26:card_byte=3+entry;
                        28:card_byte=WAV_SIZE&255;29:card_byte=WAV_SIZE>>8;
                    endcase
                end
            end else if(block>=3&&block<=12&&pos<WAV_SIZE)
                card_byte=wav_byte(pos);
        end
    endfunction

    reg sec_valid=0,sec_end=0;reg [7:0] sec_q=0;
    integer state=0,pos=0,active_lba=0;
    assign valid=sec_valid;assign last=sec_end;assign sec_data=sec_q;
    always @(posedge clk)begin
        sec_valid<=0;sec_end<=0;
        if(rst)state<=0;
        else case(state)
            0:if(req)begin active_lba<=lba;pos<=0;state<=1;end
            1:begin sec_q<=card_byte(active_lba,pos);sec_valid<=1;
                if(pos==511)state<=2;else pos<=pos+1;end
            2:begin sec_end<=1;state<=3;end
            3:if(!req)state<=0;
        endcase
    end

    task fail;input [8*120-1:0] msg;begin
        $display("TEST_FAIL tb_console_wav_fat_pipeline: %0s",msg);$finish;end endtask
    integer result_count=0;
    integer crc_byte,accepted_samples=0;
    reg [31:0] expected_crc=32'hffffffff;
    function [31:0] crc_next;
        input [31:0] c;input [7:0] b;reg [31:0] v;integer j;
        begin v=c^b;for(j=0;j<8;j=j+1)v=(v>>1)^(v[0]?32'hedb88320:0);crc_next=v;end
    endfunction
    always @(posedge clk)begin
        if(dut.data_start)accepted_samples=0;
        else if(dut.sample_valid)accepted_samples=accepted_samples+1;
    end
    always @(posedge clk)if(result)begin
        if(BAD_CHAIN&&result_count==4)begin
            if(result_index!=4||admitted||reason!=15||length!=0||crc!=0)
                fail("bad-chain file did not receive a bound rejection");
        end else begin
        if(result_index!=result_count||admitted==CORRUPT||
                reason!=(CORRUPT ? 10 : 0)||length!=(CORRUPT ? 0 : WAV_SIZE)||
                purpose!=8'h21+result_count||version!=16'h0500)
            fail("per-file admission result mismatch");
        if(!CORRUPT&&(crc!=~expected_crc||accepted_samples!=(IMA ? 912 : 32)))
            fail("container binding or FFT backpressure lost samples");
        end
        result_count=result_count+1;
    end
    initial begin
        for(crc_byte=0;crc_byte<WAV_SIZE;crc_byte=crc_byte+1)
            expected_crc=crc_next(expected_crc,wav_byte(crc_byte));
        repeat(5)@(negedge clk);rst=0;
        wait(!busy);#1;
        if(error_code!=(BAD_CHAIN ? 6 : 0)||!mounted||wav_count!=10||result_count!=10||
                completed_count!=10||certificate_bitmap!=16'h03ff||
                admitted_bitmap!=(CORRUPT ? 0 : BAD_CHAIN ? 16'h03ef : 16'h03ff)||!certificate_valid)
            fail("ten-file batch result mismatch");
        if(certificate[7:0]!=8'h2a||certificate[39:8]!=(CORRUPT ? 0 : WAV_SIZE)||
                certificate[72]==CORRUPT||certificate[76:73]!=(CORRUPT ? 10 : 0)||
                certificate[92:77]!=16'h0500)
            fail("last certificate packing");
        $display("TEST_PASS tb_console_wav_fat_pipeline reused one parser/checker for ten FAT WAV files, IMA=%0d",IMA);
        $finish;
    end
    initial begin #20000000;
        $display("DEBUG state=%0d file=%0d done=%0d mounted=%b wav=%0d fat=%0d reader=%0d parser=%0d",
            dut.state,dut.current_file,completed_count,mounted,wav_count,error_code,
            dut.files.state,dut.parser.state);
        fail("timeout");
    end
endmodule

module tb_console_ima_fat_pipeline;
    tb_console_wav_fat_pipeline #(.IMA(1)) test();
endmodule

module tb_console_wav_fail_closed;
    tb_console_wav_fat_pipeline #(.IMA(1),.CORRUPT(1)) test();
endmodule

module tb_console_strict_chain;
    tb_console_wav_fat_pipeline #(.STRICT_CHAIN(1),.BAD_CHAIN(1)) test();
endmodule
