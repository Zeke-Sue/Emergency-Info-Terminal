`timescale 1ns/1ps
module tb_demo_playlist;
    reg clk=0,rst=1,frame=0,alarm=0,allowed=0;
    always #5 clk=~clk;
    reg [3:0] image_id=0;
    reg [5:0] cue_address=0;
    wire [3:0] mapped,selected;
    wire [31:0] cue_sample;
    wire [7:0] subtitle;
    wire last,request,alarm_asset;
    demo_playlist_rom rom(.image_id(image_id),.cue_address(cue_address),
        .asset_index(mapped),.cue_sample(cue_sample),.cue_subtitle(subtitle),.cue_last(last));
    media_audio_requests #(.CONFIGURED_PLAYLIST(1)) requests(
        .clk(clk),.rst(rst),.frame_tick(frame),.ready(1'b1),.narration_enable(1'b1),
        .image_index(image_id),.alarm_active(alarm),.alarm_kind(3'd0),
        .configured_narration_index(mapped),.configuration_valid(allowed),
        .request(request),.asset_index(selected),.alarm_asset(alarm_asset));
    integer i;
    initial begin
        repeat(3)@(negedge clk);rst=0;frame=1;
        @(negedge clk);if(request)$fatal(1,"unvalidated list played");
        allowed=1;image_id=14;
        @(negedge clk);if(!request||selected!=8)$fatal(1,"fixed mapping reverted to modulo");
        for(i=0;i<64;i=i+1)begin
            cue_address=i;#1;
            if(cue_sample!=(i%4)*240000||subtitle<1||subtitle>16||last!=(i%4==3))
                $fatal(1,"cue association mismatch");
        end
        @(negedge clk);alarm=1;frame=0;
        @(negedge clk);if(!request||selected!=10||!alarm_asset)$fatal(1,"alarm priority lost");
        $display("TEST_PASS tb_demo_playlist fixed mapping, sample cues and alarm priority");$finish;
    end
    initial begin #20000;$fatal(1,"playlist timeout");end
endmodule
