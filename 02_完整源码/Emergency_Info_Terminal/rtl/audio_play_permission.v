// 管理远端播放许可及超时状态，阻止失效许可继续驱动外部录音。
`timescale 1ns/1ps

module audio_play_permission #(
    parameter integer TIMEOUT_FRAMES=180
)(
    input wire clk,rst,frame_tick,snapshot_apply,
    input wire [31:0] parameters,
    output reg allowed
);
    localparam integer AGE_BITS=TIMEOUT_FRAMES<2 ? 1 : $clog2(TIMEOUT_FRAMES);
    reg [AGE_BITS-1:0] age;
    always @(posedge clk or posedge rst)begin
        if(rst)begin allowed<=0;age<=0;end
        else if(snapshot_apply)begin
            allowed<=parameters[31:20]==12'ha61&&parameters[0];age<=0;
        end else if(frame_tick&&allowed)begin
            if(age==TIMEOUT_FRAMES-1)begin allowed<=0;age<=0;end
            else age<=age+1'b1;
        end
    end
endmodule
