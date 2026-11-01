`timescale 1ns/1ps
module tb_stft_512;
    reg clk=0,rst=1,sample_tick=0;always #5 clk=~clk;
    reg [8:0] phase=0;wire signed [15:0] sine;reg signed [15:0] sample_in=0;
    sine_quarter_rom source(.phase(phase),.value(sine));
    wire spectrum_valid,done,busy;wire [5:0] bin;wire [15:0] magnitude;wire [23:0] peak_q8;
    stft_512_serial dut(.clk(clk),.rst(rst),.sample_tick(sample_tick),.sample_in(sample_in),
        .spectrum_valid(spectrum_valid),.spectrum_bin(bin),.spectrum_magnitude(magnitude),
        .transform_done(done),.peak_frequency_q8(peak_q8),.busy(busy));
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_stft_512: %0s",reason);$finish;end endtask
    integer i;integer phase_remainder;integer hz;
    initial begin
        repeat(3)@(negedge clk);rst=0;phase_remainder=0;
        for(i=0;i<512;i=i+1)begin
            @(negedge clk);sample_in=sine>>>1;sample_tick=1;
            phase_remainder=phase_remainder+32;
            if(phase_remainder>=48)begin phase<=phase+11;phase_remainder=phase_remainder-48;end else phase<=phase+10;
            @(negedge clk);sample_tick=0;
        end
        wait(done);#1;hz=peak_q8>>8;
        if(hz<990||hz>1010)begin $display("peak=%0d.%0d Hz",hz,((peak_q8&255)*100)/256);fail("1 kHz peak interpolation");end
        $display("TEST_PASS tb_stft_512 512-point Hann STFT 1 kHz peak=%0d.%0d Hz",hz,((peak_q8&255)*100)/256);$finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
