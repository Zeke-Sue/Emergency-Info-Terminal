`timescale 1ns/1ps
module tb_audio_output_stage #(parameter SATURATING_FLAGS=0);
    reg clk=0,rst=1,valid=0,mute=0;
    reg signed [17:0] sample=16384;
    reg [2:0] level=7;
    wire out_valid,overrun;wire signed [15:0] out_sample;
    wire [15:0] peak;wire [31:0] limited,clipped;
    integer i,j,previous,expected,cycles,outputs=0;
    always #5 clk=~clk;
    audio_output_stage #(.SATURATING_FLAGS(SATURATING_FLAGS)) dut(.clk(clk),.rst(rst),.sample_valid(valid),
        .sample_in(sample),.volume_level(level),.mute(mute),
        .output_valid(out_valid),.sample_out(out_sample),.peak_absolute(peak),
        .limited_count(limited),.clipped_count(clipped),.overrun(overrun));
    task fail;input [8*100-1:0] message;begin
        $display("TEST_FAIL tb_audio_output_stage %0s",message);$finish;
    end endtask
    task tick;begin
        @(negedge clk);valid=1;@(negedge clk);valid=0;cycles=0;
        while(!out_valid)begin @(negedge clk);cycles=cycles+1;if(cycles>20)fail("output deadline");end
        if(cycles!=16)fail("sample latency changed during ramp");
        outputs=outputs+1;
        @(negedge clk);if(out_valid)fail("valid wider than one clock");
    end endtask
    function integer gain_for;input integer n;begin
        case(n)0:gain_for=91;1:gain_for=129;2:gain_for=182;3:gain_for=257;
            4:gain_for=363;5:gain_for=513;6:gain_for=725;default:gain_for=1024;endcase
    end endfunction
    initial begin
        repeat(3)@(negedge clk);rst=0;previous=0;
        for(i=1;i<=240;i=i+1)begin
            tick();expected=((1024*i)/240)*16;
            if(out_sample!==expected)fail("startup is not a 240-sample linear ramp");
            if(out_sample<previous)fail("nonmonotonic startup");previous=out_sample;
        end
        for(j=0;j<8;j=j+1)begin
            level=j;repeat(240)tick();
            if(out_sample!=gain_for(j)*16)fail("3dB gain table");
        end
        sample=32767;tick();if(out_sample!=26623||limited!=1||clipped!=0)
            fail("positive soft knee");
        sample=-32768;tick();if(out_sample!=-26624||limited!=(SATURATING_FLAGS ? 1 : 2)||clipped!=0)
            fail("negative soft knee");
        sample=131071;tick();if(out_sample!=32767||clipped!=1||peak!=32767)
            fail("hard saturation or actual output peak");
        sample=-131072;tick();if(out_sample!=-32767||clipped!=(SATURATING_FLAGS ? 1 : 2))
            fail("negative saturation");
        sample=16384;mute=1;
        repeat(240)tick();if(out_sample!=0||dut.gain!=0)fail("five millisecond mute ramp");
        if(overrun)fail("unexpected overrun");
        @(negedge clk);valid=1;repeat(4)@(negedge clk);valid=0;
        if(!overrun)fail("overrun not detected");
        $display("TEST_PASS tb_audio_output_stage 8 gains, 240-sample ramps, signed soft knee, counters and valid alignment");$finish;
    end
    initial begin #10000000;fail("timeout");end
endmodule
