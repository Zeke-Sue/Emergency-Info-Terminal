`timescale 1ns/1ps
module tb_quality_multiplier_equivalence;
    reg clk=0,rst=1,frame_tick=0,valid=0,bypass=0,auto_contrast=1;
    always #5 clk=~clk;
    reg [23:0] rgb=0;
    reg signed [8:0] brightness=0;
    reg [7:0] contrast=128;
    reg [1:0] gamma=1,temperature=1;
    wire [23:0] actual,reference;
    wire ready,old_ready;
    wire [7:0] low,high,old_low,old_high;
    reg [31:0] random_state=32'h51a9c20d;
    integer frames=0,pixels=0,i,f,cycles,max_cycles=0;
    image_quality_engine dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .pixel_valid(valid),.enable(1'b1),.alarm_bypass(bypass),.rgb_in(rgb),
        .histogram_rgb(24'd0),.histogram_valid(1'b0),.target_brightness(brightness),
        .target_contrast_q7(contrast),.gamma_mode(gamma),.temperature_mode(temperature),
        .auto_contrast_enable(auto_contrast),.histogram_query(8'd0),.histogram_column(6'd0),
        .histogram_value(),.histogram_column_value(),.low_cut(low),.high_cut(high),
        .lut_ready(ready),.rgb_out(actual));
    image_quality_engine_reference old(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .pixel_valid(valid),.enable(1'b1),.alarm_bypass(bypass),.rgb_in(rgb),
        .histogram_rgb(24'd0),.histogram_valid(1'b0),.target_brightness(brightness),
        .target_contrast_q7(contrast),.gamma_mode(gamma),.temperature_mode(temperature),
        .auto_contrast_enable(auto_contrast),.histogram_query(8'd0),.histogram_column(6'd0),
        .histogram_value(),.histogram_column_value(),.low_cut(old_low),.high_cut(old_high),
        .lut_ready(old_ready),.rgb_out(reference));
    task fail;input [8*100-1:0] reason;begin
        $display("TEST_FAIL shared quality multiply: %0s frame=%0d pixel=%0d actual=%h reference=%h",
            reason,frames,pixels,actual,reference);$finish;
    end endtask
    always @(posedge clk)begin
        #1;
        if(!rst && frames!=0 && actual!==reference)fail("pixel changed");
    end
    task randomize;begin
        random_state=random_state^(random_state<<13);
        random_state=random_state^(random_state>>17);
        random_state=random_state^(random_state<<5);
    end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;wait(ready&&old_ready);
        for(f=0;f<1024;f=f+1)begin
            @(negedge clk);randomize();brightness=random_state[8:0];contrast=random_state[16:9];
            gamma=random_state[18:17];temperature=random_state[20:19];auto_contrast=random_state[21];
            for(i=0;i<256;i=i+1)begin
                randomize();rgb=random_state[23:0];valid=1;pixels=pixels+1;
                @(negedge clk);
            end
            valid=0;repeat(3)@(negedge clk);frame_tick=1;
            @(negedge clk);frame_tick=0;frames=frames+1;cycles=0;
            while(!ready||!old_ready)begin
                randomize();rgb=random_state[23:0];bypass=random_state[24];
                @(negedge clk);cycles=cycles+1;
                if(cycles>1400)fail("blanking calculation deadline");
            end
            if(cycles>max_cycles)max_cycles=cycles;
            bypass=0;
            if(low!==old_low||high!==old_high)fail("histogram cut changed");
        end
        $display("TEST_PASS shared quality multiply %0d frames %0d pixels exact, maximum build %0d clocks",frames,pixels,max_cycles);
        $finish;
    end
    initial begin #30000000;fail("bounded timeout");end
endmodule
