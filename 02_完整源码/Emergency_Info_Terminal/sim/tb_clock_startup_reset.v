`timescale 1ns/1ps
module tb_clock_startup_reset;
    reg sys_clk=0,pixel_clk=0,fast_clk=0,reset=1,fast_reset=1,fast_run=1;
    always #10 sys_clk=~sys_clk;
    always #20 pixel_clk=~pixel_clk;
    always #5 if(fast_run)fast_clk=~fast_clk;
    wire sys_reset,pixel_reset,short_reset;
    clock_startup_reset #(.SETTLE_BITS(20)) sys_dut(.clk(sys_clk),.async_reset(reset),.reset_out(sys_reset));
    clock_startup_reset #(.SETTLE_BITS(19)) pixel_dut(.clk(pixel_clk),.async_reset(reset),.reset_out(pixel_reset));
    clock_startup_reset #(.SETTLE_BITS(4)) short_dut(.clk(fast_clk),.async_reset(fast_reset),.reset_out(short_reset));
    integer sys_cycles=0,pixel_cycles=0,n,phase;
    always @(posedge sys_clk)if(!reset)sys_cycles=sys_cycles+1;
    always @(posedge pixel_clk)if(!reset)pixel_cycles=pixel_cycles+1;
    reg sys_done=0,pixel_done=0,short_done=0;
    always @(negedge sys_reset)begin
        if(sys_clk!==0||sys_cycles!=1048578)$fatal(1,"system settle duration/release edge: %0d",sys_cycles);
        sys_done=1;
    end
    always @(negedge pixel_reset)begin
        if(pixel_clk!==0||pixel_cycles!=524290)$fatal(1,"pixel settle duration/release edge: %0d",pixel_cycles);
        pixel_done=1;
    end
    initial begin #2;reset=0;end
    initial begin
        for(phase=0;phase<5;phase=phase+1)begin
            @(negedge fast_clk);#1;fast_reset=1;#1;
            if(!short_reset)$fatal(1,"asynchronous assertion missing");
            @(negedge fast_clk);#(phase+0.25);fast_reset=0;
            for(n=0;n<16;n=n+1)begin
                @(posedge fast_clk);#1;
                if(!short_reset)$fatal(1,"settle hold ended early");
            end
            repeat(2)begin @(negedge fast_clk);#1;if(!short_reset)$fatal(1,"release pipeline too short");end
            @(negedge fast_clk);#1;if(short_reset)$fatal(1,"release did not finish");
        end

        @(negedge fast_clk);#1;fast_run=0;#2;fast_reset=1;#1;
        if(!short_reset)$fatal(1,"clock-stopped reset assertion failed");
        #20;fast_run=1;
        @(negedge fast_clk);#1;fast_reset=0;
        repeat(7)@(posedge fast_clk);
        #2;fast_reset=1;#2;fast_reset=0;
        repeat(15)begin @(posedge fast_clk);#1;if(!short_reset)$fatal(1,"re-lock did not restart full hold");end
        wait(!short_reset);short_done=1;
    end
    initial begin
        wait(sys_done&&pixel_done&&short_done);
        $display("TEST_PASS registered PLL settle: full 20/19-bit waits, falling-edge release, asynchronous loss and re-lock restart");
        $finish;
    end
    initial begin #22000000;$fatal(1,"startup reset timeout");end
endmodule
