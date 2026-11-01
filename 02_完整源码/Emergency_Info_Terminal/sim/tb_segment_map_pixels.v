`timescale 1ns/1ps
module tb_segment_map_pixels;
    reg [10:0] x,y;
    reg [7:0] blocked;
    wire [5:0] segment;
    wire [7:0] phase;
    wire cross_pixel;
    integer ix,iy,mask,dx,dy,expected;
    n10_prototype_segment_map dut(.x(x),.y(y),.blocked_set(blocked),
        .segment_id(segment),.segment_phase(phase),.blocked_exit_pixel(cross_pixel));
    initial begin
        for(mask=0;mask<4;mask=mask+1)begin
            blocked=mask;
            for(iy=0;iy<480;iy=iy+1)for(ix=0;ix<640;ix=ix+1)begin
                x=ix;y=iy;expected=0;
                if((mask&1)!=0&&ix>=194&&ix<226&&iy>=310&&iy<342)begin
                    dx=ix-194;dy=iy-310;
                    if((dx+3>=dy&&dx<=dy+3)||(dx+dy>=28&&dx+dy<=34))expected=1;
                end
                if((mask&2)!=0&&ix>=574&&ix<606&&iy>=186&&iy<218)begin
                    dx=ix-574;dy=iy-186;
                    if((dx+3>=dy&&dx<=dy+3)||(dx+dy>=28&&dx+dy<=34))expected=1;
                end
                #1;
                if(cross_pixel!==expected[0])begin
                    $display("TEST_FAIL mask=%0d x=%0d y=%0d",mask,ix,iy);$finish;
                end
            end
        end
        $display("TEST_PASS 1228800 exit marker pixels match integer reference");$finish;
    end
endmodule
