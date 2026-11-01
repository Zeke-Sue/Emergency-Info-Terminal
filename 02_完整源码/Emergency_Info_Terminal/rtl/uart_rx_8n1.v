`timescale 1ns/1ps
module uart_rx_8n1 #(
    parameter integer CLK_HZ=25000000,
    parameter integer BAUD=115200
)(
    input wire clk,
    input wire rst,
    input wire rx,
    output reg [7:0] data,
    output reg valid,
    output reg framing_error
);
    localparam integer CLKS_PER_BIT=CLK_HZ/BAUD;
    reg rx_meta,rx_sync;
    reg [15:0] count;
    reg [3:0] bit_index;
    reg [7:0] shift;
    reg busy;
    always @(posedge clk or posedge rst) begin
        if(rst) begin rx_meta<=1;rx_sync<=1;count<=0;bit_index<=0;shift<=0;busy<=0;
            data<=0;valid<=0;framing_error<=0;end
        else begin
            rx_meta<=rx;rx_sync<=rx_meta;valid<=0;framing_error<=0;
            if(!busy) begin
                if(!rx_sync) begin busy<=1;count<=CLKS_PER_BIT/2;bit_index<=0;end
            end else if(count!=0) count<=count-1'b1;
            else if(bit_index==0) begin
                if(rx_sync) busy<=0;
                else begin count<=CLKS_PER_BIT-1;bit_index<=1;end
            end else if(bit_index<=8) begin
                shift[bit_index-1]<=rx_sync;count<=CLKS_PER_BIT-1;bit_index<=bit_index+1'b1;
            end else begin
                busy<=0;
                if(rx_sync) begin data<=shift;valid<=1;end
                else framing_error<=1;
            end
        end
    end
endmodule
