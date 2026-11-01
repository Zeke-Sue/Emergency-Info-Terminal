`timescale 1ns/1ps

module tb_human_wav_admission #(parameter MOUNT_ONLY=0);
    reg clk=0,rst=1;always #5 clk=~clk;
    reg [7:0] bytes[0:15728639];
    reg [31:0] sizes[0:14],crcs[0:14];
    wire request,valid,last,result,admitted,mounted,busy;
    wire [31:0] lba,length,crc;
    wire [7:0] purpose;
    wire [3:0] reason,index,error_code;
    wire [4:0] count,completed;
    wire [15:0] admitted_bitmap;
    reg [7:0] data;
    reg active=0;reg [31:0] block;
    reg [8:0] position;
    integer seen=0;
    console_wav_admission_pipeline #(.MAX_AUDIO_FILES(15),.DEPLOYMENT_PROFILES(1),
        .FIXED_PLAYLIST(1),.STRICT_CHAIN(1),.ENABLE_IMA(0),
        .STREAM_BYTES_PER_SECOND(50000000)) dut(
        .clk(clk),.rst(rst),.start_ready(!rst),.sd_ready(!rst),.reload(1'b0),
        .trajectory_error(1'b0),.purpose(8'h21),.sector_req(request),.sector_lba(lba),
        .sector_data(data),.sector_valid(valid),.sector_end(last),
        .result_valid(result),.admitted(admitted),.reason(reason),.result_index(index),
        .admitted_length(length),.admitted_crc32(crc),.admitted_purpose(purpose),
        .wav_count(count),.completed_count(completed),.admitted_bitmap(admitted_bitmap),
        .mounted(mounted),.busy(busy),.error_code(error_code));
    function [7:0] card_byte;
        input integer sector,offset;
        integer cluster,slot,relative,value,entry,k;
        reg [87:0] filename;
        begin
            card_byte=0;
            if(sector==0)case(offset)
                11:card_byte=0;12:card_byte=2;13:card_byte=1;
                14:card_byte=1;16:card_byte=1;37:card_byte=1;
                44:card_byte=2;510:card_byte=8'h55;511:card_byte=8'haa;
            endcase
            else if(sector<=256)begin
                cluster=(sector-1)*128+(offset>>2);value=0;
                if(cluster<3)value=32'h0fffffff;
                else begin
                    slot=(cluster-3)/2048;relative=(cluster-3)%2048;
                    if(slot<15&&relative<(sizes[slot]+511)/512)
                        value=relative+1==(sizes[slot]+511)/512 ? 32'h0fffffff : cluster+1;
                end
                card_byte=value>>((offset&3)*8);
            end else if(sector==257)begin
                entry=offset>>5;k=offset&31;
                if(entry<15)begin
                    filename="AUDIO00 WAV";
                    filename[47:40]="0"+entry/10;filename[39:32]="0"+entry%10;
                    cluster=3+entry*2048;
                    if(k<11)card_byte=filename>>((10-k)*8);
                    else case(k)
                        11:card_byte=8'h20;
                        20:card_byte=cluster>>16;21:card_byte=cluster>>24;
                        26:card_byte=cluster;27:card_byte=cluster>>8;
                        28,29,30,31:card_byte=sizes[entry]>>((k-28)*8);
                    endcase
                end
            end else begin
                slot=(sector-258)/2048;relative=((sector-258)%2048)*512+offset;
                if(slot<15&&relative<sizes[slot])card_byte=bytes[slot*1048576+relative];
            end
        end
    endfunction
    assign valid=active;
    assign last=active&&position==511;
    always @* data=card_byte(block,position);
    reg served=0;
    always @(posedge clk)begin
        if(rst)begin active<=0;served<=0;position<=0;block<=0;end
        else begin
            if(!request)served<=0;
            if(!active&&request&&!served)begin active<=1;served<=1;position<=0;block<=lba;end
            else if(active)begin
                if(position==511)active<=0;
                else position<=position+1'b1;
            end
            if(result)begin
                if(index!==seen||!admitted||reason!=0||length!==sizes[seen]||crc!==crcs[seen]||purpose!==8'h21+seen)
                    $fatal(1,"real WAV slot %0d: pass=%b reason=%0d length=%0d CRC=%h expected=%h",index,admitted,reason,length,crc,crcs[seen]);
                $display("PASS real WAV slot %0d complete CRC=%h samples=%0d",seen,crc,(length-44)/2);
                seen=seen+1;
                if(seen==15)begin $display("TEST_PASS 15 real WAV FAT/strict-chain/FFT/admission certificates");$finish;end
            end
            if(error_code!=0)$fatal(1,"real WAV FAT error %0d",error_code);
            if(MOUNT_ONLY&&mounted)begin
                if(count!=15)$fatal(1,"human catalog count %0d",count);
                $display("TEST_PASS 15-file fixed catalog completion retained across FAT read");$finish;
            end
        end
    end
    initial begin
        $readmemh("../../sim/human_audio_bytes.mem",bytes);
        $readmemh("../../sim/human_audio_sizes.mem",sizes);
        $readmemh("../../sim/human_audio_crcs.mem",crcs);
        repeat(5)@(negedge clk);rst=0;
    end
    initial begin #(64'd20000000000);$fatal(1,"real WAV admission timeout seen=%0d",seen);end
endmodule

module tb_human_catalog_mount;
    tb_human_wav_admission #(.MOUNT_ONLY(1)) test();
endmodule
