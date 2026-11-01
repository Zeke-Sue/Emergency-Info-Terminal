`timescale 1ns/1ps

module axis_fifo #(parameter integer AW=10, DW=26)(
    input wire clk, rst,
    input wire push,
    input wire [DW-1:0] push_data,
    output reg overflow,
    output reg valid,
    input wire ready,
    output reg [DW-1:0] data
);
    localparam integer DEPTH=1<<AW;
    reg [DW-1:0] ram [0:DEPTH-1];
    reg [AW-1:0] wptr, rptr;
    reg [AW:0] count;
    wire pop = (!valid || ready) && count != 0;
    wire accept = push && (count < DEPTH || pop);
    always @(posedge clk) begin
        if (accept) ram[wptr] <= push_data;
        if (pop) data <= ram[rptr];
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin wptr<=0; rptr<=0; count<=0; valid<=0; overflow<=0; end
        else begin
            if (push && !accept) overflow<=1;
            if (accept) wptr<=wptr+1'b1;
            if (pop) begin rptr<=rptr+1'b1; valid<=1; end
            else if (ready) valid<=0;
            case ({accept,pop})
                2'b10: count<=count+1'b1;
                2'b01: count<=count-1'b1;
            endcase
        end
    end
endmodule
