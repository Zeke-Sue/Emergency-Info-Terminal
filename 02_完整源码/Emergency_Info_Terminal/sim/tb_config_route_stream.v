`timescale 1ns/1ps
module tb_config_route_stream;
    reg clk=0,rst=1,start=0,byte_valid=0,file_end=0;reg [7:0] byte_data=0;
    wire byte_ready,cfg_write,cfg_commit,crc_ok,checked,assets,done,valid;
    wire [7:0] key;wire [31:0] segments,directions,cfg_crc;
    wire [2:0] selected_exit;wire [1:0] status;wire [15:0] version;
    wire [3:0] error_reason;
    reg [7:0] payload [0:2303];integer i,writes;reg [31:0] crc;
    always #5 clk=~clk;
    config_route_stream_parser dut(.clk(clk),.rst(rst),.file_start(start),
        .byte_valid(byte_valid),.byte_data(byte_data),.byte_ready(byte_ready),
        .cfg_ready(1'b1),
        .file_end(file_end),.cfg_write(cfg_write),.cfg_blocked_key(key),
        .cfg_segment_mask(segments),.cfg_direction_mask(directions),
        .cfg_exit(selected_exit),.cfg_status(status),.cfg_commit(cfg_commit),
        .cfg_crc_ok(crc_ok),.cfg_checked(checked),.cfg_assets_match(assets),
        .cfg_version(version),.cfg_crc32(cfg_crc),.done(done),.valid(valid),
        .error_reason(error_reason));
    function [31:0] crc32_byte;input [31:0] current;input [7:0] value;
        integer k;reg [31:0] work;begin work=current^value;
        for(k=0;k<8;k=k+1)work=work[0]?(work>>1)^32'hedb88320:work>>1;
        crc32_byte=work;end endfunction
    task send_byte;input [7:0] value;begin
        while(!byte_ready)@(negedge clk);byte_data=value;byte_valid=1;
        @(negedge clk);byte_valid=0;
    end endtask
    task send_le16;input [15:0] value;begin send_byte(value[7:0]);send_byte(value[15:8]);end endtask
    task send_le32;input [31:0] value;begin send_byte(value[7:0]);send_byte(value[15:8]);
        send_byte(value[23:16]);send_byte(value[31:24]);end endtask
    task send_config;input integer corrupt;begin
        @(negedge clk);start=1;@(negedge clk);start=0;
        send_byte("E");send_byte("I");send_byte("T");send_byte("4");
        send_le16(16'h4101);send_le16(16'd32);send_le32(32'd2336);
        send_le32(crc);send_le32(crc);send_le32(32'hda11eb23);
        send_le32(32'd3);send_le32(32'd256);
        for(i=0;i<2304;i=i+1)send_byte(payload[i]^(corrupt&&i==100 ? 8'h01:0));
        repeat(2)@(negedge clk);file_end=1;@(negedge clk);file_end=0;
        wait(done);#1;
    end endtask
    task fail;input [8*100-1:0] message;begin
        $display("TEST_FAIL tb_config_route_stream: %0s",message);$finish;end endtask
    always @(posedge clk)if(cfg_write)begin
        if(writes==0&&(key!=0||segments!=1||selected_exit!=1||status!=0))
            fail("first route entry");
        if(writes==255&&(key!=255||segments!=32'h80000000||selected_exit!=2||status!=1))
            fail("last route entry");
        writes=writes+1;
    end
    initial begin
        for(i=0;i<256;i=i+1)begin
            payload[i*9+0]=(32'h1<<i[4:0]);payload[i*9+1]=(32'h1<<i[4:0])>>8;
            payload[i*9+2]=(32'h1<<i[4:0])>>16;payload[i*9+3]=(32'h1<<i[4:0])>>24;
            payload[i*9+4]=0;payload[i*9+5]=0;payload[i*9+6]=0;payload[i*9+7]=0;
            payload[i*9+8]=(i==255)?8'h0a:8'h01;
        end
        crc=32'hffffffff;for(i=0;i<2304;i=i+1)crc=crc32_byte(crc,payload[i]);crc=~crc;
        repeat(4)@(negedge clk);rst=0;writes=0;send_config(0);
        if(!valid||!cfg_commit||!crc_ok||!checked||!assets||writes!=256||
                version!=16'h4101||cfg_crc!=crc)fail("valid config rejected");
        writes=0;send_config(1);
        if(valid||cfg_commit||crc_ok||error_reason!=5||writes!=256)
            fail("corrupt config committed");
        $display("TEST_PASS tb_config_route_stream atomic 256-entry CONFIG route update and CRC rejection");
        $finish;
    end
    initial begin #20000000;fail("timeout");end
endmodule
