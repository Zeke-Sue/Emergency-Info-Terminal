`timescale 1ns/1ps

module tb_viewport_transition_pin;
    reg clk=0,rst=1,frame=0,complete=0;
    reg [3:0] requested=0;
    always #5 clk=~clk;
    wire toggle,ready;
    wire [3:0] command;
    wire [15:0] resident;
    image_cache_control #(.VIEWPORT_CACHE(1),.FAST_PREVIEW(1),.TRANSITION_PIN(1)) dut(
        .clk(clk),.rst(rst),.frame_tick(frame),.current_image(4'd0),.requested_image(requested),
        .lookup_image(4'd0),.second_lookup_image(requested),.pin_valid(1'b0),.pin_image(requested),
        .complete_toggle(complete),.load_failed(1'b0),.storage_fault(1'b0),.requested_view(8'd0),
        .command_toggle(toggle),.command_image(command),.ready(ready),.resident(resident));
    task tick;begin frame=1;@(negedge clk);frame=0;@(negedge clk);end endtask
    task load;begin tick();complete=toggle;repeat(5)@(negedge clk);tick();end endtask
    integer i;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        load();load();load();
        if(!ready||!resident[1]||!resident[15])$fatal(1,"initial neighbor preload failed");
        requested=6;load();
        if(!resident[6])$fatal(1,"distant request not loaded");
        for(i=0;i<5;i=i+1)begin
            tick();
            if(!resident[6])$fatal(1,"prefetch evicted transition target before registered pin");
        end
        $display("TEST_PASS requested Fit view retained across transition-start / prefetch race");$finish;
    end
    initial begin #100000;$fatal(1,"viewport transition pin timeout");end
endmodule
