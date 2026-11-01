`timescale 1ns/1ps
module tb_loader_errors;
    reg clk=0,rst=1,start_ready=0,sd_ready=0;
    always #5 clk=~clk;
    wire sector_req,pixel_valid,done;
    wire [31:0] sector_lba;
    reg [7:0] sector_data=0;
    reg sector_valid=0,sector_end=0;
    wire pixel_ready=1;
    wire [20:0] pixel_addr;
    wire [23:0] pixel_rgb;
    wire [4:0] image_count;
    wire [3:0] error_code;
    bmp_preloader #(.WIDTH(4),.HEIGHT(2),.SCAN_FIRST(0),.SCAN_LIMIT(2),.IO_TIMEOUT(1024),.INIT_TIMEOUT(20)) dut(
        .clk(clk),.rst(rst),.start_ready(start_ready),.sd_ready(sd_ready),
        .sector_req(sector_req),.sector_lba(sector_lba),.sector_data(sector_data),
        .sector_valid(sector_valid),.sector_end(sector_end),.pixel_valid(pixel_valid),
        .pixel_ready(pixel_ready),.pixel_addr(pixel_addr),.pixel_rgb(pixel_rgb),
        .done(done),.image_count(image_count),.error_code(error_code),
        .route_cfg_ready(1'b1));
    task fail;
        input [8*160-1:0] reason;
        begin
            $display("TEST_FAIL tb_loader_errors: %0s",reason);
            $finish;
        end
    endtask
    task automatic tick(input integer n);repeat(n)@(negedge clk);endtask
    task automatic restart(input initialized);
        begin rst=1;sector_valid=0;sector_end=0;start_ready=initialized;sd_ready=initialized;tick(3);rst=0;end
    endtask
    task automatic send_sector(input integer bytes_to_send);
        integer k;
        begin
            wait(sector_req);@(negedge clk);
            for(k=0;k<bytes_to_send;k=k+1)begin sector_valid=1;sector_data=0;tick(1);end
            sector_valid=0;sector_end=1;tick(1);sector_end=0;tick(3);
        end
    endtask
    initial begin
        $dumpfile("tb_loader_errors.vcd");$dumpvars(1,tb_loader_errors);$dumpvars(1,dut);
        restart(0);wait(error_code);if(error_code!=1)fail("initialization watchdog");
        restart(1);send_sector(10);wait(error_code);if(error_code!=5)fail("short sector accepted");
        restart(1);wait(error_code);if(error_code!=4)fail("sector timeout");
        restart(1);send_sector(512);wait(error_code);
        if(error_code!=2||done||image_count||pixel_valid)fail("non-FAT32 volume accepted");
        $display("TEST_PASS tb_loader_errors missing card, short sector, timeout and non-FAT32 rejection");$finish;
    end
    initial begin #100000;fail("error tests timeout");end
endmodule
