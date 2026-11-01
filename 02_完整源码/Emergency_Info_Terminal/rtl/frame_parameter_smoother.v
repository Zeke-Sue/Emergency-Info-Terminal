// 在帧边界推进画面参数，避免同一帧内出现不一致的参数值。
`timescale 1ns/1ps

module frame_parameter_smoother #(
    parameter integer WIDTH=9,
    parameter signed [WIDTH-1:0] INITIAL_VALUE=0
)(
    input wire clk,rst,frame_tick,
    input wire signed [WIDTH-1:0] target,
    output wire signed [WIDTH-1:0] value,
    output wire busy
);
    reg signed [WIDTH+4:0] accumulator;
    reg signed [WIDTH:0] step;
    reg signed [WIDTH-1:0] target_q;
    reg [5:0] remaining;
    wire signed [WIDTH:0] delta={target[WIDTH-1],target}-{value[WIDTH-1],value};
    assign value=accumulator[WIDTH+4:5];
    assign busy=remaining!=0 || target!=target_q;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            accumulator<={INITIAL_VALUE,5'd0};target_q<=INITIAL_VALUE;
            step<=0;remaining<=0;
        end else if(frame_tick)begin
            if(target!=target_q)begin
                target_q<=target;step<=delta;remaining<=31;
                accumulator<=$signed({value,5'd0})+delta;
            end else if(remaining!=0)begin
                remaining<=remaining-1'b1;
                accumulator<=remaining==1 ? $signed({target_q,5'd0}) : accumulator+step;
            end
        end
    end
endmodule
