// 短按预确认后长按提交；超时、权限变化或取消时清除确认状态。
`timescale 1ns/1ps

module operator_confirmation #(
    parameter integer HOLD_MS=2000,
    parameter integer TIMEOUT_MS=10000,
    parameter integer CONTEXT_BITS=16
)(
    input wire clk,rst,ms_tick,
    input wire arm,cancel,held,eligible,
    input wire [CONTEXT_BITS-1:0] context,
    output reg armed,confirmed,expired,denied,
    output wire [CONTEXT_BITS-1:0] confirmed_context,
    output reg [4:0] progress
);
    localparam HOLD_BITS=HOLD_MS<2 ? 1 : $clog2(HOLD_MS+1);
    localparam TIME_BITS=TIMEOUT_MS<2 ? 1 : $clog2(TIMEOUT_MS);
    localparam STEP_MS=HOLD_MS<20 ? 1 : HOLD_MS/20;
    localparam STEP_BITS=STEP_MS<2 ? 1 : $clog2(STEP_MS);
    reg [HOLD_BITS-1:0] hold_count;
    reg [TIME_BITS-1:0] elapsed;
    reg [STEP_BITS-1:0] step_count;
    reg [CONTEXT_BITS-1:0] saved_context;
    assign confirmed_context=saved_context;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            armed<=0;confirmed<=0;expired<=0;denied<=0;progress<=0;
            hold_count<=0;elapsed<=0;step_count<=0;saved_context<=0;
        end else begin
            confirmed<=0;
            if(cancel||(armed&&(context!=saved_context||!eligible)))begin
                armed<=0;hold_count<=0;elapsed<=0;step_count<=0;progress<=0;
                denied<=armed&&!eligible;
            end else if(arm)begin
                armed<=!armed&&eligible;expired<=0;denied<=!eligible;
                hold_count<=0;elapsed<=0;step_count<=0;progress<=0;
                saved_context<=context;
            end else if(armed)begin
                if(!held)begin hold_count<=0;step_count<=0;progress<=0;end
                if(ms_tick)begin
                    if(elapsed==TIMEOUT_MS-1)begin
                        armed<=0;expired<=1;hold_count<=0;step_count<=0;progress<=0;
                    end else begin
                        elapsed<=elapsed+1'b1;
                        if(held)begin

                            if(hold_count==HOLD_MS)begin
                                confirmed<=1;armed<=0;progress<=20;hold_count<=0;step_count<=0;
                            end else begin
                                hold_count<=hold_count+1'b1;
                                if(step_count==STEP_MS-1)begin
                                    step_count<=0;
                                    if(progress<19)progress<=progress+1'b1;
                                end else step_count<=step_count+1'b1;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
