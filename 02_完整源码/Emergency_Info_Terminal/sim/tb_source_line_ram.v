`timescale 1ns/1ps
module tb_source_line_ram;
    reg clk=0;
    reg write_enable=0;
    reg [10:0] write_addr=0,read_addr=0;
    reg [23:0] write_data=0;
    wire [23:0] read_data;
    integer i;

    always #5 clk=~clk;

    source_line_ram dut(.clk(clk),.write_enable(write_enable),
        .write_addr(write_addr),.write_data(write_data),
        .read_addr(read_addr),.read_data(read_data));

    function [23:0] pattern;
        input [10:0] address;
        begin
            pattern={address[7:0]^8'ha5,address[10:3],
                address[7:0]+8'h31};
        end
    endfunction

    task fail;
        input [8*120-1:0] reason;
        begin
            $display("TEST_FAIL tb_source_line_ram: %0s",reason);
            $finish;
        end
    endtask

    initial begin
        for(i=0;i<2048;i=i+1)begin
            @(negedge clk);
            write_enable=1;write_addr=i[10:0];write_data=pattern(i[10:0]);
        end
        @(negedge clk);write_enable=0;

        for(i=0;i<2048;i=i+1)begin
            @(negedge clk);read_addr=i[10:0];
            @(posedge clk);#1;
            if(read_data!==pattern(i[10:0]))begin
                $display("address=%0d got=%h expected=%h",i,read_data,
                    pattern(i[10:0]));
                fail("2048 x 24 readback mismatch");
            end
        end
        $display("TEST_PASS tb_source_line_ram native 2048x16 + 2048x8 BRAM split and full-address readback");
        $finish;
    end
endmodule
