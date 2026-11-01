`timescale 1ns/1ps

module audio_sample_fifo #(
    parameter integer AW=9
)(
    input wire wr_clk,input wire wr_rst,input wire wr_flush,
    input wire wr_valid,input wire signed [15:0] wr_data,output wire wr_ready,
    output reg wr_overflow,
    input wire rd_clk,input wire rd_rst,input wire rd_ready,
    output reg rd_valid,output reg signed [15:0] rd_data
);
    reg signed [15:0] memory [0:(1<<AW)-1];
    reg [AW:0] wr_binary,wr_gray,rd_binary,rd_gray;
    reg [AW:0] rd_gray_w1,rd_gray_w2,wr_gray_r1,wr_gray_r2;
    reg flush_toggle,flush_r1,flush_r2,flush_seen;
    reg flush_active,flush_ack,flush_ack_w1,flush_ack_w2;
    reg [1:0] flush_settle;
    reg [1:0] wr_reset_release,rd_reset_release;
    wire reset_all=wr_rst|rd_rst;
    always @(posedge wr_clk or posedge reset_all)
        if(reset_all)wr_reset_release<=3;
        else wr_reset_release<={wr_reset_release[0],1'b0};
    always @(posedge rd_clk or posedge reset_all)
        if(reset_all)rd_reset_release<=3;
        else rd_reset_release<={rd_reset_release[0],1'b0};
    wire reset_write=wr_reset_release[1];
    wire reset_read=rd_reset_release[1];
    wire [AW:0] wr_binary_next=wr_binary+1'b1;
    wire [AW:0] wr_gray_next=(wr_binary_next>>1)^wr_binary_next;
    wire full=wr_gray_next=={~rd_gray_w2[AW:AW-1],rd_gray_w2[AW-2:0]};
    wire empty=rd_gray==wr_gray_r2;
    assign wr_ready=!full&&!flush_active&&!wr_flush&&!reset_write;

    always @(posedge wr_clk)begin
        if(wr_valid&&wr_ready)memory[wr_binary[AW-1:0]]<=wr_data;
    end
    always @(posedge wr_clk or posedge reset_write)begin
        if(reset_write)begin
            wr_binary<=0;wr_gray<=0;rd_gray_w1<=0;rd_gray_w2<=0;
            flush_toggle<=0;wr_overflow<=0;
            flush_active<=0;flush_ack_w1<=0;flush_ack_w2<=0;
        end else begin
            rd_gray_w1<=rd_gray;rd_gray_w2<=rd_gray_w1;
            flush_ack_w1<=flush_ack;flush_ack_w2<=flush_ack_w1;
            if(wr_flush)begin
                wr_binary<=0;wr_gray<=0;
                if(!flush_active)begin flush_toggle<=!flush_toggle;flush_active<=1;end
            end else if(flush_active)begin
                if(flush_ack_w2==flush_toggle)flush_active<=0;
            end else if(wr_valid&&wr_ready)begin
                wr_binary<=wr_binary_next;wr_gray<=wr_gray_next;
            end
            if(wr_valid&&!wr_ready&&!flush_active&&!wr_flush)wr_overflow<=1;
        end
    end

    always @(posedge rd_clk or posedge reset_read)begin
        if(reset_read)begin
            rd_binary<=0;rd_gray<=0;wr_gray_r1<=0;wr_gray_r2<=0;
            flush_r1<=0;flush_r2<=0;flush_seen<=0;rd_valid<=0;rd_data<=0;
            flush_ack<=0;flush_settle<=0;
        end else begin
            wr_gray_r1<=wr_gray;wr_gray_r2<=wr_gray_r1;
            flush_r1<=flush_toggle;flush_r2<=flush_r1;
            if(flush_r2!=flush_seen)begin
                flush_seen<=flush_r2;rd_binary<=0;rd_gray<=0;rd_valid<=0;
                flush_settle<=3;
            end else if(flush_settle!=0)begin

                rd_binary<=0;rd_gray<=0;rd_valid<=0;
                flush_settle<=flush_settle-1'b1;
                if(flush_settle==1)flush_ack<=flush_seen;
            end else if((!rd_valid||rd_ready)&&!empty)begin
                rd_data<=memory[rd_binary[AW-1:0]];
                rd_binary<=rd_binary+1'b1;
                rd_gray<=((rd_binary+1'b1)>>1)^(rd_binary+1'b1);
                rd_valid<=1;
            end else if(rd_ready)rd_valid<=0;
        end
    end
endmodule
