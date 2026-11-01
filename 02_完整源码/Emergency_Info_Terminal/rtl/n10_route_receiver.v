`timescale 1ns/1ps

module n10_route_receiver #(
    parameter [15:0] MAP_VERSION=16'h5001,
    parameter [31:0] GRAPH_CRC=32'hc6ef49a1,
    parameter integer TIMEOUT_FRAMES=179
)(
    input wire clk,rst,frame_tick,message_valid,
    input wire [7:0] message_type,input wire [95:0] payload,
    input wire cfg_ready,
    output reg cfg_write,output reg [7:0] cfg_key,
    output reg [31:0] cfg_segments,cfg_directions,
    output reg [2:0] cfg_exit,output reg [1:0] cfg_status,
    output reg cfg_commit,output reg batch_error,
    output wire [15:0] cfg_version,output reg [31:0] cfg_crc32
);
    reg receiving;
    reg [15:0] batch;
    reg [8:0] count;
    reg [$clog2(TIMEOUT_FRAMES+1)-1:0] idle_frames;
    reg [31:0] crc;
    reg [79:0] crc_word;
    reg [3:0] crc_left;
    wire route_message=message_valid&&(message_type==8'h23||message_type==8'h24||message_type==8'h25);
    wire entry_format_ok=payload[71:69]==0&&payload[68:67]<=2&&
        ((payload[68:67]==0&&payload[66:64]>=1&&payload[66:64]<=3)||
         (payload[68:67]!=0&&payload[66:0]==0))&&
        (payload[63:32]&~payload[31:0])==0;
    assign cfg_version=MAP_VERSION;
    function [31:0] crc_byte;
        input [31:0] old;input [7:0] b;integer i;reg [31:0] c;
        begin c=old^b;for(i=0;i<8;i=i+1)c=c[0] ? (c>>1)^32'hedb88320 : c>>1;
            crc_byte=c;end
    endfunction
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            receiving<=0;batch<=0;count<=0;idle_frames<=0;crc<=32'hffffffff;
            crc_word<=0;crc_left<=0;cfg_write<=0;cfg_key<=0;cfg_segments<=0;
            cfg_directions<=0;cfg_exit<=0;cfg_status<=3;cfg_commit<=0;batch_error<=0;cfg_crc32<=0;
        end else begin
            cfg_write<=0;cfg_commit<=0;batch_error<=0;
            if(crc_left!=0)begin
                crc<=crc_byte(crc,crc_word[7:0]);crc_word<=crc_word>>8;crc_left<=crc_left-1'b1;
            end
            if(frame_tick&&receiving)begin
                if(idle_frames==TIMEOUT_FRAMES-1)begin receiving<=0;batch_error<=1;end
                else idle_frames<=idle_frames+1'b1;
            end
            if(route_message)begin
                idle_frames<=0;
                if(message_type==8'h23)begin
                    count<=0;crc<=32'hffffffff;crc_left<=0;
                    if(cfg_ready&&payload[95:80]==MAP_VERSION&&payload[63:32]==GRAPH_CRC&&
                            payload[31:16]==21&&payload[15:8]==32&&payload[7:0]==3)begin
                        receiving<=1;batch<=payload[79:64];
                    end else begin receiving<=0;batch_error<=1;end
                end else if(!receiving||crc_left!=0||!cfg_ready)begin
                    receiving<=0;batch_error<=1;
                end else if(message_type==8'h24)begin
                    if(payload[95:80]!=batch||count>=256||payload[79:72]!=count[7:0]||!entry_format_ok)begin
                        receiving<=0;batch_error<=1;
                    end else begin
                        cfg_write<=1;cfg_key<=payload[79:72];cfg_segments<=payload[31:0];
                        cfg_directions<=payload[63:32];cfg_exit<=payload[66:64];cfg_status<=payload[68:67];
                        crc_word<=payload[79:0];crc_left<=10;count<=count+1'b1;
                    end
                end else begin
                    receiving<=0;
                    if(count==256&&payload[95:80]==MAP_VERSION&&payload[79:64]==batch&&
                            payload[63:32]==~crc&&payload[31:0]==GRAPH_CRC)begin
                        cfg_commit<=1;cfg_crc32<=~crc;
                    end else batch_error<=1;
                end
            end
        end
    end
endmodule
