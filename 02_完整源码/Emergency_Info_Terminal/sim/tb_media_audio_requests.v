`timescale 1ns/1ps
module tb_media_audio_requests;
    reg clk=0,rst=1,frame=0,ready=0,enabled=1,alarm=0;
    reg [3:0] image_id=0;reg [2:0] kind=0;
    wire request,alarm_asset;wire [3:0] index;
    always #5 clk=~clk;
    media_audio_requests dut(.clk(clk),.rst(rst),.frame_tick(frame),.ready(ready),
        .narration_enable(enabled),.image_index(image_id),.alarm_active(alarm),
        .alarm_kind(kind),.request(request),.asset_index(index),.alarm_asset(alarm_asset));
    integer i,count=0;
    always @(posedge clk)if(request)count=count+1;
    task fail;input [511:0] why;
        begin $display("TEST_FAIL tb_media_audio_requests %0s",why);$finish;end
    endtask
    task pulse_frame;begin frame=1;@(negedge clk);frame=0;@(negedge clk);end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        pulse_frame();if(count!=0)fail("unready normal stream");
        ready=1;
        for(i=0;i<16;i=i+1)begin
            image_id=i;pulse_frame();
            if(index!=(i%10)||alarm_asset||count!=i+1)fail("16 images / 10 narration mapping");
        end
        pulse_frame();if(count!=16)fail("duplicate normal request");
        alarm=1;ready=0;repeat(2)@(negedge clk);
        if(index!=10||!alarm_asset||count!=17)fail("quake priority without frame/cache");
        kind=1;repeat(2)@(negedge clk);
        if(index!=11||count!=18)fail("evacuation purpose switch");
        image_id=4;pulse_frame();if(index!=11||count!=18)fail("ordinary change preempted alarm");
        alarm=0;ready=1;pulse_frame();
        if(index!=4||alarm_asset||count!=19)fail("narration restart after alarm");
        $display("TEST_PASS tb_media_audio_requests stable identity, all 16 images, alarm priority and resume");$finish;
    end
endmodule
