`timescale 1ns/1ps
module tb_waveform_capture;
    reg clk=0,rst=1,frame=0,valid=0;
    always #5 clk=~clk;
    reg signed [15:0] sample=0;
    reg [6:0] address=0;
    wire [15:0] data;
    wire ready;
    integer n;
    audio_waveform_capture dut(.clk(clk),.rst(rst),.frame_tick(frame),
        .sample_valid(valid),.sample(sample),.read_index(address),.read_sample(data),.ready(ready));
    task put;input signed [15:0] value;begin
        sample=value;valid=1;@(negedge clk);valid=0;@(negedge clk);
    end endtask
    task publish;begin frame=1;@(negedge clk);frame=0;@(negedge clk);end endtask
    task expect;input [6:0] index;input [15:0] value;begin
        address=index;@(negedge clk);@(negedge clk);
        if(data!==value)$fatal(1,"scope sample %0d = %0d expected %0d",index,data,value);
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        put(-16'sd1);
        for(n=0;n<128;n=n+1)put(n*16);
        if(ready)$fatal(1,"scope changed before frame boundary");
        publish();if(!ready)$fatal(1,"scope never ready");
        expect(0,0);expect(64,1024);expect(127,2032);
        put(-16'sd1);
        for(n=0;n<128;n=n+1)begin put(n*32);expect(64,1024);end
        expect(127,2032);publish();expect(64,2048);expect(127,4064);

        for(n=0;n<400;n=n+1)put(0);
        publish();expect(0,0);expect(127,0);
        $display("TEST_PASS stable frame waveform, upward trigger, real sample RAM, silence timeout");$finish;
    end
    initial begin #100000;$fatal(1,"scope timeout");end
endmodule
