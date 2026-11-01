`timescale 1ns/1ps
module tb_shared_keys;
    reg clk=0,rst=1;
    reg [3:0] keys=15;
    wire [3:0] press,short_release,long_press,held;
    integer presses[0:3],shorts[0:3],longs[0:3];
    integer i,j,k;
    always #5 clk=~clk;
    key_events_shared #(.DEBOUNCE_CYCLES(4),.LONG_CYCLES(40)) dut(
        .clk(clk),.rst(rst),.key_n(keys),.press(press),
        .short_release(short_release),.long_press(long_press),.held(held));
    always @(negedge clk)for(k=0;k<4;k=k+1)begin
        if(press[k])presses[k]=presses[k]+1;
        if(short_release[k])shorts[k]=shorts[k]+1;
        if(long_press[k])longs[k]=longs[k]+1;
    end
    task fail;
        input [511:0] reason;
        begin $display("TEST_FAIL tb_shared_keys %0s",reason);$finish;end
    endtask
    initial begin
        for(i=0;i<4;i=i+1)begin presses[i]=0;shorts[i]=0;longs[i]=0;end
        repeat(3)@(negedge clk);rst=0;
        keys[0]=0;
        for(j=0;j<80;j=j+1)begin @(negedge clk);keys[1]=!keys[1];end
        if(presses[0]!=1 || longs[0]!=1 || presses[1]!=0)fail("bouncing key blocked held key");
        keys=15;repeat(12)@(negedge clk);
        if(shorts[0]!=0 || held!=0)fail("long release classified short");
        keys=0;repeat(16)@(negedge clk);keys=15;repeat(16)@(negedge clk);
        for(i=0;i<4;i=i+1)if(shorts[i]!=1)fail("simultaneous short release lost");
        $display("TEST_PASS tb_shared_keys bounce isolation, simultaneous keys, short/long classification");$finish;
    end
endmodule
