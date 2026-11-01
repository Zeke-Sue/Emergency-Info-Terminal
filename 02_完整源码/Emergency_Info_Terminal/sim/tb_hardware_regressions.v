`timescale 1ns/1ps
module tb_preloaded_pan_scanout;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg [10:0] pan_x=160,pan_y=120;
    video_scanout #(.PRELOADED_VIEW(1)) dut(
        .clk(clk),.rst(rst),.cache_ready(1'b0),.zoom_scale(2'd1),
        .zoom_pan_x(pan_x),.zoom_pan_y(pan_y),.slide_active(1'b0),
        .image_index(4'd0),.transition_mode(3'd0),.line_ack_toggle(1'b0));
    initial begin
        repeat(3)@(negedge clk);
        force dut.h=260;force dut.v=120;
        #1;
        if(dut.source_x!==100||dut.current_source_y!==75)
            $fatal(1,"pre-cropped viewport must read (100,75), got (%0d,%0d)",dut.source_x,dut.current_source_y);
        pan_x=480;pan_y=360;#1;
        if(dut.source_x!==100||dut.current_source_y!==75)$fatal(1,"pan applied twice");
        $display("TEST_PASS preloaded framebuffer coordinates independent of original crop pan");$finish;
    end
endmodule

module tb_drill_republish;
    reg clk=0,rst=1,cmd=0,frame=0;
    always #5 clk=~clk;
    reg [2:0] op=0,kind=0;
    reg [15:0] id=1;
    reg [7:0] seq=1;
    wire ready,result,primary,cancel,settled;
    wire [3:0] code,count;
    wire [2:0] pkind;
    event_manager #(.CHECK_ROLE(1)) dut(.clk(clk),.rst(rst),.frame_tick(frame),.now_seconds(32'd0),
        .cmd_valid(cmd),.cmd_opcode(op),.cmd_source(2'd2),.cmd_kind(kind),.cmd_event_id(id),
        .cmd_sequence(seq),.cmd_level(3'd1),.cmd_drill(1'b1),.cmd_pending(1'b0),.cmd_region(3'd0),
        .cmd_time_trusted(1'b0),.cmd_remaining_seconds(16'd120),.cmd_role(2'd2),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),.cmd_ready(ready),
        .result_valid(result),.result_code(code),.primary_valid(primary),.primary_kind(pkind),
        .active_count(count),.cancel_notice(cancel),.settled(settled));
    task send;input [2:0] action,k;input [15:0] event_id;begin
        wait(ready);@(negedge clk);op=action;kind=k;id=event_id;cmd=1;
        @(negedge clk);cmd=0;wait(result);#1;
        if(code!=0)$fatal(1,"command rejected: %0d",code);
        @(negedge clk);frame=1;@(negedge clk);frame=0;
        repeat(3)@(negedge clk);wait(settled);@(negedge clk);seq=seq+1'b1;
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        send(0,0,1);if(!primary)$fatal(1,"earthquake missing state=%0d count=%0d record=%h",dut.state,count,dut.candidate_event);
        send(1,0,1);if(primary||!cancel)$fatal(1,"release missing");
        send(0,1,2);
        if(!primary||pkind!=1||cancel)$fatal(1,"old cancellation hides fresh fire drill");
        send(0,3,2);if(!primary||pkind!=3||count!=1)$fatal(1,"evacuation update missing");
        send(1,3,2);if(primary||count!=0||!cancel)$fatal(1,"evacuation cancel missing");
        send(0,0,3);if(!primary||pkind!=0||cancel)$fatal(1,"cannot publish after evacuation cancel");
        $display("TEST_PASS earthquake drill / cancel / fire drill / evacuation / cancel / republish");$finish;
    end
    initial begin #1000000;$fatal(1,"sequence timeout");end
endmodule

module tb_proxy_glyph_bounds;
    reg [10:0] x=468,y=35;
    wire [23:0] rgb;
    console_proxy_overlay dut(.x(x),.y(y),.status_valid(1'b1),.status(96'd0),
        .rgb_in(24'd0),.rgb_out(rgb));
    integer col;
    initial begin

        for(col=0;col<4;col=col+1)begin
            x=468+40*col;y=35;#1;
            if(rgb!==24'h101820)$fatal(1,"label leaks into gap, column %0d",col);
            x=490+40*col;y=16;#1;
            if(rgb!==24'h101820)$fatal(1,"label leaks into column spacing");
        end
        $display("TEST_PASS B proxy glyphs have bounded label and value cells");$finish;
    end
endmodule
