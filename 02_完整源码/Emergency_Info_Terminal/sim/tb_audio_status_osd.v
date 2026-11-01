`timescale 1ns/1ps
module tb_audio_status_osd;
    reg clk=0,rst=1,frame=0;
    reg [10:0] x=0,y=0;
    reg [15:0] peak=16'habcd;
    reg [31:0] limited=32'h01234567,clipped=32'h89abcdef;
    reg [1:0] rate=1,duty=1;
    reg [3:0] selection=9;
    wire [23:0] rgb;
    integer row,col,bitpos,r;
    reg [31:0] number;
    reg [7:0] glyph;
    always #5 clk=~clk;
    video_effects #(.LUT_ONLY(1)) dut(.clk(clk),.rst(rst),.frame_tick(frame),
        .x(x),.y(y),.image_index(4'd0),.fade_gain(5'd16),.transition_mode(3'd2),
        .zoom_mode(1'b0),.grayscale_enable(1'b0),.overlay_enable(1'b0),
        .brightness_level(3'd2),.contrast_level(3'd2),.saturation_level(3'd2),
        .gamma_mode(2'd1),.temperature_mode(2'd1),.quality_selection(selection),
        .volume_level(3'd7),.flash_rate(rate),.flash_duty(duty),
        .audio_peak_absolute(peak),.audio_limited_count(limited),.audio_clipped_count(clipped),
        .transition_settings(6'd0),.osd_visible(1'b1),.color_lut_active(1'b0),
        .audio_sample_valid(1'b0),.audio_sample(16'd0),.rgb_in(24'd0),.rgb_out(rgb));
    function [7:0] top_row;
        input [3:0] digit;
        begin case(digit)
            0,2,8,9,10,12:top_row=8'h3c;
            1:top_row=8'h18;
            3,5,7:top_row=8'h7e;
            4:top_row=8'h0c;
            6:top_row=8'h1c;
            11,13:top_row=8'hfc;
            14:top_row=8'hfe;
            15:top_row=8'hff;
        endcase end
    endfunction
    task check_glyph;
        input integer px,py;input [7:0] bits;
        integer k;
        begin for(k=0;k<8;k=k+1)begin
            x=px+k;y=py;@(negedge clk);
            if(rgb!==(bits[7-k] ? 24'hffffff : 24'd0))
                $fatal(1,"TEST_FAIL OSD (%0d,%0d) rgb=%h bits=%h",px+k,py,rgb,bits);
        end end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;frame=1;@(negedge clk);frame=0;

        peak=0;limited=0;clipped=0;
        for(row=0;row<3;row=row+1)begin
            number=row==0 ? 32'h0000abcd : row==1 ? 32'h01234567 : 32'h89abcdef;
            for(col=0;col<8;col=col+1)
                check_glyph(48+col*8,216+row*18,top_row(number>>((7-col)*4)));
        end
        for(r=0;r<3;r=r+1)begin
            rate=r;duty=r;@(negedge clk);
            check_glyph(48,270,top_row(r==2 ? 5 : 4));
            check_glyph(56,270,top_row(r==1 ? 5 : 0));
            check_glyph(48,288,top_row(1));
            check_glyph(64,288,top_row(r+3));
        end
        x=8;y=270;@(negedge clk);if(rgb!==24'hffffff)$fatal(1,"TEST_FAIL rate selection");
        selection=10;y=288;@(negedge clk);if(rgb!==24'hffffff)$fatal(1,"TEST_FAIL duty selection");
        frame=1;@(negedge clk);frame=0;
        check_glyph(72,216,top_row(0));
        $display("TEST_PASS final audio statistic hex pixels, frame snapshots, flash settings and selection");$finish;
    end
endmodule
