`timescale 1ns/1ps
module tb_bad_image_skip;
    reg clk=0,rst=1,frame_tick=0,next_event=0,previous_event=0;
    always #5 clk=~clk;
    wire [3:0] image,desired,command_image;
    wire [15:0] resident,failed;
    wire ready,command_toggle;
    wire [1:0] command_slot;
    reg complete=0,load_failed=0,seen=0;
    reg [15:0] corrupt=16'h0003;
    reg storage_fault=0;
    integer delay_left=-1,divider=0,requests=0,i,before_requests;
    integer attempts[0:15];
    reg [3:0] loading;
    image_cache_control #(.IMAGE_COUNT(8),.FAULT_CONTROL(1)) cache(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.current_image(image),
        .requested_image(desired),.lookup_image(image),.pin_valid(1'b0),
        .pin_image(4'd0),.second_lookup_image(image),.complete_toggle(complete),
        .load_failed(load_failed),.storage_fault(storage_fault),
        .command_toggle(command_toggle),.command_image(command_image),
        .command_slot(command_slot),.ready(ready),.resident(resident),
        .failed_images(failed));
    player_control #(.CLK_HZ(1000),.IMAGE_COUNT(8),.FADE_STEPS(1),
        .USE_CACHE(1),.SKIP_FAILED(1)) player(
        .clk(clk),.rst(rst),.ready(ready),.frame_tick(frame_tick),
        .next_event(next_event),.previous_event(previous_event),.auto_event(1'b0),
        .period_event(1'b0),.effect_select(3'd0),.external_play(1'b0),
        .external_activity(1'b0),.follow_narration(1'b0),.external_period(2'd0),
        .resident(resident),.failed_images(failed),.emergency_abort(1'b0),
        .transition_duration(2'd0),.transition_easing(1'b0),
        .desired_image(desired),.image_index(image));
    task fail;
        input [799:0] reason;
        begin $display("TEST_FAIL tb_bad_image_skip %0s image=%0d desired=%0d failed=%h resident=%h",reason,image,desired,failed,resident);$finish;end
    endtask
    always @(posedge clk)begin
        frame_tick<=0;
        if(rst)begin
            divider<=0;delay_left<=-1;seen<=0;complete<=0;load_failed<=0;requests<=0;
            for(i=0;i<16;i=i+1)attempts[i]<=0;
        end else begin
            if(divider==9)begin divider<=0;frame_tick<=1;end
            else divider<=divider+1;
            if(command_toggle!=seen && delay_left<0)begin
                if(ready && command_slot==cache.display_slot)fail("visible slot overwritten");
                if(failed[command_image])fail("blacklisted image requested again");
                seen<=command_toggle;loading<=command_image;delay_left<=23;
                attempts[command_image]<=attempts[command_image]+1;requests<=requests+1;
            end else if(delay_left==0)begin
                complete<=seen;load_failed<=corrupt[loading];delay_left<=-1;
            end else if(delay_left>0)delay_left<=delay_left-1;
        end
    end
    task navigate;
        input reverse;
        begin @(negedge clk);previous_event=reverse;next_event=!reverse;
            @(negedge clk);previous_event=0;next_event=0;end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        wait(ready && image==2);
        if(failed[1:0]!=3 || attempts[0]!=1 || attempts[1]!=1)fail("bad first images not skipped once");
        navigate(1);wait(image==7);
        if(!ready)fail("reverse skip lost current frame");
        navigate(0);wait(image==2);
        storage_fault=1;repeat(100)@(negedge clk);before_requests=requests;
        navigate(0);repeat(100)@(negedge clk);
        if(requests!=before_requests)fail("storage fault did not inhibit requests");
        storage_fault=0;
        @(negedge clk);rst=1;corrupt=16'hffff;
        repeat(4)@(negedge clk);rst=0;
        wait(failed[7:0]==8'hff);
        repeat(200)@(negedge clk);
        if(ready || requests!=8)fail("all-bad catalog did not terminate boundedly");
        for(i=0;i<8;i=i+1)if(attempts[i]!=1)fail("all-bad image retried indefinitely");
        @(negedge clk);rst=1;corrupt=0;
        repeat(4)@(negedge clk);rst=0;
        wait(ready);if(image!=0 || failed!=0)fail("new session did not clear blacklist");
        $display("TEST_PASS tb_bad_image_skip startup failures, forward/reverse skip, protected frame, all-bad bound, storage halt, new session");$finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
