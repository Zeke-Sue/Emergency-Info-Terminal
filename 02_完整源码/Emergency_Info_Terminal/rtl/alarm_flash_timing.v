`timescale 1ns/1ps

module alarm_flash_timing #(
    parameter integer TICKS_PER_MINUTE=60000000
)(
    input wire clk,rst,tick,frame_tick,enable,steady,
    input wire [1:0] rate_select,duty_select,
    output reg flash_on
);
    localparam integer PHASE_BITS=$clog2(TICKS_PER_MINUTE+50);
    reg [PHASE_BITS-1:0] phase;
    reg [1:0] rate_q,duty_q;
    wire [5:0] increment=rate_q==0 ? 6'd40 : rate_q==2 ? 6'd50 : 6'd45;
    wire [PHASE_BITS:0] advanced={1'b0,phase}+increment;
    wire [PHASE_BITS-1:0] on_limit=duty_q==0 ? TICKS_PER_MINUTE/4 :
        duty_q==2 ? TICKS_PER_MINUTE/6 : TICKS_PER_MINUTE/5;
    wire changed=rate_select!=rate_q||duty_select!=duty_q;
    always @(posedge clk or posedge rst)begin
        if(rst)begin phase<=0;rate_q<=1;duty_q<=1;flash_on<=0;end
        else begin
            if(!enable)phase<=0;
            else if(tick)phase<=advanced>=TICKS_PER_MINUTE ?
                advanced-TICKS_PER_MINUTE : advanced;
            if(frame_tick)begin
                rate_q<=rate_select;duty_q<=duty_select;
                if(changed)phase<=0;
                flash_on<=enable&&(steady||changed||phase<on_limit);
            end
        end
    end
endmodule
