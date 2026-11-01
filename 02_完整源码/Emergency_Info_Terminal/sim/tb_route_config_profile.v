`timescale 1ns/1ps
module tb_bypass_config;
    reg clk=0,rst=1,request=0;
    always #5 clk=~clk;
    wire cfg_write,cfg_commit,cfg_valid;
    wire [3:0] cfg_error;
    reg saw_default_config=0,saw_image_request=0;
    bmp_preloader #(.WIDTH(8),.HEIGHT(4),.ON_DEMAND(1),
        .ENABLE_ROUTE_CONFIG(0)) bypass(
        .clk(clk),.rst(rst),.start_ready(1'b0),.sd_ready(1'b0),
        .load_request(request),.load_image(4'd3),.load_slot(2'd2),.load_view(8'd0),
        .sector_data(8'd0),.sector_valid(1'b0),.sector_end(1'b0),
        .pixel_ready(1'b1),.route_cfg_ready(1'b1),
        .route_cfg_write(cfg_write),.route_cfg_commit(cfg_commit),
        .route_config_valid(cfg_valid),.route_config_error(cfg_error),
        .audio_open_req(1'b0),.audio_file_index(4'd0),.audio_file_ready(1'b1));
    bmp_preloader #(.WIDTH(8),.HEIGHT(4),.ON_DEMAND(1)) local_config(
        .clk(clk),.rst(rst),.start_ready(1'b0),.sd_ready(1'b0),
        .load_request(1'b0),.load_image(4'd0),.load_slot(2'd0),.load_view(8'd0),
        .sector_data(8'd0),.sector_valid(1'b0),.sector_end(1'b0),
        .pixel_ready(1'b1),.route_cfg_ready(1'b1),
        .audio_open_req(1'b0),.audio_file_index(4'd0),.audio_file_ready(1'b1));
    task fail;input [8*100-1:0] reason;begin
        $display("TEST_FAIL route CONFIG bypass: %0s",reason);$finish;
    end endtask
    always @(negedge clk)if(!rst)begin
        if(cfg_write!==0||cfg_commit!==0||cfg_valid!==0||cfg_error!==0)
            fail("disabled route interface was not inactive");
        if(local_config.open_req&&local_config.files.open_type==3)
            saw_default_config=1;
        if(bypass.open_req)begin
            if(bypass.files.open_type!==1||bypass.files.file_index!==3||
               bypass.selected_slot!==2)fail("image request changed by bypass");
            saw_image_request=1;
        end
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;
        force bypass.fat_mounted=1'b1;
        force bypass.catalog_config_found=1'b1;
        force local_config.fat_mounted=1'b1;
        force local_config.catalog_config_found=1'b1;
        repeat(8)@(negedge clk);
        if(!saw_default_config||bypass.state!==bypass.WAIT_MOUNT||bypass.open_req)
            fail("CONFIG presence did not respect the profile");
        request=1;@(negedge clk);request=0;
        repeat(5)@(negedge clk);
        if(!saw_image_request)fail("image load was blocked by unused CONFIG");
        $display("TEST_PASS default CONFIG retained; board profile ignores CONFIG and preserves image request");
        $finish;
    end
    initial begin #100000;fail("bounded timeout");end
endmodule

module tb_media_board_route_profile;
    tb_media_player test();
    defparam test.dut.BOARD_ROUTE_AUTHORITY=1;
endmodule
