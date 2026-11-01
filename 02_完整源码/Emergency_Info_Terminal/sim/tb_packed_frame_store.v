`timescale 1ns/1ps
module tb_packed_frame_store;
    localparam integer W=8,H=4,PIXELS=W*H,IMAGES=8,WORDS=IMAGES*PIXELS*3/4;
    reg clk=0,pixel_clk=0,rst=1,load_done=0,pixel_valid=0;
    reg [21:0] pixel_addr=0;
    reg [23:0] pixel_rgb=0;
    reg line_req_toggle=0,line_bank=0;
    reg [3:0] line_image=0,line_second_image=0;
    reg [9:0] line_row=0,line_split=0;
    reg [10:0] line_ram_addr=0;
    wire pixel_ready,cache_ready,line_ack_toggle,wr_en,rd_en;
    wire [3:0] error_code;
    wire [20:0] wr_addr,rd_addr;
    wire [31:0] wr_data;
    wire [23:0] line_ram_q,second_ram_q;
    reg rd_valid=0;
    reg [31:0] rd_data=0;
    reg [31:0] memory [0:WORDS-1];
    reg written [0:WORDS-1];
    integer writes=0,i,j,k,g;
    always #5 clk=~clk;
    always #10 pixel_clk=~pixel_clk;
    frame_store #(.WIDTH(W),.HEIGHT(H),.BURST(4),.DRAIN_CYCLES(2),.DUAL_SOURCE(1)) dut(
        .clk(clk),.rst(rst),.pixel_clk(pixel_clk),.mem_init(1'b1),.mem_busy(1'b0),
        .reads_enabled(1'b1),
        .load_done(load_done),.pixel_valid(pixel_valid),.pixel_ready(pixel_ready),
        .pixel_addr(pixel_addr),.pixel_rgb(pixel_rgb),
        .cache_ready(cache_ready),.error_code(error_code),
        .line_req_toggle(line_req_toggle),.line_image(line_image),.line_row(line_row),
        .line_bank(line_bank),.line_second_image(line_second_image),.line_split(line_split),
        .line_horizontal_slide(1'b0),.line_zoom(2'd0),.line_ack_toggle(line_ack_toggle),
        .line_ram_addr(line_ram_addr),.line_ram_q(line_ram_q),
        .line_dual(1'b1),.second_ram_addr(line_ram_addr),.second_ram_q(second_ram_q),
        .wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
        .rd_en(rd_en),.rd_addr(rd_addr),.rd_valid(rd_valid),.rd_data(rd_data));
    function [23:0] pixel_at;
        input integer n;
        integer image,x,y;
        reg [7:0] r,g,b;
        begin
            image=n/PIXELS;x=(n%PIXELS)%W;y=(n%PIXELS)/W;
            r=image*23+x;g=y*37+image;b=x^y^image;
            pixel_at={r,g,b};
        end
    endfunction
    task fail;
        input [8*160-1:0] reason;
        begin $display("TEST_FAIL tb_packed_frame_store: %0s",reason);$finish;end
    endtask
    always @(posedge clk)begin
        rd_valid<=rd_en;
        if(rd_en)begin
            if(rd_addr>=WORDS)fail("read address outside packed area");
            rd_data<=memory[rd_addr];
        end
        if(wr_en)begin
            if(wr_addr>=WORDS)fail("write address outside packed area");
            if(written[wr_addr])fail("duplicate packed word");
            written[wr_addr]<=1;
            memory[wr_addr]<=wr_data;
            writes<=writes+1;
        end
    end
    reg [31:0] expected_word;
    reg [23:0] p0,p1,p2,p3;
    initial begin
        for(i=0;i<WORDS;i=i+1)written[i]=0;
        repeat(4)@(negedge clk);rst=0;
        for(i=0;i<IMAGES*PIXELS;i=i+1)begin
            wait(pixel_ready);
            @(negedge clk);pixel_addr=i;pixel_rgb=pixel_at(i);pixel_valid=1;
            @(negedge clk);pixel_valid=0;
        end
        load_done=1;
        wait(cache_ready);@(negedge clk);
        if(error_code!=0||writes!=WORDS)fail("load did not finish with exact packed word count");
        for(g=0;g<IMAGES*PIXELS/4;g=g+1)begin
            p0=pixel_at(g*4);p1=pixel_at(g*4+1);
            p2=pixel_at(g*4+2);p3=pixel_at(g*4+3);
            expected_word={p1[23:16],p0};
            if(memory[g*3]!==expected_word)fail("packed word zero mismatch");
            expected_word={p2[15:0],p1[15:0]};
            if(memory[g*3+1]!==expected_word)fail("packed word one mismatch");
            expected_word={p3,p2[23:16]};
            if(memory[g*3+2]!==expected_word)fail("packed word two mismatch");
        end
        for(i=0;i<IMAGES;i=i+1)for(j=0;j<H;j=j+1)begin
            @(negedge clk);line_image=i;line_second_image=IMAGES-1-i;line_row=j;line_req_toggle=~line_req_toggle;
            wait(line_ack_toggle==line_req_toggle);
            for(k=0;k<W;k=k+1)begin
                @(negedge pixel_clk);line_ram_addr=k;
                @(posedge pixel_clk);#1;
                if(line_ram_q!==pixel_at(i*PIXELS+j*W+k))begin
                    $display("image=%0d row=%0d x=%0d got=%h expected=%h",i,j,k,line_ram_q,pixel_at(i*PIXELS+j*W+k));
                    fail("unpacked pixel mismatch");
                end
                if(second_ram_q!==pixel_at((IMAGES-1-i)*PIXELS+j*W+k))
                    fail("second-source unpacked pixel mismatch");
            end
        end
        $display("TEST_PASS tb_packed_frame_store eight frames, %0d packed words, all pixels",writes);$finish;
    end
    initial begin #1000000;fail("timeout");end
endmodule
