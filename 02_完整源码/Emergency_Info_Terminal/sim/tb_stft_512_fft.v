`timescale 1ns/1ps
module tb_stft_512_fft;
    reg clk=0,rst=1,sample_tick=0;
    reg signed [15:0] sample_in=0;
    wire spectrum_valid,done,busy;
    wire [5:0] bin;wire [15:0] magnitude;wire [23:0] peak_q8;
    integer i,hz,spectrum_count;
    real angle;
    always #5 clk=~clk;

    stft_512_fft dut(.clk(clk),.rst(rst),.sample_tick(sample_tick),
        .sample_in(sample_in),.spectrum_valid(spectrum_valid),
        .spectrum_bin(bin),.spectrum_magnitude(magnitude),
        .transform_done(done),.peak_frequency_q8(peak_q8),.busy(busy));

    task fail;
        input [8*120-1:0] reason;
        begin $display("TEST_FAIL tb_stft_512_fft: %0s",reason);$finish;end
    endtask

    always @(posedge clk)if(spectrum_valid)spectrum_count=spectrum_count+1;

    initial begin
        spectrum_count=0;repeat(3)@(negedge clk);rst=0;
        for(i=0;i<512;i=i+1)begin
            angle=6.283185307179586*1000.0*i/48000.0;
            @(negedge clk);sample_in=$rtoi(14000.0*$sin(angle));sample_tick=1;
            @(negedge clk);sample_tick=0;
        end
        wait(done);#1;hz=peak_q8>>8;
        if(hz<990||hz>1010)begin
            $display("peak=%0d.%0d Hz",hz,((peak_q8&255)*100)/256);
            fail("1 kHz interpolated peak mismatch");
        end
        if(spectrum_count!=64)begin
            $display("spectrum_count=%0d",spectrum_count);
            fail("display spectrum must contain exactly 64 bins");
        end
        @(negedge clk);rst=1;spectrum_count=0;
        repeat(3)@(negedge clk);rst=0;
        for(i=0;i<512;i=i+1)begin
            angle=6.283185307179586*10000.0*i/48000.0;
            @(negedge clk);sample_in=$rtoi(14000.0*$sin(angle));sample_tick=1;
            @(negedge clk);sample_tick=0;
        end
        wait(done);#1;hz=peak_q8>>8;
        if(hz<9990||hz>10010)begin
            $display("high-band peak=%0d.%0d Hz",hz,
                ((peak_q8&255)*100)/256);
            fail("10 kHz full-band peak mismatch");
        end
        if(spectrum_count!=64)
            fail("high-band transform changed the 64-bin display contract");
        $display("TEST_PASS tb_stft_512_fft official FFT full 0-24 kHz single-sided analysis, 64 display bins, high-band peak=%0d.%0d Hz",
            hz,((peak_q8&255)*100)/256);
        $finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
