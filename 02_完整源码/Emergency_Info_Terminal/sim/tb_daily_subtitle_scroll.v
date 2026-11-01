`timescale 1ns/1ps
module tb_daily_subtitle_scroll;
    reg clk=0,rst=1,frame_tick=0,active=0;
    reg [2:0] track=0;
    reg [31:0] samples=0;
    reg [10:0] x=0,y=0;
    reg [7:0] caption=1;
    wire [23:0] rgb;
    reg [7:0] pixels[0:16383];
    reg [15:0] positions[0:2047];
    reg [7:0] legacy[0:4095];
    integer t,b,xx,yy,offset,address,white_count=0;
    reg [23:0] expected;
    always #5 clk=~clk;
    daily_subtitle_overlay dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .active(active),.track(track),.elapsed_samples(samples),.x(x),.y(y),
        .subtitle_id(caption),.rgb_in(24'h4080c0),.rgb_out(rgb));
    task frame;
        begin
            repeat(3)@(negedge clk);frame_tick=1;
            @(negedge clk);frame_tick=0;
        end
    endtask
    task check_pixel;
        input integer px,py;
        begin
            x=px;y=py;expected=24'h4080c0;
            if(active&&px>=16&&px<624&&py>=432&&py<464)begin
                expected=24'h204060;
                if(py>=440&&py<456&&px-624+offset>=0&&px-624+offset<1024)begin
                    address=t*2048+(py-440)*128+(px-624+offset)/8;
                    if(pixels[address][7-((px-624+offset)%8)])begin
                        expected=24'hffffff;white_count=white_count+1;
                    end
                end
            end else if(caption>=9&&caption<=16&&px>=16&&px<624&&py>=432&&py<464)begin
                expected=24'h204060;
                if(py>=440&&py<456&&px<144)begin
                    address=(caption-1)*256+(py-440)*16+(px-16)/8;
                    if(legacy[address][7-((px-16)%8)])expected=24'hffffff;
                end
            end
            @(negedge clk);
            if(rgb!==expected)$fatal(1,"scroll pixel track=%0d offset=%0d xy=%0d,%0d got=%h expected=%h",t,offset,px,py,rgb,expected);
        end
    endtask
    initial begin
        $readmemh("../../rtl/daily_subtitle_strip.mem",pixels);
        $readmemh("../../rtl/daily_subtitle_position.mem",positions);
        $readmemh("../../rtl/subtitle_bitmap.packed.mem",legacy);
        repeat(4)@(negedge clk);rst=0;
        frame();check_pixel(32,442);
        active=1;
        for(t=0;t<8;t=t+1)begin
            track=t;

            for(b=0;b<256;b=b+1)begin
                samples=b*2048;frame();offset=positions[t*256+b];
                if(dut.frame_offset!==offset||!dut.show)$fatal(1,"timing/track latch mismatch");
                if(b==0&&offset!=0)$fatal(1,"entry must be empty");
                if(b>0&&b<190&&positions[t*256+b]<=positions[t*256+b-1])$fatal(1,"initial or mid-clip stall");
                if(b>0&&positions[t*256+b]<positions[t*256+b-1])$fatal(1,"scroll moved backwards");
            end

            samples=2048;frame();offset=positions[t*256+1];
            white_count=0;
            for(yy=440;yy<456;yy=yy+1)
                for(xx=16;xx<624;xx=xx+1)begin
                    check_pixel(xx,yy);
                    if(rgb==24'hffffff&&xx<624-offset)$fatal(1,"text entered from wrong edge");
                end
            if(white_count==0)$fatal(1,"first timing bin still empty");

            for(b=0;b<3;b=b+1)begin
                samples=b*100*2048;frame();offset=positions[t*256+b*100];
                for(yy=430;yy<466;yy=yy+1)
                    for(xx=0;xx<640;xx=xx+1)check_pixel(xx,yy);
            end
        end
        if(white_count<1000)$fatal(1,"text coverage missing");
        t=0;track=0;samples=204800;frame();offset=dut.frame_offset;
        samples=300000;repeat(50)@(negedge clk);
        if(dut.frame_offset!=offset)$fatal(1,"mid-frame tearing");
        frame();offset=dut.frame_offset;
        repeat(10)frame();
        if(dut.frame_offset!=offset)$fatal(1,"stalled audio moved subtitles");
        active=0;caption=9;check_pixel(24,442);
        caption=1;samples=0;active=1;@(negedge clk);
        if(dut.show)$fatal(1,"restart displayed stale offset");
        frame();if(dut.frame_offset!=0||!dut.show)$fatal(1,"restart did not begin at zero");
        samples=32'hffffffff;frame();
        if(dut.frame_offset!=positions[255])$fatal(1,"out-of-range playback wrapped");
        track=1;@(negedge clk);if(dut.show)$fatal(1,"new track showed old text");
        rst=1;@(negedge clk);if(dut.show)$fatal(1,"reset kept text enabled");
        $display("TEST_PASS eight complete text strips, all timing bins, native-size pixels, pause/stall, preemption, restart, page change and saturation");$finish;
    end
    initial begin #100000000;$fatal(1,"scroll test timeout");end
endmodule
