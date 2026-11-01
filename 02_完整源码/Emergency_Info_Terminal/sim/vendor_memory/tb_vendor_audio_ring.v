`timescale 1ns/1ps
module tb_vendor_audio_ring;
    reg clk=0,rst=1,flush=0,valid=0,last=0,out_ready=0,error=0;
    always #10 clk=~clk; reg shift=0; initial begin #8;forever #10 shift=~shift;end
    reg [15:0] sample=0;
    wire ready,out_valid,mvalid,mwrite,mready;
    wire [15:0] out_sample;
    wire [20:0] addr;
    wire [31:0] wdata;
    wire [5:0] buffered;
    wire fault;
    wire done;
    wire [31:0] rdata;
    reg [20:0] saved_addr;
    reg saved_write;
    integer cycles=0,delay=0,expected=0,received=0,base=1000,i;

    sdram_audio_ring #(.SAMPLE_BITS(5),.BASE_WORD(21'h1e0000)) dut(
        .clk(clk),.rst(rst),.flush(flush),.sample_valid(valid),.sample(sample),
        .sample_ready(ready),.stream_end(last),.output_valid(out_valid),
        .output_sample(out_sample),.output_ready(out_ready),
        .mem_valid(mvalid),.mem_write(mwrite),.mem_addr(addr),.mem_wdata(wdata),
        .mem_ready(mready),.mem_done(done),.mem_rdata(rdata),.mem_error(error),
        .buffered_samples(buffered),.fault(fault));

    wire init,busy,we,re,rv;wire [20:0] wa,ra;wire [31:0] wd,rd;wire [3:0] ec;
    memory_phy phy(.clk(clk),.shifted_clk(shift),.rst(rst),.initialized(init),.busy(busy),
        .wr_en(we),.wr_addr(wa),.wr_data(wd),.rd_en(re),.rd_addr(ra),.rd_valid(rv),.rd_data(rd));
    frame_store #(.STREAMING(1),.ENABLE_AUX(1)) store(
        .clk(clk),.rst(rst),.pixel_clk(clk),.mem_init(init),.mem_busy(busy),.load_done(1'b0),
        .pixel_valid(1'b0),.pixel_addr(22'd0),.pixel_rgb(24'd0),.reads_enabled(1'b0),.error_code(ec),
        .line_req_toggle(1'b0),.line_image(4'd0),.line_row(10'd0),.line_bank(1'b0),
        .line_second_image(4'd0),.line_split(10'd0),.line_horizontal_slide(1'b0),.line_zoom(2'd0),
        .line_dual(1'b0),.second_ram_addr(11'd0),.line_ram_addr(11'd0),
        .wr_en(we),.wr_addr(wa),.wr_data(wd),.rd_en(re),.rd_addr(ra),.rd_valid(rv),.rd_data(rd),
        .aux_valid(mvalid),.aux_write(mwrite),.aux_addr(addr),.aux_wdata(wdata),
        .aux_ready(mready),.aux_done(done),.aux_rdata(rdata));
    always @(posedge clk)if(ec!=0)$fatal(1,"vendor memory error");
    task fail;
        input [511:0] why;
        begin $display("TEST_FAIL audio ring: %0s",why);$finish;end
    endtask
    always @(posedge clk)begin
        cycles<=cycles+1;
        if(out_valid&&out_ready)begin
            if(out_sample!==base+expected)begin
                $display("got=%0d expected=%0d",out_sample,base+expected);
                fail("sample order");
            end
            expected=expected+1;received=received+1;
        end
        if(cycles>800000)fail("timeout");
    end
    task push;
        input [15:0] value;
        begin
            @(negedge clk);while(!ready)@(negedge clk);
            sample=value;valid=1;@(negedge clk);valid=0;
        end
    endtask
    task finish_stream;
        begin @(negedge clk);last=1;@(negedge clk);last=0;end
    endtask
    task clear_stream;
        begin @(negedge clk);flush=1;@(negedge clk);flush=0;end
    endtask
    initial begin
        repeat(20)@(negedge clk);rst=0;wait(init);

        for(i=0;i<32;i=i+1)push(base+i);
        repeat(30)@(negedge clk);
        out_ready=1;
        for(i=32;i<193;i=i+1)push(base+i);
        finish_stream();wait(received==193);
        repeat(20)@(negedge clk);
        if(buffered!=0||out_valid)fail("odd tail was padded into output");
        out_ready=0;clear_stream();base=2000;expected=0;received=0;
        push(16'hdead);push(16'hbeef);
        wait(dut.state==1);clear_stream();
        push(2000);finish_stream();out_ready=1;wait(received==1);
        repeat(20)@(negedge clk);
        if(buffered!=0)fail("flush left old data");
        out_ready=0;clear_stream();push(3000);push(3001);
        wait(dut.state==2);clear_stream();base=4000;expected=0;received=0;
        push(4000);finish_stream();out_ready=1;wait(received==1);
        @(negedge clk);error=1;@(negedge clk);error=0;
        if(!fault||out_valid||ready||mvalid)fail("memory fault did not inhibit ring");
        $display("TEST_PASS actual vendor controller plus SDRAM audio ring: wrap, stalls, odd tail, in-flight write/read flush, fault");
        $finish;
    end
endmodule
