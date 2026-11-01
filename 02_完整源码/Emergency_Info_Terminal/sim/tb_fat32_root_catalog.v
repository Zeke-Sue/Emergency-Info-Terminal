`timescale 1ns/1ps
module tb_fat32_root_catalog;
    reg clk=0,rst=1,start=0,valid=0,finish=0;reg [7:0] data=0;
    wire ready,item_valid,complete,long_name,overflow;
    wire [1:0] item_type;wire [5:0] item_index,count;
    wire [31:0] hash,cluster,size;wire [7:0] name_length,attrs,malformed;
    reg [7:0] e [0:31];integer i,seen=0;reg [7:0] checksum;
    always #5 clk=~clk;
    fat32_root_catalog #(.MAX_FILES(3)) dut(.clk(clk),.rst(rst),
        .scan_start(start),.byte_valid(valid),.byte_data(data),.byte_ready(ready),
        .scan_finish(finish),.catalog_valid(item_valid),.catalog_type(item_type),
        .catalog_index(item_index),.long_name(long_name),.name_hash(hash),
        .name_length(name_length),.start_cluster(cluster),.file_size(size),
        .attributes(attrs),.scan_complete(complete),.file_count(count),
        .malformed_count(malformed),.overflow(overflow));
    function [7:0] checksum_next;input [7:0] current,input_value;
        begin checksum_next={current[0],current[7:1]}+input_value;end endfunction
    task clear_entry;begin for(i=0;i<32;i=i+1)e[i]=0;end endtask
    task emit_entry;begin
        for(i=0;i<32;i=i+1)begin
            while(!ready)@(negedge clk);data=e[i];valid=1;@(negedge clk);valid=0;
        end
        while(!ready)@(negedge clk);
    end endtask
    task put_short;
        input [87:0] short_name;input [31:0] first_cluster;input [31:0] bytes;
        begin clear_entry;
            for(i=0;i<11;i=i+1)e[i]=short_name>>((10-i)*8);
            e[11]=8'h20;e[20]=first_cluster[23:16];e[21]=first_cluster[31:24];
            e[26]=first_cluster[7:0];e[27]=first_cluster[15:8];
            e[28]=bytes[7:0];e[29]=bytes[15:8];e[30]=bytes[23:16];e[31]=bytes[31:24];
        end
    endtask
    task put_lfn_alarm;
        input [7:0] sum;begin clear_entry;e[0]=8'h41;e[11]=8'h0f;e[13]=sum;
            e[1]="A";e[3]="L";e[5]="A";e[7]="R";e[9]="M";
            e[14]=".";e[16]="W";e[18]="A";e[20]="V";
            e[22]=0;e[23]=0;for(i=24;i<=31;i=i+1)e[i]=8'hff;

            e[26]=0;e[27]=0;
        end
    endtask
    task fail;input [8*100-1:0] message;begin
        $display("TEST_FAIL tb_fat32_root_catalog: %0s",message);$finish;end endtask
    always @(posedge clk)if(item_valid)begin
        case(seen)
            0:if(item_type!=1||long_name||cluster!=5||size!=1024)fail("BMP metadata");
            1:if(item_type!=2||!long_name||name_length!=9||cluster!=9||size!=96000)
                fail("validated LFN WAV metadata");
            2:if(item_type!=3||cluster!=12||size!=4096)fail("CONFIG metadata");
            default:fail("catalog exceeded limit");
        endcase
        seen=seen+1;
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;@(negedge clk);start=1;
        @(negedge clk);start=0;
        put_short("IMAGE1  BMP",32'd5,32'd1024);emit_entry;
        put_short("ALARM~1 WAV",32'd9,32'd96000);
        checksum=0;for(i=0;i<11;i=i+1)checksum=checksum_next(checksum,e[i]);
        put_lfn_alarm(checksum);emit_entry;
        put_short("ALARM~1 WAV",32'd9,32'd96000);emit_entry;
        put_short("CONFIG  BIN",32'd12,32'd4096);emit_entry;
        put_short("EXTRA   BMP",32'd15,32'd2048);emit_entry;
        @(negedge clk);finish=1;@(negedge clk);finish=0;
        wait(complete);#1;
        if(seen!=3||count!=3||!overflow||malformed!=0)
            fail("count, overflow or malformed status");
        $display("TEST_PASS tb_fat32_root_catalog SFN/LFN catalog, metadata and bounded overflow");
        $finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
