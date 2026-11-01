`timescale 1ns/1ps
module tb_alarm_disaster_ticker;
    reg clk=0,rst=1,tick=0,en=0,evac=0,drill=1;
    reg [2:0] kind=0;
    reg [10:0] x=0,y=0;
    wire [23:0] rgb;
    always #5 clk=~clk;
    alarm_disaster_ticker dut(.clk(clk),.rst(rst),.frame_tick(tick),
        .enable(en),.evacuation(evac),.drill(drill),.kind(kind),
        .x(x),.y(y),.rgb_in(24'h123456),.rgb_out(rgb));
    reg [23:0] row[0:127];
    integer i,j,count,changed;
    reg [23:0] quake[0:1023];
    task frame;
        begin @(negedge clk);tick=1;@(negedge clk);tick=0;end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        y=8;#1;if(rgb!==24'h123456)$fatal(1,"idle ticker visible");
        en=1;frame();
        count=0;
        for(j=0;j<16;j=j+1)for(i=0;i<64;i=i+1)begin
            x=i;y=j+4;#1;quake[j*64+i]=rgb;
            if(rgb==24'hfff4cc)count=count+1;
        end
        if(count<150)$fatal(1,"missing Chinese disaster text");
        y=11;
        for(i=0;i<128;i=i+1)begin x=i;#1;row[i]=rgb;end
        frame();
        for(i=0;i<128;i=i+1)begin
            x=i;#1;if(rgb!==row[i])$fatal(1,"ticker moved before second frame");
        end
        frame();
        for(i=0;i<128;i=i+1)begin
            x=i;#1;if(rgb!==row[(i+1)%128])$fatal(1,"ticker did not move left one pixel");
        end
        repeat(254)frame();
        if(dut.scroll!==0)$fatal(1,"ticker wrap failed");
        kind=1;#1;if(dut.kind_q!==0)$fatal(1,"kind changed midframe");
        frame();changed=0;
        for(j=0;j<16;j=j+1)for(i=0;i<64;i=i+1)begin
            x=i;y=j+4;#1;if(rgb!==quake[j*64+i])changed=changed+1;
        end
        if(changed<50)$fatal(1,"fire text identical to earthquake");
        evac=1;kind=3;frame();x=32;#1;
        if(dut.glyph!==6)$fatal(1,"evacuation text missing");
        evac=0;kind=2;frame();#1;
        if(dut.glyph!==10)$fatal(1,"notice text incorrect");
        kind=7;frame();#1;if(dut.glyph!==4)$fatal(1,"unknown kind fallback incorrect");
        y=24;#1;if(rgb!==24'h123456)$fatal(1,"ticker overlaps map/title");
        en=0;frame();y=8;#1;if(rgb!==24'h123456)$fatal(1,"ticker survived clear");
        en=1;frame();if(dut.scroll!==0)$fatal(1,"new alarm did not restart ticker");
        $display("TEST_PASS disaster glyphs, left scroll, frame atomicity, wrap, kind changes, clear and restart");
        $finish;
    end
endmodule
