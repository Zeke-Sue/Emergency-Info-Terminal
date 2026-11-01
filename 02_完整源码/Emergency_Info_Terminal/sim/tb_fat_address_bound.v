`timescale 1ns/1ps
module tb_fat_address_bound;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    fat32_file_reader dut(.clk(clk),.rst(rst),.start_ready(1'b0),.sd_ready(1'b0),
        .sector_data(8'd0),.sector_valid(1'b0),.sector_end(1'b0),
        .open_req(1'b0),.abort_file(1'b0),.open_type(2'd1),.file_index(6'd0),.file_ready(1'b0));
    integer trial,shift,seed=32'h03182571;
    reg [31:0] base,cluster;
    reg [39:0] old_end;
    reg [32:0] bound;
    task compare;begin
        @(negedge clk);
        dut.state=17;dut.data_lba=base;dut.cluster_shift=shift;dut.root_cluster=cluster;
        old_end={8'd0,base}+(({8'd0,cluster}-1'b1)<<shift)-1'b1;
        @(posedge clk);#1;
        if(dut.cluster_address_overflow!==(old_end[39:32]!=0))
            $fatal(1,"address bound mismatch base=%h cluster=%h shift=%0d",base,cluster,shift);
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(trial=0;trial<20000;trial=trial+1)begin
            base=$random(seed);shift=trial%8;
            cluster=2+(($random(seed)&32'h7fffffff)%268435438);
            compare;
            bound=((33'h100000000-{1'b0,base})>>shift)+1;
            if(bound>=2&&bound<32'h0fffffef)begin
                cluster=bound;compare;
                cluster=bound+1;compare;
            end
        end
        for(shift=0;shift<8;shift=shift+1)begin
            base=0;cluster=2;compare;
            base=32'hffffffff;cluster=2;compare;
            base=32'hffffff80;cluster=2;compare;
        end
        $display("TEST_PASS FAT32 mount-time cluster bound matches 40-bit address overflow including boundary clusters");
        $finish;
    end
    initial begin #2000000;$fatal(1,"address bound timeout");end
endmodule
