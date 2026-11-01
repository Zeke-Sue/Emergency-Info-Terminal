`timescale 1ns/1ps
module uart_tx_8n1 #(
    parameter integer CLK_HZ=25000000,
    parameter integer BAUD=115200
)(
    input wire clk,input wire rst,
    input wire [7:0] data,input wire valid,
    output wire ready,output reg tx
);
    localparam integer CLKS_PER_BIT=CLK_HZ/BAUD;
    reg [15:0] count;
    reg [3:0] bit_index;
    reg [9:0] shift;
    reg busy;
    assign ready=!busy;
    always @(posedge clk or posedge rst) begin
        if(rst) begin count<=0;bit_index<=0;shift<=10'h3ff;busy<=0;tx<=1;end
        else if(!busy) begin
            tx<=1;
            if(valid) begin
                shift<={1'b1,data,1'b0};tx<=0;busy<=1;bit_index<=0;
                count<=CLKS_PER_BIT-1;
            end
        end else if(count!=0) count<=count-1'b1;
        else if(bit_index==9) begin busy<=0;tx<=1;end
        else begin
            bit_index<=bit_index+1'b1;shift<={1'b1,shift[9:1]};
            tx<=shift[1];count<=CLKS_PER_BIT-1;
        end
    end
endmodule
