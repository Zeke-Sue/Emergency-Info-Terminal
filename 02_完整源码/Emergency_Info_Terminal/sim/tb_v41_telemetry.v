`timescale 1ns/1ps
module tb_v41_telemetry;
    reg clk=0,rst=1,clear=0,line_start=0,line_end=0,busy=0;
    reg vu=0,au=0,ce=0,fe=0,cache=0,tf=0;integer k;
    wire [15:0] last_cycles,max_cycles;wire [31:0] vuc,auc,cec,fec,cachec,tfc;
    always #5 clk=~clk;
    v41_telemetry_monitor dut(.clk(clk),.rst(rst),.clear_stats(clear),
        .line_start(line_start),.line_end(line_end),.sdram_busy(busy),
        .video_underflow(vu),.audio_underflow(au),.uart_crc_error(ce),
        .uart_frame_error(fe),.cache_error(cache),.tf_error(tf),
        .last_line_cycles(last_cycles),.max_line_cycles(max_cycles),
        .video_underflow_count(vuc),.audio_underflow_count(auc),
        .uart_crc_error_count(cec),.uart_frame_error_count(fec),
        .cache_error_count(cachec),.tf_error_count(tfc));
    task fail;input [8*80-1:0] msg;begin $display("TEST_FAIL tb_v41_telemetry: %0s",msg);$finish;end endtask
    task run_line;input integer cycles;begin
        @(negedge clk);line_start=1;@(negedge clk);line_start=0;busy=1;
        for(k=0;k<cycles;k=k+1)@(negedge clk);
        busy=0;line_end=1;@(negedge clk);line_end=0;#1;
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;run_line(5);
        if(last_cycles!=5||max_cycles!=5)fail("first line accounting");
        run_line(3);if(last_cycles!=3||max_cycles!=5)fail("maximum preservation");
        @(negedge clk);vu=1;au=1;ce=1;fe=1;cache=1;tf=1;
        @(negedge clk);vu=0;au=0;ce=0;fe=0;cache=0;tf=0;#1;
        if(vuc!=1||auc!=1||cec!=1||fec!=1||cachec!=1||tfc!=1)fail("event counters");
        @(negedge clk);clear=1;@(negedge clk);clear=0;#1;
        if(max_cycles!=0||vuc!=0||tfc!=0)fail("clear stats");
        $display("TEST_PASS tb_v41_telemetry per-line SDRAM maximum and persistent fault counters");$finish;
    end
endmodule
