`timescale 1ns/1ps
module tb_human_stage_audio;
    reg clk=0,rst=1,frame=1,alarm=0,drill=1,pending=0,complete=0,consume=0,failed=0,io_failed=0,configured=1;
    always #5 clk=~clk;
    reg [2:0] kind=0;
    reg [7:0] purpose=0;
    wire request,alarm_asset,voice;
    wire [3:0] selected;wire [7:0] subtitle;
    human_stage_audio_requests dut(.clk(clk),.rst(rst),.frame_tick(frame),.ready(1'b1),
        .narration_enable(1'b1),.configuration_valid(configured),.image_index(4'd3),
        .configured_narration_index(4'd3),.alarm_active(alarm),.alarm_drill(drill),
        .alarm_pending(pending),.alarm_kind(kind),.asset_complete(complete),
        .asset_purpose(purpose),.asset_samples(32'd3),.consume(consume),.asset_failed(failed),.io_failed(io_failed),
        .request(request),.asset_index(selected),.alarm_asset(alarm_asset),
        .voice_asset(voice),.voice_subtitle(subtitle));
    task expect_asset;
        input [3:0] index;input is_voice;
        begin @(negedge clk);
            if(!request||selected!==index||voice!==is_voice)
                $fatal(1,"stage selection wanted %0d voice %0b got %0d %0b req %0b",index,is_voice,selected,voice,request);
        end
    endtask
    task finish;
        begin
            purpose=8'h21+selected;complete=1;@(negedge clk);complete=0;
            consume=1;repeat(3)@(negedge clk);consume=0;
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;expect_asset(3,0);
        alarm=1;expect_asset(8,1);finish();
        if(!request||selected!=10||voice)$fatal(1,"quake speech did not yield to alarm");
        kind=1;pending=1;expect_asset(9,1);
        pending=0;expect_asset(12,1);
        kind=3;expect_asset(13,1);finish();
        if(!request||selected!=11||voice)$fatal(1,"evac speech did not yield to alarm");
        alarm=0;expect_asset(14,1);finish();expect_asset(3,0);
        alarm=1;drill=0;kind=0;expect_asset(10,0);
        alarm=0;@(negedge clk);expect_asset(3,0);
        alarm=1;drill=1;expect_asset(8,1);
        purpose=8'h29;complete=1;@(negedge clk);complete=0;failed=1;@(negedge clk);failed=0;
        if(!request||selected!=10||voice)$fatal(1,"rejected speech did not yield to alarm");
        configured=0;@(negedge clk);if(request||voice)$fatal(1,"invalid manifest played");
        configured=1;expect_asset(8,1);
        io_failed=1;@(negedge clk);io_failed=0;
        if(!request||selected!=10||voice)$fatal(1,"I/O failure before measurement did not fall back");
        $display("TEST_PASS five human stages, preemption, exact length, real-event exclusion, rejection and manifest gate");$finish;
    end
    initial begin #10000;$fatal(1,"human stage timeout");end
endmodule
