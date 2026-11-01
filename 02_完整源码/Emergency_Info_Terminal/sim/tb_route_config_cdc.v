`timescale 1ns/1ps
module tb_route_config_cdc;
    reg src_clk=0,dst_clk=0,src_rst=1,dst_rst=1;
    reg src_write=0,src_commit=0;reg [7:0] key=0;
    reg [31:0] segments=0,directions=0,crc=0;
    reg [2:0] selected_exit=0;reg [1:0] status=0;
    reg crc_ok=0,checked=0,assets=0;reg [15:0] version=0;
    wire src_ready,overflow,dst_write,dst_commit;wire [7:0] dst_key;
    wire [31:0] dst_segments,dst_directions,dst_crc;
    wire [2:0] dst_exit;wire [1:0] dst_status;wire dst_crc_ok,dst_checked,dst_assets;
    wire [15:0] dst_version;integer seen=0,sent;
    always #4 src_clk=~src_clk;always #10 dst_clk=~dst_clk;
    route_config_cdc dut(.src_clk(src_clk),.src_rst(src_rst),
        .src_write(src_write),.src_key(key),.src_segments(segments),
        .src_directions(directions),.src_exit(selected_exit),.src_status(status),
        .src_commit(src_commit),.src_crc_ok(crc_ok),.src_checked(checked),
        .src_assets_match(assets),.src_version(version),.src_crc32(crc),
        .src_ready(src_ready),.src_overflow(overflow),
        .dst_clk(dst_clk),.dst_rst(dst_rst),
        .dst_write(dst_write),.dst_key(dst_key),.dst_segments(dst_segments),
        .dst_directions(dst_directions),.dst_exit(dst_exit),.dst_status(dst_status),
        .dst_commit(dst_commit),.dst_crc_ok(dst_crc_ok),.dst_checked(dst_checked),
        .dst_assets_match(dst_assets),.dst_version(dst_version),.dst_crc32(dst_crc));
    task fail;input [8*80-1:0] msg;begin
        $display("TEST_FAIL tb_route_config_cdc: %0s",msg);$finish;end endtask
    always @(posedge dst_clk)if(dst_write)begin
        if(dst_key!=seen||dst_segments!=(32'h1000+seen)||
                dst_directions!=(32'h2000+seen)||dst_exit!=seen[2:0])
            fail("record changed across CDC");
        seen=seen+1;
    end
    initial begin
        repeat(4)@(negedge src_clk);src_rst=0;dst_rst=0;
        for(sent=0;sent<4;sent=sent+1)begin
            while(dut.write_request!=dut.write_ack_sync[1])@(negedge src_clk);
            key=sent;segments=32'h1000+sent;directions=32'h2000+sent;
            selected_exit=sent;status=sent[1:0];src_write=1;
            @(negedge src_clk);src_write=0;
        end
        while(dut.write_request!=dut.write_ack_sync[1])@(negedge src_clk);
        crc_ok=1;checked=1;assets=1;version=16'h4101;crc=32'h21608fac;
        src_commit=1;@(negedge src_clk);src_commit=0;
        wait(dst_commit);#1;
        if(seen!=4||overflow||!dst_crc_ok||!dst_checked||!dst_assets||
                dst_version!=16'h4101||dst_crc!=32'h21608fac)
            fail("commit metadata or record count");
        $display("TEST_PASS tb_route_config_cdc bundled route records and ordered commit");
        $finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
