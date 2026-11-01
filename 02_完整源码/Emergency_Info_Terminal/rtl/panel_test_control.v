`timescale 1ns/1ps

module panel_test_control #(parameter integer SECOND_FRAMES=60)(
    input wire clk,rst,frame_tick,enable,blocked,
    input wire previous,next,toggle,level_next,voice_enable,
    output wire mode,output reg running,
    output reg [4:0] selection,output reg [2:0] level,
    output wire active,cancel,pending,evacuation,trusted,tone40k,synth_only,flash,
    output wire [2:0] kind,output reg [15:0] seconds,
    output reg restart_audio
);
    reg enabled_q,blocked_q,voice_q;
    reg [5:0] frames;
    assign mode=enable&&!blocked;

    assign active=mode&&selection>=16&&selection<=19;
    assign cancel=mode&&selection==20;
    assign pending=selection==17;
    assign evacuation=selection==19;
    assign trusted=selection==16;
    assign kind=selection==16 ? 0 : selection==19 ? 3 : 1;
    assign flash=mode&&frames<SECOND_FRAMES/2;

    assign tone40k=mode&&running&&!voice_enable;
    assign synth_only=mode&&(!voice_enable||!running);
    always @(posedge clk or posedge rst)
        if(rst)begin
            enabled_q<=0;blocked_q<=0;voice_q<=0;running<=0;selection<=0;level<=1;
            seconds<=12;frames<=0;restart_audio<=0;
        end else begin
            enabled_q<=enable;blocked_q<=blocked;voice_q<=voice_enable;restart_audio<=0;
            if(!enable||blocked)begin
                if(running||enable!=enabled_q||blocked!=blocked_q)restart_audio<=1;
                running<=0;frames<=0;selection<=0;seconds<=12;
            end else if(!enabled_q)begin
                running<=1;selection<=0;restart_audio<=1;frames<=0;seconds<=12;
            end else if(previous||next)begin
                selection<=previous ? (selection==0 ? 20 : selection-1'b1) :
                    (selection==20 ? 0 : selection+1'b1);
                running<=1;restart_audio<=1;frames<=0;seconds<=12;
            end else if(toggle)begin
                running<=!running;restart_audio<=1;frames<=0;
            end else if(voice_enable!=voice_q)restart_audio<=1;
            else if(level_next)level<=level==4 ? 1 : level+1'b1;
            else if(frame_tick&&running)begin
                if(frames==SECOND_FRAMES-1)begin
                    frames<=0;if(selection==16&&seconds!=0)seconds<=seconds-1'b1;
                end else frames<=frames+1'b1;
            end
        end
endmodule
