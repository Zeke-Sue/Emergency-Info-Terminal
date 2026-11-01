`timescale 1ns/1ps

module alarm_scene_control #(parameter integer DIRECT_RELEASE=0)(
    input wire clk,rst,scene_tick,
    input wire alarm_active,input wire [2:0] alarm_kind,alarm_level,
    input wire alarm_drill,cancel_notice,flash_on,countdown_trusted,
    input wire [15:0] countdown_seconds,
    output reg [6:0] opacity,
    output reg [2:0] level,
    output reg drill,cancel,flash,trusted,
    output reg [15:0] seconds,
    output wire visible
);
    localparam IDLE=0,NOTICE=1,URGENT=2,RELEASE=3;
    reg [1:0] state;
    assign visible=opacity!=0;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=IDLE;opacity<=0;level<=0;drill<=0;
            cancel<=0;flash<=0;trusted<=0;seconds<=0;
        end else if(scene_tick)begin
            if(alarm_active&&!cancel_notice)begin
                level<=alarm_level;drill<=alarm_drill;cancel<=0;
                flash<=flash_on;trusted<=countdown_trusted;seconds<=countdown_seconds;
                if(alarm_kind==2)begin
                    state<=NOTICE;
                    if(state!=NOTICE)opacity<=8;
                    else if(opacity<64)opacity<=opacity+7'd8;
                end else begin state<=URGENT;opacity<=64;end
            end else if(DIRECT_RELEASE&&cancel_notice)begin

                state<=RELEASE;opacity<=64;cancel<=1;trusted<=0;flash<=0;
            end else if(state==NOTICE||state==URGENT)begin

                state<=RELEASE;opacity<=62;cancel<=1;trusted<=0;flash<=0;
            end else if(state==RELEASE)begin
                if(opacity>2)opacity<=opacity-7'd2;
                else begin opacity<=0;state<=IDLE;end
            end
        end
    end
endmodule
