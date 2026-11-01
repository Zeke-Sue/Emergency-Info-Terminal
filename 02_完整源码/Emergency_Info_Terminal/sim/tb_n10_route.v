`timescale 1ns/1ps
module tb_n10_route;
    reg clk=0,rst=1,frame_tick=0,cfg_write=0,cfg_commit=0;
    reg cfg_crc_ok=0,cfg_checked=0,cfg_assets_match=0;
    reg [7:0] cfg_key=0,blocked=0,segment_phase=0;
    reg [31:0] cfg_segments=0,cfg_directions=0;
    reg [2:0] cfg_exit=0;reg [1:0] cfg_status=0;
    reg [15:0] cfg_version=0;reg [31:0] cfg_crc=0;
    reg pixel_valid=0,blocked_exit_pixel=0,flash_on=0;
    reg [5:0] segment=0;
    wire route_valid,reachable,all_blocked,unreachable,overlay_valid,fallback,changed;
    wire [2:0] selected_exit;wire [1:0] selected_status;
    wire [31:0] selected_segments,selected_directions;wire [23:0] rgb;
    wire [15:0] active_version;wire [31:0] active_crc;
    always #5 clk=~clk;
    n10_route_engine dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .cfg_write(cfg_write),.cfg_blocked_key(cfg_key),
        .cfg_segment_mask(cfg_segments),.cfg_direction_mask(cfg_directions),
        .cfg_exit(cfg_exit),.cfg_status(cfg_status),.cfg_commit(cfg_commit),
        .cfg_crc_ok(cfg_crc_ok),.cfg_checked(cfg_checked),
        .cfg_assets_match(cfg_assets_match),.cfg_version(cfg_version),
        .cfg_crc32(cfg_crc),.blocked_set(blocked),.pixel_valid(pixel_valid),
        .segment_id(segment),.segment_phase(segment_phase),
        .blocked_exit_pixel(blocked_exit_pixel),.flash_on(flash_on),
        .route_valid(route_valid),.route_reachable(reachable),
        .all_exits_blocked(all_blocked),.route_unreachable(unreachable),
        .selected_exit(selected_exit),.selected_status(selected_status),
        .selected_segment_mask(selected_segments),
        .selected_direction_mask(selected_directions),
        .overlay_valid(overlay_valid),.overlay_rgb(rgb),
        .safe_fallback(fallback),.route_changed(changed),
        .active_version(active_version),.active_crc32(active_crc));
    task fail;input [8*100-1:0] msg;begin $display("TEST_FAIL tb_n10_route: %0s",msg);$finish;end endtask
    task write_entry;
        input [7:0] key;input [31:0] segs,dirs;input [2:0] ex;input [1:0] status;
        begin @(negedge clk);cfg_key=key;cfg_segments=segs;cfg_directions=dirs;
            cfg_exit=ex;cfg_status=status;cfg_write=1;
            @(negedge clk);cfg_write=0;end
    endtask
    task pulse_frame;begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end endtask
    task settle_lookup;begin repeat(2)@(posedge clk);#1;end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        write_entry(0,32'h00000003,32'h00000002,1,0);
        write_entry(1,32'h0000001c,32'h00000000,2,0);
        write_entry(3,0,0,0,1);
        write_entry(4,0,0,0,2);
        @(negedge clk);cfg_version=16'h1234;cfg_crc=32'h89abcdef;
        cfg_crc_ok=1;cfg_checked=1;cfg_assets_match=1;cfg_commit=1;
        @(negedge clk);cfg_commit=0;cfg_crc_ok=0;cfg_checked=0;cfg_assets_match=0;
        if(route_valid)fail("table changed before frame boundary");
        pulse_frame;settle_lookup;
        if(!route_valid||!reachable||selected_exit!=1||selected_status!=0||
                active_version!=16'h1234||active_crc!=32'h89abcdef)
            fail("initial 72-bit table commit");
        pixel_valid=1;segment=1;segment_phase=0;#1;
        if(!overlay_valid||rgb!=24'hb0ffb0)fail("initial route highlight");
        segment=2;segment_phase=0;#1;
        if(!selected_directions[1]||!overlay_valid)fail("direction mask lookup");
        blocked=1;settle_lookup;
        if(selected_exit!=1)fail("route tore before frame commit");
        pulse_frame;settle_lookup;
        if(selected_exit!=2||selected_segments!=32'h1c)fail("blocked-set lookup");
        blocked_exit_pixel=1;flash_on=1;#1;
        if(!overlay_valid||rgb!=24'hff2020)fail("blocked exit red marker");
        flash_on=0;#1;
        if(!overlay_valid||rgb!=24'hff2020)fail("blocked marker disappeared in flash off phase");
        blocked_exit_pixel=0;blocked=3;pulse_frame;settle_lookup;
        if(!all_blocked||reachable||fallback)fail("all-exits-blocked status");
        blocked=4;pulse_frame;settle_lookup;
        if(!unreachable||reachable||fallback)fail("unreachable status");
        blocked=0;pulse_frame;settle_lookup;
        write_entry(0,32'h1,0,7,0);
        @(negedge clk);cfg_crc_ok=1;cfg_checked=0;cfg_assets_match=1;cfg_commit=1;
        @(negedge clk);cfg_commit=0;cfg_crc_ok=0;pulse_frame;settle_lookup;
        if(selected_exit!=1||active_version!=16'h1234)
            fail("unchecked table changed active bank");
        $display("TEST_PASS tb_n10_route v4.1 72-bit banks, direction animation, status fallback and checked atomic commit");$finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
