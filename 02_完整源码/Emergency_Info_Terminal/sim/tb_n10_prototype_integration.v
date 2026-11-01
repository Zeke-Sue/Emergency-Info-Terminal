`timescale 1ns/1ps
module tb_n10_prototype_integration;
    reg clk=0,rst=1,frame_tick=0,pixel_valid=1,flash_on=1;
    reg [7:0] blocked=0;reg [10:0] x=0,y=0;always #5 clk=~clk;
    wire cfg_write,cfg_commit,cfg_crc_ok,cfg_checked,cfg_assets_match;
    wire [7:0] cfg_key;wire [31:0] cfg_segments,cfg_directions,cfg_crc;
    wire [2:0] cfg_exit;wire [1:0] cfg_status;wire [15:0] cfg_version;
    n10_prototype_route_loader loader(.clk(clk),.rst(rst),.cfg_write(cfg_write),
        .cfg_blocked_key(cfg_key),.cfg_segment_mask(cfg_segments),
        .cfg_direction_mask(cfg_directions),.cfg_exit(cfg_exit),
        .cfg_status(cfg_status),.cfg_commit(cfg_commit),.cfg_crc_ok(cfg_crc_ok),
        .cfg_checked(cfg_checked),.cfg_assets_match(cfg_assets_match),
        .cfg_version(cfg_version),.cfg_crc32(cfg_crc));
    wire [5:0] segment;wire [7:0] phase;wire blocked_exit_pixel;
    n10_prototype_segment_map map(.x(x),.y(y),.blocked_set(blocked),
        .segment_id(segment),.segment_phase(phase),
        .blocked_exit_pixel(blocked_exit_pixel));
    wire route_valid,reachable,all_blocked,unreachable,overlay,fallback,changed;
    wire [2:0] selected_exit;wire [1:0] status;
    wire [31:0] selected_segments,selected_directions;wire [23:0] rgb;
    wire [15:0] active_version;wire [31:0] active_crc;
    n10_route_engine routes(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .cfg_write(cfg_write),.cfg_blocked_key(cfg_key),
        .cfg_segment_mask(cfg_segments),.cfg_direction_mask(cfg_directions),
        .cfg_exit(cfg_exit),.cfg_status(cfg_status),.cfg_commit(cfg_commit),
        .cfg_crc_ok(cfg_crc_ok),.cfg_checked(cfg_checked),
        .cfg_assets_match(cfg_assets_match),.cfg_version(cfg_version),
        .cfg_crc32(cfg_crc),.blocked_set(blocked),.pixel_valid(pixel_valid),
        .segment_id(segment),.segment_phase(phase),
        .blocked_exit_pixel(blocked_exit_pixel),.flash_on(flash_on),
        .route_valid(route_valid),.route_reachable(reachable),
        .all_exits_blocked(all_blocked),.route_unreachable(unreachable),
        .selected_exit(selected_exit),.selected_status(status),
        .selected_segment_mask(selected_segments),
        .selected_direction_mask(selected_directions),
        .overlay_valid(overlay),.overlay_rgb(rgb),.safe_fallback(fallback),
        .route_changed(changed),.active_version(active_version),.active_crc32(active_crc));
    integer k;
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tb_n10_prototype_integration: %0s blocked=%02x",msg,blocked);$finish;end endtask
    task pulse_frame;begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;wait(cfg_commit);@(posedge clk);pulse_frame;
        repeat(3)@(posedge clk);#1;
        if(!route_valid||active_version!=16'h4101||active_crc!=32'h21608fac)
            fail("prototype table did not commit");
        for(k=0;k<256;k=k+1)begin
            blocked=k;pulse_frame;repeat(2)@(posedge clk);#1;
            if((k&3)==3)begin
                if(!all_blocked||status!=1||selected_exit!=0||selected_segments!=0)
                    fail("all-blocked table entry");
            end else if(k&1)begin
                if(!reachable||selected_exit!=2||selected_segments!=32'h1c)
                    fail("alternate route table entry");
            end else if(!reachable||selected_exit!=1||selected_segments!=32'h3)
                fail("normal route table entry");
        end
        blocked=0;x=300;y=260;pulse_frame;repeat(2)@(posedge clk);#1;
        if(segment!=1||!overlay)fail("normal route pixel");
        blocked=1;x=420;y=202;pulse_frame;repeat(2)@(posedge clk);#1;
        if(segment!=5||!overlay)fail("alternate route pixel");
        x=210;y=326;#1;if(!blocked_exit_pixel||!overlay||rgb!=24'hff2020)
            fail("blocked exit marker");
        $display("TEST_PASS tb_n10_prototype_integration 256/256 states, five segments, reroute and blocked marker");$finish;
    end
    initial begin #1000000;fail("timeout");end
endmodule
