`timescale 1ns/1ps
module tb_fixed_catalog #(parameter HASH_NAMES=1, WAV_FILES=12, WINDOWS_METADATA=0);
    reg clk=0,rst=1,start=0,valid=0,finish=0;
    reg [7:0] data=0,entry[0:31];
    always #5 clk=~clk;
    wire ready,item,done,overflow,long_name;
    wire [1:0] kind;
    wire [5:0] count,index;
    wire [31:0] cluster,size,hash;
    wire [7:0] malformed,length;
    integer round_no,i,j,k,number,rank,seen=0;
    reg [87:0] filename;
    reg [31:0] expected_hash[0:16+WAV_FILES];
    fat32_sorted_catalog #(.NAME_CHARS(32),.FIXED_NAMES(1),.FIXED_WAV_FILES(WAV_FILES),.HASH_NAMES(HASH_NAMES)) dut(
        .clk(clk),.rst(rst),.scan_start(start),.byte_valid(valid),.byte_data(data),
        .byte_ready(ready),.scan_finish(finish),.catalog_valid(item),.catalog_type(kind),
        .catalog_index(index),.long_name(long_name),.name_hash(hash),.name_length(length),
        .start_cluster(cluster),.file_size(size),.scan_complete(done),.file_count(count),
        .malformed_count(malformed),.overflow(overflow));
    task emit;input integer id;begin
        for(j=0;j<32;j=j+1)entry[j]=0;
        if(id<16)begin filename="IMAGE00 BMP";number=id+1;end
        else if(id<16+WAV_FILES)begin filename="AUDIO00 WAV";number=id-16;end
        else begin filename="CONFIG  BIN";number=0;end
        if(id<16+WAV_FILES)begin filename[47:40]="0"+number/10;filename[39:32]="0"+number%10;end
        if(id==17+WAV_FILES)filename="WRONG   WAV";
        for(j=0;j<11;j=j+1)entry[j]=filename>>((10-j)*8);
        entry[11]=8'h20;entry[26]=id+2;entry[28]=id;entry[29]=2;
        if(id<17+WAV_FILES)begin
            expected_hash[id]=32'h811c9dc5;
            for(j=0;j<11;j=j+1)expected_hash[id]=(expected_hash[id]^entry[j])*32'h01000193;
        end
        for(k=0;k<32;k=k+1)begin
            while(!ready)@(negedge clk);data=entry[k];valid=1;@(negedge clk);valid=0;
        end
        while(!ready)@(negedge clk);
    end endtask
    task windows_directory;begin

        for(j=0;j<32;j=j+1)entry[j]=0;
        entry[0]=8'h42;entry[11]=8'h0f;
        for(k=0;k<32;k=k+1)begin
            while(!ready)@(negedge clk);data=entry[k];valid=1;@(negedge clk);valid=0;
        end
        while(!ready)@(negedge clk);
        entry[0]=8'h01;
        for(k=0;k<32;k=k+1)begin
            while(!ready)@(negedge clk);data=entry[k];valid=1;@(negedge clk);valid=0;
        end
        while(!ready)@(negedge clk);
        filename="SYSTEM~1   ";
        for(j=0;j<11;j=j+1)entry[j]=filename>>((10-j)*8);
        entry[11]=8'h16;
        for(k=0;k<32;k=k+1)begin
            while(!ready)@(negedge clk);data=entry[k];valid=1;@(negedge clk);valid=0;
        end
        while(!ready)@(negedge clk);
    end endtask
    always @(negedge clk)if(item)begin
        rank=round_no<2 ? seen : round_no==3 ? seen+1 : 1;
        if(cluster!=rank+2||size!=512+rank||hash!==(HASH_NAMES ? expected_hash[rank] : 32'd0)||
            index!=seen||long_name||length!=11||kind!=(rank<16 ? 1 : rank<16+WAV_FILES ? 2 : 3))
            $fatal(1,"fixed catalog identity mismatch round=%0d ordinal=%0d",round_no,seen);
        seen=seen+1;
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;
        for(round_no=0;round_no<(WAV_FILES==16 ? 4 : 3);round_no=round_no+1)begin
            seen=0;start=1;@(negedge clk);start=0;
            if(WINDOWS_METADATA)windows_directory();
            if(round_no<2)for(i=0;i<17+WAV_FILES;i=i+1)emit(round_no==0 ? i : 16+WAV_FILES-i);
            else if(round_no==2)begin emit(0);emit(1);emit(0);emit(17+WAV_FILES);end
            else begin for(i=0;i<32;i=i+1)emit(i);emit(0);end
            finish=1;@(negedge clk);finish=0;wait(done);@(negedge clk);
            if(count!=(round_no<2 ? (WAV_FILES==16 ? 32 : 17+WAV_FILES) : round_no==3 ? 31 : 1)||seen!=count||overflow||
                (round_no<2 ? malformed!=(WAV_FILES==16 ? 1 : 0) : round_no==3 ? malformed!=2 : malformed<3))$fatal(1,"fixed catalog count/diagnostic count=%d malformed=%d",count,malformed);
        end
        $display("TEST_PASS fixed catalog 16 BMP + %0d WAV + CONFIG, reverse order, metadata/hash, duplicate exclusion, bad-name rejection",WAV_FILES);$finish;
    end
    initial begin #2000000;$fatal(1,"fixed catalog timeout");end
endmodule

module tb_windows_fixed_catalog;
    tb_fixed_catalog #(.HASH_NAMES(0),.WAV_FILES(15),.WINDOWS_METADATA(1)) test();
endmodule

module tb_fixed_catalog_human;
    tb_fixed_catalog #(.HASH_NAMES(0),.WAV_FILES(15)) test();
endmodule

module tb_fixed_catalog_full32;
    tb_fixed_catalog #(.HASH_NAMES(0),.WAV_FILES(16),.WINDOWS_METADATA(1)) test();
endmodule
