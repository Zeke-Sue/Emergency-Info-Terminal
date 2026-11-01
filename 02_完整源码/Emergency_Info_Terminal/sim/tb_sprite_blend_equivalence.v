`timescale 1ns/1ps
module tb_sprite_blend_equivalence;
    reg clk=0;
    always #5 clk=~clk;
    demo_sprite_overlay dut(.clk(clk),.rst(1'b1),.frame_tick(1'b0),.enable(1'b0),
        .x(11'd0),.y(11'd0),.rgb_in(24'd0),.rgb_out());
    integer base,front,weight,expected,cases=0;
    initial begin
        for(weight=0;weight<=16;weight=weight+1)
            for(base=0;base<256;base=base+1)for(front=0;front<256;front=front+1)begin
                expected=(base*(16-weight)+front*weight+8)>>4;
                if(dut.blend(base,front*weight,16-weight)!==expected[7:0])
                    $fatal(1,"sprite blend mismatch base=%d front=%d weight=%d",base,front,weight);
                if(weight<16)begin
                    expected=weight<=4 ? base : weight>=12 ? front : (base+front+1)>>1;
                    if(dut.half_blend(base,front,weight)!==expected[7:0])
                        $fatal(1,"compact sprite blend mismatch");
                end
                cases=cases+1;
            end
        $display("TEST_PASS sprite single-multiplier blend: %0d exact input combinations",cases);$finish;
    end
endmodule
