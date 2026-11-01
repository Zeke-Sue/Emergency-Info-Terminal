`timescale 1ns/1ps

module route_config_cdc(
    input wire src_clk,input wire src_rst,
    input wire src_write,input wire [7:0] src_key,
    input wire [31:0] src_segments,input wire [31:0] src_directions,
    input wire [2:0] src_exit,input wire [1:0] src_status,
    input wire src_commit,input wire src_crc_ok,input wire src_checked,
    input wire src_assets_match,input wire [15:0] src_version,
    input wire [31:0] src_crc32,output wire src_ready,output reg src_overflow,
    input wire dst_clk,input wire dst_rst,
    output reg dst_write,output reg [7:0] dst_key,
    output reg [31:0] dst_segments,output reg [31:0] dst_directions,
    output reg [2:0] dst_exit,output reg [1:0] dst_status,
    output reg dst_commit,output reg dst_crc_ok,output reg dst_checked,
    output reg dst_assets_match,output reg [15:0] dst_version,
    output reg [31:0] dst_crc32
);
    reg write_request,write_ack;
    reg [1:0] write_ack_sync,write_request_sync;
    reg [7:0] held_key;
    reg [31:0] held_segments,held_directions;
    reg [2:0] held_exit;reg [1:0] held_status;

    reg commit_pending,commit_request,commit_ack;
    reg [1:0] commit_ack_sync,commit_request_sync;
    reg held_crc_ok,held_checked,held_assets_match;
    reg [15:0] held_version;reg [31:0] held_crc32;
    assign src_ready=write_request==write_ack_sync[1];

    always @(posedge src_clk or posedge src_rst)begin
        if(src_rst)begin
            write_request<=0;write_ack_sync<=0;src_overflow<=0;
            held_key<=0;held_segments<=0;held_directions<=0;
            held_exit<=0;held_status<=0;commit_pending<=0;
            commit_request<=0;commit_ack_sync<=0;held_crc_ok<=0;
            held_checked<=0;held_assets_match<=0;held_version<=0;
            held_crc32<=0;
        end else begin
            write_ack_sync<={write_ack_sync[0],write_ack};
            commit_ack_sync<={commit_ack_sync[0],commit_ack};
            if(src_write)begin
                if(src_ready)begin
                    held_key<=src_key;held_segments<=src_segments;
                    held_directions<=src_directions;held_exit<=src_exit;
                    held_status<=src_status;write_request<=!write_request;
                end else src_overflow<=1;
            end
            if(src_commit)begin
                held_crc_ok<=src_crc_ok;held_checked<=src_checked;
                held_assets_match<=src_assets_match;held_version<=src_version;
                held_crc32<=src_crc32;commit_pending<=1;
            end
            if(commit_pending&&write_request==write_ack_sync[1]&&
                    commit_request==commit_ack_sync[1])begin
                commit_request<=!commit_request;commit_pending<=0;
            end
        end
    end

    always @(posedge dst_clk or posedge dst_rst)begin
        if(dst_rst)begin
            write_request_sync<=0;write_ack<=0;commit_request_sync<=0;
            commit_ack<=0;dst_write<=0;dst_key<=0;dst_segments<=0;
            dst_directions<=0;dst_exit<=0;dst_status<=0;dst_commit<=0;
            dst_crc_ok<=0;dst_checked<=0;dst_assets_match<=0;
            dst_version<=0;dst_crc32<=0;
        end else begin
            dst_write<=0;dst_commit<=0;
            write_request_sync<={write_request_sync[0],write_request};
            commit_request_sync<={commit_request_sync[0],commit_request};
            if(write_request_sync[1]!=write_ack)begin
                dst_key<=held_key;dst_segments<=held_segments;
                dst_directions<=held_directions;dst_exit<=held_exit;
                dst_status<=held_status;dst_write<=1;
                write_ack<=write_request_sync[1];
            end
            if(commit_request_sync[1]!=commit_ack)begin
                dst_crc_ok<=held_crc_ok;dst_checked<=held_checked;
                dst_assets_match<=held_assets_match;dst_version<=held_version;
                dst_crc32<=held_crc32;dst_commit<=1;
                commit_ack<=commit_request_sync[1];
            end
        end
    end
endmodule
