`timescale 1ns/1ps
module tb_image_cache_16;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg frame_tick=0;
    reg [3:0] current_image=0,requested_image=0,lookup_image=0;
    reg complete_toggle=0,load_failed=0;
    wire command_toggle,ready;
    wire [3:0] command_image;
    wire [1:0] command_slot,display_slot,lookup_slot;
    wire [15:0] resident;
    image_cache_control #(.IMAGE_COUNT(16)) dut(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),
        .current_image(current_image),.requested_image(requested_image),
        .lookup_image(lookup_image),.complete_toggle(complete_toggle),
        .load_failed(load_failed),.command_toggle(command_toggle),
        .command_image(command_image),.command_slot(command_slot),
        .ready(ready),.resident(resident),.display_slot(display_slot),
        .lookup_slot(lookup_slot));

    integer frame_div=0;
    always @(posedge clk)begin
        frame_tick<=0;
        if(rst)frame_div<=0;
        else if(frame_div==5)begin frame_div<=0;frame_tick<=1;end
        else frame_div<=frame_div+1;
    end

    reg command_seen=0;
    integer load_delay=-1;
    reg [3:0] loading_image;
    always @(posedge clk)begin
        if(rst)begin command_seen<=0;load_delay<=-1;complete_toggle<=0;end
        else begin
            if(command_toggle!=command_seen&&load_delay<0)begin
                command_seen<=command_toggle;loading_image<=command_image;load_delay<=3;
            end else if(load_delay==0)begin
                complete_toggle<=command_seen;load_delay<=-1;
            end else if(load_delay>0)load_delay<=load_delay-1;
        end
    end

    function integer bit_count;input [15:0] value;integer i;
        begin bit_count=0;for(i=0;i<16;i=i+1)bit_count=bit_count+value[i];end
    endfunction
    task fail;input [8*120-1:0] msg;begin
        $display("TEST_FAIL tb_image_cache_16: %0s",msg);$finish;end endtask
    task wait_resident;input [3:0] image;integer timeout;
        begin
            timeout=0;
            while(!resident[image]&&timeout<500)begin @(posedge clk);timeout=timeout+1;end
            if(!resident[image])fail("requested image did not become resident");
        end
    endtask
    task commit_current;input [3:0] image;
        begin
            @(posedge frame_tick);#1;current_image=image;
            wait_resident(image);
            @(posedge clk);#1;
            if(!ready||dut.tags[display_slot]!=image)
                fail("display slot did not track frame-boundary commit");
        end
    endtask

    always @(negedge clk)if(!rst)begin
        if(bit_count(resident)>4)fail("more than four physical slots became resident");
        if(load_delay>=0&&resident[loading_image]&&dut.tags[command_slot]==loading_image)
            fail("replacement image became visible before load completion");
    end

    initial begin
        repeat(4)@(negedge clk);rst=0;
        wait_resident(0);wait_resident(1);wait_resident(15);
        if(bit_count(resident)!=3||!ready)fail("initial current/next/previous set");

        requested_image=7;wait_resident(7);
        if(!resident[0]||!resident[1]||!resident[15]||bit_count(resident)!=4)
            fail("distant request did not use the spare slot");
        commit_current(7);
        wait_resident(8);wait_resident(6);
        lookup_image=8;@(posedge clk);#1;
        if(dut.tags[lookup_slot]!=8)fail("lookup slot tag mismatch");

        requested_image=15;wait_resident(15);commit_current(15);
        wait_resident(14);wait_resident(0);
        if(!resident[15]||!resident[14]||!resident[0])
            fail("image 15 wrap neighbours were not prefetched");

        requested_image=0;commit_current(0);wait_resident(1);wait_resident(15);
        if(!resident[0]||!resident[1]||!resident[15]||bit_count(resident)>4)
            fail("image 0 wrap neighbours were not restored");
        $display("TEST_PASS tb_image_cache_16 four slots, distant replacement, atomic completion and 15/0 wrap");
        $finish;
    end
    initial begin #200000;
        fail("timeout");
    end
endmodule
