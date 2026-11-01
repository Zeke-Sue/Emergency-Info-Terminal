`timescale 1ns/1ps

module n10_prototype_route_loader(
    input wire clk,input wire rst,
    output reg cfg_write,output reg [7:0] cfg_blocked_key,
    output reg [31:0] cfg_segment_mask,output reg [31:0] cfg_direction_mask,
    output reg [2:0] cfg_exit,output reg [1:0] cfg_status,
    output reg cfg_commit,output wire cfg_crc_ok,output wire cfg_checked,
    output wire cfg_assets_match,output wire [15:0] cfg_version,
    output wire [31:0] cfg_crc32
);
    reg loading;
    assign cfg_crc_ok=1'b1;
    assign cfg_checked=1'b1;
    assign cfg_assets_match=1'b1;
    assign cfg_version=16'h4101;
    assign cfg_crc32=32'h21608fac;
    always @* begin
        cfg_direction_mask=0;
        if(cfg_blocked_key[1:0]==2'b11)begin
            cfg_segment_mask=0;cfg_exit=0;cfg_status=1;
        end else if(cfg_blocked_key[0])begin
            cfg_segment_mask=32'h0000001c;cfg_exit=2;cfg_status=0;
        end else begin
            cfg_segment_mask=32'h00000003;cfg_exit=1;cfg_status=0;
        end
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin loading<=1;cfg_write<=1;cfg_blocked_key<=0;cfg_commit<=0;end
        else begin
            cfg_commit<=0;
            if(loading)begin
                cfg_write<=1;
                if(cfg_blocked_key==8'hff)begin loading<=0;cfg_blocked_key<=0;end
                else cfg_blocked_key<=cfg_blocked_key+1'b1;
            end else if(cfg_write)begin
                cfg_write<=0;cfg_commit<=1;
            end
        end
    end
endmodule
