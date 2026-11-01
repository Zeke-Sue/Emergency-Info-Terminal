`timescale 1ns/1ps
module tb_frame_parameter_smoother;
    reg clk=0,rst=1,tick=0;
    always #5 clk=~clk;
    reg signed [8:0] target=0;
    wire signed [8:0] value;
    wire busy;
    integer i,j,start_value,goal,expected;
    frame_parameter_smoother dut(.clk(clk),.rst(rst),.frame_tick(tick),
        .target(target),.value(value),.busy(busy));
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(j=0;j<100;j=j+1)begin
            start_value=value;goal=(j*79)%512-256;target=goal;
            repeat(3)@(negedge clk);
            if(value!=start_value)begin $display("TEST_FAIL non-frame update");$finish;end
            for(i=1;i<=32;i=i+1)begin
                tick=1;@(negedge clk);tick=0;@(negedge clk);
                expected=(start_value*32+(goal-start_value)*i)>>>5;
                if(value!=expected)begin
                    $display("TEST_FAIL DDA frame=%0d got=%0d expected=%0d",i,value,expected);$finish;
                end
            end
            if(busy || value!=goal)begin $display("TEST_FAIL DDA final");$finish;end
        end
        $display("TEST_PASS 3200 signed 32-frame smoothing commits");$finish;
    end
endmodule
