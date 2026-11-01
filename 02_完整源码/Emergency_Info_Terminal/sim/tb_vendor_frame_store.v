`timescale 1ns/1ps

module tb_vendor_frame_store;
    reg clk=0,pclk=0,shift=0,rst=1;
    always #10 clk=~clk;
    always #20 pclk=~pclk;
    initial begin #8;forever #10 shift=~shift;end
    wire init,busy,we,re,rv;wire [20:0] wa,ra;wire [31:0] wd,rd;
    memory_phy phy(.clk(clk),.shifted_clk(shift),.rst(rst),.initialized(init),.busy(busy),
        .wr_en(we),.wr_addr(wa),.wr_data(wd),.rd_en(re),.rd_addr(ra),.rd_valid(rv),.rd_data(rd));
    reg pv=0,done=0,toggle=0;reg [21:0] pa=0;reg [23:0] rgb=0;
    reg [10:0] addr=0;wire [23:0] q;wire ready,idle,ack;wire [3:0] error;
    reg [9:0] row=0;reg [3:0] slot=0;reg bank=0;
    reg aux=0,auxwr=0;reg [20:0] auxaddr=21'h1e0000;reg [31:0] auxdata=0;
    wire ar,ad;wire [31:0] aq;
    frame_store #(.WIDTH(640),.HEIGHT(480),.BURST(128),.STREAMING(1),.ENABLE_AUX(1)) dut(
        .clk(clk),.rst(rst),.pixel_clk(pclk),.mem_init(init),.mem_busy(busy),
        .load_done(done),.pixel_valid(pv),.pixel_ready(ready),.pixel_addr(pa),.pixel_rgb(rgb),
        .reads_enabled(1'b1),.write_idle(idle),.error_code(error),.line_req_toggle(toggle),
        .line_image(slot),.line_row(row),.line_bank(bank),.line_second_image(4'd0),
        .line_split(10'd0),.line_horizontal_slide(1'b0),.line_zoom(2'd0),.line_dual(1'b0),
        .second_ram_addr(11'd0),.line_ack_toggle(ack),.line_ram_addr(addr),.line_ram_q(q),
        .wr_en(we),.wr_addr(wa),.wr_data(wd),.rd_en(re),.rd_addr(ra),.rd_valid(rv),.rd_data(rd),
        .aux_valid(aux),.aux_write(auxwr),.aux_addr(auxaddr),.aux_wdata(auxdata),
        .aux_ready(ar),.aux_done(ad),.aux_rdata(aq));
    function [23:0] color(input integer x);
        color=x<320 ? 24'h123456 : {8'h82,x[7:0],x[15:8]};
    endfunction
    integer i,j,k,errors=0;
    task pcm_access;
        input wr; input [20:0] address; input [31:0] data;
        begin
            @(negedge clk);auxaddr=address;auxdata=data;auxwr=wr;aux=1;
            @(posedge clk);while(!ar)@(posedge clk);@(negedge clk);aux=0;wait(ad);
            if(!wr&&aq!==data)$fatal(1,"vendor SDRAM audio word addr=%h got=%h expected=%h",address,aq,data);
        end
    endtask
    integer commands=0,returns=0;
    always @(posedge phy.sdram_clk)if({phy.ras_n,phy.cas_n,phy.we_n}!=7&&commands<24)begin
        $display("SDR cmd=%b addr=%h bank=%h dq=%h t=%t",{phy.ras_n,phy.cas_n,phy.we_n},phy.address,phy.bank,phy.dq,$time);commands=commands+1;
    end
    always @(posedge clk)if(rv&&returns<12)begin $display("APP_READ %h t=%t",rd,$time);returns=returns+1;end
    initial begin
        repeat(20)@(negedge clk);rst=0;wait(init);repeat(100)@(negedge clk);

        for(k=0;k<4;k=k+1)for(j=479;j>=472;j=j-1)begin
        for(i=0;i<640;i=i+1)begin
            @(negedge clk);pa=k*307200+j*640+i;rgb=color(pa);pv=1;
            @(posedge clk);while(!ready)@(posedge clk);
            @(negedge clk);pv=0;
        end
        wait(idle);done=1;repeat(100)@(negedge clk);
        slot=k;row=j;bank=j%2;toggle=!toggle;wait(ack==toggle);
        for(i=0;i<640;i=i+1)begin
            @(negedge pclk);addr={bank,10'd0}+i;@(posedge pclk);#1;
            if(q!==color(k*307200+j*640+i))begin
                if(errors<12)$display("PIXEL_FAIL slot=%0d row=%0d x=%0d got=%h expected=%h",k,j,i,q,color(k*307200+j*640+i));
                errors=errors+1;
            end
        end
        if(errors)$fatal(1,"vendor SDRAM packed pixels: %0d mismatches",errors);
        end
        $display("IMAGE_PASS 20480 packed pixels, four slots, both line banks, bottom-up rows");
        for(i=0;i<64;i=i+1)pcm_access(1,21'h1e0000+i*4,32'h734512ab+i*1009);
        for(i=0;i<64;i=i+1)pcm_access(0,21'h1e0000+i*4,32'h734512ab+i*1009);
        pcm_access(1,21'h1ffffc,32'h76543210);pcm_access(0,21'h1ffffc,32'h76543210);
        if(error)$fatal(1,"memory error %d",error);
        $display("TEST_PASS vendor controller/SDRAM: 20480 packed pixels and 65 aligned PCM words");$finish;
    end
    initial begin #10000000;$fatal(1,"vendor memory timeout state=%d init=%b busy=%b",dut.state,init,busy);end
endmodule
