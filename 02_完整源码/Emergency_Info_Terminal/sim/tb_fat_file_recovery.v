`timescale 1ns/1ps
module tb_fat_file_recovery;
    reg clk=0,rst=1,open_req=0,abort_file=0;
    always #5 clk=~clk;
    reg [5:0] file_index=0;
    wire req,valid,ended,mounted,opened,missing;
    wire [31:0] lba,size;
    wire [7:0] data;
    wire [3:0] error;
    reg [7:0] sd_data=0;
    reg sd_valid=0,sd_end=0;
    integer sd_state=0,pos=0,block=0,cycle=0,received=0,opens=0;
    wire ready=cycle%5!=0;
    fat32_file_reader #(.IO_TIMEOUT(3000),.INIT_TIMEOUT(100)) dut(
        .clk(clk),.rst(rst),.start_ready(!rst),.sd_ready(!rst),
        .sector_req(req),.sector_lba(lba),.sector_data(sd_data),
        .sector_valid(sd_valid),.sector_end(sd_end),.open_req(open_req),
        .abort_file(abort_file),.open_type(2'd1),.file_index(file_index),
        .open_done(opened),.open_not_found(missing),.file_size(size),
        .file_data(data),.file_valid(valid),.file_ready(ready),
        .file_end(ended),.mounted(mounted),.error_code(error));
    task fail;
        input [799:0] reason;
        begin $display("TEST_FAIL tb_fat_file_recovery %0s error=%0d state=%0d bytes=%0d",reason,error,dut.state,received);$finish;end
    endtask
    function [7:0] card_byte;
        input integer b,p;
        integer entry,n;
        begin
            card_byte=0;
            if(b==0)case(p)
                12:card_byte=2;13:card_byte=1;14:card_byte=1;
                16:card_byte=1;36:card_byte=1;44:card_byte=2;
                510:card_byte=8'h55;511:card_byte=8'haa;
            endcase
            else if(b==2 && p<96)begin
                entry=p/32;n=p%32;
                case(n)
                    0:card_byte="I";1:card_byte="M";2:card_byte="G";
                    3:card_byte="0"+entry;4,5,6,7:card_byte=" ";
                    8:card_byte="B";9:card_byte="M";10:card_byte="P";
                    11:card_byte=8'h20;26:card_byte=entry+3;
                    28:card_byte=entry==2 ? 64 : 88;
                    29:card_byte=entry==2 ? 0 : 2;
                endcase
            end else if(b>=3)card_byte=(b*17+p)&255;

            else if(b==1 && p>=12 && p<20)card_byte=p%4==3 ? 8'h0f : 8'hff;
        end
    endfunction
    always @(posedge clk)begin
        cycle<=cycle+1;sd_valid<=0;sd_end<=0;
        if(rst)begin sd_state<=0;received<=0;opens<=0;end
        else begin
            if(opened)opens<=opens+1;
            if(open_req)received<=0;
            else if(valid && ready && !abort_file)begin
                if(data!==((17*(file_index+3)+received)&255))fail("payload mismatch after recovery");
                received<=received+1;
            end
            case(sd_state)
                0:if(req)begin block<=lba;pos<=0;sd_state<=1;end
                1:if(cycle%3!=0)begin
                    sd_valid<=1;sd_data<=card_byte(block,pos);
                    if(pos==511)sd_state<=2;else pos<=pos+1;
                end
                2:begin sd_end<=1;sd_state<=3;end
                3:if(!req)sd_state<=0;
            endcase
        end
    end
    task open_image;
        input [5:0] index;
        begin @(negedge clk);file_index=index;open_req=1;
            @(negedge clk);open_req=0;end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;wait(mounted);
        open_image(0);wait(received>=54);
        @(negedge clk);abort_file=1;@(negedge clk);abort_file=0;
        if(!ended || !mounted || error!=0)fail("abort did not release file while preserving catalog");
        open_image(1);wait(error!=0);
        if(error!=6 || !ended || !mounted || received!=512)fail("broken chain corrupted mount or length");
        open_image(2);wait(opened);wait(ended);
        if(error!=0 || received!=64 || opens!=3)fail("good file could not open after file-local error");
        open_image(7);wait(missing);
        open_image(2);wait(opened);wait(ended);
        if(error!=0 || received!=64)fail("missing file blocked following open");
        $display("TEST_PASS tb_fat_file_recovery header abort, broken chain, retained catalog, good reopen, absent entry, byte stalls");$finish;
    end
    initial begin #300000;fail("timeout");end
endmodule
