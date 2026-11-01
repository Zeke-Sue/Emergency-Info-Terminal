`timescale 1ns/1ps
module tb_official_fft512;
    reg clk=0,rst=1,start=0,din_en=0;
    reg [15:0] din_re=0;
    wire done,busy,dout_en;
    wire [24:0] dout_re,dout_im;
    integer i,output_count,max_index;
    reg [25:0] max_magnitude;
    reg signed [24:0] signed_re,signed_im;
    reg [24:0] abs_re,abs_im;
    reg [25:0] magnitude;
    real angle;

    always #5 clk=~clk;

    fft dut(.clk(clk),.rst(rst),.mode(1'b0),.start(start),
        .din_en(din_en),.din_re(din_re),.din_im(16'd0),
        .done(done),.busy(busy),.dout_en(dout_en),
        .dout_re(dout_re),.dout_im(dout_im));

    task fail;
        input [8*120-1:0] reason;
        begin
            $display("TEST_FAIL tb_official_fft512: %0s",reason);
            $finish;
        end
    endtask

    always @(negedge clk)if(dout_en)begin
        signed_re=dout_re;signed_im=dout_im;
        abs_re=signed_re<0 ? -signed_re : signed_re;
        abs_im=signed_im<0 ? -signed_im : signed_im;
        magnitude=abs_re+abs_im;
        if(output_count<=256 && magnitude>max_magnitude)begin
            max_magnitude=magnitude;max_index=output_count;
        end
        output_count=output_count+1;
    end

    initial begin
        output_count=0;max_index=-1;max_magnitude=0;
        repeat(4)@(negedge clk);rst=0;
        for(i=0;i<512;i=i+1)begin
            angle=6.283185307179586*32.0*i/512.0;
            @(negedge clk);
            start=i==0;din_en=1;
            din_re=$rtoi(12000.0*$sin(angle));
        end
        @(negedge clk);start=0;din_en=0;din_re=0;
        wait(done);
        wait(output_count==512);repeat(2)@(negedge clk);
        if(output_count!=512)begin
            $display("outputs=%0d max_index=%0d magnitude=%0d",
                output_count,max_index,max_magnitude);
            fail("official core did not emit exactly 512 bins");
        end
        if(max_index!=32)begin
            $display("max_index=%0d magnitude=%0d",max_index,max_magnitude);
            fail("official core output order or bin position mismatch");
        end
        $display("TEST_PASS tb_official_fft512 legacy Anlogic area core, 512 outputs, natural-order bin-32 peak");
        $finish;
    end

    initial begin
        #2000000;fail("timeout");
    end
endmodule
