`timescale 1ns/1ps
module tb_sd_response;
    reg clk=0,rst=1,req=0,spi_ack=0;
    reg [47:0] cmd={8'd8,32'h000001aa,8'h87};
    reg [31:0] reply=32'h000001aa;reg [7:0] r1=1,spi_out=8'hff;
    wire done,error,spi_req;wire [7:0] actual_r1;wire [31:0] actual_data;
    integer phase=0;
    always #5 clk=~clk;
    reg read_req=0;
    sd_card_cmd #(.IO_TIMEOUT_CYCLES(100)) dut(.sys_clk(clk),.rst(rst),.spi_clk_div(16'd0),
        .cmd_req(req),.cmd_req_ack(done),.cmd_req_error(error),.cmd(cmd),
        .cmd_r1(8'd1),.cmd_data_len(16'd4),.response_r1(actual_r1),
        .response_data(actual_data),.block_read_req(read_req),.block_write_req(1'b0),
        .block_write_data(8'd0),.spi_wr_req(spi_req),.spi_wr_ack(spi_ack),.spi_data_out(spi_out));
    always @(negedge clk)begin
        spi_ack=0;
        if(spi_req&&phase==0)begin
            phase=1;spi_out=8'hff;
            if(dut.state==dut.S_CMD)begin
                if(dut.byte_cnt<6)spi_out=0;
                else if(dut.byte_cnt==7)spi_out=r1;
            end
            if(dut.state==dut.S_CMD_DATA)
                spi_out=reply>>((3-dut.byte_cnt)*8);
        end else if(phase==1)begin spi_ack=1;phase=2;end
        else if(phase==2)phase=0;
    end
    task fail;input [8*80-1:0] message;begin
        $display("TEST_FAIL tb_sd_response %0s r1=%h data=%h",message,actual_r1,actual_data);$finish;
    end endtask
    initial begin
        repeat(4)@(posedge clk);#1;rst=0;req=1;
        wait(done);#1;
        if(error||actual_r1!=1||actual_data!=reply)fail("R7 response bytes or early R1");
        req=0;repeat(5)@(posedge clk);#1;
        reply=32'hc0ff8000;cmd={8'd58,32'd0,8'hff};req=1;
        wait(done);#1;
        if(error||actual_data!=reply)fail("OCR response order");
        req=0;repeat(5)@(posedge clk);#1;r1=5;req=1;
        wait(done);#1;if(!error||actual_r1!=5)fail("illegal-command response lost");
        req=0;repeat(5)@(posedge clk);#1;read_req=1;
        wait(error);#1;read_req=0;
        if(dut.nCS_ctrl!=1)fail("token timeout did not release chip select");
        repeat(5)@(posedge clk);
        $display("TEST_PASS tb_sd_response command-byte isolation, R7/OCR, illegal response and token timeout");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
