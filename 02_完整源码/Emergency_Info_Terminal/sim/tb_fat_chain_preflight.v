`timescale 1ns/1ps
module tb_fat_chain_preflight;
    reg clk=0,rst=1,start=0;always #5 clk=~clk;
    reg [31:0] first=3,size=1300,fat_base=1,fat_length=2,data_base=3;
    reg [2:0] shift=0;
    reg [7:0] data=0;reg byte_valid=0,sector_end=0;
    wire req,busy,done,valid;wire [31:0] lba;wire [3:0] error;
    integer mode=0,state=0,pos=0,case_id=0,requests=0,block=0,n;
    reg [31:0] value;
    fat32_chain_preflight #(.IO_TIMEOUT(800),.MAX_CLUSTERS(64)) dut(
        .clk(clk),.rst(rst),.start(start),.first_cluster(first),.file_size(size),
        .fat_lba(fat_base),.fat_sectors(fat_length),.data_lba(data_base),.cluster_shift(shift),
        .sector_req(req),.sector_lba(lba),.sector_data(data),.sector_valid(byte_valid),
        .sector_end(sector_end),.busy(busy),.done(done),.valid(valid),.error_code(error));
    task fail;input [799:0] why;begin
        $display("TEST_FAIL FAT preflight mode=%0d %0s error=%0d requests=%0d",mode,why,error,requests);$finish;
    end endtask
    function [31:0] fat;
        input integer cluster;
        begin
            case(cluster)
                3:fat=11;
                11:fat=137;
                137:fat=32'h0fffffff;
                default:fat=0;
            endcase
            if(mode==1&&cluster==3)fat=3;
            if(mode==2&&cluster==11)fat=3;
            if(mode==3&&cluster==11)fat=32'h0fffffff;
            if(mode==4&&cluster==11)fat=32'h0ffffff7;
            if(mode==5&&cluster==11)fat=256;
            if(mode==6&&cluster==11)fat=32'h0ffffff0;
            if(mode==7&&cluster==137)fat=3;
        end
    endfunction
    always @(posedge clk)begin
        byte_valid<=0;sector_end<=0;
        if(rst)begin state<=0;requests<=0;end
        else case(state)
            0:if(req)begin block<=lba-fat_base;pos<=0;state<=1;requests<=requests+1;end
            1:if(mode!=10)begin
                value=fat(block*128+pos/4);data<=value>>((pos%4)*8);byte_valid<=1;
                if(pos==511||(mode==8&&requests==1&&pos==30)||(mode==9&&pos==30))state<=2;
                else pos<=pos+1;
            end
            2:begin sector_end<=1;state<=3;end
            3:if(!req)state<=0;
        endcase
    end
    task run;input integer m;input [31:0] bytes;input integer success;input integer reason;
        begin
            @(negedge clk);rst=1;start=0;mode=m;size=bytes;
            repeat(3)@(negedge clk);rst=0;@(negedge clk);start=1;@(negedge clk);start=0;
            wait(done);@(negedge clk);
            if(valid!=success||error!=reason||busy||req)fail("unexpected result");
        end
    endtask
    initial begin
        run(0,1300,1,0);if(requests!=2)fail("fragmented length/FAT cache");
        run(1,6000,0,7);run(2,6000,0,7);run(3,1300,0,6);
        run(4,1300,0,6);run(5,1300,0,6);run(6,1300,0,6);
        run(7,1300,0,6);run(0,0,0,9);run(0,40000,0,9);
        run(8,1300,1,0);if(requests!=3)fail("closed-sector retry");
        run(9,1300,0,5);if(requests!=4)fail("retry bound");
        run(10,1300,0,4);
        first=32'h0ffffff8;run(0,10,0,6);first=3;
        data_base=32'hffffffff;run(0,1300,0,6);data_base=3;
        fat_base=32'hffffffff;run(0,1300,0,6);fat_base=1;
        shift=3;run(0,9000,1,0);
        $display("TEST_PASS FAT preflight fragmented/EOC, self/multinode cycles, free/bad/reserved/out-of-FAT clusters, LBA overflow, size bound, retry bound, timeout, SPC8");$finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
