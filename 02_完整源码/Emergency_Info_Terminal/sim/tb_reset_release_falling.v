`timescale 1ns/1ps
module tb_reset_release_falling;
    reg clk=0,async_reset=1;
    always #10 clk=~clk;
    wire reset_out;
    reset_release_falling dut(.clk(clk),.async_reset(async_reset),.reset_out(reset_out));
    integer phase,n;
    time last_release=0;
    reg [7:0] counter=0;
    always @(posedge clk or posedge reset_out)
        if(reset_out)counter<=0;else counter<=counter+1'b1;
    task fail;
        input [511:0] why;
        begin $display("TEST_FAIL reset release: %0s",why);$finish;end
    endtask
    always @(negedge reset_out)begin
        if(clk!==0||$time%20!=0)fail("release not on falling edge");
        last_release=$time;
    end
    initial begin
        #1;if(reset_out!==1)fail("initial reset assertion");
        for(phase=0;phase<20;phase=phase+1)begin
            @(posedge clk);#1;async_reset=1;#1;
            if(!reset_out||counter!=0)fail("asynchronous assertion");
            @(negedge clk);#(phase+1);async_reset=0;
            for(n=0;n<3;n=n+1)begin
                @(negedge clk);#1;
                if(reset_out!==(n<2))fail("release stage count");
            end
            @(posedge clk);#1;
            if($time-last_release!=11||counter!=1)fail("consumer recovery separation");
        end

        @(negedge clk);#3;async_reset=1;#2;async_reset=0;
        @(negedge clk);#3;async_reset=1;#2;async_reset=0;
        repeat(2)begin @(negedge clk);#1;if(!reset_out)fail("early release after reassertion");end
        @(negedge clk);#1;if(reset_out)fail("release after reassertion");
        $display("TEST_PASS falling-edge reset release: all assertion phases, 3 stages, half-cycle recovery, restart");
        $finish;
    end
endmodule
