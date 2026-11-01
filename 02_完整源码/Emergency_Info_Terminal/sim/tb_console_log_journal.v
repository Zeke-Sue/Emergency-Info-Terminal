`timescale 1ns/1ps
module tb_console_log_journal;
    reg clk=0,rst=1,append=0,ready=1,program_done=0,restore_valid=0;
    always #5 clk=~clk;
    wire append_ready,pvalid,committed;wire [23:0] address;wire [7:0] pdata;
    wire [15:0] next_sequence;wire [7:0] slot;
    reg [7:0] captured [0:35];integer count=0,k;
    console_log_journal dut(.clk(clk),.rst(rst),.append_valid(append),
        .append_ready(append_ready),.category(2'd2),.flags(6'h15),.b_boot(16'h1234),
        .b_ms(32'h01020304),.a_boot(32'h11223344),.a_us(32'h55667788),
        .event_type(8'h92),.payload(56'h01020304050607),.program_valid(pvalid),
        .program_ready(ready),.program_address(address),.program_data(pdata),
        .program_done(program_done),.program_error(1'b0),
        .restore_valid(restore_valid),.restore_next_sequence(16'd0),
        .restore_write_slot(8'd0),.committed_pulse(committed),
        .next_sequence(next_sequence),.write_slot(slot),.failed_pulse());
    reg vstart=0,vbyte=0,vfinish=0;reg [7:0] vdata=0;
    wire vdone,vok;wire [15:0] vseq;
    console_log_record_validator validator(.clk(clk),.rst(rst),.start(vstart),
        .byte_valid(vbyte),.byte_data(vdata),.finish(vfinish),.done(vdone),
        .record_valid(vok),.sequence(vseq));
    always @(posedge clk)begin
        program_done<=0;
        if(pvalid&&ready)begin
            captured[count]=pdata;count=count+1;
            if(count==36)program_done<=1;
        end
    end
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tb_console_log_journal: %0s",msg);$finish;end endtask
    task validate_capture;input integer corrupt;begin
        @(negedge clk);vstart=1;@(negedge clk);vstart=0;
        for(k=0;k<36;k=k+1)begin
            @(negedge clk);vdata=captured[k]^(corrupt&&k==10 ? 8'h01 : 8'h00);vbyte=1;
            @(negedge clk);vbyte=0;
        end
        @(negedge clk);vfinish=1;@(negedge clk);vfinish=0;#1;
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        @(negedge clk);restore_valid=1;@(negedge clk);restore_valid=0;
        @(negedge clk);append=1;
        @(negedge clk);append=0;wait(committed);#1;
        if(count!=36||captured[0]!=8'h4c||captured[1]!=8'h47||
           captured[32]!=8'h43||captured[35]!=8'h54)
            fail("record layout or commit order");
        if(next_sequence!=1||slot!=1)fail("journal advance");
        validate_capture(0);if(!vdone||!vok||vseq!=0)fail("valid record recovery");
        validate_capture(1);if(!vdone||vok)fail("corrupt record accepted");
        $display("TEST_PASS tb_console_log_journal CRC32, commit-last and recovery rejection");
        $finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
