`timescale 1ns/1ps
module tb_fat_geometry;
    reg clk=0,rst=1,open_req=0;
    always #5 clk=~clk;
    wire req,valid,file_end,mounted,open_done;
    wire [31:0] lba,file_size;
    wire [7:0] data;
    wire [3:0] error;
    wire open_not_found;wire [5:0] catalog_count;
    wire [4:0] bmp_count,wav_count;wire config_found;
    wire [7:0] malformed;wire catalog_overflow;
    reg [7:0] sector_data=0;
    reg sector_valid=0,sector_end=0;
    integer cycle=0,spc=1,partition=0,fats=1,received=0;
    integer sd_state=0,sd_pos=0,sd_lba=0,case_id,expected_size;
    reg saw_fat=0;
    reg req_q=0;reg [31:0] lba_q;
    always @(posedge clk)begin
        req_q<=!rst&&req;lba_q<=lba;
        if(!rst&&req)begin
            if(^lba===1'bx)fail("request exposed an uninitialized address");
            if(req_q&&lba!==lba_q)fail("address changed while request was active");
        end
    end
    wire file_ready=cycle%7!=0 && cycle%11!=0;
    fat32_file_reader #(.IO_TIMEOUT(4000),.INIT_TIMEOUT(4000)) dut(
        .clk(clk),.rst(rst),.start_ready(!rst),.sd_ready(!rst),
        .sector_req(req),.sector_lba(lba),.sector_data(sector_data),
        .sector_valid(sector_valid),.sector_end(sector_end),
        .open_req(open_req),.abort_file(1'b0),.open_type(2'd1),.file_index(6'd0),
        .open_done(open_done),.open_not_found(open_not_found),
        .file_size(file_size),.file_data(data),.file_valid(valid),
        .file_ready(file_ready),.file_end(file_end),.mounted(mounted),
        .catalog_file_count(catalog_count),.bmp_file_count(bmp_count),
        .wav_file_count(wav_count),.config_found(config_found),
        .catalog_malformed_count(malformed),.catalog_overflow(catalog_overflow),
        .error_code(error));
    task fail;
        input [511:0] reason;
        begin $display("TEST_FAIL tb_fat_geometry case=%0d SPC=%0d %0s",case_id,spc,reason);$finish;end
    endtask
    function [7:0] name_byte;
        input integer n;
        case(n)
            0:name_byte="I";1:name_byte="M";2:name_byte="A";
            3:name_byte="G";4:name_byte="E";5:name_byte="1";
            6,7:name_byte=" ";8:name_byte="B";9:name_byte="M";
            10:name_byte="P";default:name_byte=0;
        endcase
    endfunction
    function [7:0] card_byte;
        input integer block,pos;
        integer base,offset;
        begin
            base=partition+7+fats*17;
            card_byte=0;
            if(block==0 && partition!=0)begin
                case(pos)
                    450:card_byte=8'h0c;
                    454,455,456,457:card_byte=partition>>((pos-454)*8);
                    510:card_byte=8'h55;511:card_byte=8'haa;
                endcase
            end else if(block==partition)begin
                case(pos)
                    12:card_byte=2;13:card_byte=spc;14:card_byte=7;
                    16:card_byte=fats;36:card_byte=17;44:card_byte=2;
                    510:card_byte=8'h55;511:card_byte=8'haa;
                endcase
            end else if(block==base)begin
                if(pos<11)card_byte=name_byte(pos);
                else if(pos==11)card_byte=8'h20;
                else if(pos==26)card_byte=5;
                else if(pos>=28 && pos<=31)card_byte=expected_size>>((pos-28)*8);
            end else if(block==partition+7)begin
                if(pos==20)card_byte=13;
            end else begin
                if(block>=base+3*spc && block<base+4*spc)
                    offset=(block-base-3*spc)*512+pos;
                else if(block==base+11*spc)offset=spc*512+pos;
                else offset=-1;
                card_byte=(offset*13+(offset>>8))&255;
            end
        end
    endfunction
    always @(posedge clk)begin
        cycle<=cycle+1;sector_valid<=0;sector_end<=0;
        if(rst)begin sd_state<=0;received<=0;saw_fat<=0;end
        else begin
            if(valid && file_ready)begin
                if(data!==((received*13+(received>>8))&255))fail("BRAM stream data mismatch under stalls");
                received<=received+1;
            end
            case(sd_state)
                0:if(req)begin
                    sd_lba<=lba;sd_pos<=0;sd_state<=1;
                    if(lba==partition+7)saw_fat<=1;
                    if(lba!=0 && lba!=partition && lba!=partition+7 &&
                       lba!=partition+7+fats*17 &&
                       !(lba>=partition+7+fats*17+3*spc && lba<partition+7+fats*17+4*spc) &&
                       lba!=partition+7+fats*17+11*spc)fail("incorrect cluster or FAT geometry LBA");
                end
                1:if(cycle%3!=0)begin
                    sector_data<=card_byte(sd_lba,sd_pos);sector_valid<=1;
                    if(sd_pos==511)sd_state<=2;else sd_pos<=sd_pos+1;
                end
                2:begin sector_end<=1;sd_state<=3;end
                3:if(!req)sd_state<=0;
            endcase
        end
    end
    initial begin
        for(case_id=0;case_id<12;case_id=case_id+1)begin
            @(negedge clk);rst=1;open_req=0;
            spc=case_id<8 ? 1<<case_id : (case_id<10 ? (case_id==8 ? 0 : 3) : 8);
            partition=case_id>=10 ? (case_id==10 ? 32'h78000000 : 32'h88000000) :
                (case_id%2 ? 2048 : 0);
            fats=case_id%3+1;expected_size=spc*512+54;
            repeat(4)@(negedge clk);rst=0;
            if(case_id<8||case_id>=10)begin
                wait(mounted || error!=0);
                if(error!=0)fail("valid geometry rejected");
                @(negedge clk);open_req=1;@(negedge clk);open_req=0;
                wait(file_end || error!=0);
                if(error!=0 || received!=expected_size || !saw_fat)fail("fragmented file length/chain mismatch");
            end else begin
                wait(error!=0);if(error!=2)fail("invalid SPC was not rejected");
            end
        end
        $display("TEST_PASS tb_fat_geometry SPC=1..128, 1..3 FATs, MBR/raw/high-32-bit LBA, fragmented clusters, BRAM stalls, invalid SPC");$finish;
    end
    initial begin #100000000;fail("timeout");end
endmodule
