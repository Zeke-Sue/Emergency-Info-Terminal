`timescale 1ns/1ps
module tb_status_display;
    reg clk=0,rst=1,autoplay=1,ready=1;
    always #5 clk=~clk;
    reg [15:0] scene=0;
    reg [3:0] error=0;
    reg [5:0] period=10;
    wire [5:0] select;
    wire [7:0] segments;
    status_display #(.TEST_STATUS(1)) dut(.clk(clk),.rst(rst),
        .test_status(scene),.image_index(4'd3),.image_count(5'd16),
        .autoplay(autoplay),.ready(ready),.period_seconds(period),.error_code(error),
        .seg_sel(select),.seg_data(segments));
    reg [7:0] expected[0:5];
    reg [7:0] error_segments[0:11];
    integer n,e;
    task check_frame;
        begin
            wait(select==6'b111110);
            for(n=0;n<6;n=n+1)begin
                wait(select==~(6'b000001<<n));#1;
                if(segments!==expected[n])$fatal(1,"digit %0d got %h expected %h",n,segments,expected[n]);
                wait(select!=~(6'b000001<<n));
            end
        end
    endtask
    initial begin
        error_segments[0]=8'hc6; error_segments[1]=8'hf9;
        error_segments[2]=8'ha4; error_segments[3]=8'hb0;
        error_segments[4]=8'h99; error_segments[5]=8'h92;
        error_segments[6]=8'h82; error_segments[7]=8'hf8;
        error_segments[8]=8'h80; error_segments[9]=8'h90;
        error_segments[10]=8'h88; error_segments[11]=8'h83;
        repeat(4)@(negedge clk);rst=0;

        expected[0]=8'hc0;expected[1]=8'hf9;expected[2]=8'h88;
        expected[3]=8'hb0;expected[4]=8'h8e;expected[5]=8'hc6;
        check_frame();
        period=1;expected[0]=8'hf9;expected[1]=8'hc0;check_frame();
        period=2;expected[0]=8'ha4;check_frame();
        period=5;expected[0]=8'h92;check_frame();

        for(e=1;e<=11;e=e+1)begin error=e;expected[5]=error_segments[e];check_frame();end

        scene=16'hc003;
        expected[0]=8'h86;expected[1]=8'hc0;expected[2]=8'h99;
        expected[3]=8'hc0;expected[4]=8'hf9;
        for(e=0;e<=11;e=e+1)begin error=e;expected[5]=error_segments[e];check_frame();end
        scene=0;error=0;autoplay=0;ready=0;period=5;
        expected[0]=8'h92;expected[1]=8'hc0;expected[2]=8'h83;
        expected[3]=8'hc0;expected[4]=8'h8e;expected[5]=8'hc6;
        check_frame();
        $display("TEST_PASS production status: slideshow, paused/not-ready, scene and all 11 fault codes");$finish;
    end
    initial begin #60000000;$fatal(1,"display timeout");end
endmodule
