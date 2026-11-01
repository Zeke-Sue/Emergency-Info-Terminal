`timescale 1ns/1ps
module tb_n10_arrows;
    reg clk=0,rst=1,tick=0,write=0,commit=0,pixel_valid=1,cross=0;
    reg [7:0] key=0,blocked=0,phase=0;
    reg [31:0] segments=0,directions=0;
    reg [1:0] status=0,distance=0;
    reg [5:0] segment=1;
    wire valid,overlay;wire [23:0] rgb;
    integer frame_number=0,k,rev,s,p,d,a,position,checks=0;
    reg ink;reg [23:0] expected;
    always #5 clk=~clk;
    n10_route_engine #(.SHAPED_ARROWS(1)) dut(
        .clk(clk),.rst(rst),.frame_tick(tick),.cfg_write(write),
        .cfg_blocked_key(key),.cfg_segment_mask(segments),.cfg_direction_mask(directions),
        .cfg_exit(3'd1),.cfg_status(status),.cfg_commit(commit),.cfg_crc_ok(1'b1),
        .cfg_checked(1'b1),.cfg_assets_match(1'b1),.cfg_version(16'h5001),
        .cfg_crc32(32'h12345678),.blocked_set(blocked),.pixel_valid(pixel_valid),
        .segment_id(segment),.segment_phase(phase),.segment_distance(distance),
        .blocked_exit_pixel(cross),.flash_on(1'b0),.route_valid(valid),
        .overlay_valid(overlay),.overlay_rgb(rgb));
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL arrows: %0s frame=%0d reverse=%0d segment=%0d phase=%0d distance=%0d rgb=%h expected=%h",
            msg,frame_number,rev,segment,phase,distance,rgb,expected);$finish;end endtask
    task pulse;begin
        @(negedge clk);tick=1;@(negedge clk);tick=0;
        frame_number=(frame_number+1)%256;repeat(2)@(negedge clk);
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;#1;
        if(overlay)fail("unverified route shown");
        for(k=0;k<4;k=k+1)begin
            @(negedge clk);write=1;key=k;
            segments=k<2 ? 32'hffffffff : 0;
            directions=k==1 ? 32'hffffffff : 0;status=k==2 ? 1 : 0;
        end
        @(negedge clk);write=0;commit=1;
        @(negedge clk);commit=0;pulse;
        if(!valid||!overlay||rgb!=24'hb0ffb0)fail("initial highlight missing");
        for(rev=0;rev<2;rev=rev+1)begin
            blocked=rev;pulse;
            repeat(49)pulse;
            for(a=0;a<16;a=a+1)begin
                for(s=1;s<=32;s=s+1)for(p=0;p<256;p=p+1)for(d=0;d<3;d=d+1)begin
                    segment=s;phase=p;distance=d;#1;
                    position=((rev ? 256-p : p)-(frame_number/4)%16+32)%16;
                    ink=(d==0&&position<=4)||
                        (position>=5&&position<=7&&d<=7-position);
                    expected=ink ? 24'h20ff60 : 24'h087832;
                    if(!overlay||rgb!==expected)fail("directed arrow / animation mismatch");
                    checks=checks+1;
                end
                repeat(4)pulse;
            end
        end
        segment=0;#1;if(overlay)fail("segment zero rendered");
        segment=33;#1;if(overlay)fail("out-of-range segment rendered");
        segment=1;blocked=3;pulse;#1;if(overlay)fail("unselected segment rendered");
        blocked=2;pulse;#1;if(overlay)fail("unreachable route rendered");
        cross=1;#1;if(!overlay||rgb!=24'hff2020)fail("blocked cross priority/flash-off");
        pixel_valid=0;#1;if(overlay)fail("blanking overlay");
        $display("TEST_PASS arrows: %0d pixels, 32 segments, both directions, all 16 animation phases, highlight and blocked priority",checks);
        $finish;
    end
    initial begin #3000000;fail("timeout");end
endmodule
