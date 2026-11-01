`timescale 1ns/1ps

module local_fire_control #(
    parameter integer CLK_HZ=25000000,
    parameter integer DEBOUNCE_CYCLES=500000,
    parameter integer CONFIRM_CYCLES=2*CLK_HZ,
    parameter integer TIMEOUT_CYCLES=10*CLK_HZ
)(
    input wire clk,rst,contact_raw,
    input wire previous,next,confirm,back,confirm_held,
    output reg contact_closed,fire_active,fire_confirmed,evacuation,
    output reg menu_visible,armed,
    output reg [1:0] role,selection,
    output reg [3:0] result,
    output reg action_valid,
    output reg [1:0] action,
    output reg [15:0] event_version
);
    localparam DB_BITS=DEBOUNCE_CYCLES<2 ? 1 : $clog2(DEBOUNCE_CYCLES);
    localparam HOLD_BITS=CONFIRM_CYCLES<2 ? 1 : $clog2(CONFIRM_CYCLES);
    localparam TIME_BITS=TIMEOUT_CYCLES<2 ? 1 : $clog2(TIMEOUT_CYCLES);
    reg contact_meta,contact_sync;
    reg [DB_BITS-1:0] debounce_count;
    reg [HOLD_BITS-1:0] hold_count;
    reg [TIME_BITS-1:0] timeout_count;
    wire contact_commit=contact_sync!=contact_closed&&debounce_count==DEBOUNCE_CYCLES-1;
    wire closing=contact_commit&&contact_sync;

    wire reset_safe=!contact_closed&&!contact_sync&&!contact_meta;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            contact_meta<=0;contact_sync<=0;contact_closed<=0;debounce_count<=0;
            fire_active<=0;fire_confirmed<=0;evacuation<=0;
            menu_visible<=0;armed<=0;role<=0;selection<=0;result<=0;
            hold_count<=0;timeout_count<=0;action_valid<=0;action<=0;event_version<=0;
        end else begin
            contact_meta<=contact_raw;contact_sync<=contact_meta;action_valid<=0;
            if(contact_sync==contact_closed)debounce_count<=0;
            else if(contact_commit)begin contact_closed<=contact_sync;debounce_count<=0;end
            else debounce_count<=debounce_count+1'b1;
            if(closing)begin
                fire_active<=1;fire_confirmed<=0;evacuation<=0;
                event_version<=event_version+1'b1;armed<=0;hold_count<=0;
                action_valid<=1;action<=0;result<=0;
            end
            if(back)begin
                if(armed)armed<=0;
                else menu_visible<=!menu_visible;
                hold_count<=0;timeout_count<=0;
            end else if(menu_visible&&!closing)begin
                if(previous||next)begin
                    armed<=0;hold_count<=0;timeout_count<=0;result<=0;
                    if(selection==0)role<=previous ? role-1'b1 : role+1'b1;
                    else selection<=previous ? selection-1'b1 : selection+1'b1;
                end else if(confirm&&!armed)begin
                    if(selection==0)begin selection<=1;result<=0;end
                    else begin armed<=1;timeout_count<=0;hold_count<=0;result<=0;end
                end
                if(armed)begin
                    if(timeout_count==TIMEOUT_CYCLES-1)begin
                        armed<=0;result<=4'd4;hold_count<=0;
                    end else begin
                        timeout_count<=timeout_count+1'b1;
                        if(!confirm_held)hold_count<=0;
                        else if(hold_count==CONFIRM_CYCLES-1&&!previous&&!next&&!confirm)begin
                            armed<=0;hold_count<=0;
                            if(role!=2)result<=4'd1;
                            else if(!fire_active)result<=4'd2;
                            else if(selection==3&&!reset_safe)result<=4'd3;
                            else if(selection==2&&!fire_confirmed)result<=4'd5;
                            else begin
                                result<=0;action_valid<=1;action<=selection;
                                event_version<=event_version+1'b1;
                                case(selection)
                                    1:fire_confirmed<=1;
                                    2:evacuation<=1;
                                    3:begin fire_active<=0;fire_confirmed<=0;evacuation<=0;end
                                endcase
                            end
                        end else if(confirm_held)hold_count<=hold_count+1'b1;
                    end
                end
            end else if(!armed)begin hold_count<=0;timeout_count<=0;end
        end
    end
endmodule
