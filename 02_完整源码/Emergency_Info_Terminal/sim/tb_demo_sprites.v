`timescale 1ns/1ps
module tb_demo_sprites #(parameter HALF_ALPHA=0);
    reg clk=0,rst=1,frame=0,enable=1;
    always #5 clk=~clk;
    reg [10:0] x=0,y=0;
    wire [23:0] rgb;
    demo_sprite_overlay #(.HALF_ALPHA(HALF_ALPHA)) dut(.clk(clk),.rst(rst),.frame_tick(frame),.enable(enable),
        .x(x),.y(y),.rgb_in(24'h2468ac),.rgb_out(rgb));
    integer xx,yy,changed0=0,changed1=0,transparent=0;
    initial begin
        repeat(3)@(negedge clk);rst=0;frame=1;
        @(negedge clk);frame=0;
        for(yy=112;yy<416;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
            x=xx;y=yy;@(negedge clk);
            if(rgb===24'hxxxxxx)$fatal(1,"uninitialized sprite ROM");
            if(xx>=464&&xx<624&&yy<272&&rgb!=24'h2468ac)changed0=changed0+1;
            if(xx>=16&&xx<176&&yy>=256&&rgb!=24'h2468ac)changed1=changed1+1;
            if(rgb==24'h2468ac)transparent=transparent+1;
        end
        if(changed0<100||changed1<100||transparent<100)$fatal(1,"missing bitmap or transparency");
        enable=0;frame=1;@(negedge clk);frame=0;
        x=500;y=160;repeat(2)@(negedge clk);
        if(rgb!=24'h2468ac)$fatal(1,"disabled sprite obscures page");
        $display("TEST_PASS tb_demo_sprites two RGBA assets, transparent background and disable");$finish;
    end
    initial begin #5000000;$fatal(1,"sprite timeout");end
endmodule
