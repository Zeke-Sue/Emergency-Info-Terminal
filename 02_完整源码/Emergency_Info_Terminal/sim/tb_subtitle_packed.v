`timescale 1ns/1ps
module tb_subtitle_packed;
    reg clk=0;
    always #5 clk=~clk;
    reg [14:0] address;
    reg [3:0] original[0:8191];
    wire pixel;
    integer i;
    subtitle_bitmap_rom dut(.clk(clk),.subtitle_slot(address[14:11]),
        .row(address[10:7]),.pixel_x(address[6:0]),.pixel(pixel));
    initial begin
        $readmemh("../../rtl/subtitle_bitmap.mem",original);
        for(i=0;i<32768;i=i+1)begin
            @(negedge clk);address=i;
            @(posedge clk);#1;
            if(pixel !== ((original[i>>2]>>(3-(i&3)))&1))begin
                $display("TEST_FAIL subtitle pixel %0d",i);$finish;
            end
        end
        $display("TEST_PASS all 32768 subtitle pixels and consecutive-cycle latency");$finish;
    end
endmodule
