`timescale 1ns/1ps

module key_events_shared #(
    parameter integer DEBOUNCE_CYCLES=500000,LONG_CYCLES=25000000
)(
    input wire clk,rst,
    input wire [3:0] key_n,
    output reg [3:0] press,short_release,long_press,
    output wire [3:0] held
);
    localparam integer DB_BITS=DEBOUNCE_CYCLES<2 ? 1 : $clog2(DEBOUNCE_CYCLES);
    localparam integer HOLD_BITS=LONG_CYCLES<2 ? 1 : $clog2(LONG_CYCLES);
    reg [DB_BITS-1:0] divider;
    reg [3:0] meta,synced,previous,dirty,stable_n,long_sent;
    reg [HOLD_BITS-1:0] hold_count [0:3];
    integer k;
    assign held=~stable_n;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            meta<=15;synced<=15;previous<=15;stable_n<=15;
            dirty<=0;long_sent<=0;divider<=0;
            press<=0;short_release<=0;long_press<=0;
            for(k=0;k<4;k=k+1)hold_count[k]<=0;
        end else begin
            meta<=key_n;synced<=meta;previous<=synced;
            press<=0;short_release<=0;long_press<=0;
            dirty<=dirty|(synced^previous);
            if(divider==DEBOUNCE_CYCLES-1)begin
                divider<=0;dirty<=0;
                for(k=0;k<4;k=k+1)begin
                    if(!dirty[k] && synced[k]==previous[k] && synced[k]!=stable_n[k])begin
                        stable_n[k]<=synced[k];
                        if(!synced[k])begin
                            press[k]<=1;hold_count[k]<=0;long_sent[k]<=0;
                        end else if(!long_sent[k])short_release[k]<=1;
                    end
                end
            end else divider<=divider+1'b1;
            for(k=0;k<4;k=k+1)begin
                if(!stable_n[k] && !long_sent[k])begin
                    if(hold_count[k]==LONG_CYCLES-1)begin
                        long_press[k]<=1;long_sent[k]<=1;
                    end else hold_count[k]<=hold_count[k]+1'b1;
                end
            end
        end
    end
endmodule
