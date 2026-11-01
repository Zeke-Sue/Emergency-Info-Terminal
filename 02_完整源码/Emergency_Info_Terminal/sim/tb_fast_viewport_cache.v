`timescale 1ns/1ps
module tb_fast_viewport_cache;
    reg clk=0,rst=1,frame=0,complete=0,failed=0;
    always #5 clk=~clk;
    reg [7:0] view=0;
    wire toggle,ready,pending;
    wire [3:0] image_id;
    wire [1:0] slot,visible_slot,lookup;
    wire [7:0] command_view;
    wire [15:0] resident,failed_images;
    image_cache_control #(.VIEWPORT_CACHE(1),.FAST_PREVIEW(1),.FAULT_CONTROL(1)) dut(
        .clk(clk),.rst(rst),.frame_tick(frame),.current_image(4'd0),.requested_image(4'd0),
        .lookup_image(4'd0),.lookup_slot(lookup),.pin_valid(1'b0),.pin_image(4'd0),.second_lookup_image(4'd0),
        .complete_toggle(complete),.load_failed(failed),.storage_fault(1'b0),
        .requested_view(view),.command_view(command_view),.command_toggle(toggle),
        .command_image(image_id),.command_slot(slot),.ready(ready),.resident(resident),
        .failed_images(failed_images),.display_slot(visible_slot),.view_pending(pending));
    task tick;begin frame=1;@(negedge clk);frame=0;@(negedge clk);end endtask
    task finish_load;begin complete=toggle;repeat(5)@(negedge clk);end endtask
    reg [1:0] base_slot;
    reg saved_toggle;
    integer n;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        tick();finish_load();if(ready)$fatal(1,"published before vertical blanking");
        tick();if(!ready)$fatal(1,"initial image missing");base_slot=visible_slot;
        view={2'd1,3'd2,3'd2};#1;
        if(visible_slot!=base_slot||!pending||!ready)$fatal(1,"no immediate full-image preview");
        tick();if(slot==base_slot||command_view!=view)$fatal(1,"overwriting preview base");
        finish_load();tick();
        if(visible_slot==base_slot||pending||lookup!=visible_slot)$fatal(1,"detail not published");
        for(n=0;n<12;n=n+1)begin
            view={2'd2,n[2:0],3'd0};#1;
            if(visible_slot!=base_slot||!pending||!ready)$fatal(1,"pan waits for TF before preview");
            tick();if(slot==base_slot)$fatal(1,"evicted full-resolution preview base");
            finish_load();tick();
            if(pending||!ready||!dut.valid[base_slot])$fatal(1,"detail/base retention failure");
        end
        view={2'd1,3'd0,3'd4};tick();
        view={2'd1,3'd4,3'd0};finish_load();tick();
        if(visible_slot!=base_slot||!pending)$fatal(1,"superseded crop replaced live preview");
        tick();failed=1;finish_load();tick();
        if(visible_slot!=base_slot||failed_images[0])$fatal(1,"failed detail lost preview");
        saved_toggle=toggle;tick();tick();
        if(toggle!=saved_toggle)$fatal(1,"failed viewport retry storm");
        view=0;#1;
        if(visible_slot!=base_slot||pending||!ready)$fatal(1,"return to Fit requires reload");
        $display("TEST_PASS instant pan preview, atomic detail refinement, supersession/failure, Fit without TF reload");$finish;
    end
    initial begin #100000;$fatal(1,"fast viewport timeout");end
endmodule
