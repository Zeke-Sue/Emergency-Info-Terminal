`timescale 1ns/1ps
module tb_fat_sorted_catalog #(parameter NAME_CHARS=256);
    reg clk=0,rst=1,start=0,valid=0,finish=0;
    reg [7:0] data=0;reg [7:0] entry [0:31];
    always #5 clk=~clk;
    wire ready,item,done;wire [31:0] cluster,size;wire [5:0] count;
    wire [7:0] malformed;wire overflow,long_name;
    wire [31:0] name_hash;
    wire [7:0] name_length,attributes;
    wire [1:0] item_type;
    reg [31:0] expected_hash[0:7];
    reg [31:0] long_hash;
    function [31:0] fnv;input [31:0] hash;input [7:0] value;
        begin fnv=(hash^value)*32'h01000193;end endfunction
    integer seen=0,i,j,k,round_no,ordinal,p,offset,n;reg [7:0] sum;
    reg [255:0] long_text;
    fat32_sorted_catalog #(.NAME_CHARS(NAME_CHARS)) dut(.clk(clk),.rst(rst),.scan_start(start),
        .byte_valid(valid),.byte_data(data),.byte_ready(ready),.scan_finish(finish),
        .catalog_valid(item),.start_cluster(cluster),.file_size(size),.long_name(long_name),
        .name_hash(name_hash),.name_length(name_length),.attributes(attributes),.catalog_type(item_type),
        .scan_complete(done),.file_count(count),.malformed_count(malformed),.overflow(overflow));
    task fail;input [799:0] reason;begin $display("TEST_FAIL sorted catalog: %0s round=%d seen=%d cluster=%d",reason,round_no,seen,cluster);$finish;end endtask
    always @(negedge clk)if(item)begin
        case(seen)
            0:if(cluster!=1)fail("ALPHA order");
            1:if(cluster!=7||!long_name)fail("LFN not sorted by full validated name");
            2:if(cluster!=6)fail("CONFIG order");
            3:if(cluster!=2)fail("MID order");
            4:if(cluster!=3)fail("ZED order");
            default:fail("duplicate not excluded");
        endcase
        if(size!=1024||name_hash!==expected_hash[cluster]||attributes!=8'h20||
            name_length!=(cluster==7 ? 19 : 11)||item_type!=(cluster==6 ? 3 : 1))
            fail("metadata/hash lost during serial sort");seen=seen+1;
    end
    task clear;begin for(j=0;j<32;j=j+1)entry[j]=0;end endtask
    task emit;begin
        for(k=0;k<32;k=k+1)begin
            while(!ready)@(negedge clk);data=entry[k];valid=1;
            @(negedge clk);valid=0;
        end
        while(!ready)@(negedge clk);
    end endtask
    task short_entry;input [87:0] name;input [7:0] cl;begin
        clear();for(j=0;j<11;j=j+1)entry[j]=name>>((10-j)*8);
        entry[11]=8'h20;entry[26]=cl;entry[29]=4;
        expected_hash[cl]=32'h811c9dc5;
        for(j=0;j<11;j=j+1)expected_hash[cl]=fnv(expected_hash[cl],entry[j]);
    end endtask
    function integer lfn_offset;input integer pos;begin
        case(pos)0:lfn_offset=1;1:lfn_offset=3;2:lfn_offset=5;3:lfn_offset=7;4:lfn_offset=9;
            5:lfn_offset=14;6:lfn_offset=16;7:lfn_offset=18;8:lfn_offset=20;9:lfn_offset=22;
            10:lfn_offset=24;11:lfn_offset=28;default:lfn_offset=30;endcase
    end endfunction
    task long_entry;begin
        short_entry("ZZZZZ~1 BMP",7);sum=0;
        for(j=0;j<11;j=j+1)sum={sum[0],sum[7:1]}+entry[j];
        long_text="Beta_long_image.bmp";
        long_hash=32'h811c9dc5;
        for(ordinal=2;ordinal>=1;ordinal=ordinal-1)begin
            clear();entry[0]=ordinal==2 ? 8'h42 : 8'h01;entry[11]=8'h0f;entry[13]=sum;
            for(p=0;p<13;p=p+1)begin
                offset=lfn_offset(p);n=(ordinal-1)*13+p;
                if(n<19)begin entry[offset]=long_text>>((18-n)*8);entry[offset+1]=0;end
                else if(n==19)begin entry[offset]=0;entry[offset+1]=0;end
                else begin entry[offset]=255;entry[offset+1]=255;end
                if(n<19)begin
                    long_hash=fnv(long_hash,entry[offset]);
                    long_hash=fnv(long_hash,entry[offset+1]);
                end
            end
            emit();
        end
        short_entry("ZZZZZ~1 BMP",7);expected_hash[7]=long_hash;emit();
    end endtask
    task file_entry;input integer id;begin
        case(id)
            0:short_entry("ZED     BMP",3);
            1:short_entry("alpha   bmp",1);
            2:short_entry("MID     BMP",2);
            3:short_entry("SAME    WAV",4);
            4:short_entry("same    wav",5);
            5:short_entry("CONFIG  BIN",6);
        endcase
        if(id==6)long_entry();else emit();
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        for(round_no=0;round_no<2;round_no=round_no+1)begin
            seen=0;start=1;@(negedge clk);start=0;
            for(i=0;i<7;i=i+1)file_entry(round_no==0 ? i : 6-i);
            finish=1;@(negedge clk);finish=0;wait(done);@(negedge clk);
            if(seen!=5||count!=5||malformed!=2||overflow)fail("final count or duplicate diagnostic");
        end
        $display("TEST_PASS sorted catalog: opposite physical orders, ASCII folding, full two-entry LFN ordering, duplicate exclusion, metadata retention, restart");$finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule

module tb_fat_sorted_catalog_compact;
    tb_fat_sorted_catalog #(.NAME_CHARS(32)) test();
endmodule
