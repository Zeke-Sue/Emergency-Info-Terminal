`timescale 1ns/1ps
module tb_viewport_cache;
    reg clk=0,rst=1,frame=0,complete=0,failed=0;
    always #5 clk=~clk;
    reg [7:0] view=0;
    wire toggle,ready;
    wire [3:0] image_id;
    wire [1:0] slot,visible_slot;
    wire [7:0] command_view;
    wire [15:0] resident,failed_images;
    image_cache_control #(.VIEWPORT_CACHE(1),.FAULT_CONTROL(1)) dut(
        .clk(clk),.rst(rst),.frame_tick(frame),.current_image(4'd0),.requested_image(4'd0),
        .lookup_image(4'd0),.pin_valid(1'b0),.pin_image(4'd0),.second_lookup_image(4'd0),
        .complete_toggle(complete),.load_failed(failed),.storage_fault(1'b0),
        .requested_view(view),.command_view(command_view),.command_toggle(toggle),
        .command_image(image_id),.command_slot(slot),.ready(ready),.resident(resident),
        .failed_images(failed_images),.display_slot(visible_slot));
    task tick;
        begin frame=1;@(negedge clk);frame=0;@(negedge clk);end
    endtask
    task finish_load;
        begin complete=toggle;repeat(5)@(negedge clk);end
    endtask
    reg [1:0] old_slot;
    reg old_toggle;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        tick();finish_load();if(ready)$fatal(1,"published before frame boundary");
        tick();if(!ready)$fatal(1,"initial frame missing");old_slot=visible_slot;
        view={2'd1,3'd2,3'd2};tick();
        if(slot==old_slot||command_view!=view)$fatal(1,"overwrote visible slot");
        finish_load();if(visible_slot!=old_slot||!ready)$fatal(1,"old frame lost while loading");
        tick();if(visible_slot==old_slot)$fatal(1,"replacement not committed");
        old_slot=visible_slot;
        view={2'd2,3'd4,3'd0};tick();
        view={2'd2,3'd0,3'd4};finish_load();tick();
        if(visible_slot!=old_slot)$fatal(1,"superseded viewport became visible");
        tick();if(command_view!=view)$fatal(1,"latest viewport not requested");
        failed=1;finish_load();tick();
        if(visible_slot!=old_slot||failed_images[0])$fatal(1,"failed replacement lost usable frame");
        old_toggle=toggle;tick();tick();if(toggle!=old_toggle)$fatal(1,"failed viewport retry storm");
        view=0;failed=0;tick();finish_load();tick();
        if(dut.views[visible_slot]!=0||!ready)$fatal(1,"Fit return failed");
        $display("TEST_PASS tb_viewport_cache atomic replacement, supersession, failed-load retention");$finish;
    end
    initial begin #20000;$fatal(1,"viewport cache timeout");end
endmodule
