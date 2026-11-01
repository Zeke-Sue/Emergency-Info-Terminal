`timescale 1ns/1ps
module tb_test_tone_40k;
    reg clk=0,rst=1,enable=0;
    always #20 clk=~clk;
    wire tick,native_valid,underflow,overflow;
    wire signed [15:0] native_sample,converted;
    global_timebase rate(.clk(clk),.rst(rst),.sample_tick(tick));
    test_tone_40k dut(.clk(clk),.rst(rst),.enable(enable),.output_tick(tick),
        .native_valid(native_valid),.native_sample(native_sample),.output_sample(converted),
        .underflow(underflow),.overflow(overflow));
    integer cycles,native_count=0,output_count=0,expected,error,last_native_cycle=0;
    integer max_error=0;
    reg check_output;
    initial begin
        repeat(4)@(negedge clk);rst=0;enable=1;
        for(cycles=1;cycles<=2500000;cycles=cycles+1)begin
            @(posedge clk);check_output=dut.step;#1;
            if(native_valid)begin
                if(last_native_cycle!=0&&cycles-last_native_cycle!=625)$fatal(1,"native rate is not 40kHz");
                last_native_cycle=cycles;
                expected=$rtoi(4096.0*$sin(6.283185307179586*(native_count%40)/40.0));
                error=$signed(native_sample)-expected;if(error<0)error=-error;
                if(error>2)$fatal(1,"native sine sample mismatch");
                native_count=native_count+1;
            end
            if(check_output)begin
                expected=$rtoi(4096.0*$sin(6.283185307179586*(output_count%48)/48.0));
                error=$signed(converted)-expected;if(error<0)error=-error;
                if(error>max_error)max_error=error;
                if(error>16)$fatal(1,"resampled pitch/phase/amplitude mismatch n=%0d got=%0d expected=%0d",output_count,converted,expected);
                output_count=output_count+1;
            end
            if(underflow||overflow)$fatal(1,"diagnostic resampler FIFO fault");
            @(negedge clk);
        end
        if(native_count!=4000||output_count<4790||output_count>4800)$fatal(1,"sample counts %0d/%0d",native_count,output_count);
        enable=0;repeat(3)@(negedge clk);
        if(converted!=0||native_valid||dut.count!=0)$fatal(1,"disable failed to clear tone");
        enable=1;repeat(25000)@(negedge clk);
        if(underflow||overflow||!dut.started)$fatal(1,"restart failed");
        $display("TEST_PASS native 40kHz / HDMI 48kHz, 1kHz pitch, interpolation error <= %0d LSB, stop/restart",max_error);$finish;
    end
    initial begin #120000000;$fatal(1,"tone timeout");end
endmodule
