`timescale 1ns/1ps

module audio_output_stage #(parameter integer SATURATING_FLAGS=0)(
    input wire clk,input wire rst,input wire sample_valid,
    input wire signed [17:0] sample_in,input wire [2:0] volume_level,
    input wire mute,
    output reg output_valid,output reg signed [15:0] sample_out,
    output reg [15:0] peak_absolute,
    output reg [31:0] limited_count,output reg [31:0] clipped_count,
    output reg overrun
);
    reg [10:0] requested_gain;
    always @* begin
        case(volume_level)
            0:requested_gain=91;
            1:requested_gain=129;
            2:requested_gain=182;
            3:requested_gain=257;
            4:requested_gain=363;
            5:requested_gain=513;
            6:requested_gain=725;
            default:requested_gain=1024;
        endcase
        if(mute)requested_gain=0;
    end
    localparam IDLE=0,RAMP=1,MULTIPLY=2,LIMIT=3;
    reg [1:0] state;
    reg [10:0] gain,target,delta;
    reg [11:0] remainder;
    reg descending;
    reg [7:0] remaining;
    reg [4:0] deadline;
    reg signed [17:0] sample_q;
    reg signed [29:0] product;
    wire signed [19:0] scaled=product>>>10;
    wire [19:0] magnitude=scaled[19] ? -scaled : scaled;

    wire [19:0] compressed=magnitude>24576 ?
        20'd24576+((magnitude-20'd24576)>>2) : magnitude;
    wire [15:0] bounded=compressed>32767 ? 16'd32767 : compressed[15:0];
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=IDLE;gain<=0;target<=0;delta<=0;remainder<=0;
            descending<=0;remaining<=0;sample_q<=0;product<=0;
            deadline<=0;
            output_valid<=0;sample_out<=0;peak_absolute<=0;
            limited_count<=0;clipped_count<=0;overrun<=0;
        end else begin

            output_valid<=deadline==1;
            if(deadline!=0)deadline<=deadline-1'b1;
            if(sample_valid&&(state!=IDLE||deadline!=0))overrun<=1;
            case(state)
                IDLE:if(sample_valid&&deadline==0)begin
                    deadline<=16;
                    sample_q<=sample_in;
                    if(requested_gain!=target)begin
                        target<=requested_gain;descending<=requested_gain<gain;
                        delta<=requested_gain<gain ? gain-requested_gain : requested_gain-gain;
                        remainder<=requested_gain<gain ? gain-requested_gain : requested_gain-gain;
                        remaining<=240;state<=RAMP;
                    end else if(remaining!=0)begin
                        remainder<=remainder+delta;state<=RAMP;
                    end else state<=MULTIPLY;
                end
                RAMP:if(remainder>=240)begin
                    remainder<=remainder-240;
                    gain<=descending ? gain-1'b1 : gain+1'b1;
                end else begin remaining<=remaining-1'b1;state<=MULTIPLY;end
                MULTIPLY:begin product<=sample_q*$signed({1'b0,gain});state<=LIMIT;end
                LIMIT:begin
                    sample_out<=scaled[19] ? -$signed(bounded) : $signed(bounded);
                    state<=IDLE;
                    if(bounded>peak_absolute)peak_absolute<=bounded;
                    if(magnitude>24576&&limited_count!=32'hffffffff)
                        limited_count<=SATURATING_FLAGS ? 32'd1 : limited_count+1'b1;
                    if(compressed>32767&&clipped_count!=32'hffffffff)
                        clipped_count<=SATURATING_FLAGS ? 32'd1 : clipped_count+1'b1;
                end
            endcase
        end
    end
endmodule
