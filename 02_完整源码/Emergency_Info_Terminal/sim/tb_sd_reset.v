`timescale 1ns/1ps
module tb_sd_reset;
    reg clk=0,rst=1;
    always #10 clk=~clk;
    wire init_done,cmd_req,block_read_req,block_write_req;
    wire [15:0] clk_div,cmd_data_len;
    wire [47:0] cmd;
    wire [7:0] cmd_r1;
    sd_card_sec_read_write #(.SPI_LOW_SPEED_DIV(123),.SPI_HIGH_SPEED_DIV(0)) dut(
        .clk(clk),.rst(rst),.sd_init_done(init_done),
        .sd_sec_read(1'b0),.sd_sec_read_addr(32'd0),
        .sd_sec_read_data(),.sd_sec_read_data_valid(),.sd_sec_read_end(),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),
        .sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end(),
        .spi_clk_div(clk_div),.cmd_req(cmd_req),.cmd_req_ack(1'b0),
        .cmd_req_error(1'b0),.cmd(cmd),.cmd_r1(cmd_r1),
        .cmd_data_len(cmd_data_len),.block_read_req(block_read_req),
        .block_read_valid(1'b0),.block_read_data(8'd0),.block_read_req_ack(1'b0),
        .block_write_req(block_write_req),.block_write_data(),
        .block_write_data_rd(1'b0),.block_write_req_ack(1'b0));
    task fail;
        input [511:0] reason;
        begin $display("TEST_FAIL tb_sd_reset %0s",reason);$finish;end
    endtask
    initial begin
        repeat(3)@(negedge clk);
        if(cmd_req || init_done || clk_div!=123)fail("power-on reset outputs");
        rst=0;repeat(3)@(negedge clk);
        if(!cmd_req || cmd[47:40]!=0 || cmd[7:0]!=8'h95 || cmd_r1!=8'h01)
            fail("CMD0 request after reset release");
        rst=1;repeat(2)@(negedge clk);
        if(cmd_req || init_done || cmd!=0 || block_read_req || block_write_req)
            fail("synchronous reset did not clear command state");
        rst=0;repeat(3)@(negedge clk);
        if(!cmd_req || cmd[47:40]!=0)fail("CMD0 did not restart after reset");
        $display("TEST_PASS tb_sd_reset synchronous SD command reset and CMD0 restart");$finish;
    end
endmodule
