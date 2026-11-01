`timescale 1ns/1ps
module tb_n10_demo_map;
    reg [10:0] x=0,y=0;reg [7:0] blocked=0;
    reg enable=1,valid=1;reg [1:0] status=0;reg [2:0] selected_exit=1;
    wire [5:0] segment;wire [7:0] phase;wire cross,foreground;wire [23:0] rgb;
    wire [1:0] distance;
    integer ref_distance;
    integer px,py,i,ax,ay,bx,by,ref_segment,ref_phase,lx,ly,k,cross_count;
    integer text_counts[0:3];integer fd;reg expected_cross;
    n10_demo_segment_map map(.x(x),.y(y),.blocked_set(blocked),
        .segment_id(segment),.segment_phase(phase),.segment_distance(distance),
        .blocked_exit_pixel(cross));
    n10_demo_map_renderer page(.x(x),.y(y),.enable(enable),.segment_id(segment),
        .route_valid(valid),.status(status),.selected_exit(selected_exit),
        .rgb_in(24'h123456),.rgb_out(rgb),.foreground(foreground));
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL map: %0s at %d,%d segment %d/%d phase %d/%d",msg,x,y,segment,ref_segment,phase,ref_phase);
        $finish;end endtask
    initial begin
        blocked=7;status=1;cross_count=0;
        fd=$fopen("n10_demo_map.ppm","w");$fwrite(fd,"P3\n640 480\n255\n");
        for(py=0;py<480;py=py+1)for(px=0;px<640;px=px+1)begin
            x=px;y=py;#1;ref_segment=0;ref_phase=0;ref_distance=0;

            for(i=31;i>=0;i=i-1)begin
                if(i<16)begin
                    ax=80+(i%4)*120;ay=80+(i/4)*100;bx=ax+120;
                    if(px>=ax&&px<bx&&py>=ay-2&&py<=ay+2)begin
                        ref_segment=i+1;ref_phase=px-ax;
                        ref_distance=py>=ay ? py-ay : ay-py;end
                end else if(i<31)begin
                    ax=80+((i-16)%5)*120;ay=80+((i-16)/5)*100;by=ay+100;
                    if(px>=ax-2&&px<=ax+2&&py>=ay&&py<by)begin
                        ref_segment=i+1;ref_phase=py-ay;
                        ref_distance=px>=ax ? px-ax : ax-px;end
                end else if(px>=318&&px<=322&&py>=380&&py<=440)begin
                    ref_segment=32;ref_phase=440-py;
                    ref_distance=px>=320 ? px-320 : 320-px;end
            end
            if(segment!=ref_segment||phase!=ref_phase)fail("edge coverage/orientation");
            if(distance!=ref_distance)fail("transverse arrow coordinate");
            expected_cross=0;
            for(i=0;i<3;i=i+1)begin
                ax=i==0 ? 80 : 560;ay=i==2 ? 380 : 80;lx=px-ax+16;ly=py-ay+16;
                if(lx>=0&&lx<32&&ly>=0&&ly<32&&
                    (((lx-ly)>=-2&&(lx-ly)<=2)||(lx+ly>=29&&lx+ly<=33)))expected_cross=1;
            end
            if(cross!==expected_cross)fail("32x32 blocked marker");
            if(cross)cross_count=cross_count+1;
            if((px<32||px>=608||py<28||py>=452)&&rgb!=24'h123456)fail("alarm border overwritten");
            if(cross)$fwrite(fd,"255 32 32\n");
            else $fwrite(fd,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);
        end
        $fclose(fd);
        if(cross_count<600)fail("marker coverage missing");
        for(k=0;k<4;k=k+1)begin
            status=k;text_counts[k]=0;
            for(py=32;py<46;py=py+1)for(px=272;px<592;px=px+1)begin
                x=px;y=py;#1;if(rgb==24'hffffff)text_counts[k]=text_counts[k]+1;
            end
            if(text_counts[k]<100)fail("missing status text");
        end
        if(text_counts[0]==text_counts[1]||text_counts[1]==text_counts[2]||text_counts[2]==text_counts[3])
            fail("status messages not distinct");
        enable=0;
        for(i=0;i<640;i=i+1)begin x=i;y=80;#1;if(rgb!=24'h123456||foreground)fail("disabled passthrough");end
        $display("TEST_PASS map: all 307200 pixels, 32 oriented edges, three 32x32 crosses, markers/status/passthrough");$finish;
    end
endmodule
