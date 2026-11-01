`timescale 1ns/1ps
module tb_quality_shared_smoother;
    reg clk=0,rst=1,tick=0;
    reg signed [8:0] target_brightness=0;
    reg [7:0] target_contrast=128;
    reg [1:0] gamma_mode=1,temperature_mode=1;
    wire signed [8:0] brightness,contrast,ref_brightness,ref_contrast;
    wire signed [6:0] gamma_weight,ref_gamma;
    wire signed [5:0] red,blue,ref_red,ref_blue;
    wire busy;
    integer n,k,elapsed,frames=0;
    reg [31:0] random_state=32'h703298ab;
    always #5 clk=~clk;
    quality_parameter_smoother dut(.clk(clk),.rst(rst),.frame_tick(tick),
        .target_brightness(target_brightness),.target_contrast(target_contrast),
        .gamma_mode(gamma_mode),.temperature_mode(temperature_mode),
        .brightness(brightness),.contrast(contrast),.gamma_weight(gamma_weight),
        .temperature_r(red),.temperature_b(blue),.busy(busy));
    frame_parameter_smoother rb(.clk(clk),.rst(rst),.frame_tick(tick),
        .target(target_brightness),.value(ref_brightness));
    frame_parameter_smoother #(.INITIAL_VALUE(128)) rc(.clk(clk),.rst(rst),.frame_tick(tick),
        .target($signed({1'b0,target_contrast})),.value(ref_contrast));
    frame_parameter_smoother #(.WIDTH(7)) rgamma(.clk(clk),.rst(rst),.frame_tick(tick),
        .target(gamma_mode==0 ? -7'sd32 : gamma_mode==2 ? 7'sd32 : 7'sd0),.value(ref_gamma));
    frame_parameter_smoother #(.WIDTH(6)) rr(.clk(clk),.rst(rst),.frame_tick(tick),
        .target(temperature_mode==0 ? 6'sd12 : temperature_mode==2 ? -6'sd10 : 6'sd0),.value(ref_red));
    frame_parameter_smoother #(.WIDTH(6)) rblue(.clk(clk),.rst(rst),.frame_tick(tick),
        .target(temperature_mode==0 ? -6'sd12 : temperature_mode==2 ? 6'sd14 : 6'sd0),.value(ref_blue));
    task fail;input [8*120-1:0] msg;begin
        $display("TEST_FAIL shared smoother: %0s frame=%0d n=%0d k=%0d",msg,frames,n,k);$finish;end endtask
    task check_outputs;
        begin
            if({brightness,contrast,gamma_weight,red,blue}!==
                    {ref_brightness,ref_contrast,ref_gamma,ref_red,ref_blue})fail("five-channel reference mismatch");
        end
    endtask
    task frame;
        begin
            tick=1;@(negedge clk);tick=0;
            elapsed=0;

            if(n[0]&&k==3)begin target_brightness=~target_brightness;temperature_mode=temperature_mode+1'b1;end
            while(busy&&elapsed<64)begin @(negedge clk);elapsed=elapsed+1;end
            if(busy||elapsed!=40)fail("40-clock update budget");
            check_outputs;frames=frames+1;
            repeat(7)begin @(negedge clk);check_outputs;end
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        repeat(16)@(negedge clk);if(busy)fail("initialization");check_outputs;
        for(n=0;n<512;n=n+1)begin
            target_brightness=n-256;target_contrast=n[7:0];gamma_mode=n%4;temperature_mode=(n/4)%4;
            for(k=0;k<34;k=k+1)frame;
        end
        for(n=0;n<1000;n=n+1)begin
            random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            target_brightness=random_state[8:0];target_contrast=random_state[16:9];
            gamma_mode=random_state[18:17];temperature_mode=random_state[20:19];k=0;frame;
        end

        tick=1;@(negedge clk);tick=0;repeat(13)@(negedge clk);rst=1;
        repeat(3)@(negedge clk);rst=0;repeat(16)@(negedge clk);check_outputs;
        for(k=0;k<33;k=k+1)frame;
        $display("TEST_PASS shared smoother: %0d frames, five old DDA references, all signed brightness values, retarget/snapshot/reset, 40-clock budget",frames);
        $finish;
    end
    initial begin #20000000;fail("timeout");end
endmodule
