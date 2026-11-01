`timescale 1ns/1ps
module tb_sd_addressing;
    reg clk=0,rst=1,ack=0,error=0,read_req=0,write_req=0,block_ack=0;
    reg [7:0] response_r1=0;reg [31:0] response_data=0;
    wire initialized,cmd_req,read_end;wire [47:0] cmd;
    wire [15:0] divider,length;wire [7:0] expected_r1;
    integer kind;
    always #5 clk=~clk;
    sd_card_sec_read_write #(.SPI_LOW_SPEED_DIV(123),.SPI_HIGH_SPEED_DIV(2)) dut(
        .clk(clk),.rst(rst),.sd_init_done(initialized),
        .sd_sec_read(read_req),.sd_sec_read_addr(32'h1234),.sd_sec_read_end(read_end),
        .sd_sec_write(write_req),.sd_sec_write_addr(32'h2345),.sd_sec_write_data(8'd0),
        .spi_clk_div(divider),.cmd_req(cmd_req),.cmd_req_ack(ack),.cmd_req_error(error),
        .response_r1(response_r1),.response_data(response_data),.cmd(cmd),
        .cmd_r1(expected_r1),.cmd_data_len(length),.block_read_valid(1'b0),
        .block_read_data(8'd0),.block_read_req_ack(block_ack),
        .block_write_data_rd(1'b0),.block_write_req_ack(1'b0));
    task fail;input [8*100-1:0] message;begin
        $display("TEST_FAIL tb_sd_addressing kind=%0d %0s cmd=%h",kind,message,cmd);$finish;
    end endtask
    task respond;input [7:0] opcode;input [7:0] r1;input [31:0] data;
        begin
            wait(cmd_req&&cmd[47:40]==opcode);@(negedge clk);
            response_r1=r1;response_data=data;error=r1!=expected_r1;ack=1;
            @(negedge clk);ack=0;error=0;
        end
    endtask
    initial begin

        for(kind=0;kind<3;kind=kind+1)begin
            rst=1;read_req=0;write_req=0;repeat(3)@(negedge clk);rst=0;
            respond(0,1,0);
            respond(8,kind==0 ? 5 : 1,32'h000001aa);
            respond(55,1,0);
            wait(cmd_req&&cmd[47:40]==41);@(negedge clk);
            if(cmd[39:8]!=(kind==0 ? 32'd0 : 32'h40000000))fail("ACMD41 HCS");
            respond(41,0,0);
            if(initialized||divider!=123)fail("high speed or ready before OCR");
            respond(58,0,kind==2 ? 32'hc0ff8000 : 32'h80ff8000);
            if(kind!=2)begin
                wait(cmd_req&&cmd[47:40]==16);@(negedge clk);
                if(cmd[39:8]!=512||initialized)fail("SDSC CMD16 block size");
                respond(16,0,0);
            end
            wait(initialized);repeat(3)@(negedge clk);
            if(divider!=2)fail("configured high-speed divider ignored");
            read_req=1;@(negedge clk);read_req=0;
            wait(cmd_req&&cmd[47:40]==17);@(negedge clk);
            if(cmd[39:8]!=(kind==2 ? 32'h1234 : 32'h246800))fail("CMD17 address units");
            respond(17,0,0);repeat(2)@(negedge clk);
            block_ack=1;@(negedge clk);block_ack=0;
            wait(read_end);repeat(3)@(negedge clk);
            read_req=1;@(negedge clk);read_req=0;
            respond(17,4,0);respond(17,4,0);respond(17,4,0);respond(17,4,0);
            wait(read_end);repeat(3)@(negedge clk);
            if(!initialized||cmd_req)fail("bounded read retry recovery");
            write_req=1;@(negedge clk);write_req=0;
            wait(cmd_req&&cmd[47:40]==24);@(negedge clk);
            if(cmd[39:8]!=(kind==2 ? 32'h2345 : 32'h468a00))fail("CMD24 address units");
        end
        $display("TEST_PASS tb_sd_addressing v1/v2 SDSC, SDHC OCR, CMD16 and read/write address units");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
