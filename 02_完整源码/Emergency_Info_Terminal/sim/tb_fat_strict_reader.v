`timescale 1ns/1ps
module tb_fat_strict_reader;
    reg clk=0,rst=1,open_req=0;always #5 clk=~clk;
    reg [5:0] index=0;reg [7:0] sd_data=0;reg sd_valid=0,sd_end=0;
    wire req,mounted,valid,ended,opened;wire [31:0] lba;wire [7:0] data;wire [3:0] error;
    integer mode=0,sd_state=0,pos=0,block=0,received=0,requests=0,opens=0;
    reg [31:0] value;
    fat32_file_reader #(.STRICT_CHAIN(1),.IO_TIMEOUT(1000),.INIT_TIMEOUT(100)) dut(
        .clk(clk),.rst(rst),.start_ready(!rst),.sd_ready(!rst),
        .sector_req(req),.sector_lba(lba),.sector_data(sd_data),.sector_valid(sd_valid),.sector_end(sd_end),
        .open_req(open_req),.abort_file(1'b0),.open_type(2'd1),.file_index(index),
        .open_done(opened),.file_data(data),.file_valid(valid),.file_ready(1'b1),.file_end(ended),
        .mounted(mounted),.error_code(error));
    task fail;input [799:0] why;begin
        $display("TEST_FAIL strict reader mode=%0d %0s state=%0d err=%0d bytes=%0d",mode,why,dut.state,error,received);$finish;
    end endtask
    function [7:0] card_byte;
        input integer b,p;integer e,n,c;reg [31:0] f;
        begin
            card_byte=0;
            if(b==0)case(p)
                12:card_byte=2;13:card_byte=1;14:card_byte=1;16:card_byte=1;
                36:card_byte=1;44:card_byte=2;510:card_byte=8'h55;511:card_byte=8'haa;
            endcase
            else if(b==1)begin
                c=p/4;f=32'h0fffffff;
                if(c==2&&mode==1)f=2;
                if(c==3)f=4;
                if(c==4)f=3;
                card_byte=f>>((p%4)*8);
            end else if(b==2)begin
                if(mode==1)card_byte=8'he5;
                else if(p<64)begin
                    e=p/32;n=p%32;
                    case(n)
                        0:card_byte="I";1:card_byte="M";2:card_byte="G";3:card_byte="0"+e;
                        4,5,6,7:card_byte=" ";8:card_byte="B";9:card_byte="M";10:card_byte="P";
                        11:card_byte=8'h20;26:card_byte=e==0 ? 3 : 5;
                        28:card_byte=e==0 ? 0 : 64;29:card_byte=e==0 ? 20 : 0;
                    endcase
                end
            end else card_byte=(b*17+p)&255;
        end
    endfunction
    always @(posedge clk)begin
        sd_valid<=0;sd_end<=0;
        if(rst)begin sd_state<=0;received<=0;requests<=0;opens<=0;end
        else begin
            if(open_req)received<=0;
            else if(valid)begin
                if(index==0)fail("cyclic file leaked payload before preflight");
                if(data!==((5*17+received)&255))fail("good file payload");
                received<=received+1;
            end
            if(opened)opens<=opens+1;
            case(sd_state)
                0:if(req)begin block<=lba;pos<=0;sd_state<=1;requests<=requests+1;end
                1:begin sd_data<=card_byte(block,pos);sd_valid<=1;
                    if(pos==511||(mode==2&&requests==1&&pos==100))sd_state<=2;else pos<=pos+1;end
                2:begin sd_end<=1;sd_state<=3;end
                3:if(!req)sd_state<=0;
            endcase
        end
    end
    task reset_case;input integer m;begin
        @(negedge clk);rst=1;mode=m;repeat(4)@(negedge clk);rst=0;
    end endtask
    task open;input [5:0] i;begin
        @(negedge clk);index=i;open_req=1;@(negedge clk);open_req=0;
    end endtask
    initial begin
        reset_case(0);wait(mounted);open(0);wait(error!=0);@(negedge clk);
        if(error!=7||received!=0||opens!=0||!ended||!mounted)fail("cyclic file not local failure");
        open(1);wait(opened);wait(ended);@(negedge clk);
        if(error||received!=64||opens!=1)fail("good reopen after bad chain");
        reset_case(1);wait(error!=0);if(error!=7||mounted||requests>5)fail("root cycle not bounded");
        reset_case(2);wait(mounted);open(1);wait(opened);wait(ended);@(negedge clk);
        if(error||received!=64||opens!=1)fail("short boot-sector retry polluted fields");
        $display("TEST_PASS strict FAT reader: cyclic payload withheld, good file after rejection, root directory loop bound, clean closed-sector retry");$finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
