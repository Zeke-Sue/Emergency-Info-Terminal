`timescale 1ns/1ps
module tb_catalog_name_limit;
    reg clk=0,rst=1,start=0,valid=0,finish=0;
    reg [7:0] data=0,e[0:31];
    always #5 clk=~clk;
    wire ready,item,done,long_name;
    wire [31:0] cluster;
    wire [7:0] length,malformed;
    wire [5:0] count;
    wire [511:0] name_key;
    integer i,j,k,ordinal,p,n,off,seen=0;
    reg [7:0] checksum;
    fat32_root_catalog #(.NAME_CHARS(32)) dut(
        .clk(clk),.rst(rst),.scan_start(start),.byte_valid(valid),.byte_data(data),
        .byte_ready(ready),.scan_finish(finish),.catalog_valid(item),
        .start_cluster(cluster),.name_length(length),.long_name(long_name),
        .normalized_name(name_key),.scan_complete(done),.file_count(count),
        .malformed_count(malformed));
    task clear;begin for(j=0;j<32;j=j+1)e[j]=0;end endtask
    task short_entry;input [7:0] id;reg [87:0] s;begin
        clear();s="IMAGE01 BMP";
        for(j=0;j<11;j=j+1)e[j]=s>>((10-j)*8);
        e[11]=8'h20;e[26]=id;e[29]=4;
    end endtask
    task emit;begin
        for(k=0;k<32;k=k+1)begin
            while(!ready)@(negedge clk);
            data=e[k];valid=1;@(negedge clk);valid=0;
        end
        while(!ready)@(negedge clk);
    end endtask
    function integer offset;input integer pos;begin
        case(pos)0:offset=1;1:offset=3;2:offset=5;3:offset=7;4:offset=9;
            5:offset=14;6:offset=16;7:offset=18;8:offset=20;9:offset=22;
            10:offset=24;11:offset=28;default:offset=30;endcase
    end endfunction
    task long_entry;input integer chars;input [7:0] id;begin
        short_entry(id);checksum=0;
        for(j=0;j<11;j=j+1)checksum={checksum[0],checksum[7:1]}+e[j];
        for(ordinal=3;ordinal>=1;ordinal=ordinal-1)begin
            clear();e[0]=ordinal==3 ? 8'h43 : ordinal;e[11]=8'h0f;e[13]=checksum;
            for(p=0;p<13;p=p+1)begin
                n=(ordinal-1)*13+p;off=offset(p);
                if(n<chars)begin e[off]=8'h2d;e[off+1]=8'h4e;end
                else if(n>chars)begin e[off]=255;e[off+1]=255;end
            end
            emit();
        end
        short_entry(id);emit();
    end endtask
    always @(negedge clk)if(item)begin
        if(seen==0)begin
            if(cluster!=5||!long_name||length!=31||name_key[15:0]!=0)
                $fatal(1,"31 UTF-16 characters or terminator lost");
            for(i=1;i<32;i=i+1)if(name_key[i*16 +:16]!=16'h4e2d)
                $fatal(1,"UTF-16 name changed");
        end else if(seen==1)begin
            if(cluster!=7||long_name)$fatal(1,"overlong name aliased or next SFN damaged");
        end else $fatal(1,"unexpected accepted overlong name");
        seen=seen+1;
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
        long_entry(31,5);long_entry(32,6);short_entry(7);emit();
        finish=1;@(negedge clk);finish=0;wait(done);@(negedge clk);
        if(seen!=2||count!=2||malformed==0)$fatal(1,"limit diagnostic/count missing");
        $display("TEST_PASS compact catalog 31 UTF-16 characters, 32-character rejection without SFN alias, next-entry recovery");
        $finish;
    end
    initial begin #2000000;$fatal(1,"catalog limit timeout");end
endmodule
