`timescale 1ns/1ps
module tb_wav_canonical;
    reg clk=0,rst=1,start=0,valid=0,eof=0,ready_sample=0;
    always #5 clk=~clk;
    reg [7:0] data=0,bytes[0:52];
    wire ready,sv,done,good,finish;
    wire signed [15:0] sample;
    wire [31:0] count,length,crc,container;
    wire [3:0] error;
    integer trial,i,n,accepted,cycle=0,finishes;
    reg [31:0] expected_crc;
    wav_canonical_pcm_parser dut(.clk(clk),.rst(rst),.file_start(start),
        .byte_valid(valid),.byte_data(data),.byte_ready(ready),.file_end(eof),
        .sample_ready(ready_sample),.data_start(),.data_byte_valid(),.data_byte(),
        .sample_valid(sv),.sample(sample),.data_finish(finish),.parse_done(done),
        .file_valid(good),.error_reason(error),.data_length(length),.sample_count(count),
        .container_length(container),.container_crc32(crc));
    function [31:0] update_crc;input [31:0] c;input [7:0] b;
        integer bitnum;reg [31:0] work;begin
            work=c^b;
            for(bitnum=0;bitnum<8;bitnum=bitnum+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            update_crc=work;
        end
    endfunction
    always @(negedge clk)begin cycle=cycle+1;ready_sample=(cycle%23)>=13;end
    always @(posedge clk)begin
        if(sv&&ready_sample)begin
            if(sample!=={bytes[45+accepted*2],bytes[44+accepted*2]})$fatal(1,"PCM sample/stall mismatch");
            accepted=accepted+1;
        end
        if(finish)finishes=finishes+1;
    end
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(trial=0;trial<49;trial=trial+1)begin
            for(i=0;i<53;i=i+1)bytes[i]=0;
            bytes[0]="R";bytes[1]="I";bytes[2]="F";bytes[3]="F";bytes[4]=44;
            bytes[8]="W";bytes[9]="A";bytes[10]="V";bytes[11]="E";
            bytes[12]="f";bytes[13]="m";bytes[14]="t";bytes[15]=" ";bytes[16]=16;
            bytes[20]=1;bytes[22]=1;bytes[24]=8'h80;bytes[25]=8'hbb;
            bytes[29]=8'h77;bytes[30]=1;bytes[32]=2;bytes[34]=16;
            bytes[36]="d";bytes[37]="a";bytes[38]="t";bytes[39]="a";bytes[40]=8;
            bytes[44]=8'h00;bytes[45]=8'h80;bytes[46]=8'hff;bytes[47]=8'h7f;
            bytes[48]=8'hff;bytes[49]=8'hff;bytes[50]=8'h21;bytes[51]=8'h43;
            if(trial<44)bytes[trial]=bytes[trial]^1;
            n=trial==46 ? 51 : trial==47 ? 53 : 52;
            accepted=0;finishes=0;expected_crc=32'hffffffff;
            start=1;@(negedge clk);start=0;
            for(i=0;i<n;i=i+1)begin
                while(!ready)@(negedge clk);
                data=bytes[i];valid=1;
                if(trial==45&&i==n-1)eof=1;
                expected_crc=update_crc(expected_crc,bytes[i]);
                @(negedge clk);valid=0;eof=0;
            end
            if(trial!=45)begin eof=1;@(negedge clk);eof=0;end
            wait(done);@(negedge clk);
            if(container!=n||crc!==~expected_crc)$fatal(1,"full-container serial CRC/length mismatch trial=%0d",trial);
            if(good!==(trial==44||trial==45||trial==48))$fatal(1,"canonical acceptance mismatch trial=%0d",trial);
            if(good&&(accepted!=4||count!=4||length!=8||finishes!=1||error!=0))$fatal(1,"canonical completion mismatch");
        end
        $display("TEST_PASS canonical WAV every header byte rejection, signed PCM, stalled consumer, truncated/extra input, EOF with final byte, complete CRC");
        $finish;
    end
    initial begin #3000000;$fatal(1,"canonical timeout");end
endmodule
