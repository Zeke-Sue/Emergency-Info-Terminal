`timescale 1ns/1ps
module tb_quality_engine #(parameter SMOOTH_PARAMETERS=1);
    reg clk=0,rst=1,frame_tick=0,pixel_valid=0,alarm_bypass=0;always #5 clk=~clk;
    reg [23:0] rgb_in=0;reg signed [8:0] brightness=0;reg [7:0] contrast=128;reg [1:0] gamma=1,temp=1;
    reg [7:0] query=0;wire [19:0] hist;wire [7:0] low,high;wire ready;wire [23:0] rgb_out;
    reg automatic_contrast=1;
    image_quality_engine #(.FRAME_PIXELS(307200),.SMOOTH_PARAMETERS(SMOOTH_PARAMETERS)) dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .pixel_valid(pixel_valid),.enable(1'b1),.alarm_bypass(alarm_bypass),.rgb_in(rgb_in),
        .target_brightness(brightness),.target_contrast_q7(contrast),.gamma_mode(gamma),
        .temperature_mode(temp),.auto_contrast_enable(automatic_contrast),.histogram_query(query),
        .histogram_column(6'd0),.histogram_value(hist),.histogram_column_value(),
        .low_cut(low),.high_cut(high),.lut_ready(ready),.rgb_out(rgb_out));
    reg full_pixel_valid=0;reg [23:0] full_rgb=24'h404040;
    wire [19:0] full_hist;wire full_ready;
    image_quality_engine #(.FRAME_PIXELS(307200),.SEPARATE_STATS(1)) full_frame_dut(
        .clk(clk),.rst(rst),.frame_tick(1'b0),.pixel_valid(full_pixel_valid),
        .enable(1'b1),.alarm_bypass(1'b0),.rgb_in(24'hffffff),
        .histogram_rgb(full_rgb),.histogram_valid(full_pixel_valid),
        .target_brightness(9'sd0),.target_contrast_q7(8'd128),
        .gamma_mode(2'd1),.temperature_mode(2'd1),
        .auto_contrast_enable(1'b0),.histogram_query(8'd64),
        .histogram_column(6'd0),.histogram_value(full_hist),
        .histogram_column_value(),.low_cut(),.high_cut(),.lut_ready(full_ready),
        .rgb_out());
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_quality_engine: %0s",reason);$finish;end endtask
    task build_frame;
        begin
            wait(ready);@(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;
            wait(ready);@(negedge clk);
        end
    endtask
    integer i,v,g,t,f,expected,er,eb,ref_low,ref_high,ref_gain;
    real exponent;
    initial begin
        repeat(3)@(negedge clk);rst=0;wait(ready);@(negedge clk);
        for(i=0;i<200;i=i+1)begin v=50+(i>>1);@(negedge clk);rgb_in={v[7:0],v[7:0],v[7:0]};pixel_valid=1;end
        @(negedge clk);pixel_valid=0;frame_tick=1;@(negedge clk);frame_tick=0;
        wait(ready);#1;
        if(low<49||low>51||high<148||high>150)begin $display("cuts %0d..%0d",low,high);fail("0.5 percent histogram cuts");end
        rgb_in=24'h323232;repeat(2)@(posedge clk);#1;
        if(rgb_out!=24'h323232)fail("LUT became visible before frame commit");
        @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;
        ref_low=(50+3)/4;ref_high=255-(255-149+3)/4;
        ref_gain=65280/(ref_high-ref_low);
        for(v=0;v<256;v=v+1)begin
            rgb_in={3{v[7:0]}};repeat(2)@(posedge clk);#1;
            expected=v<=ref_low ? 0 : (v>=ref_high ? 255 : ((v-ref_low)*ref_gain)/256);
            if(rgb_out!=={3{expected[7:0]}})fail("first-frame CDF low-pass or LUT mismatch");
        end
        alarm_bypass=1;rgb_in=24'h123456;repeat(2)@(posedge clk);#1;if(rgb_out!=24'h123456)fail("alarm LUT bypass");
        wait(full_ready);@(negedge clk);full_pixel_valid=1;
        for(i=0;i<307200;i=i+1)@(negedge clk);
        full_pixel_valid=0;repeat(4)@(posedge clk);#1;
        if(full_hist!=307200)begin
            $display("full-frame histogram=%0d",full_hist);
            fail("single-bin full-frame histogram overflow");
        end
        alarm_bypass=0;automatic_contrast=0;
        for(g=0;g<3;g=g+1)for(t=0;t<3;t=t+1)begin
            gamma=g;temp=t;
            for(f=0;f<33;f=f+1)build_frame();
            exponent=g==0 ? 2.2/1.8 : (g==2 ? 2.2/2.6 : 1.0);
            for(v=0;v<256;v=v+1)begin
                expected=$rtoi(255.0*((v/255.0)**exponent)+0.5);
                er=expected+(t==0 ? 12 : (t==2 ? -10 : 0));
                eb=expected+(t==0 ? -12 : (t==2 ? 14 : 0));
                if(er<0)er=0;else if(er>255)er=255;
                if(eb<0)eb=0;else if(eb>255)eb=255;
                rgb_in={v[7:0],v[7:0],v[7:0]};repeat(2)@(posedge clk);#1;
                if(rgb_out!=={er[7:0],expected[7:0],eb[7:0]})begin
                    $display("gamma=%0d temp=%0d v=%0d got=%h expected=%h",g,t,v,rgb_out,{er[7:0],expected[7:0],eb[7:0]});
                    fail("settled gamma/temperature differs from floating reference");
                end
                @(negedge clk);
            end
        end
        $display("TEST_PASS tb_quality_engine full-frame histogram, atomic LUT, CDF low-pass, 2304 gamma/temperature vectors");$finish;
    end
    initial begin #20000000;fail("timeout");end
endmodule
