`timescale 1ns/1ps
module tb_sd_init_bounds;
    reg clk=0,rst=1,ack=0,error=0;
    reg [7:0] r1=1;
    reg [31:0] data=0;
    wire ready,failed,request;
    wire [47:0] cmd;
    integer i;
    always #5 clk=~clk;
    sd_card_sec_read_write #(.INIT_TIMEOUT_CYCLES(200)) dut(.clk(clk),.rst(rst),
        .sd_init_done(ready),.sd_init_failed(failed),.sd_sec_read(1'b0),.sd_sec_read_addr(32'd0),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
        .cmd_req(request),.cmd_req_ack(ack),.cmd_req_error(error),.cmd(cmd),
        .response_r1(r1),.response_data(data),.block_read_valid(1'b0),.block_read_data(8'd0),
        .block_read_req_ack(1'b0),.block_write_data_rd(1'b0),.block_write_req_ack(1'b0));
    task reset;
        begin rst=1;ack=0;error=0;repeat(3)@(negedge clk);rst=0;end
    endtask
    task response;
        input [7:0] opcode;input bad;input [31:0] value;
        begin wait(request&&cmd[47:40]==opcode);@(negedge clk);
            ack=1;error=bad;data=value;@(negedge clk);ack=0;error=0;
        end
    endtask
    initial begin
        reset();repeat(205)@(negedge clk);
        if(!failed||ready||request)$fatal(1,"TEST_FAIL absent-card bound");
        reset();
        for(i=0;i<4;i=i+1)begin
            response(0,1,0);
            if(i<3&&failed)$fatal(1,"TEST_FAIL premature CMD0 retry limit");
        end
        if(!failed||ready||request)$fatal(1,"TEST_FAIL CMD0 retry exhaustion");
        reset();response(0,0,0);response(8,0,32'h1aa);

        while(!failed)begin
            @(negedge clk);ack=request;error=cmd[47:40]==41;
        end
        ack=0;error=0;
        if(ready||request)$fatal(1,"TEST_FAIL ACMD41 permanent idle");
        reset();response(0,0,0);response(8,0,32'h1aa);response(55,0,0);
        response(41,0,0);response(58,0,32'hc0ff8000);
        repeat(220)@(negedge clk);
        if(!ready||failed)$fatal(1,"TEST_FAIL initialization timer affected ready card");
        $display("TEST_PASS bounded absent-card, CMD0 retries, ACMD41 idle, reset recovery");$finish;
    end
    initial begin #20000;$fatal(1,"TEST_FAIL SD init test timeout");end
endmodule
